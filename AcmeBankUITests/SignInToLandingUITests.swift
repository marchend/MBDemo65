import XCTest

/// End-to-end XCUITest that drives a real sign-in against the live
/// Okta tenant and asserts the post-auth `LandingView` displays the
/// expected `displayName` / `email`.
///
/// **Configuration contract:** the test runner process must export
/// `OKTA_TEST_USERNAME` and `OKTA_TEST_PASSWORD` (the test account's
/// credentials) AND the four build-time `OKTA_*` vars
/// (`OKTA_ISSUER`, `OKTA_CLIENT_ID`, `OKTA_REDIRECT_URI`,
/// `OKTA_SCOPES`) so the app under test was actually built against a
/// real tenant. When any of those is missing, every test in this
/// suite skips via `XCTSkipUnless(Self.isOktaConfigured(), …)` —
/// keeping CI without secrets green.
///
/// `Self.isOktaConfigured()` is a process-env probe — a local mirror
/// of `OktaConfig.isConfigured(in:)`. We replicate the logic inline
/// rather than calling into `AcmeBank` because UI-test bundles run
/// out-of-process and are NOT linked against the host app dylib (no
/// `-bundle_loader`), so any `import AcmeBank` symbol reference
/// produces a link-time "Undefined symbol" error. The semantics match
/// exactly: all four `OKTA_*` vars present, non-empty, and not the
/// build-time sentinel.
///
/// **Credential injection:** we pass the test account's username and
/// password to the app under test via `XCUIApplication.launchEnvironment`,
/// NOT via `typeText`. Xcode's default `XCTestObservation` logs the
/// argument of every `typeText(_:)` call into the test activity log
/// (the `.xcresult` bundle), which on CI is typically retained as a
/// build artefact accessible to anyone with repo read access — i.e.
/// `typeText(password)` would silently leak the test account's
/// password into a low-trust artefact. `launchEnvironment` values are
/// scoped to the app process and are not echoed into the activity log.
/// The app under test honours the env injection only when the explicit
/// `UI_TEST_PREFILL_CREDENTIALS=1` opt-in flag is also set, so a
/// developer machine with stray `OKTA_TEST_*` vars exported can never
/// accidentally see its login form pre-populated.
final class SignInToLandingUITests: XCTestCase {

    // MARK: - Setup

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        // NOTE: do NOT call `app.launch()` here — the credential
        // pre-fill values must be set into `launchEnvironment` BEFORE
        // launch, which the individual tests do in their own setup
        // section. Launching twice would be wasteful and the first
        // launch wouldn't see the env values.
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Local probe

    /// Sentinel written by `InjectOktaConfig.sh` whenever a build-time
    /// `OKTA_*` var is missing. Duplicated here (instead of imported
    /// from `OktaConfig.sentinel`) because UI-test bundles cannot link
    /// against the app module — see file header.
    private static let oktaNotConfiguredSentinel = "__OKTA_NOT_CONFIGURED__"

    /// Mirror of `OktaConfig.isConfigured(in:)` — replicated here so
    /// the UI-test bundle does not need to link against `AcmeBank`.
    /// Returns `true` only when all four `OKTA_*` vars are present in
    /// the test runner's process environment, non-empty, and not the
    /// build-time sentinel.
    private static func isOktaConfigured() -> Bool {
        let env = ProcessInfo.processInfo.environment
        let required = ["OKTA_ISSUER", "OKTA_CLIENT_ID", "OKTA_REDIRECT_URI", "OKTA_SCOPES"]
        for key in required {
            guard let value = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty,
                  value != oktaNotConfiguredSentinel
            else {
                return false
            }
        }
        return true
    }

    // MARK: - Tests

