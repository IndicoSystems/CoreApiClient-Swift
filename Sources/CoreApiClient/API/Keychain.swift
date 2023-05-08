import Foundation
import Security

enum KeychainError: Error {
    case invalidContent
    case failure(OSStatus)
}

class Keychain {
    
    static let standard = Keychain()
    
    private init() {}
    
    private func setupQueryDictionary(forKey key: String) throws -> [CFString: Any] {
        guard let keyData = key.data(using: .utf8) else {
            print("Could not convert key to expected format")
            throw KeychainError.invalidContent
        }
        
        let queryDictionary: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: keyData]
        
        return queryDictionary
    }
    
    func set(entry: String, forKey key: String) throws {
        guard !entry.isEmpty && !key.isEmpty else {
            print("Key must not be empty")
            throw KeychainError.invalidContent
        }
        
        try removeEntry(forKey: key)
        
        var queryDictionary = try setupQueryDictionary(forKey: key)
        queryDictionary[kSecValueData] = entry.data(using: .utf8)
        
        let status = SecItemAdd(queryDictionary as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.failure(status)
        }
    }
    
    func entry(forKey key: String) throws -> String? {
        guard !key.isEmpty else {
            print("Key must be valid")
            throw KeychainError.invalidContent
        }
        
        var queryDictionary = try setupQueryDictionary(forKey: key)
        
        queryDictionary[kSecReturnData] = kCFBooleanTrue
        queryDictionary[kSecMatchLimit] = kSecMatchLimitOne
        
        var data: AnyObject?
        
        let status = SecItemCopyMatching(queryDictionary as CFDictionary, &data)
        guard status == errSecSuccess else {
            throw KeychainError.failure(status)
        }
        
        guard let itemData = data as? Data, let result = String(data: itemData, encoding: .utf8) else {
            return nil
        }
        
        return result
    }
    
    func removeEntry(forKey key: String) throws {
        guard !key.isEmpty else {
            print("Key must be valid")
            throw KeychainError.invalidContent
        }
        
        let queryDictionary = try setupQueryDictionary(forKey: key)
        SecItemDelete(queryDictionary as CFDictionary)
    }
}
