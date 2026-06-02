import Foundation
import OktaDirectAuth

// MARK: - Test seam

/// The narrowed view of `DirectAuthenticationFlow` that `OktaAuthService`
/// actually needs. Hidden behind a protocol so unit tests can swap in a
/// fake without touching `OktaDirectAuth` at all — the production
/// implementation (`LiveDirectAuthFlow`) is a thin adapter over the real
/// SDK flow.
public protocol DirectAuthFlowProtocol {
    /// Submit `username` + password factor. Returns a `DirectAuthResult`
    /// that the service maps onto `UserSession` / `AuthError`.
    func start(username: String, password: String) async throws -> DirectAuthResult
}

/// Status the service cares about. We translate the SDK's richer
/// `DirectAuthenticationFlow.Status` into this minimal shape at the
/// boundary so the rest of the service never imports `OktaDirectAuth`.
public enum DirectAuthResult {
    /// Authentication succeeded; tokens are issued.
    case success(idToken: String, accessToken: String, refreshToken: String?)
    /// Okta requires a second factor — surfaced as `AuthError.mfaRequired`.
    case mfaRequired
}

/// Factory closure for a `DirectAuthFlowProtocol` given an `OktaConfig`.
/// The `OktaAuthService` accepts this rather than a flow directly so the
/// flow can be constructed lazily after we've verified config is real.
public typealias DirectAuthFlowFactory = (OktaConfig) -> DirectAuthFlowProtocol

// MARK: - Service

/// Concrete `AuthService` backed by Okta's `DirectAuthenticationFlow`.
///
/// Composition root pattern: pass in the validated `OktaConfig`, the
/// `KeychainStore` for token persistence, and a flow factory. The factory
/// indirection is what makes this class unit-testable — production wires
/// it to `LiveDirectAuthFlow.make`, tests wire it to a stub that returns
/// canned `DirectAuthResult` values.
public final class OktaAuthService: AuthService {

    private let config: OktaConfig
    private let keychain: KeychainStore
    private let flowFactory: DirectAuthFlowFactory

    public init(
        config: OktaConfig,
        keychain: KeychainStore,
        flowFactory: @escaping DirectAuthFlowFactory = LiveDirectAuthFlow.make
    ) {
        self.config = config
        self.keychain = keychain
        self.flowFactory = flowFactory
    }

    public func signIn(
        username: String,
        password: String,
        keepSignedIn: Bool
    ) async throws -> UserSession {

        // 1. Refuse to make a network call on a build that has no tenant
        //    config. Short-circuits before any DirectAuth construction so
        //    we don't leak partial state through the SDK.
        switch config {
        case .notConfigured(let reason):
            throw AuthError.notConfigured(reason)
        case .configured:
            break
        }

        let flow = flowFactory(config)

        // 2. Submit credentials. Map transport / SDK errors to typed
        //    `AuthError` values; never let a raw `URLError` or
        //    `OktaDirectAuth`-internal type escape.
        let result: DirectAuthResult
        do {
            result = try await flow.start(username: username, password: password)
        } catch is URLError {
            throw AuthError.networkError
        } catch let authError as AuthError {
            throw authError
        } catch {
            // Catch-all: SDK-specific error types we haven't enumerated.
            // Treat as `invalidCredentials` only if the SDK signalled an
            // explicit auth-rejection; otherwise pass through as
            // `unexpected` so the UI doesn't lie about the cause.
            if Self.looksLikeAuthRejection(error) {
                throw AuthError.invalidCredentials
            }
            throw AuthError.unexpected(error)
        }

        // 3. Branch on the boundary-level result.
        switch result {
        case .mfaRequired:
            throw AuthError.mfaRequired

        case let .success(idToken, accessToken, refreshToken):
            return try finalize(
                idToken: idToken,
                accessToken: accessToken,
                refreshToken: refreshToken,
                keepSignedIn: keepSignedIn
            )
        }
    }

    // MARK: - Post-success plumbing

    /// Decode the ID token into a `UserSession` and persist the tokens.
    ///
    /// **Keychain writes are best-effort.** Per the repo lessons, a
    /// failed `keychain.save` must NOT collapse a successful Okta auth
    /// into a phantom "network error" — the worst it does is force a
    /// re-login next launch. We log and continue. JWT decode failures,
    /// by contrast, *are* real bugs (we got tokens but can't read them),
    /// and they fold into `AuthError.unexpected` so the typed catch
    /// still fires.
    private func finalize(
        idToken: String,
        accessToken: String,
        refreshToken: String?,
        keepSignedIn: Bool
    ) throws -> UserSession {

        let session: UserSession
        do {
            session = try UserSession.make(
                fromIDToken: idToken,
                accessToken: accessToken
            )
        } catch {
            throw AuthError.unexpected(error)
        }

        // ID + access token always go to the Keychain.
        persistQuietly(idToken, for: .idToken)
        persistQuietly(accessToken, for: .accessToken)

        // Refresh token only when the user opted in. When they didn't,
        // proactively *delete* any previously-stored refresh token so a
        // sign-in with the box unchecked clears stale persistence from a
        // prior sign-in.
        if keepSignedIn, let refreshToken {
            persistQuietly(refreshToken, for: .refreshToken)
        } else {
            try? keychain.delete(.refreshToken)
        }

        return session
    }

