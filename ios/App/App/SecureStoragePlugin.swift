import Foundation
import Capacitor
import CryptoKit

/**
 * Yacht — iOS hardware-backed vault wrap.
 *
 * Mirrors the Android SecureStoragePlugin:
 *   • The encrypted vault (Argon2id-derived AES-GCM) is wrapped a SECOND
 *     time with an AES-256-GCM key.
 *   • That second key is stored in the iOS Keychain with
 *     kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly, which means it's
 *     unlocked the first time the user enters their passcode after a
 *     reboot, but never replicated to iCloud Keychain — it stays on
 *     THIS device.
 *   • The key is bound to the app's bundle ID; no other app on the
 *     device (or on iCloud Keychain) can read it.
 *
 * The actual AES-GCM crypto runs in user-space via CryptoKit. iOS's
 * Secure Enclave doesn't support AES (only EC P-256), so for parity
 * with the Android plugin we use Keychain-stored AES bytes rather than
 * a SE-resident key. Adding biometric-gated re-derivation is a v0.2
 * task (BiometricPrompt on Android, kSecAccessControlBiometryAny here).
 */
@objc(SecureStoragePlugin)
public class SecureStoragePlugin: CAPPlugin, CAPBridgedPlugin {

    // CAPBridgedPlugin conformance. Capacitor 6/7/8 only auto-registers an
    // app-embedded Swift plugin (no .podspec) when it advertises its JS name
    // and method table here. Without this the JS `registerPlugin('SecureStorage')`
    // never binds to these methods, every encrypt/decrypt call rejects, and
    // mobile-shim silently falls back to storing the vault UNWRAPPED in
    // Preferences. `jsName` MUST match registerPlugin('SecureStorage').
    public let identifier = "SecureStoragePlugin"
    public let jsName = "SecureStorage"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "encrypt", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "decrypt", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
    ]

    private static let keyAccount = "com.yacht.wallet.master"
    private static let keyService = "com.yacht.wallet"

    // MARK: - Plugin methods

    @objc func encrypt(_ call: CAPPluginCall) {
        guard let plaintext = call.getString("data") else {
            call.reject("Missing 'data'")
            return
        }
        do {
            let key = try loadOrCreateMasterKey()
            guard let pt = plaintext.data(using: .utf8) else {
                call.reject("Plaintext is not valid UTF-8")
                return
            }
            let sealed = try AES.GCM.seal(pt, using: key)
            guard let combined = sealed.combined else {
                call.reject("AES.GCM.seal returned no combined data")
                return
            }
            call.resolve(["data": combined.base64EncodedString()])
        } catch {
            call.reject("Encrypt failed: \(error.localizedDescription)")
        }
    }

    @objc func decrypt(_ call: CAPPluginCall) {
        guard let encoded = call.getString("data") else {
            call.reject("Missing 'data'")
            return
        }
        guard let combined = Data(base64Encoded: encoded) else {
            call.reject("Ciphertext is not valid base64")
            return
        }
        do {
            let key = try loadOrCreateMasterKey()
            let sealed = try AES.GCM.SealedBox(combined: combined)
            let pt = try AES.GCM.open(sealed, using: key)
            guard let s = String(data: pt, encoding: .utf8) else {
                call.reject("Decrypted bytes are not valid UTF-8")
                return
            }
            call.resolve(["data": s])
        } catch {
            call.reject("Decrypt failed: \(error.localizedDescription)")
        }
    }

    @objc func clear(_ call: CAPPluginCall) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: SecureStoragePlugin.keyAccount,
            kSecAttrService as String: SecureStoragePlugin.keyService
        ]
        SecItemDelete(query as CFDictionary)
        call.resolve()
    }

    @objc func status(_ call: CAPPluginCall) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: SecureStoragePlugin.keyAccount,
            kSecAttrService as String: SecureStoragePlugin.keyService,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        call.resolve(["present": status == errSecSuccess])
        _ = query  // silence unused warning when compiled in some configs
    }

    // MARK: - Key management

    /**
     * Load the master AES-256 key from Keychain, or generate + store
     * a new one if this is the first call. The Keychain entry is
     * scoped to this app's bundle and the user's device only.
     */
    private func loadOrCreateMasterKey() throws -> SymmetricKey {
        if let bytes = try keychainRead() {
            return SymmetricKey(data: bytes)
        }
        let fresh = SymmetricKey(size: .bits256)
        let raw = fresh.withUnsafeBytes { Data($0) }
        try keychainWrite(raw)
        return fresh
    }

    private func keychainRead() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: SecureStoragePlugin.keyAccount,
            kSecAttrService as String: SecureStoragePlugin.keyService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: "SecureStorage", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Keychain read failed (\(status))"])
        }
        return data
    }

    private func keychainWrite(_ data: Data) throws {
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: SecureStoragePlugin.keyAccount,
            kSecAttrService as String: SecureStoragePlugin.keyService,
            kSecValueData as String: data,
            // After first device unlock following a reboot. NEVER syncs
            // to iCloud Keychain — staying on THIS device is the whole
            // point of the wrap.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrSynchronizable as String: false
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess {
            throw NSError(domain: "SecureStorage", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Keychain write failed (\(status))"])
        }
    }
}
