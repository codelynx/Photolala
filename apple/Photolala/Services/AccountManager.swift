import Foundation
import AuthenticationServices
import CryptoKit
@preconcurrency import AWSLambda
import AWSClientRuntime
import SmithyIdentity
import Combine

@MainActor
final class AccountManager: ObservableObject {
	static let shared = AccountManager()

	@Published private(set) var currentUser: PhotolalaUser?
	@Published private(set) var isSignedIn: Bool = false
	@Published private(set) var accountStatus: AccountStatus = .active
	internal var stsCredentials: STSCredentials?
	private var currentNonce: String?
	private var googleSignInCoordinator: GoogleSignInCoordinator?
	private var statusCheckTimer: Timer?

	private let userUUIDKey = "com.electricwoods.photolala.account.uuid"

	private init() {
		Task {
			await loadStoredSession()
			await checkAccountStatus()
			startStatusPolling()
		}
	}

	// MARK: - OAuth Authentication (Step 1)

	func authenticateWithGoogle() async throws -> OAuthTokens {
		print("[AccountManager] Getting Google OAuth tokens")

		// Create and hold a strong reference to the coordinator
		let coordinator = GoogleSignInCoordinator()
		self.googleSignInCoordinator = coordinator
		defer {
			// Release the coordinator when the function completes
			self.googleSignInCoordinator = nil
		}

		// Use the GoogleSignInCoordinator to perform OAuth flow
		let credential = try await coordinator.performSignIn()

		print("[AccountManager] Got Google credential for: \(credential.claims.email ?? "unknown")")

		return OAuthTokens(
			googleIdToken: credential.idToken,
			accessToken: credential.accessToken,
			email: credential.claims.email,
			name: credential.claims.name,
			subject: credential.claims.subject
		)
	}

	func authenticateWithApple() async throws -> OAuthTokens {
		print("[AccountManager] Getting Apple OAuth tokens")

		let credential = try await performAppleSignIn()
		guard let identityToken = credential.identityToken,
		      let tokenString = String(data: identityToken, encoding: .utf8) else {
			throw AccountError.invalidCredential
		}

		let authCode = credential.authorizationCode != nil ?
			String(data: credential.authorizationCode!, encoding: .utf8) : nil

		return OAuthTokens(
			appleIdentityToken: tokenString,
			authorizationCode: authCode,
			nonce: currentNonce,
			userIdentifier: credential.user
		)
	}

	// MARK: - Account Check (Step 2)

	func checkAccountExists(provider: String, oauthTokens: OAuthTokens) async throws -> Bool {
		print("[AccountManager] Checking if account exists for \(provider)")

		// TEMPORARY: Until Lambda supports check_only, we'll call the regular endpoint
		// and check the isNewUser flag in the response

		// Prepare payload (without check_only for now since Lambda doesn't support it)
		let payload: [String: Any] = [
			"id_token": oauthTokens.idToken,
			"provider": provider,
			"access_token": oauthTokens.accessToken ?? "",
			"nonce": oauthTokens.nonce ?? "",
			"authorization_code": oauthTokens.authorizationCode ?? "",
			"user": oauthTokens.userIdentifier,
			"email": oauthTokens.email ?? "",
			"name": oauthTokens.displayName ?? ""
		]

		// Lambda expects API Gateway format with body as JSON string
		let bodyData = try JSONSerialization.data(withJSONObject: payload)
		let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
		let lambdaPayload = ["body": bodyString]
		let jsonData = try JSONSerialization.data(withJSONObject: lambdaPayload)

		// Call Lambda - this will create account if it doesn't exist (temporary behavior)
		do {
			let result = try await callAuthLambdaWithData("photolala-auth", payloadData: jsonData)

			// TEMPORARY: Check if this was a new user
			// Once Lambda supports check_only, this should be replaced
			if result.isNewUser {
				print("[AccountManager] Account was just created (isNewUser=true) - treating as no existing account")
				// TODO: This is problematic because account is already created
				// We need Lambda to support check_only to properly implement this

				// For now, we'll store these credentials temporarily
				// and return false to trigger the signup flow
				// The signup flow will need to handle this edge case
				return false
			} else {
				print("[AccountManager] Existing account found (isNewUser=false)")
				// Store credentials since we already have them
				self.currentUser = result.user
				self.stsCredentials = result.credentials
				return true
			}
		} catch {
			// Check if error indicates no account
			let errorMessage = error.localizedDescription.lowercased()
			if errorMessage.contains("no account") || errorMessage.contains("not found") {
				return false
			}
			// Re-throw other errors
			throw error
		}
	}

