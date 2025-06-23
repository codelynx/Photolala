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
			kSecAttrService as String: self.service,
			kSecAttrAccount as String: key,
			kSecValueData as String: data,
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
			kSecAttrService as String: self.service,
			kSecAttrAccount as String: key,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne,
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
			kSecAttrService as String: self.service,
			kSecAttrAccount as String: key,
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
		      let secretData = secretKey.data(using: .utf8)
		else {
			throw KeychainError.unexpectedPasswordData
		}

		try self.save(accessData, for: self.accessKeyId)
		try self.save(secretData, for: self.secretAccessKey)
	}

	func loadAWSCredentials() throws -> (accessKey: String, secretKey: String) {
		let accessData = try load(key: accessKeyId)
		let secretData = try load(key: secretAccessKey)

		guard let accessKey = String(data: accessData, encoding: .utf8),
		      let secretKey = String(data: secretData, encoding: .utf8)
		else {
			throw KeychainError.unexpectedPasswordData
		}

		return (accessKey, secretKey)
	}

	func deleteAWSCredentials() throws {
		try self.delete(key: self.accessKeyId)
		try self.delete(key: self.secretAccessKey)
	}

	func hasAWSCredentials() -> Bool {
		do {
			_ = try self.loadAWSCredentials()
			return true
		} catch {
			return false
		}
	}

	// MARK: - AWS Credentials with Fallback
	
	/// Load AWS credentials from Keychain or fall back to encrypted credentials
	func loadAWSCredentialsWithFallback() throws -> (accessKey: String, secretKey: String) {
		// First try Keychain
		do {
			return try loadAWSCredentials()
		} catch {
			// Fall back to encrypted credentials
			guard let accessKey = Credentials.decryptCached(.AWS_ACCESS_KEY_ID),
			      let secretKey = Credentials.decryptCached(.AWS_SECRET_ACCESS_KEY),
			      !accessKey.isEmpty, !secretKey.isEmpty
			else {
				throw KeychainError.noPassword
			}
			
			return (accessKey, secretKey)
		}
	}
	
	/// Check if AWS credentials are available from any source
	func hasAnyAWSCredentials() -> Bool {
		// Check Keychain first
		if hasAWSCredentials() {
			return true
		}
		
		// Check encrypted credentials
		if let accessKey = Credentials.decryptCached(.AWS_ACCESS_KEY_ID),
		   let secretKey = Credentials.decryptCached(.AWS_SECRET_ACCESS_KEY),
		   !accessKey.isEmpty, !secretKey.isEmpty
		{
			return true
		}
		
		return false
	}
}
