import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

// MARK: - User Model

struct PhotolalaUser: Codable {
	let serviceUserID: String // Our internal UUID
	let appleUserID: String // From Sign in with Apple
	let email: String? // Optional - user may not share
	let fullName: String? // Optional - user may not share
	let createdAt: Date
	var subscription: Subscription?

	var displayName: String {
		self.fullName ?? self.email ?? "Photolala User"
	}
}

struct Subscription: Codable {
	let tier: SubscriptionTier
	let expiresAt: Date
	let originalTransactionId: String

	var isActive: Bool {
		Date() < self.expiresAt
	}

	var displayName: String {
		self.tier.displayName
	}

	var quotaBytes: Int64 {
		self.tier.storageLimit
	}
}

enum SubscriptionTier: String, Codable, CaseIterable {
	case free
	case starter = "com.electricwoods.photolala.starter"
	case essential = "com.electricwoods.photolala.essential"
	case plus = "com.electricwoods.photolala.plus"
	case family = "com.electricwoods.photolala.family"

	var displayName: String {
		switch self {
		case .free: "Free"
		case .starter: "Starter"
		case .essential: "Essential"
		case .plus: "Plus"
		case .family: "Family"
		}
	}

	var storageLimit: Int64 {
		switch self {
		case .free: 200 * 1_024 * 1_024 // 200 MB (trial)
		case .starter: 500 * 1_024 * 1_024 * 1_024 // 500 GB photos
		case .essential: 1_024 * 1_024 * 1_024 * 1_024 // 1 TB photos
		case .plus: 2_048 * 1_024 * 1_024 * 1_024 // 2 TB photos
		case .family: 5_120 * 1_024 * 1_024 * 1_024 // 5 TB photos (shareable)
		}
	}

	var monthlyPrice: String {
		switch self {
		case .free: "Free"
		case .starter: "$0.99"
		case .essential: "$1.99"
		case .plus: "$2.99"
		case .family: "$5.99"
		}
	}
}

// MARK: - Identity Manager

@MainActor
class IdentityManager: NSObject, ObservableObject {
	static let shared = IdentityManager()

	// Published properties
	@Published var currentUser: PhotolalaUser?
	@Published var isSignedIn: Bool = false
	@Published var isLoading: Bool = false
	@Published var errorMessage: String?

	// Private properties
	private let keychainKey = "com.electricwoods.photolala.user"
	private var currentNonce: String?

	override init() {
		super.init()
		self.loadStoredUser()
	}

	// MARK: - Public Methods

	func signIn() {
		Task {
			await self.performSignIn()
		}
	}

	func signOut() {
		self.currentUser = nil
		self.isSignedIn = false

		// Clear stored user
		try? KeychainManager.shared.delete(key: self.keychainKey)

		// Clear any cached data
		S3BackupManager.shared.clearCache()
	}

	// MARK: - Private Methods

	private func loadStoredUser() {
		do {
			let userData = try KeychainManager.shared.load(key: self.keychainKey)
			let user = try JSONDecoder().decode(PhotolalaUser.self, from: userData)

			// Validate user is still valid (could check with backend)
			self.currentUser = user
			self.isSignedIn = true

			print("Loaded stored user: \(user.displayName)")
		} catch {
			print("No stored user found")
		}
	}

	private func performSignIn() async {
		self.isLoading = true
		self.errorMessage = nil

		// Generate nonce for security
		self.currentNonce = self.randomNonceString()

		let appleIDProvider = ASAuthorizationAppleIDProvider()
		let request = appleIDProvider.createRequest()
		request.requestedScopes = [.fullName, .email]
		request.nonce = self.sha256(self.currentNonce!)

		do {
			#if os(macOS)
				let authorization = try await performSignInMacOS(request: request)
			#else
				let authorization = try await performSignIniOS(request: request)
			#endif

			await handleSignInResult(authorization)
		} catch {
			await MainActor.run {
				self.errorMessage = error.localizedDescription
				self.isLoading = false
			}
		}
	}

