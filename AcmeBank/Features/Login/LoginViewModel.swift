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
/// The async path is what `LoginView` wires up from this PR on. The
/// closure path is left in place because the composition root (PR 4) is
/// what will switch `ContentView` over to the real path; until then the
/// closure-based unit tests in `LoginViewModelTests` still exercise the
/// existing API surface unchanged.
///
/// Not annotated `@MainActor` so existing synchronous unit tests that
/// instantiate the ViewModel directly compile unchanged. SwiftUI calls
/// the async `signIn(...)` from a `Task` launched in a `@MainActor`
/// body, so `@Published` mutations land on main; tests drive `signIn`
/// from XCTest's main thread for the same reason.
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

    /// Populated on a successful `signIn(...)`. The composition root
    /// (PR 4) observes this to drive navigation; this ViewModel never
    /// presents or pushes anything itself.
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

    /// - Parameter authService: the auth backend. Defaults to a real
    ///   `OktaAuthService` reading `OktaConfig.load()` so production
    ///   wiring needs no arguments; tests inject a fake.
    init(
        authService: AuthService = OktaAuthService(
            config: .load(),
            keychain: KeychainStore()
        )
    ) {
        self.authService = authService
        wireErrorClearingOnEdit()
    }

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
    /// PR 4 observes this to navigate). On a typed `AuthError`, maps it
    /// to the exact user-facing copy declared in MD065-7.
    ///
    /// Re-entry guard: a tap while a previous call is in flight is a
    /// no-op, so double-taps can't kick off a second concurrent
    /// `AuthService.signIn` (which would also fight over the keychain).
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
            // No bespoke copy specified for this case in MD065-7 — pick
            // a terse, actionable string so users see something rather
            // than nothing. A dedicated copy string for `.unexpected` is
            // a future-PR concern.
            return "Something went wrong signing you in. Please try again."
        }
    }
}
