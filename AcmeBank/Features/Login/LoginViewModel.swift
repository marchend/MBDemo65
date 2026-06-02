import Foundation
import Combine

/// ViewModel for the Login screen.
///
/// Holds all `@Published` state consumed by `LoginView` and exposes two
/// entry points:
///
///   - `signInTapped()` — fires the legacy `onSignIn` closure if set
///     (preserved so existing callers / previews / unit tests that wire
///     a closure directly continue to work).
///   - `signIn(username:password:keepSignedIn:)` — calls the injected
///     `AuthService` directly, driving the `isSigningIn` loading state
///     and mapping any `AuthError` into the exact user-facing copy
///     declared in MD065-7.
///
/// The async path is what `LoginView` invokes from the Sign-in button
/// and what `AcmeBankApp` observes via `signedInSession` to swap the
/// root to `LandingView`. The closure path is left in place because
/// the `LoginViewModelTests` suite still exercises it; new wiring
/// should target the async path.
///
/// Annotated `@MainActor` to guarantee that every `@Published` mutation
/// — including those *after* the `await authService.signIn(...)`
/// suspension point — runs on the main thread. Without this annotation
/// the post-await mutations would run on whatever executor the
/// `AuthService` resumed onto (e.g. a background thread inside the Okta
/// SDK), producing "Publishing changes from background threads is not
/// allowed" runtime warnings and risking dropped renders. The
/// annotation also makes the `isSigningIn` re-entry guard atomic: two
/// Tasks racing into `signIn(...)` are now serialized on the main
/// actor's executor, so the check-then-set can't interleave.
@MainActor
final class LoginViewModel: ObservableObject {

    // MARK: - Published State

    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isPasswordVisible: Bool = false
    @Published var keepMeSignedIn: Bool = false
    @Published var errorMessage: String? = nil

    /// `true` from the moment `signIn(...)` is awaited to the moment the
    /// `AuthService` call returns (success or throw). Drives the View's
    /// field/button disable + spinner swap.
    @Published var isSigningIn: Bool = false

    /// Populated on a successful `signIn(...)`. `AcmeBankApp` (the
    /// composition root) observes this on its `@StateObject`
    /// `LoginViewModel` and swaps the root view from `LoginView` to
    /// `LandingView(displayName:email:)` the moment it becomes non-nil.
    /// The ViewModel never presents or pushes anything itself.
    @Published var signedInSession: UserSession? = nil

    // MARK: - Injected Action (legacy closure path)

    /// Called by `signInTapped()` when the form is valid. Receives
    /// `(username, password, keepMeSignedIn)`. Kept for the existing
    /// closure-based callers / tests; the new async path in `signIn(...)`
    /// bypasses this entirely.
    var onSignIn: ((String, String, Bool) -> Void)?

    // MARK: - Injected dependency

    private let authService: AuthService

    // MARK: - Combine

    /// Subscriptions that clear `errorMessage` whenever the user edits
    /// either credential field. Held for the lifetime of the ViewModel.
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Computed

    /// `true` only when both `username` and `password` are non-empty.
    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty
    }

    // MARK: - Init

    /// - Parameter authService: the auth backend. Every production
    ///   call-site (currently just `AcmeBankApp`, the composition root)
    ///   must supply an explicit service — the repo rule is
    ///   "constructor injection; no service locator", so a
    ///   production-valued default would leave an invisible
    ///   silent-wrong-path for any future caller that forgot to pass
    ///   one in. Tests inject a fake here directly.
    init(authService: AuthService) {
        self.authService = authService
        wireErrorClearingOnEdit()
    }

    #if DEBUG
    /// DEBUG-only convenience initialiser for SwiftUI `#Preview` blocks
    /// that need a `LoginViewModel` without spelling out a fake
    /// `AuthService`. Builds a real `OktaAuthService` against
    /// `OktaConfig.load()` — fine for previews (no network is actually
    /// hit until Sign in is tapped, and previews never tap), but
    /// deliberately unavailable in release builds so production cannot
    /// silently bypass the composition root.
    convenience init() {
        self.init(
            authService: OktaAuthService(
                config: .load(),
                keychain: KeychainStore()
            )
        )
    }
    #endif

    // MARK: - Combine wiring

    /// Clear `errorMessage` whenever the user edits `username` or
    /// `password`. `.dropFirst()` discards the initial value the
    /// `@Published` publisher emits on subscription so the banner isn't
    /// wiped before the user has touched anything.
    private func wireErrorClearingOnEdit() {
        $username
            .dropFirst()
            .sink { [weak self] _ in
                self?.errorMessage = nil
            }
            .store(in: &cancellables)

        $password
            .dropFirst()
            .sink { [weak self] _ in
                self?.errorMessage = nil
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions (legacy closure path)

    /// Attempts sign-in via the injected `onSignIn` closure. Guards on
    /// `isSignInEnabled`; no-ops if the form is incomplete.
    func signInTapped() {
        guard isSignInEnabled else { return }
        onSignIn?(username, password, keepMeSignedIn)
    }

    // MARK: - Actions (async / real-auth path)

    /// Submit credentials to the injected `AuthService`.
    ///
    /// Drives `isSigningIn` so the view disables its fields + button and
    /// swaps in a spinner. On success, publishes the resulting
    /// `UserSession` via `signedInSession` (the composition root in
    /// `AcmeBankApp` observes this to swap the root view). On a typed
    /// `AuthError`, maps it to the exact user-facing copy declared in
    /// MD065-7.
    ///
    /// Re-entry guard: a tap while a previous call is in flight is a
    /// no-op, so double-taps can't kick off a second concurrent
    /// `AuthService.signIn` (which would also fight over the keychain).
    /// Because the type is `@MainActor`-isolated, the check-then-set on
    /// `isSigningIn` is atomic with respect to other Tasks awaiting
    /// this method.
    func signIn(username: String, password: String, keepSignedIn: Bool) async {
        // Re-entry guard. Must be the very first thing — before we flip
        // any state — so a second tap mid-flight doesn't even reset the
        // error banner.
        guard !isSigningIn else { return }

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let session = try await authService.signIn(
                username: username,
                password: password,
                keepSignedIn: keepSignedIn
            )
            signedInSession = session
            errorMessage = nil
        } catch let authError as AuthError {
            errorMessage = Self.copy(for: authError)
        } catch {
            // Anything else is a bug — surface it as the "unexpected"
            // copy rather than a misleading network banner. See repo
            // lesson on "post-SDK-success failures must not propagate
            // as untyped errors": `OktaAuthService` already funnels its
            // own errors into `AuthError`, so reaching this branch is
            // genuinely unexpected.
            errorMessage = Self.copy(for: .unexpected(error))
        }
    }

    // MARK: - Error copy

    /// Map an `AuthError` to the exact user-facing string declared in
    /// MD065-7. Kept as a `static` pure function so tests can lock the
    /// copy down without instantiating the ViewModel.
    static func copy(for error: AuthError) -> String {
        switch error {
        case .invalidCredentials:
            return "Incorrect username or password. Please try again."
        case .networkError:
            return "Couldn't reach Okta — check your connection and try again."
        case .mfaRequired:
            return "MFA is required but not supported in this build."
        case .notConfigured:
            return "Okta is not configured on this build — see README."
        case .unexpected:
            // No bespoke copy specified for this case in MD065-7 —
            // pick a terse, actionable string so users see something
            // rather than nothing. A dedicated copy string for
            // `.unexpected` is a future-PR concern.
            return "Something went wrong signing you in. Please try again."
        }
    }
}
