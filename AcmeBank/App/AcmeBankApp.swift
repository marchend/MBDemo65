import SwiftUI

/// AcmeBank composition root.
///
/// This is the single place in the app that wires concrete
/// implementations to abstract collaborators. It owns:
///
///   1. The validated `OktaConfig` loaded from the built `Info.plist`.
///   2. The real `OktaAuthService` (built on top of that config and a
///      `KeychainStore`).
///   3. The single app-wide `LoginViewModel` that consumes that service.
///
/// Per the repo rule "constructor injection; no service locator", every
/// dependency is passed in at the construction site below — no
/// singletons, no `EnvironmentValues` for services. The view layer
/// (`LoginView`, `LandingView`) observes `LoginViewModel.signedInSession`
/// through ordinary SwiftUI state and switches the root accordingly.
///
/// Deleted in this PR: the previous `ContentView` placeholder that
/// instantiated its own `LoginViewModel()`. Two view models racing for
/// the same auth state would have made `signedInSession` unobservable
/// from the App, so the composition root now owns the only instance.
@main
struct AcmeBankApp: App {

    /// The validated Okta tenant config, loaded once at app start. When
    /// any required `OKTA_*` env var was missing at build time this is
    /// `.notConfigured(reason:)`; we surface that reason as an inline
    /// banner on the login screen so the app still launches cleanly on
    /// CI without secrets.
    private let oktaConfig: OktaConfig

    /// The single app-wide `LoginViewModel`. `@StateObject` so SwiftUI
    /// keeps it alive across re-renders and we observe its `@Published`
    /// `signedInSession` from `RootView`.
    @StateObject private var loginViewModel: LoginViewModel

    init() {
        let config = OktaConfig.load()
        self.oktaConfig = config

        // Build the real auth service against the validated config and
        // a shared `KeychainStore`. The service short-circuits on
        // `.notConfigured` before any network call, so it is safe to
        // construct here even when the build has no Okta secrets.
        let service = OktaAuthService(
            config: config,
            keychain: KeychainStore()
        )

        // Pre-seed the banner copy when the build itself is not
        // configured, so the user (and the
        // `NotConfiguredBannerUITests` CI gate) see the not-configured
        // message immediately on launch — without waiting for a
        // (necessarily-failing) tap on Sign in.
        let viewModel = LoginViewModel(authService: service)
        if case .notConfigured = config {
            viewModel.errorMessage = LoginViewModel.copy(for: .notConfigured(""))
        }
        _loginViewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: loginViewModel)
        }
    }
}

/// Top-level root view. Observes the composition-root `LoginViewModel`
/// and conditionally swaps `LoginView` for `LandingView` the moment
/// `signedInSession` becomes non-nil.
///
/// Using a conditional root swap (rather than a `NavigationStack` path
/// push) keeps the post-auth landing surface unambiguously the only
/// thing on screen — no back-stack the user could accidentally pop
/// back to the login form on. A coordinator-driven `NavigationStack`
/// is a future-PR concern.
private struct RootView: View {

    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        if let session = viewModel.signedInSession {
            LandingView(session: session)
        } else {
            LoginView(viewModel: viewModel)
        }
    }
}
