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

        // UI-test-only credential pre-fill. The end-to-end
        // `SignInToLandingUITests` injects credentials via
        // `XCUIApplication.launchEnvironment` (not `typeText`) so the
        // test account's password never enters Xcode's test activity
        // log. We only honour these values when an explicit opt-in
        // sentinel (`UI_TEST_PREFILL_CREDENTIALS=1`) is also set, so a
        // developer machine with stray `OKTA_TEST_*` env vars exported
        // can never accidentally see its login form pre-populated.
        Self.applyUITestPrefillIfRequested(to: viewModel)

        _loginViewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: loginViewModel)
        }
    }

    /// Pre-populate `viewModel.username` / `.password` from the app
    /// process environment, but ONLY when the UI-test runner has set
    /// the `UI_TEST_PREFILL_CREDENTIALS=1` opt-in flag via
    /// `XCUIApplication.launchEnvironment`. Without that flag we leave
    /// the fields blank no matter what env vars are present.
    private static func applyUITestPrefillIfRequested(to viewModel: LoginViewModel) {
        let env = ProcessInfo.processInfo.environment
        guard env["UI_TEST_PREFILL_CREDENTIALS"] == "1" else { return }
        if let username = env["OKTA_TEST_USERNAME"], !username.isEmpty {
            viewModel.username = username
        }
        if let password = env["OKTA_TEST_PASSWORD"], !password.isEmpty {
            viewModel.password = password
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
///
/// Note that we deliberately pass only the two display strings down
/// into `LandingView` — not the full `UserSession`. The bearer
/// `accessToken` stays at the composition root and never travels
/// through child views. See `LandingView`'s doc comment for why.
private struct RootView: View {

    @ObservedObject var viewModel: LoginViewModel

    var body: some View {
        if let session = viewModel.signedInSession {
            LandingView(
                displayName: session.displayName,
                email: session.email
            )
        } else {
            LoginView(viewModel: viewModel)
        }
    }
}