	// MARK: - Sign In / Create Account (Step 3)

	func completeSignIn(provider: String, oauthTokens: OAuthTokens) async throws -> PhotolalaUser {
		print("[AccountManager] Completing sign-in for \(provider)")

		// Check if we already have credentials from checkAccountExists
		if let user = currentUser, let creds = stsCredentials, !creds.isExpired {
			print("[AccountManager] Using cached credentials from checkAccountExists")
			self.isSignedIn = true

			// Ensure status.json exists
			await ensureStatusFileExists(for: user)

			// Store user UUID for status checking
			storeUserUUID(user.id.uuidString)

			await saveSession()
			return user
		}

		// Otherwise, call Lambda to sign in
		let payload: [String: Any] = [
			"id_token": oauthTokens.idToken,
			"provider": provider,
			"access_token": oauthTokens.accessToken ?? "",
			"nonce": oauthTokens.nonce ?? "",
			"authorization_code": oauthTokens.authorizationCode ?? "",
			"user": oauthTokens.userIdentifier,
			"email": oauthTokens.email ?? "",
			"name": oauthTokens.displayName ?? ""
		]

		// Lambda expects API Gateway format with body as JSON string
		let bodyData = try JSONSerialization.data(withJSONObject: payload)
		let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
		let lambdaPayload = ["body": bodyString]
		let jsonData = try JSONSerialization.data(withJSONObject: lambdaPayload)

		let result = try await callAuthLambdaWithData("photolala-auth", payloadData: jsonData)

		self.currentUser = result.user
		self.stsCredentials = result.credentials
		self.isSignedIn = true

		// Ensure status.json exists
		await ensureStatusFileExists(for: result.user)

		// Store user UUID for status checking
		storeUserUUID(result.user.id.uuidString)

		await saveSession()

		return result.user
	}

	func createAccount(provider: String, oauthTokens: OAuthTokens, termsAccepted: Bool) async throws -> PhotolalaUser {
		print("[AccountManager] Creating new account for \(provider)")

		guard termsAccepted else {
			throw AccountError.termsNotAccepted
		}

		// TEMPORARY: Account might already be created due to Lambda not supporting check_only
		// If we have cached credentials, use them
		if let user = currentUser, let creds = stsCredentials, !creds.isExpired {
			print("[AccountManager] Account was already created during checkAccountExists")
			self.isSignedIn = true

			// Ensure status.json exists
			await ensureStatusFileExists(for: user)

			// Store user UUID for status checking
			storeUserUUID(user.id.uuidString)

			await saveSession()
			return user
		}

		// Prepare payload for account creation
		// Lambda currently ignores create_account flag but we include it for future compatibility
		let payload: [String: Any] = [
			"id_token": oauthTokens.idToken,
			"provider": provider,
			"create_account": true,  // For future Lambda compatibility
			"terms_accepted": termsAccepted,
			"terms_version": "1.0",
			"access_token": oauthTokens.accessToken ?? "",
			"nonce": oauthTokens.nonce ?? "",
			"authorization_code": oauthTokens.authorizationCode ?? "",
			"user": oauthTokens.userIdentifier,
			"email": oauthTokens.email ?? "",
			"name": oauthTokens.displayName ?? ""
		]

		// Lambda expects API Gateway format with body as JSON string
		let bodyData = try JSONSerialization.data(withJSONObject: payload)
		let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
		let lambdaPayload = ["body": bodyString]
		let jsonData = try JSONSerialization.data(withJSONObject: lambdaPayload)

		let result = try await callAuthLambdaWithData("photolala-auth", payloadData: jsonData)

		self.currentUser = result.user
		self.stsCredentials = result.credentials
		self.isSignedIn = true

		// Ensure status.json exists
		await ensureStatusFileExists(for: result.user)

		// Store user UUID for status checking
		storeUserUUID(result.user.id.uuidString)

		await saveSession()

		return result.user
	}


	func getCurrentUser() -> PhotolalaUser? {
		currentUser
	}

	@MainActor
	func updateUser(_ user: PhotolalaUser) async {
		currentUser = user
		// The STS credentials don't change when user profile updates
		// User profile is stored separately in S3
	}

