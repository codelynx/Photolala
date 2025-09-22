import Foundation
import Security

actor KeychainService {
	static let shared = KeychainService()

	private let service = "com.electricwoods.photolala"

	private init() {}

	func save(key: String, data: Data) {
		delete(key: key)

		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key,
			kSecValueData as String: data,
			kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
		]

		let status = SecItemAdd(query as CFDictionary, nil)
		if status != errSecSuccess {
			print("Failed to save to keychain: \(status)")
		}
	}

	func load(key: String) -> Data? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]

		var dataTypeRef: AnyObject?
		let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

		if status == errSecSuccess {
			return dataTypeRef as? Data
		}

		return nil
	}

	func delete(key: String) {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: service,
			kSecAttrAccount as String: key
		]

		SecItemDelete(query as CFDictionary)
	}
}