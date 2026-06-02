import Foundation

/// Build-time-injected Okta tenant configuration, read at runtime from
/// `Bundle.main.infoDictionary`. Values are written into the built
/// `Info.plist` by the `InjectOktaConfig.sh` Run Script build phase, which
/// reads four environment variables on the build machine:
///
///   - `OKTA_ISSUER`        → Info.plist key `OktaIssuer`
///   - `OKTA_CLIENT_ID`     → Info.plist key `OktaClientID`
///   - `OKTA_REDIRECT_URI`  → Info.plist key `OktaRedirectURI`
///   - `OKTA_SCOPES`        → Info.plist key `OktaScopes`
///
/// If ANY of those env vars is unset at build time, the Run Script writes a
/// recognisable sentinel string (`__OKTA_NOT_CONFIGURED__`) into the
/// corresponding Info.plist key instead of hard-failing the build. At
/// runtime, `OktaConfig.load()` detects that sentinel and returns
/// `.notConfigured(reason:)`, which `LoginViewModel` surfaces via the
/// existing inline error banner. This keeps CI green on builds without real
/// Okta credentials while still letting the app boot and exercise its UI.
public enum OktaConfig: Equatable {
    /// All four tenant values were real (no sentinel) and well-formed.
    case configured(issuer: URL, clientID: String, redirectURI: URL, scopes: [String])

    /// At least one tenant value was missing, sentinel-valued, or malformed.
    /// `reason` is human-readable copy safe to render in the login error
    /// banner.
    case notConfigured(reason: String)

    // MARK: - Info.plist keys

    public static let issuerKey = "OktaIssuer"
    public static let clientIDKey = "OktaClientID"
    public static let redirectURIKey = "OktaRedirectURI"
    public static let scopesKey = "OktaScopes"

    /// Sentinel string written by `InjectOktaConfig.sh` whenever the
    /// corresponding `OKTA_*` env var is unset on the build machine. Detected
    /// at runtime to route control through `.notConfigured`.
    public static let sentinel = "__OKTA_NOT_CONFIGURED__"

    // MARK: - Loading

    /// Load Okta config from the main bundle's Info.plist. Never throws,
    /// never traps — a bad/missing config always returns `.notConfigured`.
    public static func load(bundle: Bundle = .main) -> OktaConfig {
        let info = bundle.infoDictionary ?? [:]
        return load(infoDictionary: info)
    }

    /// Test seam: load Okta config from an explicit dictionary. Used by
    /// `OktaConfigTests` to exercise the sentinel / mixed / real branches
    /// without mucking with the bundle.
    public static func load(infoDictionary info: [String: Any]) -> OktaConfig {
        let issuerRaw = (info[issuerKey] as? String) ?? ""
        let clientIDRaw = (info[clientIDKey] as? String) ?? ""
        let redirectRaw = (info[redirectURIKey] as? String) ?? ""
        let scopesRaw = (info[scopesKey] as? String) ?? ""

        var missing: [String] = []
        if isMissing(issuerRaw) { missing.append(issuerKey) }
        if isMissing(clientIDRaw) { missing.append(clientIDKey) }
        if isMissing(redirectRaw) { missing.append(redirectURIKey) }
        if isMissing(scopesRaw) { missing.append(scopesKey) }

        if !missing.isEmpty {
            let list = missing.joined(separator: ", ")
            return .notConfigured(
                reason: "Okta is not configured on this build — see README. Missing: \(list)."
            )
        }

        guard let issuerURL = URL(string: issuerRaw) else {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README. \(issuerKey) is not a valid URL."
            )
        }
        guard let redirectURL = URL(string: redirectRaw) else {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README. \(redirectURIKey) is not a valid URL."
            )
        }

        let scopes = scopesRaw
            .split(whereSeparator: { $0 == " " || $0 == "," })
            .map { String($0) }
            .filter { !$0.isEmpty }

        if scopes.isEmpty {
            return .notConfigured(
                reason: "Okta is not configured on this build — see README. \(scopesKey) is empty."
            )
        }

        return .configured(
            issuer: issuerURL,
            clientID: clientIDRaw,
            redirectURI: redirectURL,
            scopes: scopes
        )
    }

    // MARK: - Helpers

    /// `true` if the raw Info.plist value is the build-time sentinel, an
    /// empty string, or the literal `$(...)` template token (which would
    /// only appear if someone hand-edited the plist and forgot to swap the
    /// xcconfig reference).
    private static func isMissing(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        if trimmed == sentinel { return true }
        if trimmed.hasPrefix("$(") { return true }
        return false
    }

    /// Convenience: `true` only on the `.configured` branch. Useful for UI
    /// gating and for unit-test `XCTSkipUnless`.
    public var isConfigured: Bool {
        if case .configured = self { return true }
        return false
    }

    // MARK: - XCUITest process-env probe

    /// Static convenience used by XCUITest bundles to decide whether to
    /// `XCTSkipUnless` on a build without real Okta secrets.
    ///
    /// **Why this is not just `load().isConfigured`:** a UI-test runner is
    /// a separate process from the app under test; its `Bundle.main` is
    /// the test runner bundle, NOT `AcmeBank.app`. The build-time
    /// `InjectOktaConfig.sh` only writes the OKTA_* values into the
    /// *app* Info.plist, so `OktaConfig.load()` inside the UI-test
    /// process would always see the sentinels and report `false`.
    ///
    /// Instead, we replicate the *same* build-time check directly
    /// against `ProcessInfo.processInfo.environment`. On CI without
    /// secrets, none of the `OKTA_*` vars are exported into the test
    /// runner's environment and this returns `false` — so the
    /// end-to-end sign-in test skips cleanly. On a developer machine
    /// (or CI job) where all four are exported into the test runner's
    /// shell, the test runs.
    public static var isConfigured: Bool {
        return isConfigured(in: ProcessInfo.processInfo.environment)
    }

    /// Test seam: probe an explicit environment dictionary. The four
    /// OKTA_* vars must all be present and non-empty (matching
    /// `InjectOktaConfig.sh`'s build-time contract).
    public static func isConfigured(in env: [String: String]) -> Bool {
        let required = ["OKTA_ISSUER", "OKTA_CLIENT_ID", "OKTA_REDIRECT_URI", "OKTA_SCOPES"]
        for key in required {
            guard let value = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty,
                  value != sentinel
            else {
                return false
            }
        }
        return true
    }
}
