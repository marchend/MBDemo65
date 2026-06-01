import XCTest

/// XCUITest suite for `LoginView`.
///
/// These tests exercise the full sign-in form at the UI layer: field
/// interaction, button enable/disable guards, eye-icon visibility
/// toggle, keep-me-signed-in checkbox, "Need help?" sheet, and the
/// "Open one" placeholder sheet.
///
/// Important: these tests do NOT sign in against a real Okta endpoint.
/// The `onSignIn` closure in the app is a no-op stub, so tapping
/// "Sign in" never makes a network request.
final class LoginViewUITests: XCTestCase {

    // MARK: - Setup

    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        // bootstrap.md §13.2: pass -UITestMode YES so the app can swap in
        // mock repositories at the boundary.  The flag is a no-op for the
        // current stub sign-in, but the wiring point must be in place before
        // the follow-up Okta auth story lands.
        app.launchArguments += ["-UITestMode", "YES"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Helper accessors

    private var usernameField: XCUIElement {
        app.textFields["LoginView.usernameField"]
    }

    /// The secure (default) password field.
    private var passwordSecureField: XCUIElement {
        app.secureTextFields["LoginView.passwordFieldSecure"]
    }

    /// The plain-text password field shown after the eye-icon is toggled.
    private var passwordVisibleField: XCUIElement {
        app.textFields["LoginView.passwordFieldVisible"]
    }

    private var signInButton: XCUIElement {
        app.buttons["LoginView.signInButton"]
    }

    private var passwordToggle: XCUIElement {
        app.buttons["LoginView.passwordToggle"]
    }

    private var keepMeSignedInToggle: XCUIElement {
        app.buttons["LoginView.keepMeSignedInToggle"]
    }

    private var needHelpButton: XCUIElement {
        app.buttons["LoginView.needHelpButton"]
    }

    private var openOneButton: XCUIElement {
        app.buttons["LoginView.openOneButton"]
    }

    // MARK: - Tests

    /// Verifies that the "Sign in" button exists and is disabled on launch
    /// (before any credentials are entered).
    func test_signInButton_isDisabledOnLaunch() {
        XCTAssertTrue(signInButton.waitForExistence(timeout: 3),
                      "Sign in button should exist on the login screen")
        XCTAssertFalse(signInButton.isEnabled,
                       "Sign in button should be disabled when credentials are empty")
    }

    /// Verifies that entering both a username and password enables the
    /// "Sign in" button.
    func test_signInButton_enablesAfterCredentialsEntered() {
        XCTAssertTrue(usernameField.waitForExistence(timeout: 3))
        usernameField.tap()
        usernameField.typeText("user@acmebank.com")

        XCTAssertTrue(passwordSecureField.waitForExistence(timeout: 3))
        passwordSecureField.tap()
        passwordSecureField.typeText("s3cr3t!")

        XCTAssertTrue(signInButton.isEnabled,
                      "Sign in button should be enabled after both fields are filled")
    }

    /// Verifies that filling only the username field leaves the button
    /// disabled.
    func test_signInButton_remainsDisabledWithOnlyUsername() {
        XCTAssertTrue(usernameField.waitForExistence(timeout: 3))
        usernameField.tap()
        usernameField.typeText("user@acmebank.com")

        XCTAssertFalse(signInButton.isEnabled,
                       "Sign in button should remain disabled when only username is provided")
    }

    /// Verifies that tapping the eye icon switches the password field
    /// from a secure field to a plain-text field.
    func test_passwordToggle_revealsPassword() {
        // The secure field should be present by default.
        XCTAssertTrue(passwordSecureField.waitForExistence(timeout: 3),
                      "Password field should be a SecureField by default")

        // Tap the eye icon to reveal the password.
        XCTAssertTrue(passwordToggle.waitForExistence(timeout: 3))
        passwordToggle.tap()

        // After toggling, the plain-text field should appear.
        XCTAssertTrue(passwordVisibleField.waitForExistence(timeout: 2),
                      "Password field should switch to a plain TextField after tapping the eye icon")
        XCTAssertFalse(passwordSecureField.exists,
                       "SecureField should be hidden when password is revealed")
    }

    /// Verifies that tapping the "Keep me signed in" checkbox toggles
    /// its state without crashing.
    func test_keepMeSignedIn_togglesState() {
        XCTAssertTrue(keepMeSignedInToggle.waitForExistence(timeout: 3),
                      "Keep me signed in checkbox should exist")

        // Tap once — check
        keepMeSignedInToggle.tap()
        XCTAssertTrue(keepMeSignedInToggle.exists,
                      "Checkbox should still exist after first tap")

        // Tap again — uncheck
        keepMeSignedInToggle.tap()
        XCTAssertTrue(keepMeSignedInToggle.exists,
                      "Checkbox should still exist after second tap")
    }

    /// Verifies that tapping "Need help?" presents `SFSafariViewController`.
    ///
    /// `SFSafariViewController` is presented synchronously — the "Done" button
    /// appears in the accessibility tree immediately, before any network load.
    /// This assertion will go red if the `showHelpSheet` binding is never
    /// toggled, giving a real signal rather than a trivially-true liveness
    /// check.
    func test_needHelp_opensSafariSheet() {
        XCTAssertTrue(needHelpButton.waitForExistence(timeout: 3),
                      "Need help? button should exist")

        needHelpButton.tap()

        // SFSafariViewController is presented synchronously even without
        // network.  Its "Done" button is accessible immediately on
        // presentation, so this assertion is achievable in a CI environment
        // with no connectivity.
        let safariDone = app.buttons["Done"].waitForExistence(timeout: 3)
        XCTAssertTrue(safariDone,
                      "SafariVC 'Done' button should appear after tapping 'Need help?'")
    }

    /// Verifies that tapping "Open one" presents the placeholder sheet.
    func test_openOne_opensPlaceholderSheet() {
        XCTAssertTrue(openOneButton.waitForExistence(timeout: 3),
                      "Open one button should exist")

        openOneButton.tap()

        // The placeholder sheet contains a "Coming soon" static text.
        let comingSoon = app.staticTexts["OpenAccountPlaceholderView.title"]
        XCTAssertTrue(comingSoon.waitForExistence(timeout: 3),
                      "OpenAccountPlaceholderView should appear after tapping Open one")
    }
}
