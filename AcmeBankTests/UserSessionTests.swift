import XCTest
@testable import AcmeBank

/// Unit tests for `UserSession.make(fromIDToken:accessToken:)`.
///
/// We hand-craft JWTs here — a real ID token from Okta is signed, but
/// for claim-mapping we only ever decode the payload segment (base64url
/// JSON), never verify the signature. Signature verification is Okta's
/// job at the token endpoint; for our client-side claim mapping a fixture
/// JWT is identical to a real one.
final class UserSessionTests: XCTestCase {

    // MARK: - Fixture helpers

    /// Build an unsigned JWT (`header.payload.`) with the given claims.
    /// The header / signature segments are dummy; only the payload matters
    /// for `UserSession`'s decoder.
    private func makeJWT(claims: [String: Any]) throws -> String {
        let header: [String: Any] = ["alg": "none", "typ": "JWT"]
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: claims)
        return [
            base64url(headerData),
            base64url(payloadData),
            "sig"
        ].joined(separator: ".")
    }

    /// Base64url-encode `data`: replace `+` / `/` with `-` / `_` and
    /// strip `=` padding, per RFC 7515 § Appendix C.
    private func base64url(_ data: Data) -> String {
        var s = data.base64EncodedString()
        s = s.replacingOccurrences(of: "+", with: "-")
        s = s.replacingOccurrences(of: "/", with: "_")
        s = s.replacingOccurrences(of: "=", with: "")
        return s
    }

    // MARK: - Happy path

    func test_make_populatesAllClaimsFromIDToken() throws {
        let authTime: TimeInterval = 1_700_000_000
        let idToken = try makeJWT(claims: [
            "sub": "00u123abc",
            "name": "Marc Henderson",
            "email": "marc@acmebank.test",
            "auth_time": authTime
        ])

        let session = try UserSession.make(
            fromIDToken: idToken,
            accessToken: "access-tok-xyz",
            deviceName: "Test Device"
        )

        XCTAssertEqual(session.userId, "00u123abc")
        XCTAssertEqual(session.displayName, "Marc Henderson")
        XCTAssertEqual(session.email, "marc@acmebank.test")
        XCTAssertEqual(session.accessToken, "access-tok-xyz")
        XCTAssertEqual(session.deviceName, "Test Device")
        XCTAssertEqual(session.authTimestamp.timeIntervalSince1970, authTime, accuracy: 0.001)
    }

    // MARK: - Missing auth_time → near-now

    func test_make_missingAuthTime_fallsBackToNow() throws {
        let idToken = try makeJWT(claims: [
            "sub": "00u123abc",
            "name": "Marc Henderson",
            "email": "marc@acmebank.test"
            // no auth_time
        ])
        let before = Date()
        let session = try UserSession.make(
            fromIDToken: idToken,
            accessToken: "access-tok",
            deviceName: "Test Device"
        )
        let after = Date()

        // Fallback should land between the two clock samples bracketing
        // the call — i.e. it's "now", not the Unix epoch or 1970.
        XCTAssertGreaterThanOrEqual(session.authTimestamp.timeIntervalSince1970, before.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(session.authTimestamp.timeIntervalSince1970, after.timeIntervalSince1970)
    }

    // MARK: - Optional claims default to empty string

    func test_make_missingNameAndEmail_defaultToEmptyString() throws {
        let idToken = try makeJWT(claims: [
            "sub": "00u123abc"
        ])

        let session = try UserSession.make(
            fromIDToken: idToken,
            accessToken: "access-tok",
            deviceName: "Test Device"
        )

        XCTAssertEqual(session.userId, "00u123abc")
        XCTAssertEqual(session.displayName, "")
        XCTAssertEqual(session.email, "")
    }

    // MARK: - Malformed JWT → throws

    func test_make_malformedJWT_throwsMalformedError() {
        // Not three dot-separated segments → malformedJWT.
        XCTAssertThrowsError(try UserSession.make(
            fromIDToken: "not-a-jwt",
            accessToken: "access",
            deviceName: "Test"
        )) { error in
            XCTAssertEqual(error as? UserSession.DecodeError, .malformedJWT)
        }
    }

    func test_make_invalidBase64Payload_throws() {
        // Three segments, but the payload is not valid base64url.
        let bogus = "aGVhZGVy.!!!not-base64!!!.sig"
        XCTAssertThrowsError(try UserSession.make(
            fromIDToken: bogus,
            accessToken: "access",
            deviceName: "Test"
        )) { error in
            // Either invalidBase64 or invalidJSON is acceptable — both
            // mean "we couldn't get a claim dictionary out of this".
            let decodeErr = error as? UserSession.DecodeError
            XCTAssertNotNil(decodeErr)
            XCTAssertTrue(
                decodeErr == .invalidBase64 || decodeErr == .invalidJSON,
                "expected invalidBase64 or invalidJSON, got \(String(describing: decodeErr))"
            )
        }
    }

    func test_make_missingSubClaim_throws() throws {
        // Well-formed JWT, valid JSON payload, but no `sub` claim — the
        // one claim we hard-require.
        let idToken = try makeJWT(claims: [
            "name": "No Sub"
        ])
        XCTAssertThrowsError(try UserSession.make(
            fromIDToken: idToken,
            accessToken: "access",
            deviceName: "Test"
        )) { error in
            XCTAssertEqual(error as? UserSession.DecodeError, .missingRequiredClaim("sub"))
        }
    }
}