	func getSTSCredentials() async throws -> STSCredentials {
		if let credentials = stsCredentials, !credentials.isExpired {
			return credentials
		}

		guard let user = currentUser else {
			throw AccountError.notSignedIn
		}

		let result = try await refreshCredentials(userID: user.id)
		self.stsCredentials = result
		await saveSession()
		return result
	}

	func signInWithGoogle() async throws -> PhotolalaUser {
		print("[AccountManager] Starting Google Sign-In")

		// NOTE: This is the OLD method kept for compatibility
		// The NEW flow should use authenticateWithGoogle() + checkAccountExists() + completeSignIn()
		// For now, we'll just call the old Lambda endpoint which auto-creates accounts

		// Create and hold a strong reference to the coordinator
		let coordinator = GoogleSignInCoordinator()
		self.googleSignInCoordinator = coordinator
		defer {
			// Release the coordinator when the function completes
			self.googleSignInCoordinator = nil
		}

		// Use the GoogleSignInCoordinator to perform OAuth flow
		let credential = try await coordinator.performSignIn()

		print("[AccountManager] Got Google credential for: \(credential.claims.email ?? "unknown")")

		// Send credential to backend for validation and user creation
		let payload: [String: Any] = [
			"id_token": credential.idToken,  // Lambda expects "id_token" with underscore
			"provider": "google",
			"access_token": credential.accessToken,  // Consistent underscore format
			"email": credential.claims.email ?? "",
			"name": credential.claims.name ?? "",
			"subject": credential.claims.subject
		]

		// Lambda expects API Gateway format with body as JSON string
		let bodyData = try JSONSerialization.data(withJSONObject: payload)
		let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
		let lambdaPayload = ["body": bodyString]
		let jsonData = try JSONSerialization.data(withJSONObject: lambdaPayload)

		print("[AccountManager] Sending to Lambda for validation...")
		let result = try await callAuthLambdaWithData("photolala-auth", payloadData: jsonData)

		// Check if this is a new user
		if result.isNewUser {
			print("[AccountManager] WARNING: New user auto-created without explicit consent")
			// TODO: Once Lambda supports check_only, this should trigger the signup flow instead
		}

		print("[AccountManager] ✓ Sign-in successful, user ID: \(result.user.id)")
		self.currentUser = result.user
		self.stsCredentials = result.credentials
		print("[AccountManager] Setting isSignedIn = true after Google sign-in")
		self.isSignedIn = true
		print("[AccountManager] isSignedIn is now: \(self.isSignedIn)")

		// Ensure status.json exists for new or returning users
		await ensureStatusFileExists(for: result.user)

		// Store user UUID for status checking
		storeUserUUID(result.user.id.uuidString)

		await saveSession()

		return result.user
	}

	func signInWithApple() async throws -> PhotolalaUser {
		let credential = try await performAppleSignIn()
		guard let identityToken = credential.identityToken,
		      let tokenString = String(data: identityToken, encoding: .utf8) else {
			throw AccountError.invalidCredential
		}

		// Include nonce for backend validation to prevent replay attacks
		let payload: [String: Any] = [
			"id_token": tokenString,  // Lambda expects "id_token" with underscore
			"provider": "apple",
			"nonce": currentNonce ?? "", // Send raw nonce for backend validation
			"authorization_code": credential.authorizationCode != nil ?
				String(data: credential.authorizationCode!, encoding: .utf8) ?? "" : "",
			"user": credential.user
		]

		// Lambda expects API Gateway format with body as JSON string
		let bodyData = try JSONSerialization.data(withJSONObject: payload)
		let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
		let lambdaPayload = ["body": bodyString]
		let jsonData = try JSONSerialization.data(withJSONObject: lambdaPayload)
		let result = try await callAuthLambdaWithData("photolala-auth", payloadData: jsonData)

		self.currentUser = result.user
		self.stsCredentials = result.credentials
		print("[AccountManager] Setting isSignedIn = true after Apple sign-in")
		self.isSignedIn = true
		print("[AccountManager] isSignedIn is now: \(self.isSignedIn)")

		// Ensure status.json exists for new or returning users
		await ensureStatusFileExists(for: result.user)

		// Store user UUID for status checking
		storeUserUUID(result.user.id.uuidString)

		await saveSession()

		return result.user
	}

