import Foundation
import Security

/// Thin wrapper over `SecItem*` for the three OAuth2 tokens we persist.
///
/// Every query dictionary includes `kSecUseDataProtectionKeychain: true`
/// and `kSecClass: kSecClassGenericPassword`. The data-protection flag is
/// load-bearing: without it, iOS Simulator builds compiled with
/// `CODE_SIGNING_ALLOWED=NO` fail with `errSecMissingEntitlement` (-34018)
/// on every `SecItem*` call. The flag works on both simulator and signed
/// device builds, so it's safe to always set. See `AGENT.md` § Keychain.
public final class KeychainStore {

    // MARK: - Keys

    /// The three OAuth2 token kinds we ever persist. Each maps to a
    /// distinct `kSecAttrAccount` so a single keychain item per kind is
    /// addressable without colliding.
    public enum KeychainKey: String, CaseIterable {
        case idToken      = "com.acmebank.mobile.auth.idToken"
        case accessToken  = "com.acmebank.mobile.auth.accessToken"
        case refreshToken = "com.acmebank.mobile.auth.refreshToken"
    }

    // MARK: - Errors

    /// Surfaced when the underlying `SecItem*` call returns a non-success
    /// OSStatus we can't quietly absorb. `signIn` callers should treat
    /// keychain failures as cache misses (log + continue), per the
    /// `OktaAuthService` contract — see lessons in this repo.
    public enum KeychainError: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case dataConversionFailed
    }

    // MARK: - Config

    private let service: String

    public init(service: String = "com.acmebank.mobile.auth") {
        self.service = service
    }

    // MARK: - API

    /// Insert-or-replace `value` under `key`. Uses delete-then-add to
    /// avoid the dance of detecting "duplicate item" then issuing
    /// `SecItemUpdate`, which gains us nothing for a generic-password
    /// item this small.
    public func save(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        // Best-effort delete of any pre-existing item; ignore errors —
        // `errSecItemNotFound` is fine, and any other status will resurface
        // immediately on the `SecItemAdd` below.
        SecItemDelete(baseQuery(for: key) as CFDictionary)

        var addQuery = baseQuery(for: key)
        addQuery[kSecValueData as String] = data
        // Tokens must be available the moment the device unlocks after a
        // reboot, but never restored to a different device — matches the
        // Keychain Sharing posture in `AcmeBank.entitlements`.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Return the stored value for `key`, or `nil` if no item exists.
    /// Throws only on genuinely unexpected OSStatus values; an absent key
    /// is *not* an error.
    public func read(_ key: KeychainKey) throws -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let str = String(data: data, encoding: .utf8) else {
                throw KeychainError.dataConversionFailed
            }
            return str
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Remove the stored value for `key`. Idempotent: deleting an absent
    /// item is a no-op success, not an error.
    public func delete(_ key: KeychainKey) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Internals

    /// The common attributes every query needs. `kSecUseDataProtectionKeychain`
    /// is on EVERY query — see class doc comment for why.
    private func baseQuery(for key: KeychainKey) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecUseDataProtectionKeychain as String: true
        ]
    }
}
