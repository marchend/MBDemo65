import XCTest
import AcmeBank

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
/// suite skips via `XCTSkipUnless(OktaConfig.isConfigured, …)` —
/// keeping CI without secrets green.
///
/// `OktaConfig.isConfigured` here is the static, process-env-based
/// probe — see the doc comment on that property for why
/// `load().isConfigured` won't do (the UI test runner is a separate
/// process with its own `Bundle.main`).
final class SignInToLandingUITests: XCTestCase {

    // MARK: - Setup

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Tests

    /// Drives the full sign-in form against the real Okta tenant and
    /// asserts the post-auth `LandingView` greeting displays the
    /// account's `name` claim and its `email` claim.
    func test_validCredentials_navigatesToLandingView() throws {
        try XCTSkipUnless(
            OktaConfig.isConfigured,
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

        // Type credentials into the login form.
        let usernameField = app.textFields["LoginView.usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["LoginView.passwordFieldSecure"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 3))
        passwordField.tap()
        passwordField.typeText(password)

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
