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
	private var stsCredentials: STSCredentials?
	private var currentNonce: String?


	private init() {
		Task {
			await loadStoredSession()
		}
	}


	func getCurrentUser() -> PhotolalaUser? {
		currentUser
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

	func signInWithApple() async throws -> PhotolalaUser {
		let credential = try await performAppleSignIn()
		guard let identityToken = credential.identityToken,
		      let tokenString = String(data: identityToken, encoding: .utf8) else {
			throw AccountError.invalidCredential
		}

		// Include nonce for backend validation to prevent replay attacks
		let payload: [String: Any] = [
			"idToken": tokenString,
			"provider": "apple",
			"nonce": currentNonce ?? "", // Send raw nonce for backend validation
			"authorizationCode": credential.authorizationCode != nil ?
				String(data: credential.authorizationCode!, encoding: .utf8) ?? "" : "",
			"user": credential.user
		]

		// Convert to Data here to avoid sendability issues
		let jsonData = try JSONSerialization.data(withJSONObject: payload)
		let result = try await callAuthLambdaWithData("photolala-auth-signin", payloadData: jsonData)

		self.currentUser = result.user
		self.stsCredentials = result.credentials
		self.isSignedIn = true
		await saveSession()

		return result.user
	}

	@MainActor
	func signOut() async {
		currentUser = nil
		stsCredentials = nil
		isSignedIn = false
		await clearStoredSession()

		// Clear shared Lambda client
		await LambdaClientManager.shared.reset()
	}

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
	private func saveSession() async {
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

	nonisolated private func callAuthLambdaWithData(_ functionName: String, payloadData: Data) async throws -> AuthResult {
		let functionFullName = await getFunctionName(functionName)
		let responseData = try await invokeLambda(functionName: functionFullName, payload: payloadData)

		// Decode in MainActor context to avoid isolation issues
		return try await MainActor.run {
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			return try decoder.decode(AuthResult.self, from: responseData)
		}
	}

	nonisolated private func invokeLambda(functionName: String, payload: Data) async throws -> Data {
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

	private func getFunctionName(_ baseName: String) -> String {
		let environmentPreference = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
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
		let environment: Environment
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
		let environment: Environment
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
		guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
		      let window = scene.windows.first else {
			return UIWindow()
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
#if os(macOS) && DEBUG
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
}
#endif