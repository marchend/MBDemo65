import Foundation

/// The single error type the UI layer (`LoginViewModel`) catches off of
/// any `AuthService.signIn` call. Keeping this an enum (not a free-form
/// `Error`) lets the View layer pattern-match cleanly and pick the right
/// user-facing copy — see `AGENT.md` § Authentication.
///
/// **Why typed:** the login screen does
/// `do { try await authService.signIn(...) } catch let e as AuthError`.
/// If a `KeychainError` or `UserSession.DecodeError` were allowed to
/// escape `signIn` unchanged, the typed `catch` would miss them and the
/// generic catch would show a misleading "Couldn't reach Okta" banner
/// even though Okta actually returned a valid token. `OktaAuthService`
/// is responsible for funnelling everything into one of these cases.
public enum AuthError: Error {

    /// Okta confirmed the credentials are wrong (or the user isn't
    /// authorised). UI copy: "Incorrect username or password."
    case invalidCredentials

    /// Transport-level failure talking to Okta (offline, DNS, TLS,
    /// timeout). UI copy: "Couldn't reach Okta — check your connection."
    case networkError

    /// Okta wants a second factor. MFA is out of scope for this story
    /// — surfaced as a banner ("MFA is required but not supported in
    /// this build.") and the sign-in attempt stops.
    case mfaRequired

    /// The build itself has no Okta tenant configuration — usually a CI
    /// build without `OKTA_*` env vars set. `reason` is human-readable
    /// and safe to render directly in the error banner.
    case notConfigured(String)

    /// Any other failure (typically a post-success plumbing problem —
    /// e.g. the ID token decoded oddly). Wrapped so callers can log it
    /// without losing type-safety at the catch site.
    case unexpected(Error)
}

/// Headless authentication API used by `LoginViewModel`.
///
/// Implementations sit between the SwiftUI login form and the IdP SDK.
/// The protocol is intentionally minimal — one method, fully async —
/// so it can be faked in unit tests without touching the network and
/// re-implemented later if we ever swap IdPs.
public protocol AuthService {

    /// Submit `username` / `password` to the IdP and, on success,
    /// persist the resulting tokens and return the populated
    /// `UserSession`.
    ///
    /// - Parameter keepSignedIn: when `true`, the refresh token is
    ///   persisted to the Keychain so a subsequent cold launch can
    ///   restore the session silently; when `false`, the refresh
    ///   token is discarded after this call.
    /// - Throws: always an `AuthError` — never a raw `KeychainError`,
    ///   `URLError`, or SDK-specific type.
    func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession
}
