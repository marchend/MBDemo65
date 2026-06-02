import XCTest
@testable import AcmeBank

/// Unit tests for `KeychainStore`. Round-trips every `KeychainKey` on the
/// simulator's data-protection keychain. The whole point of this suite
/// is to fail loudly if a `SecItem*` call ever returns
/// `errSecMissingEntitlement` (-34018) — that's the signature failure
/// for forgetting `kSecUseDataProtectionKeychain: true` on a
/// `CODE_SIGNING_ALLOWED=NO` simulator build, and it would block CI.
final class KeychainStoreTests: XCTestCase {

    /// Use a test-specific service string so we never collide with a real
    /// app's keychain items running on the same simulator.
    private let testService = "com.acmebank.mobile.tests.keychain"

    private var store: KeychainStore!

    override func setUp() {
        super.setUp()
        store = KeychainStore(service: testService)
        // Start each test from a clean slate.
        for key in KeychainStore.KeychainKey.allCases {
            try? store.delete(key)
        }
    }

    override func tearDown() {
        for key in KeychainStore.KeychainKey.allCases {
            try? store.delete(key)
        }
        store = nil
        super.tearDown()
    }

    // MARK: - Round-trip per key

    func test_saveAndRead_idToken_roundTrips() throws {
        try store.save("id-token-value", for: .idToken)
        XCTAssertEqual(try store.read(.idToken), "id-token-value")
    }

    func test_saveAndRead_accessToken_roundTrips() throws {
        try store.save("access-token-value", for: .accessToken)
        XCTAssertEqual(try store.read(.accessToken), "access-token-value")
    }

    func test_saveAndRead_refreshToken_roundTrips() throws {
        try store.save("refresh-token-value", for: .refreshToken)
        XCTAssertEqual(try store.read(.refreshToken), "refresh-token-value")
    }

    // MARK: - Overwrite

    func test_save_overwritesExistingValue() throws {
        try store.save("first", for: .idToken)
        try store.save("second", for: .idToken)
        XCTAssertEqual(try store.read(.idToken), "second")
    }

    // MARK: - Absent key → nil, not error

    func test_read_absentKey_returnsNil() throws {
        XCTAssertNil(try store.read(.idToken))
        XCTAssertNil(try store.read(.accessToken))
        XCTAssertNil(try store.read(.refreshToken))
    }

    // MARK: - Delete

    func test_delete_removesValue() throws {
        try store.save("to-be-deleted", for: .accessToken)
        try store.delete(.accessToken)
        XCTAssertNil(try store.read(.accessToken))
    }

    func test_delete_isIdempotent() {
        // Deleting an absent item must succeed (it's a no-op), NOT throw.
        XCTAssertNoThrow(try store.delete(.refreshToken))
        XCTAssertNoThrow(try store.delete(.refreshToken))
        XCTAssertNoThrow(try store.delete(.refreshToken))
    }

    // MARK: - Simulator entitlement guard

    /// Sentinel test: any `SecItem*` failure on the simulator with status
    /// `errSecMissingEntitlement` (-34018) means we forgot
    /// `kSecUseDataProtectionKeychain: true` somewhere. Surface that
    /// explicitly rather than letting it ride as a generic OSStatus.
    func test_save_doesNotHitMissingEntitlement() {
        do {
            try store.save("entitlement-probe", for: .idToken)
        } catch KeychainStore.KeychainError.unexpectedStatus(let status) {
            XCTAssertNotEqual(
                status, -34018,
                "errSecMissingEntitlement on the simulator → kSecUseDataProtectionKeychain missing from query"
            )
            XCTFail("unexpected keychain status: \(status)")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
