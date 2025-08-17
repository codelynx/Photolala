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
			
			// Update user info from fresh JWT data (Apple only provides these on first sign-in)
			// Only update if we have non-empty values
			if let email = credential.email, !email.isEmpty {
				updatedUser.email = email
			}
			if let fullName = credential.fullName, !fullName.isEmpty {
				updatedUser.fullName = fullName
			}
			if let photoURL = credential.photoURL, !photoURL.isEmpty {
				updatedUser.photoURL = photoURL
			}
			
			// Log what we have for debugging
			print("[IdentityManager] Sign in - existing user data: fullName=\(user.fullName ?? "nil"), email=\(user.email ?? "nil")")
			print("[IdentityManager] Sign in - credential data: fullName=\(credential.fullName ?? "nil"), email=\(credential.email ?? "nil")")
			print("[IdentityManager] Sign in - updated user: fullName=\(updatedUser.fullName ?? "nil"), email=\(updatedUser.email ?? "nil")")
			
			updatedUser.lastUpdated = Date()
			try await saveUser(updatedUser)
			
			await MainActor.run {
				self.currentUser = updatedUser
				self.isSignedIn = true
				print("[IdentityManager] Sign in successful - User set: \(updatedUser.serviceUserID), provider: \(updatedUser.primaryProvider.rawValue)")
			}
			return updatedUser
			
		case (.signIn, nil):
			// Sign in failed - no account exists
			// Include the credential so it can be reused for account creation
			throw AuthError.noAccountFound(provider: provider, credential: credential)
			
		case (.createAccount, _?):
			// Create account failed - user already exists
			throw AuthError.accountAlreadyExists(provider: provider)
			
		case (.createAccount, nil):
			// Check if there's an existing account with the same email
			if let email = credential.email,
			   let existingUserWithEmail = try await findUserByEmail(email) {
				// Found existing account with same email - prompt for linking
				throw AuthError.emailAlreadyInUse(
					existingUser: existingUserWithEmail,
					newCredential: credential
				)
			}
			
			// Create account successful - create new user
			let serviceUserID = UUID().uuidString.lowercased()
			
			// Log what we're getting from Apple on first sign-in
			print("[IdentityManager] Create account - credential data: fullName=\(credential.fullName ?? "nil"), email=\(credential.email ?? "nil")")
			
			let newUser = PhotolalaUser(
				serviceUserID: serviceUserID,
				provider: provider,
				providerID: credential.providerID,
				email: credential.email,
				fullName: credential.fullName,
				photoURL: credential.photoURL,
				subscription: Subscription.freeTrial()
			)
			
			print("[IdentityManager] Create account - new user: fullName=\(newUser.fullName ?? "nil"), email=\(newUser.email ?? "nil")")
			
			try await saveUser(newUser)
			try await createS3UserFolders(for: newUser)
			
			// Create email mapping if email exists
			if let email = credential.email {
				try await updateEmailMapping(email: email, serviceUserID: serviceUserID)
			}
			
			await MainActor.run {
				self.currentUser = newUser
				self.isSignedIn = true
				print("[IdentityManager] Account created - User set: \(newUser.serviceUserID), provider: \(newUser.primaryProvider.rawValue)")
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
	
	/// Create a new account with an existing credential (avoids re-authentication)
	func createAccount(with credential: AuthCredential) async throws -> PhotolalaUser {
		isLoading = true
		errorMessage = nil
		
		defer { isLoading = false }
		
		// Check if user already exists with this provider ID
		let existingUser = try await findUserByProviderID(
			provider: credential.provider,
			providerID: credential.providerID
		)
		
		if existingUser != nil {
			// User already exists - this shouldn't happen in normal flow
			throw AuthError.accountAlreadyExists(provider: credential.provider)
		}
		
		// Check if there's an existing account with the same email
		if let email = credential.email,
		   let existingUserWithEmail = try await findUserByEmail(email) {
			// Found existing account with same email - prompt for linking
			throw AuthError.emailAlreadyInUse(
				existingUser: existingUserWithEmail,
				newCredential: credential
			)
		}
		
		// Create new account
		let serviceUserID = UUID().uuidString.lowercased()
		
		let newUser = PhotolalaUser(
			serviceUserID: serviceUserID,
			provider: credential.provider,
			providerID: credential.providerID,
			email: credential.email,
			fullName: credential.fullName,
			photoURL: credential.photoURL,
			subscription: Subscription.freeTrial()
		)
		
		try await saveUser(newUser)
		try await createS3UserFolders(for: newUser)
		
		// Create email mapping if email exists
		if let email = credential.email {
			try await updateEmailMapping(email: email, serviceUserID: serviceUserID)
		}
		
		await MainActor.run {
			self.currentUser = newUser
			self.isSignedIn = true
		}
		
		return newUser
	}
	
	/// Force create a new account even if email exists
	func forceCreateAccount(with provider: AuthProvider, credential: AuthCredential) async throws -> PhotolalaUser {
		// Skip email check and create new account
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
		
		// Don't create email mapping for forced accounts to avoid conflicts
		
		await MainActor.run {
			self.currentUser = newUser
			self.isSignedIn = true
		}
		
		return newUser
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
			linkedAt: Date()
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
		let credential: AuthCredential
		
		switch provider {
		case .apple:
			credential = try await authenticateWithApple()
		case .google:
			credential = try await GoogleAuthProvider.shared.signIn()
		}
		
		print("[IdentityManager] Authenticated with \(provider.rawValue) - ID: \(credential.providerID), Email: \(credential.email ?? "nil"), Name: \(credential.fullName ?? "nil")")
		return credential
	}
	
	private func authenticateWithApple() async throws -> AuthCredential {
		// Generate nonce for security
		currentNonce = Self.randomNonceString()
		
		let appleIDProvider = ASAuthorizationAppleIDProvider()
		let request = appleIDProvider.createRequest()
		
		// Always request full scopes - Apple will provide them on first authorization
		// On subsequent sign-ins, these will be nil even if requested
		request.requestedScopes = [.fullName, .email]
		request.nonce = Self.sha256(currentNonce!)
		
		// Note: We could check credential state first to see if user has authorized before
		// but this would require knowing the user ID beforehand
		
		#if os(macOS)
			let authorization = try await performSignInMacOS(request: request)
		#else
			let authorization = try await performSignIniOS(request: request)
		#endif
		
		guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
			throw AuthError.invalidCredentials
		}
		
		// Log what Apple provided
		print("[IdentityManager] Apple provided - email: \(appleIDCredential.email ?? "nil"), fullName: \(appleIDCredential.fullName?.debugDescription ?? "nil")")
		print("[IdentityManager] Apple provided - realUserStatus: \(appleIDCredential.realUserStatus.rawValue)")
		
		return AuthCredential(appleCredential: appleIDCredential)
	}
	
	// MARK: - User Management
	
	internal func findUserByProviderID(provider: AuthProvider, providerID: String, checkLocalCache: Bool = true) async throws -> PhotolalaUser? {
		print("[IdentityManager] findUserByProviderID called with \(provider.rawValue):\(providerID)")
		
		// Always check S3 first as the single source of truth
		let s3Manager = S3BackupManager.shared
		guard let s3Service = s3Manager.s3Service else {
			// Try legacy model if S3 not available
			if let legacyUser = try? loadLegacyUser() {
				// Migrate to new model
				let migratedUser = PhotolalaUser(legacy: legacyUser)
				try await saveUser(migratedUser)
				return migratedUser
			}
			return nil
		}
		
		// Look up UUID from identity mapping
		let identityKey = "\(provider.rawValue):\(providerID)"
		let identityPath = "identities/\(identityKey)"
		
		print("[IdentityManager] Checking S3 for identity mapping: \(identityPath)")
		
		do {
			let uuidData = try await s3Service.downloadData(from: identityPath)
			guard let serviceUserID = String(data: uuidData, encoding: .utf8) else {
				return nil
			}
			
			// Found identity mapping! Create a basic user object
			// In the future, we'll load full user data from S3
			print("Found identity mapping: \(identityPath) -> \(serviceUserID)")
			
			// Reconstruct user from available data
			let reconstructedUser = PhotolalaUser(
				serviceUserID: serviceUserID,
				provider: provider,
				providerID: providerID,
				email: nil, // Will be updated from JWT
				fullName: nil, // Will be updated from JWT
				photoURL: nil,
				subscription: Subscription.freeTrial() // Default subscription
			)
			
			// Note: The actual email/name will be updated after successful authentication
			// This is just enough to indicate the account exists
			return reconstructedUser
		} catch {
			print("No identity mapping found for \(identityPath)")
			return nil
		}
	}
	
	private func loadLegacyUser() throws -> LegacyPhotolalaUser? {
		guard let userData = try? KeychainManager.shared.load(key: keychainKey) else {
			return nil
		}
		
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return try? decoder.decode(LegacyPhotolalaUser.self, from: userData)
	}
	
	private func saveUser(_ user: PhotolalaUser) async throws {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601
		let userData = try encoder.encode(user)
		
		do {
			try KeychainManager.shared.save(userData, for: keychainKey)
		} catch {
			print("[IdentityManager] Keychain save failed: \(error), continuing anyway")
			// Don't throw - S3 persistence is sufficient
		}
	}
	
	private func createS3UserFolders(for user: PhotolalaUser) async throws {
		print("[IdentityManager] Creating S3 folders for user: \(user.serviceUserID)")
		
		let s3Manager = S3BackupManager.shared
		
		// Ensure S3 service is initialized
		await s3Manager.ensureInitialized()
		
		guard s3Manager.s3Service != nil else {
			print("[IdentityManager] ERROR: S3 service is not initialized, cannot create user folders")
			print("[IdentityManager] Attempting to continue without S3 folders...")
			// Don't throw - allow account creation to continue
			// User folders will be created on first backup
			return
		}
		
		do {
			// Create user directory
			let userPath = "users/\(user.serviceUserID)/"
			print("[IdentityManager] Creating user directory: \(userPath)")
			try await s3Manager.createFolder(at: userPath)
			print("[IdentityManager] Successfully created user directory")
			
			// Create provider ID mapping in /identities/
			let identityKey = "\(user.primaryProvider.rawValue):\(user.primaryProviderID)"
			let identityPath = "identities/\(identityKey)"
			
			print("[IdentityManager] Creating identity mapping: \(identityPath)")
			// Store the UUID as content of the identity file
			let uuidData = user.serviceUserID.data(using: .utf8)!
			try await s3Manager.uploadData(uuidData, to: identityPath)
			
			print("[IdentityManager] Successfully created identity mapping: \(identityPath) -> \(user.serviceUserID)")
		} catch {
			print("[IdentityManager] ERROR creating S3 folders: \(error)")
			print("[IdentityManager] Error type: \(type(of: error))")
			print("[IdentityManager] Error details: \(error.localizedDescription)")
			// Don't throw - allow account creation to continue
			// This way the user can still sign in even if S3 is temporarily unavailable
		}
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
// Note: providerAlreadyLinked moved to AuthError enum in AuthProvider.swift