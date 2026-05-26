import XCTest

/// XCUITest suite for the Login critical user flow.
///
/// Covers the acceptance criteria from bootstrap.md §13.2:
/// field entry → Sign In button enables → tap → stub closure fires.
///
/// The app is launched with `-UITestMode YES` so it can substitute
/// mock repositories and a stub sign-in closure instead of real Okta.
final class LoginUITests: XCTestCase {

    // MARK: - Setup

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITestMode", "YES"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Sign In Button State

    /// The Sign In button must be disabled when both fields are empty.
    func test_signInButton_disabledWhenFieldsEmpty() {
        let signInButton = app.buttons["signInButton"]
        XCTAssertTrue(
            signInButton.waitForExistence(timeout: 5),
            "signInButton should exist on the login screen"
        )
        XCTAssertFalse(
            signInButton.isEnabled,
            "signInButton must be disabled when username and password are both empty"
        )
    }

    /// The Sign In button must be disabled when only the username is filled.
    func test_signInButton_disabledWhenOnlyUsernameEntered() {
        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText("user@acmebank.com")

        XCTAssertFalse(
            app.buttons["signInButton"].isEnabled,
            "signInButton must remain disabled when password is empty"
        )
    }

    /// The Sign In button must be disabled when only the password is filled.
    func test_signInButton_disabledWhenOnlyPasswordEntered() {
        let passwordField = app.secureTextFields["passwordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText("s3cr3t!")

        XCTAssertFalse(
            app.buttons["signInButton"].isEnabled,
            "signInButton must remain disabled when username is empty"
        )
    }

    /// The Sign In button must enable once both fields have text.
    func test_signInButton_enabledWhenBothFieldsEntered() {
        enterCredentials(username: "user@acmebank.com", password: "s3cr3t!")

        XCTAssertTrue(
            app.buttons["signInButton"].isEnabled,
            "signInButton must be enabled when both username and password are non-empty"
        )
    }

    // MARK: - Happy-path Login Flow

    /// Full happy-path: fill fields → tap Sign In → stub fires → home appears.
    func test_login_happyPath_navigatesToHome() {
        enterCredentials(username: "user@acmebank.com", password: "s3cr3t!")

        app.buttons["signInButton"].tap()

        // In UITestMode the app uses a mock auth stub that immediately
        // satisfies the sign-in and transitions to the home tab bar.
        XCTAssertTrue(
            app.tabBars.element.waitForExistence(timeout: 5),
            "Home tab bar should appear after successful login in UITestMode"
        )
    }

    // MARK: - Password Visibility Toggle

    /// Tapping the eye button switches the password field from secure to plain.
    func test_passwordVisibilityToggle_revealsPassword() {
        let passwordSecure = app.secureTextFields["passwordField"]
        XCTAssertTrue(passwordSecure.waitForExistence(timeout: 5))
        passwordSecure.tap()
        passwordSecure.typeText("s3cr3t!")

        // Before toggle: field is secure
        XCTAssertTrue(
            app.secureTextFields["passwordField"].exists,
            "Password field should be secure before the eye toggle is tapped"
        )

        app.buttons["passwordVisibilityToggle"].tap()

        // After toggle: field is a plain TextField (no longer secure)
        XCTAssertTrue(
            app.textFields["passwordField"].waitForExistence(timeout: 2),
            "Password field should become a plain text field after the eye toggle is tapped"
        )
    }

    // MARK: - Need Help Sheet

    /// Tapping "Need help?" presents the in-app Safari sheet.
    func test_needHelp_presentsSheet() {
        let needHelpButton = app.buttons["needHelpButton"]
        XCTAssertTrue(needHelpButton.waitForExistence(timeout: 5))
        needHelpButton.tap()

        // SFSafariViewController presents a navigation bar with the
        // URL domain visible; we look for the Done button as the
        // stable indicator that the sheet appeared.
        XCTAssertTrue(
            app.buttons["Done"].waitForExistence(timeout: 5),
            "Safari sheet should appear with a Done button after tapping 'Need help?'"
        )
    }

    // MARK: - Helpers

    private func enterCredentials(username: String, password: String) {
        let usernameField = app.textFields["usernameField"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText(username)

        let passwordField = app.secureTextFields["passwordField"]
        passwordField.tap()
        passwordField.typeText(password)
    }
}
