import Foundation
import Security

enum KeychainError: Error {
	case unhandledError(status: OSStatus)
	case noPassword
	case unexpectedPasswordData
}

class KeychainManager {
	static let shared = KeychainManager()
	
	private let service = "com.electricwoods.photolala"
	private let accessGroup: String? = nil // Use app's default access group
	
	private init() {}
	
	// MARK: - Generic Keychain Operations
	
	func save(_ data: Data, for key: String) throws {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key,
			kSecValueData as String: data
		]
		
		// Delete any existing item
		SecItemDelete(query as CFDictionary)
		
		// Add new item
		let status = SecItemAdd(query as CFDictionary, nil)
		
		guard status == errSecSuccess else {
			throw KeychainError.unhandledError(status: status)
		}
	}
	
	func load(key: String) throws -> Data {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		
		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		
		guard status != errSecItemNotFound else {
			throw KeychainError.noPassword
		}
		
		guard status == errSecSuccess else {
			throw KeychainError.unhandledError(status: status)
		}
		
		guard let passwordData = item as? Data else {
			throw KeychainError.unexpectedPasswordData
		}
		
		return passwordData
	}
	
	func delete(key: String) throws {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key
		]
		
		let status = SecItemDelete(query as CFDictionary)
		
		guard status == errSecSuccess || status == errSecItemNotFound else {
			throw KeychainError.unhandledError(status: status)
		}
	}
	
	// MARK: - AWS Credentials
	
	private let accessKeyId = "AWSAccessKeyId"
	private let secretAccessKey = "AWSSecretAccessKey"
	
	func saveAWSCredentials(accessKey: String, secretKey: String) throws {
		guard let accessData = accessKey.data(using: .utf8),
			  let secretData = secretKey.data(using: .utf8) else {
			throw KeychainError.unexpectedPasswordData
		}
		
		try save(accessData, for: accessKeyId)
		try save(secretData, for: secretAccessKey)
	}
	
	func loadAWSCredentials() throws -> (accessKey: String, secretKey: String) {
		let accessData = try load(key: accessKeyId)
		let secretData = try load(key: secretAccessKey)
		
		guard let accessKey = String(data: accessData, encoding: .utf8),
			  let secretKey = String(data: secretData, encoding: .utf8) else {
			throw KeychainError.unexpectedPasswordData
		}
		
		return (accessKey, secretKey)
	}
	
	func deleteAWSCredentials() throws {
		try delete(key: accessKeyId)
		try delete(key: secretAccessKey)
	}
	
	func hasAWSCredentials() -> Bool {
		do {
			_ = try loadAWSCredentials()
			return true
		} catch {
			return false
		}
	}
}