	@MainActor
	func signOut() async {
		print("[AccountManager] Starting sign-out process")

		// Cancel any ongoing basket operations
		await PhotoBasket.shared.cancelCurrentOperation()

		// Clear user session
		currentUser = nil
		stsCredentials = nil
		isSignedIn = false
		accountStatus = .active

		// Clear stored UUID
		clearStoredUUID()

		await clearStoredSession()

		// Clear all caches
		await clearAllCaches()

		// Clear shared Lambda client
		await LambdaClientManager.shared.reset()

		print("[AccountManager] Sign-out complete")
	}

	@MainActor
	func deleteAccount(progressDelegate: (any DeletionProgressDelegate)? = nil) async throws {
		guard let user = currentUser else {
			throw AccountError.notSignedIn
		}

		print("[AccountManager] Starting account deletion for user: \(user.id.uuidString)")

		// Get S3 service for current environment
		let s3Service = try await S3Service.forCurrentAWSEnvironment()

		// Delete all user data from S3 with progress tracking
		// Pass provider IDs for efficient identity mapping deletion
		try await s3Service.deleteAllUserData(
			userID: user.id.uuidString,
			appleUserID: user.appleUserID,
			googleUserID: user.googleUserID,
			progressDelegate: progressDelegate
		)

		// IMPORTANT: Lambda may cache or store account data separately
		// Since Lambda returns is_new_user:false after deletion, it means:
		// 1. Lambda has its own account storage (not just S3 identity mappings)
		// 2. We need to call Lambda to delete the account from its storage

		// For now, print a warning about this limitation
		print("[AccountManager] WARNING: Lambda account data may not be fully deleted")
		print("[AccountManager] Lambda may still have cached account data")
		print("[AccountManager] To fully test signup flow, use a different Apple/Google account")

		// Sign out locally (this also clears all caches)
		await signOut()

		print("[AccountManager] Account deletion complete (S3 data deleted)")
	}

	/// Clear all application caches
	private func clearAllCaches() async {
		print("[AccountManager] Clearing all caches")

		// Clear photo identity cache
		await LocalPhotoIdentityCache.shared.clear()

		// Clear catalog cache - MUST clear in-memory cache before deleting directory
		await BasketActionService.shared.clearCatalogCache()

		// Now safe to delete the catalog cache directory
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
												   in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala")

		// Delete CatalogCache directory
		let catalogCacheDir = photolalaDir.appendingPathComponent("CatalogCache")
		try? FileManager.default.removeItem(at: catalogCacheDir)

		// Delete Checkpoints directory (star operation checkpoints)
		let checkpointsDir = photolalaDir.appendingPathComponent("Checkpoints")
		try? FileManager.default.removeItem(at: checkpointsDir)
		print("[AccountManager] Cleared star checkpoints")

		// Delete any stray metadata files in Photolala root
		let metadataFile = photolalaDir.appendingPathComponent("thumbnail-metadata.json")
		try? FileManager.default.removeItem(at: metadataFile)

		// Delete starred mapping file
		let starredMappingFile = photolalaDir.appendingPathComponent("starred-md5-mapping.json")
		try? FileManager.default.removeItem(at: starredMappingFile)

		// Clear thumbnail cache
		await ThumbnailCache.shared.clearAll()

		// Clear basket items
		PhotoBasket.shared.clear()

		print("[AccountManager] All caches cleared")
	}

	#if DEBUG || DEVELOPER
	/// Test-only method to update user and credentials
	internal func setTestCredentials(user: PhotolalaUser, credentials: STSCredentials) {
		self.currentUser = user
		self.isSignedIn = true
		self.stsCredentials = credentials
	}
	#endif

	@MainActor
	private func loadStoredSession() async {
		guard let userData = await KeychainService.shared.load(key: "photolala.user"),
		      let credentialData = await KeychainService.shared.load(key: "photolala.credentials") else {
			return
		}

		do {
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			let user = try decoder.decode(PhotolalaUser.self, from: userData)
			let credentials = try decoder.decode(STSCredentials.self, from: credentialData)

			self.currentUser = user
			self.stsCredentials = credentials
			self.isSignedIn = true

			if stsCredentials?.isExpired == true {
				_ = try? await getSTSCredentials()
			}
		} catch {
			print("Failed to decode stored session: \(error)")
		}
	}

