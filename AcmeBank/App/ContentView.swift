import SwiftUI

/// The root view of the AcmeBank app.
///
/// Owns the `LoginViewModel` and presents `LoginView` as the app's
/// entry point. The `onSignIn` closure is a no-op stub until the Okta
/// authentication story lands (deferred to a future PR).
struct ContentView: View {

    @StateObject private var loginViewModel = LoginViewModel()

    var body: some View {
        LoginView(viewModel: loginViewModel)
    }

    // The no-op onSignIn stub is set when the view's StateObject
    // is first used. Because LoginViewModel.onSignIn is optional
    // and signInTapped() guards on isSignInEnabled (which requires
    // non-empty credentials entered by the user), this is safe to
    // leave as nil until real auth is wired in the follow-up story.
    // If a caller needs the stub explicitly, it can inject its own vm.
}

#Preview {
    ContentView()
}
