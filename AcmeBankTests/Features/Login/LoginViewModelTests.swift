import XCTest
import Combine
@testable import AcmeBank

final class LoginViewModelTests: XCTestCase {

    // MARK: - Fakes

    /// Auth service whose `signIn` returns a canned `UserSession` (success)
    /// or throws a canned `Error` (failure). Records the args it was
    /// called with so tests can assert wiring.
    private final class FakeAuthService: AuthService {
        var nextResult: Result<UserSession, Error>
        private(set) var callCount = 0
        private(set) var lastUsername: String?
        private(set) var lastPassword: String?
        private(set) var lastKeepSignedIn: Bool?

        init(_ result: Result<UserSession, Error>) {
            self.nextResult = result
        }

        func signIn(
            username: String,
            password: String,
            keepSignedIn: Bool
        ) async throws -> UserSession {
            callCount += 1
            lastUsername = username
            lastPassword = password
            lastKeepSignedIn = keepSignedIn
            switch nextResult {
            case .success(let s): return s
            case .failure(let e): throw e
            }
        }
    }

    /// Auth service that suspends on `signIn` until the test resumes it
    /// via `release(with:)`. Used to observe `isSigningIn == true` while
    /// the call is in flight without racing the ViewModel's `defer`.
    private final class GatedAuthService: AuthService, @unchecked Sendable {
        private var continuation: CheckedContinuation<UserSession, Error>?
        let started = XCTestExpectation(description: "GatedAuthService.signIn started")
        private(set) var callCount = 0

        func signIn(
            username: String,
            password: String,
            keepSignedIn: Bool
        ) async throws -> UserSession {
            callCount += 1
            started.fulfill()
            return try await withCheckedThrowingContinuation { cont in
                self.continuation = cont
            }
        }

        func release(with result: Result<UserSession, Error>) {
            guard let cont = continuation else {
                XCTFail("release(with:) called before signIn suspended")
                return
            }
            continuation = nil
            switch result {
            case .success(let s): cont.resume(returning: s)
            case .failure(let e): cont.resume(throwing: e)
            }
        }
    }

    // MARK: - Fixtures

    private func makeSession(userId: String = "00uABC") -> UserSession {
        return UserSession(
            userId: userId,
            displayName: "Marc Henderson",
            email: "marc@acmebank.test",
            accessToken: "access-tok",
            authTimestamp: Date(timeIntervalSince1970: 1_700_000_000),
            deviceName: "Test Device"
        )
    }

    // MARK: - Pre-existing closure-path tests (kept intact)