	@MainActor
	internal func saveSession() async {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		if let user = currentUser,
		   let userData = try? encoder.encode(user) {
			await KeychainService.shared.save(key: "photolala.user", data: userData)
		}

		if let credentials = stsCredentials,
		   let credentialData = try? encoder.encode(credentials) {
			await KeychainService.shared.save(key: "photolala.credentials", data: credentialData)
		}
	}

	private func clearStoredSession() async {
		await KeychainService.shared.delete(key: "photolala.user")
		await KeychainService.shared.delete(key: "photolala.credentials")
	}

	private func refreshCredentials(userID: UUID) async throws -> STSCredentials {
		let payload: [String: Any] = ["userId": userID.uuidString]
		let jsonData = try JSONSerialization.data(withJSONObject: payload)
		let result = try await callAuthLambdaWithData("photolala-auth-refresh", payloadData: jsonData)
		return result.credentials
	}

	private func performAppleSignIn() async throws -> ASAuthorizationAppleIDCredential {
		let nonce = randomNonceString()
		self.currentNonce = nonce

		let appleIDProvider = ASAuthorizationAppleIDProvider()
		let request = appleIDProvider.createRequest()
		request.requestedScopes = [.fullName, .email]
		request.nonce = sha256(nonce)

		let coordinator = AppleSignInCoordinator()
		return try await coordinator.performSignIn(request: request)
	}

	nonisolated internal func callAuthLambdaWithData(_ functionName: String, payloadData: Data) async throws -> AuthResult {
		let functionFullName = await getFunctionName(functionName)
		let responseData = try await invokeLambda(functionName: functionFullName, payload: payloadData)

		// Decode in MainActor context to avoid isolation issues
		return try await MainActor.run {
			// Debug: Log the raw response
			if let responseString = String(data: responseData, encoding: .utf8) {
				print("[AccountManager] Lambda response: \(responseString)")
			}

			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601

			// First check if it's an API Gateway response format
			struct LambdaGatewayResponse: Decodable {
				let statusCode: Int?
				let body: String?
			}

			if let gatewayResponse = try? JSONDecoder().decode(LambdaGatewayResponse.self, from: responseData) {
				print("[AccountManager] Detected API Gateway response format - statusCode: \(gatewayResponse.statusCode ?? 0)")

				// Parse the body if it exists
				if let body = gatewayResponse.body, let bodyData = body.data(using: .utf8) {
					// Check if it's a successful response
					if gatewayResponse.statusCode == 200 {
						do {
							// Try to decode as AuthResult first
							return try decoder.decode(AuthResult.self, from: bodyData)
						} catch {
							// If that fails, try to decode the simplified Lambda response
							print("[AccountManager] Failed to decode body as AuthResult: \(error)")
							print("[AccountManager] Attempting to parse simplified Lambda response...")

							// Parse the simplified response from Lambda
							struct SimpleLambdaResponse: Decodable {
								let success: Bool
								let isNewUser: Bool
								let userId: String
								let providerId: String?
								let email: String?
							}

							if let simpleResponse = try? decoder.decode(SimpleLambdaResponse.self, from: bodyData),
							   simpleResponse.success {
								// Create mock AuthResult from the simple response
								// Note: Lambda doesn't return STS credentials, so we'll use empty ones for now
								let isApple = simpleResponse.providerId?.contains("apple") == true
								let user = PhotolalaUser(
									id: UUID(uuidString: simpleResponse.userId) ?? UUID(),
									appleUserID: isApple ? simpleResponse.providerId : nil,
									googleUserID: !isApple ? simpleResponse.providerId : nil,
									email: simpleResponse.email,
									displayName: simpleResponse.email ?? "User",
									createdAt: Date(),
									updatedAt: Date()
								)

								// Create mock STS credentials - these will need to be fetched separately
								let credentials = STSCredentials(
									accessKeyId: "",
									secretAccessKey: "",
									sessionToken: "",
									expiration: Date().addingTimeInterval(3600)
								)

								let result = AuthResult(
									user: user,
									credentials: credentials,
									isNewUser: simpleResponse.isNewUser
								)

								print("[AccountManager] Successfully created AuthResult from simplified response")
								return result
							} else {
								throw AccountError.lambdaError("Failed to parse Lambda response body: \(error)")
							}
						}
					} else {
						// Try to parse error response
						if let errorDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
						   let errorMessage = errorDict["error"] as? String {
							throw AccountError.lambdaError(errorMessage)
						} else {
							throw AccountError.lambdaError("Lambda returned status \(gatewayResponse.statusCode ?? 0): \(body)")
						}
					}
				} else {
					throw AccountError.lambdaError("Lambda returned empty response")
				}
			}

			// If not API Gateway format, try direct parsing
			return try decoder.decode(AuthResult.self, from: responseData)
		}
	}

