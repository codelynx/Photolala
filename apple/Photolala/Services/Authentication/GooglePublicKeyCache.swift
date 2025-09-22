//
//  GooglePublicKeyCache.swift
//  Photolala
//
//  Caches Google's public keys for JWT verification
//

import Foundation

/// Actor that manages Google's public keys for JWT verification
actor GooglePublicKeyCache {
	static let shared = GooglePublicKeyCache()

	private var keys: [String: Data] = [:]
	private var lastFetched: Date?
	private let cacheExpiry: TimeInterval = 3600  // 1 hour

	/// Get public key for a specific key ID
	func getKey(for keyID: String) async throws -> Data {
		// Check if cache needs refresh
		if shouldRefreshCache() {
			try await refreshKeys()
		}

		guard let key = keys[keyID] else {
			// Try one more refresh in case key was rotated
			try await refreshKeys()
			guard let key = keys[keyID] else {
				throw GoogleSignInError.unknownKeyID
			}
			return key
		}

		return key
	}

	/// Check if cache should be refreshed
	private func shouldRefreshCache() -> Bool {
		guard let lastFetched = lastFetched else { return true }
		return Date().timeIntervalSince(lastFetched) > cacheExpiry
	}

	/// Refresh public keys from Google
	private func refreshKeys() async throws {
		let url = URL(string: "https://www.googleapis.com/oauth2/v3/certs")!
		let (data, response) = try await URLSession.shared.data(from: url)

		guard let httpResponse = response as? HTTPURLResponse,
			  httpResponse.statusCode == 200 else {
			throw GoogleSignInError.publicKeyFetchFailed
		}

		guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let keysArray = json["keys"] as? [[String: Any]] else {
			throw GoogleSignInError.publicKeyFetchFailed
		}

		var newKeys: [String: Data] = [:]

		for keyInfo in keysArray {
			guard let kid = keyInfo["kid"] as? String,
				  let n = keyInfo["n"] as? String,  // modulus
				  let e = keyInfo["e"] as? String   // exponent
			else { continue }

			// Convert RSA components to public key
			if let publicKeyData = createRSAPublicKey(modulus: n, exponent: e) {
				newKeys[kid] = publicKeyData
			}
		}

		keys = newKeys
		lastFetched = Date()
	}

	/// Create RSA public key from modulus and exponent
	private nonisolated func createRSAPublicKey(modulus: String, exponent: String) -> Data? {
		guard let modulusData = Data(base64URLEncoded: modulus),
			  let exponentData = Data(base64URLEncoded: exponent) else {
			return nil
		}

		// Create proper ASN.1 DER encoded RSA public key with correct integer encoding
		var keyData = Data()

		// Helper to encode ASN.1 INTEGER with proper padding for sign bit
		func encodeInteger(_ data: Data) -> Data {
			var result = Data()
			result.append(0x02)  // INTEGER tag

			var intData = data
			// Add leading zero if high bit is set (to indicate positive number)
			if let firstByte = intData.first, firstByte & 0x80 != 0 {
				intData.insert(0x00, at: 0)
			}

			// Encode length
			if intData.count <= 127 {
				result.append(UInt8(intData.count))
			} else if intData.count <= 255 {
				result.append(0x81)  // Long form, 1 byte length
				result.append(UInt8(intData.count))
			} else {
				result.append(0x82)  // Long form, 2 byte length
				result.append(UInt8((intData.count >> 8) & 0xFF))
				result.append(UInt8(intData.count & 0xFF))
			}

			result.append(intData)
			return result
		}

		// Build RSAPublicKey SEQUENCE (modulus, exponent)
		let encodedModulus = encodeInteger(modulusData)
		let encodedExponent = encodeInteger(exponentData)

		var rsaPublicKey = Data()
		rsaPublicKey.append(encodedModulus)
		rsaPublicKey.append(encodedExponent)

		// Wrap in SEQUENCE
		var rsaSequence = Data()
		rsaSequence.append(0x30)  // SEQUENCE tag
		if rsaPublicKey.count <= 127 {
			rsaSequence.append(UInt8(rsaPublicKey.count))
		} else if rsaPublicKey.count <= 255 {
			rsaSequence.append(0x81)
			rsaSequence.append(UInt8(rsaPublicKey.count))
		} else {
			rsaSequence.append(0x82)
			rsaSequence.append(UInt8((rsaPublicKey.count >> 8) & 0xFF))
			rsaSequence.append(UInt8(rsaPublicKey.count & 0xFF))
		}
		rsaSequence.append(rsaPublicKey)

		// AlgorithmIdentifier for RSA
		let algorithmIdentifier = Data([
			0x30, 0x0D,  // SEQUENCE, length 13
			0x06, 0x09,  // OBJECT IDENTIFIER, length 9
			// rsaEncryption OID: 1.2.840.113549.1.1.1
			0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,
			0x05, 0x00   // NULL
		])

		// BIT STRING containing the RSA public key
		var bitString = Data()
		bitString.append(0x03)  // BIT STRING tag
		let bitStringContent = rsaSequence
		let bitStringLength = bitStringContent.count + 1  // +1 for unused bits byte

		if bitStringLength <= 127 {
			bitString.append(UInt8(bitStringLength))
		} else if bitStringLength <= 255 {
			bitString.append(0x81)
			bitString.append(UInt8(bitStringLength))
		} else {
			bitString.append(0x82)
			bitString.append(UInt8((bitStringLength >> 8) & 0xFF))
			bitString.append(UInt8(bitStringLength & 0xFF))
		}
		bitString.append(0x00)  // No unused bits
		bitString.append(bitStringContent)

		// Final SubjectPublicKeyInfo SEQUENCE
		var spki = Data()
		spki.append(algorithmIdentifier)
		spki.append(bitString)

		// Wrap in outer SEQUENCE
		keyData.append(0x30)  // SEQUENCE tag
		if spki.count <= 127 {
			keyData.append(UInt8(spki.count))
		} else if spki.count <= 255 {
			keyData.append(0x81)
			keyData.append(UInt8(spki.count))
		} else {
			keyData.append(0x82)
			keyData.append(UInt8((spki.count >> 8) & 0xFF))
			keyData.append(UInt8(spki.count & 0xFF))
		}
		keyData.append(spki)

		return keyData
	}
}

// Data extension moved to GoogleSignInCoordinator.swift to avoid duplication