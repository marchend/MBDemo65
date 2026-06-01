import Foundation

/// ViewModel for the Login screen.
///
/// Holds all `@Published` state consumed by `LoginView` and exposes
/// `signInTapped()` as the single action entry point. Authentication
/// logic is injected via the `onSignIn` closure so the ViewModel
/// remains testable without any networking or Okta dependency.
final class LoginViewModel: ObservableObject {

    // MARK: - Published State

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published var keepMeSignedIn: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Injected Action

    /// Called by `signInTapped()` when the form is valid.
    /// Receives `(username, password, keepMeSignedIn)`.
    var onSignIn: ((String, String, Bool) -> Void)?

    // MARK: - Computed

    /// `true` only when both `username` and `password` are non-empty.
    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Actions

    /// Attempts sign-in. Guards on `isSignInEnabled`; no-ops if the
    /// form is incomplete.
    func signInTapped() {
        guard isSignInEnabled else { return }
        onSignIn?(username, password, keepMeSignedIn)
    }
}
