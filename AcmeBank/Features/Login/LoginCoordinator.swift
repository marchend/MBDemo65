import SwiftUI

/// Coordinator for the Login feature.
///
/// Owns the `NavigationStack` path for login-scoped navigation,
/// creates the `LoginViewModel`, injects dependencies, and handles
/// the sign-in callback by notifying the root coordinator.
///
/// Navigation rules:
/// - This coordinator presents `LoginView` as the single entry point.
/// - On successful sign-in it calls `onSignedIn` (injected by the
///   parent `AppCoordinator`) — it does **not** push any further views
///   itself; the root coordinator owns the login → home transition.
@MainActor
final class LoginCoordinator: ObservableObject {

    // MARK: - Navigation State

    /// Navigation path for any push routes inside the login flow
    /// (e.g., a future "Forgot password" screen).
    @Published var path: NavigationPath = NavigationPath()

    // MARK: - Callbacks

    /// Called when the user successfully submits the login form.
    /// `AppCoordinator` injects this closure and handles the
    /// login → home transition.
    var onSignedIn: ((String, String, Bool) -> Void)?

    // MARK: - Root View

    /// Builds the root `View` for the login feature.
    ///
    /// Embed this inside the parent coordinator's body:
    /// ```swift
    /// .fullScreenCover(isPresented: $showLogin) {
    ///     loginCoordinator.rootView()
    /// }
    /// ```
    func rootView() -> some View {
        NavigationStack(path: $path) {
            makeLoginView()
        }
    }

    // MARK: - Factory

    private func makeLoginView() -> LoginView {
        let viewModel = LoginViewModel()
        viewModel.onSignIn = { [weak self] username, password, keepMeSignedIn in
            self?.onSignedIn?(username, password, keepMeSignedIn)
        }
        return LoginView(viewModel: viewModel)
    }
}
