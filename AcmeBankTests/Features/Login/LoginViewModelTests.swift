import XCTest
@testable import AcmeBank

final class LoginViewModelTests: XCTestCase {

    // MARK: - isSignInEnabled

    func test_isSignInEnabled_falseWhenBothFieldsEmpty() {
        let vm = LoginViewModel()
        XCTAssertFalse(vm.isSignInEnabled,
                       "isSignInEnabled should be false when username and password are both empty")
    }

    func test_isSignInEnabled_falseWhenOnlyUsernameProvided() {
        let vm = LoginViewModel()
        vm.username = "user@acmebank.com"
        XCTAssertFalse(vm.isSignInEnabled,
                       "isSignInEnabled should be false when only username is set")
    }

    func test_isSignInEnabled_falseWhenOnlyPasswordProvided() {
        let vm = LoginViewModel()
        vm.password = "s3cr3t!"
        XCTAssertFalse(vm.isSignInEnabled,
                       "isSignInEnabled should be false when only password is set")
    }

    func test_isSignInEnabled_trueWhenBothFieldsNonEmpty() {
        let vm = LoginViewModel()
        vm.username = "user@acmebank.com"
        vm.password = "s3cr3t!"
        XCTAssertTrue(vm.isSignInEnabled,
                      "isSignInEnabled should be true when both username and password are non-empty")
    }

    // MARK: - signInTapped

    func test_signInTapped_doesNotFireClosureWhenDisabled() {
        let vm = LoginViewModel()
        var closureFired = false
        vm.onSignIn = { _, _, _ in closureFired = true }

        // Fields are empty → guard should prevent the closure firing.
        vm.signInTapped()

        XCTAssertFalse(closureFired,
                       "onSignIn closure must not fire when isSignInEnabled is false")
    }

    func test_signInTapped_firesClosureWithCorrectArgs() {
        let vm = LoginViewModel()
        vm.username = "user@acmebank.com"
        vm.password = "s3cr3t!"
        vm.keepMeSignedIn = true

        var receivedUsername: String?
        var receivedPassword: String?
        var receivedKeepMeSignedIn: Bool?

        vm.onSignIn = { username, password, keepMeSignedIn in
            receivedUsername = username
            receivedPassword = password
            receivedKeepMeSignedIn = keepMeSignedIn
        }

        vm.signInTapped()

        XCTAssertEqual(receivedUsername, "user@acmebank.com",
                       "onSignIn should receive the current username")
        XCTAssertEqual(receivedPassword, "s3cr3t!",
                       "onSignIn should receive the current password")
        XCTAssertEqual(receivedKeepMeSignedIn, true,
                       "onSignIn should receive the current keepMeSignedIn value")
    }

    // MARK: - Default state

    func test_errorMessage_isNilByDefault() {
        let vm = LoginViewModel()
        XCTAssertNil(vm.errorMessage,
                     "errorMessage should be nil on initialisation")
    }

    func test_keepMeSignedIn_defaultsFalse() {
        let vm = LoginViewModel()
        XCTAssertFalse(vm.keepMeSignedIn,
                       "keepMeSignedIn should default to false")
    }
}