    private func persistQuietly(_ value: String, for key: KeychainStore.KeychainKey) {
        do {
            try keychain.save(value, for: key)
        } catch {
            // Swallow — see `finalize` doc comment. A real product would
            // route this to a diagnostic logger; we're not wiring one in
            // this PR.
            #if DEBUG
            print("[OktaAuthService] keychain save for \(key) failed: \(error)")
            #endif
        }
    }

    /// Heuristic: does the SDK error look like an explicit auth rejection
    /// rather than a transport failure? Deliberately narrow: matches only
    /// the RFC 6749 §5.2 `"invalid_grant"` literal, which Okta uses
    /// specifically for credential rejection. Broader matches like
    /// `"authentication failed"` were tried and rejected because a 5xx
    /// outage whose diagnostic copy happens to contain the word
    /// "authentication" would be misclassified as bad-password and
    /// prompt the user to change a working credential.
    ///
    /// Used as a last-resort fallback when the SDK throws an error type
    /// we don't pattern-match directly; anything else falls through to
    /// `AuthError.unexpected` where the UI surfaces a generic
    /// "something went wrong" rather than a misleading credential error.
    private static func looksLikeAuthRejection(_ error: Error) -> Bool {
        let s = String(describing: error).lowercased()
        return s.contains("invalid_grant")
    }
}

// MARK: - Live SDK adapter

/// Production adapter that wraps Okta's real `DirectAuthenticationFlow`
/// behind the test-friendly `DirectAuthFlowProtocol`.
///
/// Kept deliberately thin: construct the flow with the validated
/// `OktaConfig`, forward `start(_:with:)` using the SDK's verbatim API
/// shape — `username` positional, factor as `with: .password(password)`,
/// NOT the hallucinated `.primary(.password(...))` wrapper — and
/// translate the SDK's status enum into our boundary `DirectAuthResult`.
public final class LiveDirectAuthFlow: DirectAuthFlowProtocol {

    private let flow: DirectAuthenticationFlow

    public init(flow: DirectAuthenticationFlow) {
        self.flow = flow
    }

    /// Factory matching `DirectAuthFlowFactory`. Guarded on `.configured`
    /// because the service short-circuits `.notConfigured` before
    /// calling us; if that contract is ever violated, return a fallback
    /// flow that fails the next `start` call with a typed error rather
    /// than crashing.
    public static func make(config: OktaConfig) -> DirectAuthFlowProtocol {
        guard case let .configured(issuer, clientID, _, scopes) = config else {
            assertionFailure("LiveDirectAuthFlow.make called on \(config)")
            return UnreachableDirectAuthFlow()
        }
        do {
            // SDK expects scopes as a single space-separated string.
            let scopeString = scopes.joined(separator: " ")
            let flow = try DirectAuthenticationFlow(
                issuer: issuer,
                clientId: clientID,
                scopes: scopeString
            )
            return LiveDirectAuthFlow(flow: flow)
        } catch {
            return UnreachableDirectAuthFlow()
        }
    }

    public func start(username: String, password: String) async throws -> DirectAuthResult {
        // Verbatim DirectAuth shape — username positional, factor as
        // `with: .password(password)`. See class doc comment for the
        // anti-pattern this guards against.
        let status = try await flow.start(username, with: .password(password))
        switch status {
        case .success(let token):
            // Explicit guard rather than `?? ""`. A nil/empty `idToken`
            // means the Okta app is misconfigured (typically the
            // `openid` scope is absent from its scope list) — surfacing
            // that as a diagnostic `AuthError.unexpected` here makes the
            // misconfiguration visible in logs instead of letting the
            // empty string flow into `UserSession.make` and produce a
            // generic "malformed JWT" error downstream.
            guard let rawIDToken = token.idToken?.rawValue, !rawIDToken.isEmpty else {
                throw AuthError.unexpected(
                    NSError(
                        domain: "LiveDirectAuthFlow",
                        code: -1,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Okta token response contained no ID token — check that 'openid' is in the app's scope list."
                        ]
                    )
                )
            }
            return .success(
                idToken: rawIDToken,
                accessToken: token.accessToken,
                refreshToken: token.refreshToken
            )
        case .mfaRequired:
            return .mfaRequired
        case .continuation:
            // Any continuation other than MFA isn't supported in this
            // build — surface as MFA-required so the UI shows the
            // "MFA not supported" banner rather than a misleading
            // network error.
            return .mfaRequired
        }
    }
}

/// Defensive fallback flow that always fails with a typed error. Only
/// reachable if `LiveDirectAuthFlow.make` is called with a
/// `.notConfigured` config (or the SDK init throws) — the service is
/// expected to short-circuit before that point.
private final class UnreachableDirectAuthFlow: DirectAuthFlowProtocol {
    func start(username: String, password: String) async throws -> DirectAuthResult {
        throw AuthError.notConfigured("Okta config was not validated before flow construction.")
    }
}
