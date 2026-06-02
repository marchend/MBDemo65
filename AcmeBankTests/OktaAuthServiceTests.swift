import XCTest
@testable import AcmeBank

/// Unit tests for `OktaAuthService`. We inject a fake
/// `DirectAuthFlowProtocol` via the flow factory so we never touch
/// `OktaDirectAuth` (and so never need a live Okta tenant). The fake
/// returns canned `DirectAuthResult` values, lets us throw arbitrary
/// errors to exercise the catch-mapping, and records its calls so we
/// can assert the service didn't bypass the config gate.
final class OktaAuthServiceTests: XCTestCase {

    // MARK: - Fakes

    /// In-memory recording fake for `DirectAuthFlowProtocol`. Configure
    /// `nextResult` or `nextError` before each test.
    final class FakeDirectAuthFlow: DirectAuthFlowProtocol {
        var nextResult: DirectAuthResult?
        var nextError: Error?
        private(set) var startCallCount = 0
        private(set) var lastUsername: String?
        private(set) var lastPassword: String?

        func start(username: String, password: String) async throws -> DirectAuthResult {
            startCallCount += 1
            lastUsername = username
            lastPassword = password
            if let nextError {
                throw nextError
            }
            guard let nextResult else {
                throw NSError(domain: "FakeDirectAuthFlow", code: -1)
            }
            return nextResult
        }
    }

    // MARK: - Fixtures

    private let testService = "com.acmebank.mobile.tests.okta-auth"

    private var keychain: KeychainStore!

    /// A valid `.configured` Okta config for the service under test.
    /// Tenant URLs are intentionally fake — the fake flow never makes a
    /// real network call, so they don't need to resolve.
    private let configuredConfig: OktaConfig = .configured(
        issuer: URL(string: "https://acme.okta.test/oauth2/default")!,
        clientID: "0oa1abcDEF",
        redirectURI: URL(string: "com.acmebank.mobile:/callback")!,
        scopes: ["openid", "profile", "email", "offline_access"]
    )

    override func setUp() {
        super.setUp()
        keychain = KeychainStore(service: testService)
        for key in KeychainStore.KeychainKey.allCases {
            try? keychain.delete(key)
        }
    }

    override func tearDown() {
        for key in KeychainStore.KeychainKey.allCases {
            try? keychain.delete(key)
        }
        keychain = nil
        super.tearDown()
    }

    // MARK: - Fixture JWTs

