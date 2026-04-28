// SecureStorage.swift
// Capa 4 de seguridad — almacenamiento cifrado con AES-GCM + Keychain.
// Usar para datos sensibles locales: API keys, tokens de sesión, etc.

import CryptoKit
import Foundation

actor SecureStorage {
    static let shared = SecureStorage()
    private var cachedKey: SymmetricKey?

    private init() {}

    // MARK: - Keychain helpers

    func set(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw AppError.validation("Valor inválido para guardar en Keychain")
        }
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrAccount as String:      key,
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String:        data,
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AppError.savingFailed("Keychain error \(status)")
        }
    }

    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - AES-GCM encryption

    func encrypt(_ data: Data) async throws -> Data {
        let key = try await getOrCreateEncryptionKey()
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw AppError.savingFailed("No se pudo cifrar el dato")
        }
        return combined
    }

    func decrypt(_ data: Data) async throws -> Data {
        let key = try await getOrCreateEncryptionKey()
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    func encryptCodable<T: Codable>(_ value: T) async throws -> Data {
        let data = try JSONEncoder().encode(value)
        return try await encrypt(data)
    }

    func decryptCodable<T: Codable>(_ data: Data) async throws -> T {
        let decrypted = try await decrypt(data)
        return try JSONDecoder().decode(T.self, from: decrypted)
    }

    // MARK: - Key management

    private let encryptionKeyTag = "com.idanidev.clarity.encryption.key"

    private func getOrCreateEncryptionKey() async throws -> SymmetricKey {
        if let cached = cachedKey { return cached }

        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrAccount as String: encryptionKeyTag,
            kSecReturnData as String:  true,
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data
        {
            let key = SymmetricKey(data: data)
            cachedKey = key
            return key
        }

        // Generar nueva clave y guardar en Keychain
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        let addQuery: [String: Any] = [
            kSecClass as String:           kSecClassGenericPassword,
            kSecAttrAccount as String:     encryptionKeyTag,
            kSecValueData as String:       keyData,
            kSecAttrAccessible as String:  kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw AppError.savingFailed("No se pudo guardar la clave de cifrado")
        }
        cachedKey = newKey
        return newKey
    }
}