	nonisolated internal func invokeLambda(functionName: String, payload: Data) async throws -> Data {
		// Get shared client from singleton manager
		let lambda = try await LambdaClientManager.shared.getClient()

		let request = InvokeInput(
			functionName: functionName,
			payload: payload
		)

		let response = try await lambda.invoke(input: request)

		guard let data = response.payload else {
			throw AccountError.lambdaError("Empty response from Lambda")
		}

		if let errorMessage = response.functionError {
			throw AccountError.lambdaError(errorMessage)
		}

		return data
	}

	internal func randomNonceString(length: Int = 32) -> String {
		precondition(length > 0)
		var randomBytes = [UInt8](repeating: 0, count: length)
		let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
		if errorCode != errSecSuccess {
			fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
		}

		let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
		let nonce = randomBytes.map { byte in
			charset[Int(byte) % charset.count]
		}
		return String(nonce)
	}

	internal func getFunctionName(_ baseName: String) -> String {
		let environmentPreference = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"

		// Special cases for Lambda functions without environment suffixes
		if baseName == "photolala-auth" {
			// photolala-auth doesn't have environment-specific versions
			return baseName
		} else if baseName == "photolala-web-auth" && environmentPreference == "production" {
			// photolala-web-auth is the production version (no suffix)
			return baseName
		}

		// For other functions and environments, use suffix
		let suffix: String
		switch environmentPreference {
		case "production":
			suffix = "prod"
		case "staging":
			suffix = "stage"
		default:
			suffix = "dev"
		}
		return "\(baseName)-\(suffix)"
	}


	// Keeping this for potential future use if we need per-request clients
	nonisolated private func createLambdaClient() async throws -> LambdaClient {
		// Get current environment from UserDefaults
		let environmentPreference = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
		let environment: AWSEnvironment
		switch environmentPreference {
		case "production":
			environment = .production
		case "staging":
			environment = .staging
		default:
			environment = .development
		}

		// Get credentials for this environment
		let accessKey: CredentialKey
		let secretKey: CredentialKey

		switch environment {
		case .development:
			accessKey = .AWS_ACCESS_KEY_ID_DEV
			secretKey = .AWS_SECRET_ACCESS_KEY_DEV
		case .staging:
			accessKey = .AWS_ACCESS_KEY_ID_STAGE
			secretKey = .AWS_SECRET_ACCESS_KEY_STAGE
		case .production:
			accessKey = .AWS_ACCESS_KEY_ID_PROD
			secretKey = .AWS_SECRET_ACCESS_KEY_PROD
		}

		// Get decrypted credentials directly
		guard let accessKeyValue = await Task { @MainActor in
			Credentials.decryptCached(accessKey)
		}.value,
		      let secretKeyValue = await Task { @MainActor in
			Credentials.decryptCached(secretKey)
		}.value,
		      let region = await Task { @MainActor in
			Credentials.decryptCached(.AWS_REGION)
		}.value else {
			throw AccountError.lambdaError("AWS credentials not configured")
		}

		let credentialIdentity = AWSCredentialIdentity(
			accessKey: accessKeyValue,
			secret: secretKeyValue
		)

		let credentialsProvider = StaticAWSCredentialIdentityResolver(
			credentialIdentity
		)

		let config = try await LambdaClient.Config(
			awsCredentialIdentityResolver: credentialsProvider,
			region: region
		)

		return LambdaClient(config: config)
	}

	internal func sha256(_ input: String) -> String {
		let inputData = Data(input.utf8)
		let hashedData = SHA256.hash(data: inputData)
		let hashString = hashedData.compactMap {
			String(format: "%02x", $0)
		}.joined()
		return hashString
	}

}

// Global actor for thread-safe Lambda client management
@globalActor
actor LambdaClientActor {
	static let shared = LambdaClientActor()
}

// Manager for Lambda client
@LambdaClientActor
final class LambdaClientManager {
	static let shared = LambdaClientManager()
	private var client: LambdaClient?

	private init() {}