    /// Drives the full sign-in form against the real Okta tenant and
    /// asserts the post-auth `LandingView` greeting displays the
    /// account's `name` claim and its `email` claim.
    func test_validCredentials_navigatesToLandingView() throws {
        try XCTSkipUnless(
            Self.isOktaConfigured(),
            "Okta env vars not set — skipping end-to-end sign-in test"
        )

        let env = ProcessInfo.processInfo.environment
        let username = try XCTUnwrap(
            env["OKTA_TEST_USERNAME"],
            "OKTA_TEST_USERNAME must be set when OKTA_* secrets are configured"
        )
        let password = try XCTUnwrap(
            env["OKTA_TEST_PASSWORD"],
            "OKTA_TEST_PASSWORD must be set when OKTA_* secrets are configured"
        )

        // Even when the env vars are *present* they can be empty
        // strings — a misconfigured CI job (e.g. one that sets the
        // four build-time `OKTA_*` vars but forgets the test-account
        // pair, so the shell exports empties) would otherwise fall
        // through to the field-typing block and fail with an opaque
        // "field did not exist" error. Skip with a clear message
        // instead so the operator sees what's actually wrong.
        try XCTSkipUnless(
            !username.isEmpty && !password.isEmpty,
            "OKTA_TEST_USERNAME / OKTA_TEST_PASSWORD are present but empty — check the CI job's test-account secrets"
        )

        // Pass credentials to the app via `launchEnvironment` so the
        // app pre-populates the username / password fields itself.
        // This avoids `typeText(password)`, which would echo the
        // password into Xcode's test activity log. The opt-in
        // sentinel `UI_TEST_PREFILL_CREDENTIALS=1` gates the app's
        // consumption of these values — without it the app ignores
        // the env vars entirely.
        app.launchEnvironment["UI_TEST_PREFILL_CREDENTIALS"] = "1"
        app.launchEnvironment["OKTA_TEST_USERNAME"] = username
        app.launchEnvironment["OKTA_TEST_PASSWORD"] = password
        app.launch()

        // Confirm the fields were pre-populated. We don't type into
        // them ourselves — the assertion is on `value`, not on a
        // `typeText` call. The password field's `value` is bullets
        // (since SwiftUI's `SecureField` masks it for accessibility),
        // so we only assert non-empty rather than equality.
        let usernameField = app.textFields["LoginView.usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        XCTAssertEqual(
            (usernameField.value as? String) ?? "",
            username,
            "Username field should be pre-populated by the app from launchEnvironment"
        )

        let passwordField = app.secureTextFields["LoginView.passwordFieldSecure"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        let passwordValue = (passwordField.value as? String) ?? ""
        XCTAssertFalse(
            passwordValue.isEmpty,
            "Password field should be pre-populated by the app from launchEnvironment (value is masked as bullets, only non-empty is checked)"
        )

        // Tap Sign in.
        let signInButton = app.buttons["LoginView.signInButton"]
        XCTAssertTrue(signInButton.isEnabled,
                      "Sign in button should enable once both fields are filled")
        signInButton.tap()

        // Wait for the Welcome greeting on LandingView. Real network
        // sign-in over CI can take a few seconds; allow 20s.
        let greeting = app.staticTexts["LandingView.welcomeGreeting"]
        XCTAssertTrue(
            greeting.waitForExistence(timeout: 20),
            "Welcome greeting did not appear after sign-in — check Okta tenant + test credentials"
        )

        // Assert the greeting and email match the configured test
        // account. We expose both as optional env overrides so the
        // test can be pointed at any tenant user without code edits;
        // when the expected values are unset, we fall back to checking
        // structural invariants (greeting prefix + email contains "@").
        if let expectedName = env["OKTA_TEST_EXPECTED_NAME"], !expectedName.isEmpty {
            XCTAssertEqual(
                greeting.label,
                "Welcome, \(expectedName)",
                "LandingView greeting should reflect the ID token's `name` claim"
            )
        } else {
            XCTAssertTrue(
                greeting.label.hasPrefix("Welcome, "),
                "LandingView greeting should start with the 'Welcome, ' prefix"
            )
        }

        let emailLabel = app.staticTexts["LandingView.email"]
        XCTAssertTrue(emailLabel.exists,
                      "LandingView should render the email below the greeting")

        if let expectedEmail = env["OKTA_TEST_EXPECTED_EMAIL"], !expectedEmail.isEmpty {
            XCTAssertEqual(
                emailLabel.label,
                expectedEmail,
                "LandingView email should match the ID token's `email` claim"
            )
        } else {
            XCTAssertTrue(
                emailLabel.label.contains("@"),
                "LandingView email should look like an email address"
            )
        }

        // The login form must be gone — this is the navigation hop the
        // test exists to prove.
        XCTAssertFalse(
            app.otherElements["LoginView"].exists,
            "LoginView should be replaced by LandingView on a successful sign-in"
        )
    }
}
