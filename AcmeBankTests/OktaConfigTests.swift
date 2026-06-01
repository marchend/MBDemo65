import XCTest
@testable import AcmeBank

/// Unit tests for `OktaConfig.load(infoDictionary:)`. Covers the three
/// branches the Run Script can produce: all sentinels (no env vars set),
/// all real values (full Okta tenant config), and mixed (some env vars
/// missing). The reason string on `.notConfigured` must be human-readable
/// so it can render directly in the login error banner.
final class OktaConfigTests: XCTestCase {

    // MARK: - All sentinels → .notConfigured

    func test_load_allSentinels_returnsNotConfigured() {
        let info: [String: Any] = [
            OktaConfig.issuerKey: OktaConfig.sentinel,
            OktaConfig.clientIDKey: OktaConfig.sentinel,
            OktaConfig.redirectURIKey: OktaConfig.sentinel,
            OktaConfig.scopesKey: OktaConfig.sentinel
        ]

        let result = OktaConfig.load(infoDictionary: info)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("expected .notConfigured, got \(result)")
        }
        XCTAssertFalse(reason.isEmpty)
        XCTAssertTrue(
            reason.localizedCaseInsensitiveContains("not configured"),
            "reason should be human-readable; got: \(reason)"
        )
        XCTAssertFalse(result.isConfigured)
    }

    // MARK: - All realistic → .configured

    func test_load_allRealistic_returnsConfigured() {
        let info: [String: Any] = [
            OktaConfig.issuerKey: "https://acme.okta.com/oauth2/default",
            OktaConfig.clientIDKey: "0oa1abcDEF23456789",
            OktaConfig.redirectURIKey: "com.acmebank.mobile:/callback",
            OktaConfig.scopesKey: "openid profile email offline_access"
        ]

        let result = OktaConfig.load(infoDictionary: info)

        guard case let .configured(issuer, clientID, redirectURI, scopes) = result else {
            return XCTFail("expected .configured, got \(result)")
        }
        XCTAssertEqual(issuer.absoluteString, "https://acme.okta.com/oauth2/default")
        XCTAssertEqual(clientID, "0oa1abcDEF23456789")
        XCTAssertEqual(redirectURI.absoluteString, "com.acmebank.mobile:/callback")
        XCTAssertEqual(scopes, ["openid", "profile", "email", "offline_access"])
        XCTAssertTrue(result.isConfigured)
    }

    // MARK: - Any one sentinel → .notConfigured

    func test_load_oneSentinel_returnsNotConfigured() {
        let info: [String: Any] = [
            OktaConfig.issuerKey: "https://acme.okta.com/oauth2/default",
            OktaConfig.clientIDKey: OktaConfig.sentinel, // ← only this one is sentinel
            OktaConfig.redirectURIKey: "com.acmebank.mobile:/callback",
            OktaConfig.scopesKey: "openid profile email"
        ]

        let result = OktaConfig.load(infoDictionary: info)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(
            reason.contains(OktaConfig.clientIDKey),
            "reason should name the missing key; got: \(reason)"
        )
        XCTAssertFalse(result.isConfigured)
    }

    // MARK: - Reason copy is human-readable

    func test_load_notConfigured_reasonReferencesReadme() {
        let info: [String: Any] = [
            OktaConfig.issuerKey: OktaConfig.sentinel,
            OktaConfig.clientIDKey: OktaConfig.sentinel,
            OktaConfig.redirectURIKey: OktaConfig.sentinel,
            OktaConfig.scopesKey: OktaConfig.sentinel
        ]

        let result = OktaConfig.load(infoDictionary: info)

        guard case let .notConfigured(reason) = result else {
            return XCTFail("expected .notConfigured, got \(result)")
        }
        XCTAssertTrue(
            reason.localizedCaseInsensitiveContains("readme"),
            "reason should point developers at the README; got: \(reason)"
        )
        // Should NOT leak the raw sentinel string into the UI.
        XCTAssertFalse(
            reason.contains(OktaConfig.sentinel),
            "reason should not surface the internal sentinel token to the user; got: \(reason)"
        )
    }

    // MARK: - Empty / missing keys → .notConfigured

    func test_load_emptyDictionary_returnsNotConfigured() {
        let result = OktaConfig.load(infoDictionary: [:])

        guard case .notConfigured = result else {
            return XCTFail("expected .notConfigured, got \(result)")
        }
        XCTAssertFalse(result.isConfigured)
    }
}
