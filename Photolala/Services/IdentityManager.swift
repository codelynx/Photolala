import Foundation
import AuthenticationServices
import CryptoKit
import SwiftUI

// MARK: - User Model

struct PhotolalaUser: Codable {
	let serviceUserID: String     // Our internal UUID
	let appleUserID: String       // From Sign in with Apple
	let email: String?            // Optional - user may not share
	let fullName: String?         // Optional - user may not share
	let createdAt: Date
	var subscription: Subscription?
	
	var displayName: String {
		fullName ?? email ?? "Photolala User"
	}
}

struct Subscription: Codable {
	let tier: SubscriptionTier
	let expiresAt: Date
	let originalTransactionId: String
	
	var isActive: Bool {
		Date() < expiresAt
	}
}

enum SubscriptionTier: String, Codable, CaseIterable {
	case free = "free"
	case basic = "com.electricwoods.photolala.basic"
	case standard = "com.electricwoods.photolala.standard"
	case pro = "com.electricwoods.photolala.pro"
	case family = "com.electricwoods.photolala.family"
	
	var displayName: String {
		switch self {
		case .free: return "Free"
		case .basic: return "Basic"
		case .standard: return "Standard"
		case .pro: return "Pro"
		case .family: return "Family"
		}
	}
	
	var storageLimit: Int64 {
		switch self {
		case .free: return 5 * 1024 * 1024 * 1024          // 5 GB
		case .basic: return 100 * 1024 * 1024 * 1024      // 100 GB
		case .standard: return 1024 * 1024 * 1024 * 1024  // 1 TB
		case .pro: return 5 * 1024 * 1024 * 1024 * 1024   // 5 TB
		case .family: return 10 * 1024 * 1024 * 1024 * 1024 // 10 TB
		}
	}
	
	var monthlyPrice: String {
		switch self {
		case .free: return "Free"
		case .basic: return "$2.99"
		case .standard: return "$9.99"
		case .pro: return "$39.99"
		case .family: return "$69.99"
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
		loadStoredUser()
	}
	
	// MARK: - Public Methods
	
	func signIn() {
		Task {
			await performSignIn()
		}
	}
	
	func signOut() {
		currentUser = nil
		isSignedIn = false
		
		// Clear stored user
		try? KeychainManager.shared.delete(key: keychainKey)
		
		// Clear any cached data
		S3BackupManager.shared.clearCache()
	}
	
	// MARK: - Private Methods
	
	private func loadStoredUser() {
		do {
			let userData = try KeychainManager.shared.load(key: keychainKey)
			let user = try JSONDecoder().decode(PhotolalaUser.self, from: userData)
			
			// Validate user is still valid (could check with backend)
			currentUser = user
			isSignedIn = true
			
			print("Loaded stored user: \(user.displayName)")
		} catch {
			print("No stored user found")
		}
	}
	
	private func performSignIn() async {
		isLoading = true
		errorMessage = nil
		
		// Generate nonce for security
		currentNonce = randomNonceString()
		
		let appleIDProvider = ASAuthorizationAppleIDProvider()
		let request = appleIDProvider.createRequest()
		request.requestedScopes = [.fullName, .email]
		request.nonce = sha256(currentNonce!)
		
		do {
			#if os(macOS)
			let authorization = try await performSignInMacOS(request: request)
			#else
			let authorization = try await performSignIniOS(request: request)
			#endif
			
			await handleSignInResult(authorization)
		} catch {
			await MainActor.run {
				errorMessage = error.localizedDescription
				isLoading = false
			}
		}
	}
	
	#if os(macOS)
	private func performSignInMacOS(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
		return try await withCheckedThrowingContinuation { continuation in
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
				errorMessage = "Invalid credential type"
				isLoading = false
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
			try KeychainManager.shared.save(userData, for: keychainKey)
			
			await MainActor.run {
				currentUser = user
				isSignedIn = true
				isLoading = false
			}
			
			print("Sign in successful: \(user.displayName)")
		} catch {
			await MainActor.run {
				errorMessage = "Failed to save user: \(error.localizedDescription)"
				isLoading = false
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
			let randoms: [UInt8] = (0..<16).map { _ in
				var random: UInt8 = 0
				let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
				if errorCode != errSecSuccess {
					fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
				}
				return random
			}
			
			randoms.forEach { random in
				if remainingLength == 0 {
					return
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
	func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
		authContinuation?.resume(returning: authorization)
		authContinuation = nil
	}
	
	func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
		authContinuation?.resume(throwing: error)
		authContinuation = nil
	}
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

#if os(iOS)
extension IdentityManager: ASAuthorizationControllerPresentationContextProviding {
	func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
		guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
			  let window = scene.windows.first else {
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
			if identityManager.isLoading {
				ProgressView()
					.frame(width: 280, height: 45)
			} else {
				#if os(macOS)
				Button(action: identityManager.signIn) {
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
						identityManager.signIn()
					}
				#endif
			}
		}
		.alert("Sign In Error", isPresented: .constant(identityManager.errorMessage != nil)) {
			Button("OK") {
				identityManager.errorMessage = nil
			}
		} message: {
			Text(identityManager.errorMessage ?? "")
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