//
//  IdentityManager+Linking.swift
//  Photolala
//
//  Created by Claude on 7/3/25.
//

import Foundation
import CryptoKit

extension IdentityManager {
	
	// MARK: - Account Discovery
	
	/// Find user by email address
	func findUserByEmail(_ email: String) async throws -> PhotolalaUser? {
		// First check if current user matches
		if let currentUser = currentUser,
		   currentUser.email?.lowercased() == email.lowercased() {
			return currentUser
		}
		
		// Check S3 for email mapping
		let hashedEmail = hashEmail(email)
		let emailPath = "emails/\(hashedEmail)"
		
		let s3Manager = S3BackupManager.shared
		guard let s3Service = s3Manager.s3Service else {
			return nil
		}
		
		do {
			let data = try await s3Service.downloadData(from: emailPath)
			let serviceUserID = String(data: data, encoding: .utf8)
			
			// Now fetch the user data
			if let userID = serviceUserID {
				return try await fetchUserData(serviceUserID: userID)
			}
		} catch {
			// No email mapping found
			print("[IdentityManager] No user found for email: \(email)")
		}
		
		return nil
	}
	
	// MARK: - Account Linking
	
	/// Link a new provider to existing account
	func linkProvider(
		_ provider: AuthProvider,
		credential: AuthCredential,
		to user: PhotolalaUser
	) async throws -> PhotolalaUser {
		// Check if provider already linked
		if user.primaryProvider == provider && user.primaryProviderID == credential.providerID {
			throw AuthError.providerAlreadyLinked
		}
		
		if user.linkedProviders.contains(where: { 
			$0.provider == provider && $0.providerID == credential.providerID 
		}) {
			throw AuthError.providerAlreadyLinked
		}
		
		// Check if this provider ID is already used by another account
		let existingUser = await findUserByProviderID(provider, credential.providerID)
		if let existingUser = existingUser, existingUser.serviceUserID != user.serviceUserID {
			throw AuthError.providerInUseByAnotherAccount
		}
		
		// Create the link
		let providerLink = ProviderLink(
			provider: provider,
			providerID: credential.providerID,
			linkedAt: Date()
		)
		
		var updatedUser = user
		updatedUser.linkedProviders.append(providerLink)
		updatedUser.lastUpdated = Date()
		
		// Update email if better one available
		if updatedUser.email == nil && credential.email != nil {
			updatedUser.email = credential.email
		}
		
		// Create S3 identity mapping for linked provider
		let identityKey = "\(provider.rawValue):\(credential.providerID)"
		let identityPath = "identities/\(identityKey)"
		let uuidData = user.serviceUserID.data(using: .utf8)!
		
		let s3Manager = S3BackupManager.shared
		if let s3Service = s3Manager.s3Service {
			try await s3Service.uploadData(uuidData, to: identityPath)
		}
		print("[IdentityManager] Created identity mapping: \(identityPath) -> \(user.serviceUserID)")
		
		// Update email mapping if available
		if let email = credential.email {
			try await updateEmailMapping(email: email, serviceUserID: user.serviceUserID)
		}
		
		// Save updated user
		try await saveUserData(updatedUser)
		await MainActor.run {
			self.currentUser = updatedUser
		}
		
		return updatedUser
	}
	
	/// Unlink a provider from account
	func unlinkProvider(
		_ provider: AuthProvider,
		from user: PhotolalaUser
	) async throws -> PhotolalaUser {
		// Can't unlink primary provider if it's the only one
		if user.primaryProvider == provider && user.linkedProviders.isEmpty {
			throw AuthError.cannotUnlinkLastProvider
		}
		
		var updatedUser = user
		
		// Remove from linked providers
		updatedUser.linkedProviders.removeAll { $0.provider == provider }
		updatedUser.lastUpdated = Date()
		
		// Remove S3 identity mapping
		if let link = user.linkedProviders.first(where: { $0.provider == provider }) {
			let identityKey = "\(provider.rawValue):\(link.providerID)"
			let identityPath = "identities/\(identityKey)"
			
			let s3Manager = S3BackupManager.shared
			if let s3Service = s3Manager.s3Service {
				do {
					// Delete the identity mapping from S3
					try await s3Service.deleteObject(at: identityPath)
					print("[IdentityManager] Successfully deleted identity mapping: \(identityPath)")
				} catch {
					print("[IdentityManager] Failed to delete identity mapping: \(error)")
					// Continue anyway - the local unlinking is more important
				}
			}
		}
		
		// Save updated user
		try await saveUserData(updatedUser)
		await MainActor.run {
			self.currentUser = updatedUser
		}
		
		return updatedUser
	}
	
