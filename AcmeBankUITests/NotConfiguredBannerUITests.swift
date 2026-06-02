import XCTest
import AcmeBank

/// XCUITest that proves the composition-root + banner wiring works on
/// CI without any Okta secrets.
///
/// Runs unconditionally — no `XCTSkipUnless`. On a build where the
/// `OKTA_*` env vars were not exported to the build script, the app's
/// `Info.plist` is populated with the `__OKTA_NOT_CONFIGURED__`
/// sentinel; `OktaConfig.load()` returns `.notConfigured(reason:)`;
/// `AcmeBankApp` pre-seeds `LoginViewModel.errorMessage` with the
/// "Okta is not configured on this build — see README." copy; and the
/// existing `ErrorBannerView` renders that copy inside `LoginView`.
///
/// We only assert the banner when the build under test is actually
/// not-configured (`OktaConfig.isConfigured == false`). When the test
/// runner *does* have secrets exported (developer machine, signed CI
/// job), this suite still runs but skips the banner assertion and
/// only checks that the post-auth greeting is not yet on screen at
/// launch — i.e. the app starts on `LoginView`, not `LandingView`.
/// That keeps the suite passing in both environments without
/// pretending to verify something that didn't happen.
final class NotConfiguredBannerUITests: XCTestCase {

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

    /// On a build with no Okta secrets, the inline error banner on
    /// launch reads exactly "Okta is not configured on this build —
    /// see README." and the post-auth `LandingView` greeting is NOT
    /// on screen.
    func test_launch_showsNotConfiguredBanner_andHidesWelcomeGreeting() {
        // Confirm we landed on the LoginView (not LandingView).
        let loginView = app.otherElements["LoginView"]
        XCTAssertTrue(
            loginView.waitForExistence(timeout: 5),
            "LoginView should be the root view at launch — the composition root must not auto-navigate without a session"
        )

        // The Welcome greeting must NOT be present. This is the
        // primary acceptance criterion of this suite: a build without
        // secrets must never accidentally render the post-auth
        // landing surface.
        let greeting = app.staticTexts["LandingView.welcomeGreeting"]
        XCTAssertFalse(
            greeting.exists,
            "LandingView greeting must not be on screen at launch — sign-in has not occurred"
        )

        // Banner copy assertion: only meaningful when the build under
        // test is actually not-configured (no OKTA_* secrets exported
        // to the test runner). On a secrets-bearing build the banner
        // is correctly hidden, so we'd false-positive if we asserted
        // its presence unconditionally.
        if !OktaConfig.isConfigured {
            let expectedCopy = "Okta is not configured on this build — see README."

            // `ErrorBannerView` uses `.accessibilityElement(children:
            // .combine)` with `.accessibilityIdentifier(...)`, which
            // exposes the banner as a single combined accessibility
            // element (typically `otherElements`, sometimes
            // `staticTexts`, depending on iOS version). Query both
            // and accept either — the assertion is that the exact
            // expected copy appears somewhere as the banner's label.
            let bannerByID = app.descendants(matching: .any)
                .matching(identifier: "ErrorBannerView.container")
                .firstMatch
            XCTAssertTrue(
                bannerByID.waitForExistence(timeout: 5),
                "Expected the ErrorBannerView to appear on launch when no OKTA_* env vars are set"
            )
            XCTAssertEqual(
                bannerByID.label,
                expectedCopy,
                "The not-configured banner copy must match the README-referenced string exactly"
            )
        }

        // The app must still be alive — no crash on the not-configured
        // path. (Sanity check; if the app died `loginView.exists`
        // would already have failed above.)
        XCTAssertTrue(app.exists, "App should still be running after launch on a not-configured build")
    }
}
