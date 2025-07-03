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

/// Handles Google Sign-In authentication
actor GoogleAuthProvider {
	static let shared = GoogleAuthProvider()
	
	// Use the Web Client ID for server-side verification (same as Android)
	private let webClientID = "105828093997-qmr9jdj3h4ia0tt2772cnrejh4k0p609.apps.googleusercontent.com"
	
	private init() {}
	
	/// Sign in with Google
	func signIn() async throws -> AuthCredential {
		#if canImport(GoogleSignIn)
		// Get the presenting view controller
		let presentingViewController = await getPresentingViewController()
		
		// Configure if needed
		await MainActor.run {
			if GIDSignIn.sharedInstance.configuration == nil {
				configureGoogleSignIn()
			}
		}
		
		#if os(iOS)
		let result = try await GIDSignIn.sharedInstance.signIn(
			withPresenting: presentingViewController as! UIViewController,
			hint: nil
		)
		#elseif os(macOS)
		let result = try await GIDSignIn.sharedInstance.signIn(
			withPresenting: presentingViewController as! NSWindow,
			hint: nil
		)
		#endif
		
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
		#else
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
	@MainActor
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
		// Extract client ID from Info.plist
		guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
			  let plist = NSDictionary(contentsOfFile: path),
			  let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]],
			  let urlSchemes = urlTypes.first?["CFBundleURLSchemes"] as? [String],
			  let reversedClientId = urlSchemes.first(where: { $0.hasPrefix("com.googleusercontent.apps.") }) else {
			print("Error: Google Sign-In client ID not found in Info.plist")
			return
		}
		
		// Extract client ID from reversed client ID
		let components = reversedClientId.replacingOccurrences(of: "com.googleusercontent.apps.", with: "")
		let clientId = components + ".apps.googleusercontent.com"
		
		GIDSignIn.sharedInstance.configuration = GIDConfiguration(
			clientID: clientId,
			serverClientID: webClientID // Use web client ID for ID token
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

// MARK: - Placeholder for Google Sign-In

#if !canImport(GoogleSignIn)
// Define placeholder types when GoogleSignIn is not available
enum GIDSignInError: Int {
	case canceled
	case hasNoAuthInKeychain
	case unknown
}

let kGIDSignInErrorDomain = "com.google.GIDSignIn"
#endif