    func test_isSignInEnabled_falseWhenBothFieldsEmpty() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        XCTAssertFalse(vm.isSignInEnabled,
                       "isSignInEnabled should be false when username and password are both empty")
    }

    func test_isSignInEnabled_falseWhenOnlyUsernameProvided() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        vm.username = "user@acmebank.com"
        XCTAssertFalse(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_falseWhenOnlyPasswordProvided() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        vm.password = "s3cr3t!"
        XCTAssertFalse(vm.isSignInEnabled)
    }

    func test_isSignInEnabled_trueWhenBothFieldsNonEmpty() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        vm.username = "user@acmebank.com"
        vm.password = "s3cr3t!"
        XCTAssertTrue(vm.isSignInEnabled)
    }

    func test_signInTapped_doesNotFireClosureWhenDisabled() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        var fired = false
        vm.onSignIn = { _, _, _ in fired = true }
        vm.signInTapped()
        XCTAssertFalse(fired)
    }

    func test_signInTapped_firesClosureWithCorrectArgs() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        vm.username = "user@acmebank.com"
        vm.password = "s3cr3t!"
        vm.keepMeSignedIn = true

        var receivedU: String?, receivedP: String?, receivedK: Bool?
        vm.onSignIn = { u, p, k in receivedU = u; receivedP = p; receivedK = k }
        vm.signInTapped()

        XCTAssertEqual(receivedU, "user@acmebank.com")
        XCTAssertEqual(receivedP, "s3cr3t!")
        XCTAssertEqual(receivedK, true)
    }

    func test_keepMeSignedIn_defaultsFalse() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        XCTAssertFalse(vm.keepMeSignedIn)
    }

    // MARK: - signIn(...) — success path

    func test_signIn_success_publishesSession_andLeavesErrorMessageNil() async {
        let session = makeSession(userId: "00uXYZ")
        let fake = FakeAuthService(.success(session))
        let vm = LoginViewModel(authService: fake)

        await vm.signIn(username: "marc", password: "p@ss", keepSignedIn: true)

        XCTAssertEqual(vm.signedInSession, session,
                       "success must publish the returned UserSession")
        XCTAssertNil(vm.errorMessage,
                     "success must leave errorMessage nil")
        XCTAssertFalse(vm.isSigningIn,
                       "isSigningIn must be false after the call returns")
        XCTAssertEqual(fake.callCount, 1)
        XCTAssertEqual(fake.lastUsername, "marc")
        XCTAssertEqual(fake.lastPassword, "p@ss")
        XCTAssertEqual(fake.lastKeepSignedIn, true)
    }

    // MARK: - signIn(...) — AuthError mapping (exact copy)

    func test_signIn_invalidCredentials_setsExactCopy() async {
        let fake = FakeAuthService(.failure(AuthError.invalidCredentials))
        let vm = LoginViewModel(authService: fake)

        await vm.signIn(username: "marc", password: "wrong", keepSignedIn: false)

        XCTAssertEqual(vm.errorMessage,
                       "Incorrect username or password. Please try again.")
        XCTAssertNil(vm.signedInSession)
        XCTAssertFalse(vm.isSigningIn)
    }

    func test_signIn_networkError_setsExactCopy() async {
        let fake = FakeAuthService(.failure(AuthError.networkError))
        let vm = LoginViewModel(authService: fake)

        await vm.signIn(username: "marc", password: "p", keepSignedIn: false)

        XCTAssertEqual(vm.errorMessage,
                       "Couldn't reach Okta — check your connection and try again.")
        XCTAssertNil(vm.signedInSession)
        XCTAssertFalse(vm.isSigningIn)
    }

    func test_signIn_mfaRequired_setsExactCopy() async {
        let fake = FakeAuthService(.failure(AuthError.mfaRequired))
        let vm = LoginViewModel(authService: fake)

        await vm.signIn(username: "marc", password: "p", keepSignedIn: false)

        XCTAssertEqual(vm.errorMessage,
                       "MFA is required but not supported in this build.")
        XCTAssertNil(vm.signedInSession)
        XCTAssertFalse(vm.isSigningIn)
    }

    func test_signIn_notConfigured_setsExactCopy() async {
        let fake = FakeAuthService(.failure(AuthError.notConfigured("missing OKTA_* env vars")))
        let vm = LoginViewModel(authService: fake)

        await vm.signIn(username: "marc", password: "p", keepSignedIn: false)

        XCTAssertEqual(vm.errorMessage,
                       "Okta is not configured on this build — see README.")
        XCTAssertNil(vm.signedInSession)
        XCTAssertFalse(vm.isSigningIn)
    }

    // MARK: - isSigningIn transitions

    func test_signIn_setsIsSigningInTrueDuringCall_andFalseAfter() async {
        let gate = GatedAuthService()
        let vm = LoginViewModel(authService: gate)

        XCTAssertFalse(vm.isSigningIn, "precondition: idle before tap")

        // Launch the call; we'll observe the in-flight state before
        // releasing the gate.
        let task = Task {
            await vm.signIn(username: "marc", password: "p", keepSignedIn: false)
        }

        // Wait until the fake service has actually been entered. Without
        // this we'd race the Task scheduling and observe `false`
        // because the VM hasn't reached the `isSigningIn = true` line
        // yet.
        await fulfillment(of: [gate.started], timeout: 2.0)

        XCTAssertTrue(vm.isSigningIn,
                      "isSigningIn must be true while the AuthService call is in flight")

        // Let the AuthService return. The defer in signIn flips
        // isSigningIn back to false before the await returns to the
        // Task.
        gate.release(with: .success(makeSession()))
        await task.value

        XCTAssertFalse(vm.isSigningIn,
                       "isSigningIn must be false after the AuthService call returns")
    }

    // MARK: - Double-tap guard

    func test_signIn_secondInvocationWhileInFlight_isNoOp() async {
        let gate = GatedAuthService()
        let vm = LoginViewModel(authService: gate)

        let first = Task {
            await vm.signIn(username: "marc", password: "p", keepSignedIn: false)
        }
        await fulfillment(of: [gate.started], timeout: 2.0)

        // Second tap while the first is still suspended — must be a
        // no-op (no second AuthService call, no state thrash).
        await vm.signIn(username: "different", password: "creds", keepSignedIn: true)

        XCTAssertEqual(gate.callCount, 1,
                       "second signIn while in-flight must NOT call AuthService again")
        XCTAssertTrue(vm.isSigningIn,
                      "second tap must not flip isSigningIn back to false (the defer from a no-op would)")

        // Let the original call complete so the Task doesn't dangle.
        gate.release(with: .success(makeSession()))
        await first.value

        XCTAssertFalse(vm.isSigningIn)
        XCTAssertEqual(gate.callCount, 1,
                       "still exactly one AuthService call after the original completes")
    }

    // MARK: - errorMessage cleared on edit

    func test_editingUsername_clearsErrorMessage() async {
        let fake = FakeAuthService(.failure(AuthError.invalidCredentials))
        let vm = LoginViewModel(authService: fake)

        // Provoke an error first.
        await vm.signIn(username: "marc", password: "wrong", keepSignedIn: false)
        XCTAssertNotNil(vm.errorMessage, "precondition: errorMessage populated")

        // Mutating username via the @Published binding fires the Combine
        // sink wired up in init and clears the banner.
        vm.username = "marc2"

        // Give the Combine sink one runloop tick — `.sink` on a
        // `@Published` from a sync mutation delivers synchronously, but
        // explicit yielding here keeps the test robust against any
        // future scheduler change.
        await Task.yield()

        XCTAssertNil(vm.errorMessage,
                     "editing username must clear errorMessage")
    }

    func test_editingPassword_clearsErrorMessage() async {
        let fake = FakeAuthService(.failure(AuthError.invalidCredentials))
        let vm = LoginViewModel(authService: fake)

        await vm.signIn(username: "marc", password: "wrong", keepSignedIn: false)
        XCTAssertNotNil(vm.errorMessage)

        vm.password = "newpassword"
        await Task.yield()

        XCTAssertNil(vm.errorMessage,
                     "editing password must clear errorMessage")
    }

    // MARK: - Default state

    func test_errorMessage_isNilByDefault() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        XCTAssertNil(vm.errorMessage)
    }

    func test_isSigningIn_isFalseByDefault() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        XCTAssertFalse(vm.isSigningIn)
    }

    func test_signedInSession_isNilByDefault() {
        let vm = LoginViewModel(authService: FakeAuthService(.success(makeSession())))
        XCTAssertNil(vm.signedInSession)
    }
}
