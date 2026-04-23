//
//  KeychainStore.swift
//  Alarmio
//
//  Created by Parenthood ApS on 4/23/26
//  Copyright © 2026 Parenthood ApS. All rights reserved.
//

import Foundation
import Security

/// Minimal Keychain wrapper for storing `Int` values by string key.
///
/// Used by `ProLimitCounter` to persist the free-tier generation budget
/// across app reinstalls. Keychain items with
/// `kSecAttrAccessibleAfterFirstUnlock` survive app delete on iOS by
/// convention, which is exactly what we want: uninstalling the app
/// should NOT refund a user's free generations.
enum KeychainStore {

    // MARK: - Constants

    private static let service = "com.alarmio.prolimit"

    // MARK: - Public API

    /// Reads an `Int` value stored under the given key. Returns nil if
    /// the item doesn't exist or is unreadable.
    static func readInt(forKey key: String) -> Int? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let value = Int(string) else {
            return nil
        }
        return value
    }

    /// Writes an `Int` value under the given key. Overwrites any existing
    /// value. Throws on unexpected Keychain failure (not found + first-write
    /// case is handled internally).
    static func writeInt(_ value: Int, forKey key: String) throws {
        let data = Data("\(value)".utf8)

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
            return
        }

        throw KeychainError.unexpectedStatus(updateStatus)
    }

    /// Deletes the item under the given key. No-op if it doesn't exist.
    static func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Errors

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }
}
