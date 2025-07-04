import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

// MARK: - Identity Manager

@MainActor
class IdentityManager: NSObject, ObservableObject {
	static let shared = IdentityManager()

	// Published properties
	@Published var currentUser: PhotolalaUser?
	@Published var isSignedIn: Bool = false
	@Published var isLoading: Bool = false
	@Published var errorMessage: String?

	// Internal properties (accessible from extensions)
	let keychainKey = "com.electricwoods.photolala.user"
	var currentNonce: String?

	override init() {
		super.init()
		self.loadStoredUser()
		
		// Verify stored user exists in S3
		Task { @MainActor in
			await self.verifyStoredUserWithS3()
		}
	}

	// MARK: - Public Methods

	// Legacy sign in method - will be removed after updating UI
	@available(*, deprecated, message: "Use signIn(with:) or createAccount(with:) instead")
	func signIn() {
		Task {
			do {
				// Default to Apple for backward compatibility
				_ = try await createAccount(with: .apple)
			} catch {
				self.errorMessage = error.localizedDescription
			}
		}
	}

	func signOut() {
		self.currentUser = nil
		self.isSignedIn = false

		// Clear stored user from Keychain
		try? KeychainManager.shared.delete(key: self.keychainKey)

		// Clear any cached data
		S3BackupManager.shared.clearCache()
		
		// Clear backup queue state
		UserDefaults.standard.removeObject(forKey: "BackupQueueState")
		
		print("User signed out - all local state cleared")
	}

	// MARK: - Private Methods

	private func loadStoredUser() {
		do {
			let userData = try KeychainManager.shared.load(key: self.keychainKey)
			
			// Try to decode as new model first
			if let user = try? JSONDecoder().decode(PhotolalaUser.self, from: userData) {
				// Temporarily set user - will be verified against S3
				self.currentUser = user
				self.isSignedIn = true
				print("Loaded stored user: \(user.displayName) - pending S3 verification")
				return
			}
			
			// Try legacy model and migrate
			if let legacyUser = try? JSONDecoder().decode(LegacyPhotolalaUser.self, from: userData) {
				let migratedUser = PhotolalaUser(legacy: legacyUser)
				
				// Save migrated user
				let encoder = JSONEncoder()
				encoder.dateEncodingStrategy = .iso8601
				let migratedData = try encoder.encode(migratedUser)
				try KeychainManager.shared.save(migratedData, for: self.keychainKey)
				
				// Temporarily set user - will be verified against S3
				self.currentUser = migratedUser
				self.isSignedIn = true
				print("Migrated legacy user: \(migratedUser.displayName) - pending S3 verification")
				return
			}
			
			print("Failed to decode user data")
		} catch {
			print("No stored user found: \(error)")
		}
	}
	
	private func verifyStoredUserWithS3() async {
		guard let user = self.currentUser else { return }
		
		do {
			// Check if user exists in S3 by verifying identity mapping
			// This requires the extension method to be available
			let identityKey = "\(user.primaryProvider.rawValue):\(user.primaryProviderID)"
			let identityPath = "identities/\(identityKey)"
			
			let s3Manager = S3BackupManager.shared
			guard let s3Service = s3Manager.s3Service else {
				print("S3 service not available - keeping local user")
				return
			}
			
			do {
				// Try to download the identity mapping
				let _ = try await s3Service.downloadData(from: identityPath)
				print("User verified in S3: \(user.displayName)")
				// User exists - keep signed in state
			} catch {
				// User doesn't exist in S3 - clear local state
				print("User not found in S3 (\(identityPath)), clearing local state")
				try? KeychainManager.shared.delete(key: self.keychainKey)
				self.currentUser = nil
				self.isSignedIn = false
			}
		} catch {
			// Error verifying - clear local state to be safe
			print("Error verifying user in S3: \(error). Clearing local state.")
			try? KeychainManager.shared.delete(key: self.keychainKey)
			self.currentUser = nil
			self.isSignedIn = false
		}
	}

	// Platform-specific sign in methods (moved to extension)
	#if os(macOS)
		func performSignInMacOS(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
			try await withCheckedThrowingContinuation { continuation in
				let controller = ASAuthorizationController(authorizationRequests: [request])
				controller.delegate = self
				controller.performRequests()

				self.authContinuation = continuation
			}
		}
	#else
		func performSignIniOS(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorization {
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

	// Nonce methods moved to extension as static methods
	private func randomNonceString(length: Int = 32) -> String {
		Self.randomNonceString(length: length)
	}

	private func sha256(_ input: String) -> String {
		Self.sha256(input)
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
		// Check if user cancelled
		if let authError = error as? ASAuthorizationError,
		   authError.code == .canceled {
			// User cancelled - don't show error, just cancel silently
			self.authContinuation?.resume(throwing: CancellationError())
		} else {
			self.authContinuation?.resume(throwing: error)
		}
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
