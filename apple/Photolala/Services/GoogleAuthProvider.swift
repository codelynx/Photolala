//
//  GoogleAuthProvider.swift
//  Photolala
//
//  Created by Claude on 7/3/25.
//

import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Configuration for Google OAuth
struct GoogleOAuthConfiguration {
	// Use the Web Client ID for server-side verification
	static let webClientID = "75309194504-p2sfktq2ju97ataogb1e5fkl70cj2jg3.apps.googleusercontent.com"
	
	// Use iOS client ID for all Apple platforms (works better with ASWebAuthenticationSession)
	static let clientID = "75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv.apps.googleusercontent.com"
	
	// OAuth redirect URI
	static var redirectURI: String {
		"com.googleusercontent.apps.\(clientID.components(separatedBy: ".").first!):/oauth2redirect"
	}
}

/// Handles Google Sign-In authentication
actor GoogleAuthProvider {
	static let shared = GoogleAuthProvider()
	
	private init() {}
	
	/// Sign in with Google
	func signIn() async throws -> AuthCredential {
		#if canImport(GoogleSignIn)
			
		#if os(macOS)
		// On macOS, the native SDK sometimes fails to open the browser
		// Use web flow directly
		return try await signInWithWebFlow()
		#elseif os(iOS)
		// Get the presenting view controller
		let presentingViewController = await getPresentingViewController()
		
		// Configure if needed
		await MainActor.run {
			if GIDSignIn.sharedInstance.configuration == nil {
				configureGoogleSignIn()
			}
		}
		
		
		do {
			let result = try await GIDSignIn.sharedInstance.signIn(
				withPresenting: presentingViewController as! UIViewController,
				hint: nil
			)
			
			
			guard let profile = result.user.profile else {
				throw AuthError.unknownError("No user profile data")
			}
			
			
			let credential = AuthCredential(
				provider: .google,
				providerID: result.user.userID ?? "",
				email: profile.email,
				fullName: profile.name,
				photoURL: profile.imageURL(withDimension: 200)?.absoluteString,
				idToken: result.user.idToken?.tokenString,
				accessToken: result.user.accessToken.tokenString
			)
			
			return credential
		} catch {
			// Map the error appropriately
			throw mapError(error)
		}
		#endif  // End of iOS-specific code
		#else  // If GoogleSignIn not available
		throw AuthError.providerNotImplemented
		#endif
	}
	
	/// Sign out from Google
	func signOut() {
		#if canImport(GoogleSignIn)
		GIDSignIn.sharedInstance.signOut()
		#endif
	}
	
	/// Restore previous sign-in
	func restorePreviousSignIn() async throws -> AuthCredential? {
		#if canImport(GoogleSignIn)
		return try await withCheckedThrowingContinuation { continuation in
			Task { @MainActor in
				GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
					if let error = error {
						// Not an error if no previous sign-in
						let nsError = error as NSError
						if nsError.domain == kGIDSignInErrorDomain &&
						   nsError.code == GIDSignInError.hasNoAuthInKeychain.rawValue {
							continuation.resume(returning: nil)
						} else {
							continuation.resume(throwing: self.mapError(error))
						}
						return
					}
					
					guard let user = user,
						  let profile = user.profile else {
						continuation.resume(returning: nil)
						return
					}
					
					let credential = AuthCredential(
						provider: .google,
						providerID: user.userID ?? "",
						email: profile.email,
						fullName: profile.name,
						photoURL: profile.imageURL(withDimension: 200)?.absoluteString,
						idToken: user.idToken?.tokenString,
						accessToken: user.accessToken.tokenString
					)
					
					continuation.resume(returning: credential)
				}
			}
		}
		#else
		return nil
		#endif
	}
	
	/// Handle URL callback
	func handle(url: URL) -> Bool {
		#if canImport(GoogleSignIn)
		return GIDSignIn.sharedInstance.handle(url)
		#else
		return false
		#endif
	}
	
	// MARK: - Private Helpers
	
	#if canImport(GoogleSignIn)
	@MainActor
	private func getPresentingViewController() -> Any {
		#if os(iOS)
		guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
			  let window = windowScene.windows.first,
			  let rootViewController = window.rootViewController else {
			fatalError("No root view controller found")
		}
		
		var presentingViewController = rootViewController
		while let presented = presentingViewController.presentedViewController {
			presentingViewController = presented
		}
		
		return presentingViewController
		#elseif os(macOS)
		guard let window = NSApplication.shared.keyWindow else {
			fatalError("No key window found")
		}
		return window
		#endif
	}
	
	@MainActor
	private func configureGoogleSignIn() {
		GIDSignIn.sharedInstance.configuration = GIDConfiguration(
			clientID: GoogleOAuthConfiguration.clientID,
			serverClientID: GoogleOAuthConfiguration.webClientID
		)
	}
	
	private func mapError(_ error: Error) -> AuthError {
		let nsError = error as NSError
		
		
		if nsError.domain == kGIDSignInErrorDomain {
			switch nsError.code {
			case GIDSignInError.canceled.rawValue:
				return .userCancelled
			case GIDSignInError.hasNoAuthInKeychain.rawValue:
				return .noStoredCredentials
			case GIDSignInError.unknown.rawValue:
				return .unknownError(error.localizedDescription)
			default:
				return .authenticationFailed(reason: error.localizedDescription)
			}
		}
		
		return .authenticationFailed(reason: error.localizedDescription)
	}
	#endif
}

