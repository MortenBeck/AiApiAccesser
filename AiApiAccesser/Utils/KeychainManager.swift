import Foundation
import Security
import SwiftUI
import Combine

class KeychainManager {
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case dataConversionError
        case itemNotFound
    }
    
    private func keychainQuery(for type: LLMType) -> [String: Any] {
        let service = "com.AiApiAccesser.apikeys"
        let account = type.rawValue
        
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    
    func saveApiKey(_ key: String, for type: LLMType) throws {
        guard let encodedKey = key.data(using: .utf8) else {
            throw KeychainError.dataConversionError
        }
        
        var query = keychainQuery(for: type)
        
        // First check if the item already exists
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnAttributes as String] = true
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            // Item doesn't exist, add it
            query[kSecValueData as String] = encodedKey
            
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unknown(addStatus)
            }
        } else if status == errSecSuccess {
            // Item exists, update it
            let updateQuery = keychainQuery(for: type)
            let attributes: [String: Any] = [kSecValueData as String: encodedKey]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unknown(updateStatus)
            }
        } else {
            throw KeychainError.unknown(status)
        }
    }
    
    func getApiKey(for type: LLMType) -> String? {
        var query = keychainQuery(for: type)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    func deleteApiKey(for type: LLMType) throws {
        let query = keychainQuery(for: type)
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unknown(status)
        }
    }
}