    /// Build a fixture JWT with the given claims (see `UserSessionTests`
    /// for the rationale on unsigned fixtures).
    private func makeJWT(claims: [String: Any]) throws -> String {
        let header: [String: Any] = ["alg": "none", "typ": "JWT"]
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: claims)
        let segments = [headerData, payloadData].map { data -> String in
            var s = data.base64EncodedString()
            s = s.replacingOccurrences(of: "+", with: "-")
            s = s.replacingOccurrences(of: "/", with: "_")
            s = s.replacingOccurrences(of: "=", with: "")
            return s
        }
        return segments.joined(separator: ".") + ".sig"
    }

    private func standardIDToken() throws -> String {
        return try makeJWT(claims: [
            "sub": "00u123abc",
            "name": "Marc Henderson",
            "email": "marc@acmebank.test",
            "auth_time": 1_700_000_000 as TimeInterval
        ])
    }

    // MARK: - Helpers

    private func makeService(flow: FakeDirectAuthFlow) -> OktaAuthService {
        return OktaAuthService(
            config: configuredConfig,
            keychain: keychain,
            flowFactory: { _ in flow }
        )
    }

    // MARK: - Success: keepSignedIn = true → persists all three tokens

    func test_signIn_success_keepSignedInTrue_writesAllTokensAndReturnsSession() async throws {
        let idToken = try standardIDToken()
        let flow = FakeDirectAuthFlow()
        flow.nextResult = .success(
            idToken: idToken,
            accessToken: "access-tok",
            refreshToken: "refresh-tok"
        )
        let service = makeService(flow: flow)

        let session = try await service.signIn(
            username: "marc",
            password: "p@ss",
            keepSignedIn: true
        )

        // Returned session is populated from the JWT claims.
        XCTAssertEqual(session.userId, "00u123abc")
        XCTAssertEqual(session.displayName, "Marc Henderson")
        XCTAssertEqual(session.email, "marc@acmebank.test")
        XCTAssertEqual(session.accessToken, "access-tok")

        // All three tokens land in the keychain.
        XCTAssertEqual(try keychain.read(.idToken), idToken)
        XCTAssertEqual(try keychain.read(.accessToken), "access-tok")
        XCTAssertEqual(try keychain.read(.refreshToken), "refresh-tok")

        // Credentials were forwarded verbatim to the flow.
        XCTAssertEqual(flow.lastUsername, "marc")
        XCTAssertEqual(flow.lastPassword, "p@ss")
        XCTAssertEqual(flow.startCallCount, 1)
    }

    // MARK: - Success: keepSignedIn = false → refresh token NOT persisted

    func test_signIn_success_keepSignedInFalse_doesNotPersistRefreshToken() async throws {
        let idToken = try standardIDToken()
        let flow = FakeDirectAuthFlow()
        flow.nextResult = .success(
            idToken: idToken,
            accessToken: "access-tok",
            refreshToken: "refresh-tok"
        )
        let service = makeService(flow: flow)

        _ = try await service.signIn(
            username: "marc",
            password: "p@ss",
            keepSignedIn: false
        )

        XCTAssertEqual(try keychain.read(.idToken), idToken)
        XCTAssertEqual(try keychain.read(.accessToken), "access-tok")
        XCTAssertNil(
            try keychain.read(.refreshToken),
            "refresh token must NOT be persisted when keepSignedIn=false"
        )
    }

    /// And it must actively clear a stale refresh token from a prior
    /// session — otherwise unchecking the box would silently leak the
    /// previous sign-in's refresh token to the next launch.
    func test_signIn_keepSignedInFalse_clearsPreviouslyStoredRefreshToken() async throws {
        try keychain.save("stale-refresh-from-yesterday", for: .refreshToken)

        let idToken = try standardIDToken()
        let flow = FakeDirectAuthFlow()
        flow.nextResult = .success(
            idToken: idToken,
            accessToken: "access-tok",
            refreshToken: "fresh-refresh"
        )
        let service = makeService(flow: flow)

        _ = try await service.signIn(
            username: "marc",
            password: "p@ss",
            keepSignedIn: false
        )

        XCTAssertNil(try keychain.read(.refreshToken))
    }

    // MARK: - MFA → AuthError.mfaRequired

    func test_signIn_mfaRequired_throwsMfaRequired() async throws {
        let flow = FakeDirectAuthFlow()
        flow.nextResult = .mfaRequired
        let service = makeService(flow: flow)

        do {
            _ = try await service.signIn(username: "marc", password: "p", keepSignedIn: false)
            XCTFail("expected AuthError.mfaRequired")
        } catch AuthError.mfaRequired {
            // expected
        } catch {
            XCTFail("expected .mfaRequired, got \(error)")
        }

        // No tokens should be persisted on an MFA-required outcome.
        XCTAssertNil(try keychain.read(.idToken))
        XCTAssertNil(try keychain.read(.accessToken))
        XCTAssertNil(try keychain.read(.refreshToken))
    }

    // MARK: - Auth-rejection error → AuthError.invalidCredentials

    func test_signIn_authRejection_throwsInvalidCredentials() async throws {
        let flow = FakeDirectAuthFlow()
        // String-matched by `looksLikeAuthRejection`.
        flow.nextError = NSError(
            domain: "OktaDirectAuth",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "invalid_grant: Authentication failed"]
        )
        let service = makeService(flow: flow)

        do {
            _ = try await service.signIn(username: "marc", password: "p", keepSignedIn: false)
            XCTFail("expected AuthError.invalidCredentials")
        } catch AuthError.invalidCredentials {
            // expected
        } catch {
            XCTFail("expected .invalidCredentials, got \(error)")
        }
    }

    // MARK: - URLError → AuthError.networkError

    func test_signIn_urlError_throwsNetworkError() async throws {
        let flow = FakeDirectAuthFlow()
        flow.nextError = URLError(.notConnectedToInternet)
        let service = makeService(flow: flow)

        do {
            _ = try await service.signIn(username: "marc", password: "p", keepSignedIn: false)
            XCTFail("expected AuthError.networkError")
        } catch AuthError.networkError {
            // expected
        } catch {
            XCTFail("expected .networkError, got \(error)")
        }
    }

    // MARK: - .notConfigured → short-circuit, NO flow call

    func test_signIn_notConfigured_shortCircuitsBeforeFlowCall() async throws {
        let flow = FakeDirectAuthFlow()
        // If the service ever reaches the flow, this would crash the test
        // (no nextResult / nextError set) — but it shouldn't reach the flow.
        let service = OktaAuthService(
            config: .notConfigured(reason: "test: no OKTA_* env vars"),
            keychain: keychain,
            flowFactory: { _ in flow }
        )

        do {
            _ = try await service.signIn(username: "marc", password: "p", keepSignedIn: true)
            XCTFail("expected AuthError.notConfigured")
        } catch AuthError.notConfigured(let reason) {
            XCTAssertEqual(reason, "test: no OKTA_* env vars")
        } catch {
            XCTFail("expected .notConfigured, got \(error)")
        }

        XCTAssertEqual(
            flow.startCallCount, 0,
            "flow.start must NOT be called when config is .notConfigured"
        )
        XCTAssertNil(try keychain.read(.idToken))
        XCTAssertNil(try keychain.read(.accessToken))
        XCTAssertNil(try keychain.read(.refreshToken))
    }
}