	// MARK: - Private Helpers
	
	/// Save user data (wraps the private saveUser method)
	private func saveUserData(_ user: PhotolalaUser) async throws {
		// Save to keychain
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let userData = try encoder.encode(user)
		
		// Log data size for debugging
		print("[IdentityManager] Saving user data to Keychain, size: \(userData.count) bytes")
		
		do {
			try KeychainManager.shared.save(userData, for: keychainKey)
			print("[IdentityManager] Successfully saved user data to Keychain")
		} catch {
			print("[IdentityManager] Failed to save to Keychain: \(error)")
			// Continue with S3 save even if Keychain fails
			// The app can still function with S3 persistence
		}
		
		// Save to S3 if available
		let s3Manager = S3BackupManager.shared
		if let s3Service = s3Manager.s3Service {
			let userPath = "users/\(user.serviceUserID)/profile.json"
			try await s3Service.uploadData(userData, to: userPath)
			print("[IdentityManager] Successfully saved user data to S3")
		}
		
		// Update published state
		await MainActor.run {
			self.currentUser = user
			self.isSignedIn = true
		}
	}
	
	/// Create or update email mapping
	func updateEmailMapping(email: String, serviceUserID: String) async throws {
		let hashedEmail = hashEmail(email)
		let emailPath = "emails/\(hashedEmail)"
		let data = serviceUserID.data(using: .utf8)!
		
		let s3Manager = S3BackupManager.shared
		
		// Ensure S3 service is initialized
		await s3Manager.ensureInitialized()
		
		if let s3Service = s3Manager.s3Service {
			do {
				print("[IdentityManager] Creating email mapping: \(emailPath)")
				try await s3Service.uploadData(data, to: emailPath)
				print("[IdentityManager] Successfully created email mapping: \(email) -> \(serviceUserID)")
			} catch {
				print("[IdentityManager] ERROR creating email mapping: \(error)")
				print("[IdentityManager] Will continue without email mapping")
				// Don't throw - email mapping is not critical for account creation
			}
		} else {
			print("[IdentityManager] WARNING: S3 service not available, skipping email mapping")
		}
	}
	
	/// Hash email for privacy
	func hashEmail(_ email: String) -> String {
		let normalizedEmail = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
		let data = Data(normalizedEmail.utf8)
		let hash = SHA256.hash(data: data)
		return hash.compactMap { String(format: "%02x", $0) }.joined()
	}
	
	/// Fetch user data from S3
	private func fetchUserData(serviceUserID: String) async throws -> PhotolalaUser? {
		let userPath = "users/\(serviceUserID)/profile.json"
		
		let s3Manager = S3BackupManager.shared
		guard let s3Service = s3Manager.s3Service else {
			return nil
		}
		
		do {
			let data = try await s3Service.downloadData(from: userPath)
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			let user = try decoder.decode(PhotolalaUser.self, from: data)
			return user
		} catch {
			print("[IdentityManager] Failed to fetch user data: \(error)")
			return nil
		}
	}
	
	/// Find user by provider ID
	private func findUserByProviderID(_ provider: AuthProvider, _ providerID: String) async -> PhotolalaUser? {
		// Check local user first
		if let currentUser = currentUser {
			if currentUser.primaryProvider == provider && 
			   currentUser.primaryProviderID == providerID {
				return currentUser
			}
			
			if currentUser.linkedProviders.contains(where: { 
				$0.provider == provider && $0.providerID == providerID 
			}) {
				return currentUser
			}
		}
		
		// Check S3 identity mapping
		let identityKey = "\(provider.rawValue):\(providerID)"
		let identityPath = "identities/\(identityKey)"
		
		let s3Manager = S3BackupManager.shared
		guard let s3Service = s3Manager.s3Service else {
			return nil
		}
		
		do {
			let data = try await s3Service.downloadData(from: identityPath)
			if let serviceUserID = String(data: data, encoding: .utf8) {
				return try await fetchUserData(serviceUserID: serviceUserID)
			}
		} catch {
			// No mapping found
		}
		
		return nil
	}
}