	func getClient() async throws -> LambdaClient {
		if let existingClient = client {
			return existingClient
		}

		// Create new client
		let newClient = try await createClient()
		self.client = newClient
		return newClient
	}

	private func createClient() async throws -> LambdaClient {
		// Get current environment from UserDefaults
		let environmentPreference = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
		let environment: AWSEnvironment
		switch environmentPreference {
		case "production":
			environment = .production
		case "staging":
			environment = .staging
		default:
			environment = .development
		}

		print("[LambdaClient] Creating client for environment: \(environment)")

		// Get credentials for this environment
		let accessKey: CredentialKey
		let secretKey: CredentialKey

		switch environment {
		case .development:
			accessKey = .AWS_ACCESS_KEY_ID_DEV
			secretKey = .AWS_SECRET_ACCESS_KEY_DEV
		case .staging:
			accessKey = .AWS_ACCESS_KEY_ID_STAGE
			secretKey = .AWS_SECRET_ACCESS_KEY_STAGE
		case .production:
			accessKey = .AWS_ACCESS_KEY_ID_PROD
			secretKey = .AWS_SECRET_ACCESS_KEY_PROD
		}

		// Get decrypted credentials directly
		guard let accessKeyValue = await Task { @MainActor in
			Credentials.decryptCached(accessKey)
		}.value,
		      let secretKeyValue = await Task { @MainActor in
			Credentials.decryptCached(secretKey)
		}.value,
		      let region = await Task { @MainActor in
			Credentials.decryptCached(.AWS_REGION)
		}.value else {
			throw AccountError.lambdaError("AWS credentials not configured")
		}

		// Debug: Log which credentials are being used (partial for security)
		print("[LambdaClient] Using AWS credentials: \(String(accessKeyValue.prefix(15)))...")

		let credentialIdentity = AWSCredentialIdentity(
			accessKey: accessKeyValue,
			secret: secretKeyValue
		)

		let credentialsProvider = StaticAWSCredentialIdentityResolver(
			credentialIdentity
		)

		let config = try await LambdaClient.Config(
			awsCredentialIdentityResolver: credentialsProvider,
			region: region
		)

		return LambdaClient(config: config)
	}

	func reset() {
		// Clear the client, AWS SDK will clean up when deallocated
		self.client = nil
	}
}

@MainActor
internal class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
	private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

	func performSignIn(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorizationAppleIDCredential {
		return try await withCheckedThrowingContinuation { continuation in
			self.continuation = continuation

			let authorizationController = ASAuthorizationController(authorizationRequests: [request])
			authorizationController.delegate = self
			authorizationController.presentationContextProvider = self
			authorizationController.performRequests()
		}
	}

	func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
		#if os(macOS)
		return NSApplication.shared.keyWindow ?? NSWindow()
		#else
		// Find the foreground active scene and its key window
		let foregroundScene = UIApplication.shared.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.first { $0.activationState == .foregroundActive }

		guard let scene = foregroundScene,
		      let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
			// If no foreground scene with a window is found, this is a fatal presentation error
			fatalError("Unable to find a foreground window for authentication presentation")
		}
		return window
		#endif
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
		if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
			continuation?.resume(returning: appleIDCredential)
			continuation = nil
		}
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
		continuation?.resume(throwing: error)
		continuation = nil
	}
}

// MARK: - Test Support
#if os(macOS) && DEVELOPER
extension AccountManager {
	@MainActor
	func performTestAppleSignIn() async throws -> (credential: ASAuthorizationAppleIDCredential, nonce: String) {
		// Generate nonce using now-internal helper
		let nonce = randomNonceString()
		// Note: currentNonce remains private, we just return it for test inspection

		let appleIDProvider = ASAuthorizationAppleIDProvider()
		let request = appleIDProvider.createRequest()
		request.requestedScopes = [.fullName, .email]
		request.nonce = sha256(nonce)  // Using now-internal helper

		// Reuse now-internal coordinator
		let coordinator = AppleSignInCoordinator()
		let credential = try await coordinator.performSignIn(request: request)

		// Return for test inspection without backend processing
		return (credential, nonce)
	}

	@MainActor
	func performTestGoogleSignIn() async throws -> GoogleCredential {
		// Create coordinator for standalone OAuth test
		let coordinator = GoogleSignInCoordinator()

		// Keep a strong reference during the sign-in
		self.googleSignInCoordinator = coordinator
		defer {
			self.googleSignInCoordinator = nil
		}

		// Perform OAuth flow and return credential (no Lambda calls)
		let credential = try await coordinator.performSignIn()

		return credential
	}
}
#endif

