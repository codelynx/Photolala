import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

// MARK: - Enhanced Authentication Methods

extension IdentityManager {
	// MARK: - Public Authentication Methods
	
	/*
	 Authentication Flow:
	 1. Both "Sign In" and "Create Account" use the SAME authentication process
	 2. User authenticates with Apple/Google and we receive a JWT
	 3. We check if a Photolala user exists with the provider's user ID
	 4. Based on user intent and existence:
	    - Sign In + User Exists = Success, return user
	    - Sign In + No User = Error "No account found"
	    - Create Account + User Exists = Error "Account already exists"
	    - Create Account + No User = Success, create new user with UUID
	 */
	
	/// Unified authentication flow - handles both sign in and account creation
	private func authenticateAndProcess(with provider: AuthProvider, intent: AuthIntent) async throws -> PhotolalaUser {
		isLoading = true
		errorMessage = nil
		
		defer { isLoading = false }
		
		// Step 1: Always authenticate with provider first (same for signin/signup)
		let credential = try await authenticate(with: provider)
		
		// Step 2: Check if user exists with this provider ID
		let existingUser = try await findUserByProviderID(
			provider: credential.provider,
			providerID: credential.providerID
		)
		
		// Step 3: Handle based on intent and existence
		switch (intent, existingUser) {
		case (.signIn, let user?):
			// Sign in successful - user exists
			var updatedUser = user
			updatedUser.lastUpdated = Date()
			try await saveUser(updatedUser)
			
			await MainActor.run {
				self.currentUser = updatedUser
				self.isSignedIn = true
			}
			return updatedUser
			
		case (.signIn, nil):
			// Sign in failed - no account exists
			throw AuthError.noAccountFound(provider: provider)
			
		case (.createAccount, let user?):
			// Create account failed - user already exists
			throw AuthError.accountAlreadyExists(provider: provider)
			
		case (.createAccount, nil):
			// Create account successful - create new user
			let serviceUserID = UUID().uuidString.lowercased()
			
			let newUser = PhotolalaUser(
				serviceUserID: serviceUserID,
				provider: provider,
				providerID: credential.providerID,
				email: credential.email,
				fullName: credential.fullName,
				photoURL: credential.photoURL,
				subscription: Subscription.freeTrial()
			)
			
			try await saveUser(newUser)
			try await createS3UserFolders(for: newUser)
			
			await MainActor.run {
				self.currentUser = newUser
				self.isSignedIn = true
			}
			return newUser
		}
	}
	
	/// Sign in with an existing account
	func signIn(with provider: AuthProvider) async throws -> PhotolalaUser {
		try await authenticateAndProcess(with: provider, intent: .signIn)
	}
	
	/// Create a new account
	func createAccount(with provider: AuthProvider) async throws -> PhotolalaUser {
		try await authenticateAndProcess(with: provider, intent: .createAccount)
	}
	
	private enum AuthIntent {
		case signIn
		case createAccount
	}
	
	/// Link another provider to existing account
	func linkProvider(_ provider: AuthProvider, to user: PhotolalaUser) async throws -> PhotolalaUser {
		// Step 1: Authenticate with new provider
		let credential = try await authenticate(with: provider)
		
		// Step 2: Check if already linked to another user
		if let existingUser = try await findUserByProviderID(
			provider: credential.provider,
			providerID: credential.providerID
		), existingUser.serviceUserID != user.serviceUserID {
			throw AuthError.providerAlreadyLinked
		}
		
		// Step 3: Create provider link
		let providerLink = ProviderLink(
			provider: credential.provider,
			providerID: credential.providerID,
			email: credential.email,
			linkedAt: Date(),
			linkMethod: .userInitiated
		)
		
		// Step 4: Update user
		var updatedUser = user
		updatedUser.linkedProviders.append(providerLink)
		updatedUser.lastUpdated = Date()
		
		try await saveUser(updatedUser)
		
		// Step 5: Update app state
		await MainActor.run {
			self.currentUser = updatedUser
		}
		
		return updatedUser
	}
	