	#if os(macOS)
		private func performSignInMacOS(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
			try await withCheckedThrowingContinuation { continuation in
				let controller = ASAuthorizationController(authorizationRequests: [request])
				controller.delegate = self
				controller.performRequests()

				self.authContinuation = continuation
			}
		}
	#else
		private func performSignIniOS(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
			let controller = ASAuthorizationController(authorizationRequests: [request])

			return try await withCheckedThrowingContinuation { continuation in
				controller.delegate = self
				controller.presentationContextProvider = self
				controller.performRequests()

				self.authContinuation = continuation
			}
		}
	#endif

	private var authContinuation: CheckedContinuation<ASAuthorization, Error>?

	private func handleSignInResult(_ authorization: ASAuthorization) async {
		guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
			await MainActor.run {
				self.errorMessage = "Invalid credential type"
				self.isLoading = false
			}
			return
		}

		// Create or update user
		let serviceUserID = UUID().uuidString // In production, get from backend

		let user = PhotolalaUser(
			serviceUserID: serviceUserID,
			appleUserID: appleIDCredential.user,
			email: appleIDCredential.email,
			fullName: appleIDCredential.fullName?.formatted(),
			createdAt: Date(),
			subscription: Subscription(
				tier: .free,
				expiresAt: Date.distantFuture,
				originalTransactionId: "free"
			)
		)

		// Store user
		do {
			let userData = try JSONEncoder().encode(user)
			try KeychainManager.shared.save(userData, for: self.keychainKey)

			await MainActor.run {
				self.currentUser = user
				self.isSignedIn = true
				self.isLoading = false
			}

			print("Sign in successful: \(user.displayName)")
			print("Photolala Service User ID: \(user.serviceUserID)")
			print("Apple User ID: \(user.appleUserID)")
		} catch {
			await MainActor.run {
				self.errorMessage = "Failed to save user: \(error.localizedDescription)"
				self.isLoading = false
			}
		}
	}

	// MARK: - Nonce Generation

	private func randomNonceString(length: Int = 32) -> String {
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

	private func sha256(_ input: String) -> String {
		let inputData = Data(input.utf8)
		let hashedData = SHA256.hash(data: inputData)
		let hashString = hashedData.compactMap {
			String(format: "%02x", $0)
		}.joined()

		return hashString
	}
}

// MARK: - ASAuthorizationControllerDelegate

extension IdentityManager: ASAuthorizationControllerDelegate {
	func authorizationController(
		controller: ASAuthorizationController,
		didCompleteWithAuthorization authorization: ASAuthorization
	) {
		self.authContinuation?.resume(returning: authorization)
		self.authContinuation = nil
	}

	func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
		self.authContinuation?.resume(throwing: error)
		self.authContinuation = nil
	}
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

#if os(iOS)
	extension IdentityManager: ASAuthorizationControllerPresentationContextProviding {
		func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
			guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
			      let window = scene.windows.first
			else {
				fatalError("No window found")
			}
			return window
		}
	}
#endif

// MARK: - Sign In Button

struct SignInWithAppleButton: View {
	@StateObject private var identityManager = IdentityManager.shared

	var body: some View {
		Group {
			if self.identityManager.isLoading {
				ProgressView()
					.frame(width: 280, height: 45)
			} else {
				#if os(macOS)
					Button(action: self.identityManager.signIn) {
						HStack {
							Image(systemName: "applelogo")
							Text("Sign in with Apple")
						}
						.frame(width: 280, height: 45)
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.large)
				#else
					SignInWithAppleButtonRepresentable()
						.frame(width: 280, height: 45)
						.onTapGesture {
							self.identityManager.signIn()
						}
				#endif
			}
		}
		.alert("Sign In Error", isPresented: .constant(self.identityManager.errorMessage != nil)) {
			Button("OK") {
				self.identityManager.errorMessage = nil
			}
		} message: {
			Text(self.identityManager.errorMessage ?? "")
		}
	}
}

#if os(iOS)
	struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
		func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
			ASAuthorizationAppleIDButton(
				authorizationButtonType: .signIn,
				authorizationButtonStyle: .black
			)
		}

		func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
	}
#endif