// MARK: - Account Status Management

extension AccountManager {
	/// Check account status from S3
	@MainActor
	func checkAccountStatus() async {
		// Get stored UUID from UserDefaults
		guard let userUUID = UserDefaults.standard.string(forKey: userUUIDKey) else {
			// No stored UUID = no account or fresh install
			accountStatus = .active
			return
		}

		do {
			// Get S3 service for current environment
			let environment = getCurrentAWSEnvironment()
			let s3Service = try await S3Service.forEnvironment(environment)

			// Check status.json
			if let status = try await s3Service.getUserStatus(for: userUUID) {
				accountStatus = status.typedStatus

				// Handle different states
				switch status.typedStatus {
				case .scheduledForDeletion(let deleteDate):
					// Account is scheduled for deletion, show warning UI
					print("[AccountManager] Account scheduled for deletion on \(deleteDate)")
				case .active:
					// Normal operation
					break
				}
			} else {
				// No status.json found - account has been deleted
				print("[AccountManager] Account deleted (no status.json)")
				await handleDeletedAccount()
			}
		} catch {
			print("[AccountManager] Failed to check account status: \(error)")
			// On error, assume active to not block the user
			accountStatus = .active
		}
	}

	/// Start polling for status updates
	private func startStatusPolling() {
		// Poll every 10 minutes while app is active
		statusCheckTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
			Task { @MainActor in
				await self.checkAccountStatus()
			}
		}
	}

	/// Stop polling
	private func stopStatusPolling() {
		statusCheckTimer?.invalidate()
		statusCheckTimer = nil
	}

	/// Handle deleted account state
	@MainActor
	private func handleDeletedAccount() async {
		// Clear all local data
		currentUser = nil
		stsCredentials = nil
		isSignedIn = false
		accountStatus = .active  // Reset to active (account no longer exists)

		// Clear stored UUID
		UserDefaults.standard.removeObject(forKey: userUUIDKey)

		// Clear stored session
		await clearStoredSession()

		// Stop polling
		stopStatusPolling()
	}

	/// Store user UUID on successful sign-in
	@MainActor
	func storeUserUUID(_ uuid: String) {
		UserDefaults.standard.set(uuid, forKey: userUUIDKey)
	}

	/// Ensure status.json exists for a user (create if missing)
	private func ensureStatusFileExists(for user: PhotolalaUser) async {
		do {
			let environment = getCurrentAWSEnvironment()
			let s3Service = try await S3Service.forEnvironment(environment)

			// Check if status.json already exists
			if let existingStatus = try await s3Service.getUserStatus(for: user.id.uuidString) {
				// Status exists, update accountStatus
				accountStatus = existingStatus.typedStatus
				print("[AccountManager] Existing status.json found: \(existingStatus.accountStatus)")
			} else {
				// Create new status.json for active account
				let status = UserStatusFile(status: .active)
				try await s3Service.writeUserStatus(status, for: user.id.uuidString)
				accountStatus = .active
				print("[AccountManager] Created new status.json for user \(user.id)")

				// Also create identity mappings for this new account
				if let appleUserID = user.appleUserID {
					try await s3Service.writeIdentityMapping(
						provider: "apple",
						providerID: appleUserID,
						userID: user.id.uuidString
					)
					print("[AccountManager] Created Apple identity mapping for user \(user.id)")
				}

				if let googleUserID = user.googleUserID {
					try await s3Service.writeIdentityMapping(
						provider: "google",
						providerID: googleUserID,
						userID: user.id.uuidString
					)
					print("[AccountManager] Created Google identity mapping for user \(user.id)")
				}
			}
		} catch {
			print("[AccountManager] Failed to ensure status.json: \(error)")
			// Don't block sign-in on status.json creation failure
			accountStatus = .active
		}
	}

	/// Clear stored UUID on sign-out
	@MainActor
	func clearStoredUUID() {
		UserDefaults.standard.removeObject(forKey: userUUIDKey)
	}

	/// Get current AWS environment
	private func getCurrentAWSEnvironment() -> AWSEnvironment {
		let environmentPreference = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
		switch environmentPreference {
		case "production":
			return .production
		case "staging":
			return .staging
		default:
			return .development
		}
	}
}
