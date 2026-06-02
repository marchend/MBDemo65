import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Authenticated user state, derived from a successful Okta sign-in.
///
/// `UserSession` is a value type passed forward through coordinators after
/// login. It is intentionally `Codable` so it can be serialised when needed
/// (e.g. for diagnostic snapshots) but it is **never** stored in
/// `UserDefaults` or held in a global singleton — see `AGENT.md`.
///
/// The refresh token is deliberately NOT a field on `UserSession`. Refresh
/// tokens live only in the Keychain (and only when "Keep me signed in" was
/// checked); they are never carried around in memory alongside the user's
/// profile claims.
public struct UserSession: Codable, Equatable {

    // MARK: - Fields

    /// Stable Okta user ID — the `sub` claim of the ID token.
    public let userId: String

    /// Human-readable display name — the `name` claim of the ID token.
    public let displayName: String

    /// User email — the `email` claim of the ID token.
    public let email: String

    /// The OAuth2 access token returned alongside the ID token. Used to
    /// authenticate API calls; also persisted to the Keychain.
    public let accessToken: String

    /// When the user actually authenticated. Sourced from the ID token's
    /// `auth_time` claim (RFC 7519 §4.1.6) when present, otherwise the
    /// instant the sign-in completed locally.
    public let authTimestamp: Date

    /// The device's user-visible name (e.g. "Marc's iPhone"). Captured at
    /// session creation for audit / display, not derived from any claim.
    public let deviceName: String

    public init(
        userId: String,
        displayName: String,
        email: String,
        accessToken: String,
        authTimestamp: Date,
        deviceName: String
    ) {
        self.userId = userId
        self.displayName = displayName
        self.email = email
        self.accessToken = accessToken
        self.authTimestamp = authTimestamp
        self.deviceName = deviceName
    }

    // MARK: - JWT decoding

    /// Errors that can arise while decoding an ID token JWT into a
    /// `UserSession`. These are *post-success* errors — they only happen
    /// after the IdP has returned a token — and per the
    /// `OktaAuthService.signIn` contract are mapped to a typed
    /// `AuthError.unexpected` rather than allowed to escape raw.
    public enum DecodeError: Error, Equatable {
        /// The JWT did not have three dot-separated segments.
        case malformedJWT
        /// The payload segment was not valid base64url.
        case invalidBase64
        /// The payload segment was not valid JSON.
        case invalidJSON
        /// A required claim (`sub`) was missing from the payload.
        case missingRequiredClaim(String)
    }

    /// Build a `UserSession` from a freshly-issued ID + access token pair.
    ///
    /// Decodes the JWT payload (segment 1 of the dot-separated triple)
    /// using base64url decoding, then pulls the `sub` / `name` / `email`
    /// / `auth_time` claims. `name` and `email` fall back to an empty
    /// string when absent (Okta tenants sometimes omit them on app
    /// configurations without the corresponding scope); `auth_time` falls
    /// back to "right now". Only `sub` is hard-required — without a stable
    /// user ID we have no business creating a session.
    public static func make(
        fromIDToken idToken: String,
        accessToken: String,
        deviceName: String = UserSession.currentDeviceName,
        now: @autoclosure () -> Date = Date()
    ) throws -> UserSession {
        let claims = try decodeJWTPayload(idToken)

        guard let sub = claims["sub"] as? String, !sub.isEmpty else {
            throw DecodeError.missingRequiredClaim("sub")
        }

        let name = (claims["name"] as? String) ?? ""
        let email = (claims["email"] as? String) ?? ""

        let authTimestamp: Date
        if let authTime = claims["auth_time"] as? TimeInterval {
            authTimestamp = Date(timeIntervalSince1970: authTime)
        } else if let authTimeInt = claims["auth_time"] as? Int {
            authTimestamp = Date(timeIntervalSince1970: TimeInterval(authTimeInt))
        } else {
            authTimestamp = now()
        }

        return UserSession(
            userId: sub,
            displayName: name,
            email: email,
            accessToken: accessToken,
            authTimestamp: authTimestamp,
            deviceName: deviceName
        )
    }

    // MARK: - Helpers

    /// Best-effort device name suitable for audit display. Returns the
    /// current `UIDevice.name` on iOS; an empty string on platforms that
    /// don't expose `UIDevice` (unit-test host on non-iOS, etc.).
    public static var currentDeviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return ""
        #endif
    }

    /// Decode the payload segment of a JWT into a `[String: Any]` claims
    /// dictionary. JWT payloads are base64url-encoded JSON.
    private static func decodeJWTPayload(_ jwt: String) throws -> [String: Any] {
        let segments = jwt.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else {
            throw DecodeError.malformedJWT
        }
        guard let payloadData = base64urlDecode(String(segments[1])) else {
            throw DecodeError.invalidBase64
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: payloadData),
            let claims = json as? [String: Any]
        else {
            throw DecodeError.invalidJSON
        }
        return claims
    }

    /// Base64url → Data. JWTs use the URL-safe alphabet (`-` / `_`
    /// instead of `+` / `/`) and omit `=` padding; standard `Data(base64:)`
    /// rejects both, so we normalise first.
    private static func base64urlDecode(_ input: String) -> Data? {
        var s = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 {
            s.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: s)
    }
}