	// MARK: - Provider Authentication
	
	private func authenticate(with provider: AuthProvider) async throws -> AuthCredential {
		switch provider {
		case .apple:
			return try await authenticateWithApple()
		case .google:
			throw AuthError.providerNotImplemented
		}
	}
	
	private func authenticateWithApple() async throws -> AuthCredential {
		// Generate nonce for security
		currentNonce = Self.randomNonceString()
		
		let appleIDProvider = ASAuthorizationAppleIDProvider()
		let request = appleIDProvider.createRequest()
		request.requestedScopes = [.fullName, .email]
		request.nonce = Self.sha256(currentNonce!)
		
		#if os(macOS)
			let authorization = try await performSignInMacOS(request: request)
		#else
			let authorization = try await performSignIniOS(request: request)
		#endif
		
		guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
			throw AuthError.invalidCredentials
		}
		
		return AuthCredential(appleCredential: appleIDCredential)
	}
	
	// MARK: - User Management
	
	private func findUserByProviderID(provider: AuthProvider, providerID: String) async throws -> PhotolalaUser? {
		// For now, we'll check locally. In the future, this would query a backend
		guard let userData = try? KeychainManager.shared.load(key: keychainKey),
		      let user = try? JSONDecoder().decode(PhotolalaUser.self, from: userData) else {
			// Try legacy model
			if let legacyUser = try? loadLegacyUser() {
				// Migrate to new model
				let migratedUser = PhotolalaUser(legacy: legacyUser)
				try await saveUser(migratedUser)
				return migratedUser
			}
			return nil
		}
		
		// Check if this provider matches
		if user.primaryProvider == provider && user.primaryProviderID == providerID {
			return user
		}
		
		// Check linked providers
		for linked in user.linkedProviders {
			if linked.provider == provider && linked.providerID == providerID {
				return user
			}
		}
		
		return nil
	}
	
	private func loadLegacyUser() throws -> LegacyPhotolalaUser? {
		guard let userData = try? KeychainManager.shared.load(key: keychainKey) else {
			return nil
		}
		
		return try? JSONDecoder().decode(LegacyPhotolalaUser.self, from: userData)
	}
	
	private func saveUser(_ user: PhotolalaUser) async throws {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let userData = try encoder.encode(user)
		try KeychainManager.shared.save(userData, for: keychainKey)
	}
	
	private func createS3UserFolders(for user: PhotolalaUser) async throws {
		// This will be implemented to create the S3 folder structure
		// For now, we'll just log
		print("Creating S3 folders for user: \(user.serviceUserID)")
		
		// TODO: Implement S3 folder creation
		// let s3Manager = S3BackupManager.shared
		// try await s3Manager.createUserFolders(serviceUserID: user.serviceUserID)
	}
	
	// MARK: - Utility Methods (moved to be accessible)
	
	static func randomNonceString(length: Int = 32) -> String {
		precondition(length > 0)
		let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
		var result = ""
		var remainingLength = length
		
		while remainingLength > 0 {
			let randoms: [UInt8] = (0 ..< 16).map { _ in
				var random: UInt8 = 0
				let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
				if errorCode != errSecSuccess {
					fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
				}
				return random
			}
			
			for random in randoms {
				if remainingLength == 0 {
					continue
				}
				
				if random < charset.count {
					result.append(charset[Int(random)])
					remainingLength -= 1
				}
			}
		}
		
		return result
	}
	
	static func sha256(_ input: String) -> String {
		let inputData = Data(input.utf8)
		let hashedData = SHA256.hash(data: inputData)
		let hashString = hashedData.compactMap {
			String(format: "%02x", $0)
		}.joined()
		
		return hashString
	}
}

// MARK: - Additional Auth Errors

extension AuthError {
	static var providerAlreadyLinked: AuthError {
		.authenticationFailed(reason: "This provider is already linked to another account")
	}
}