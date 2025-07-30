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
		print("[GoogleAuthProvider] Starting Google Sign-In flow")
		
		// Get the presenting view controller
		let presentingViewController = await getPresentingViewController()
		print("[GoogleAuthProvider] Got presenting view controller")
		
		// Configure if needed
		await MainActor.run {
			if GIDSignIn.sharedInstance.configuration == nil {
				print("[GoogleAuthProvider] Configuring Google Sign-In")
				configureGoogleSignIn()
			}
		}
		
		print("[GoogleAuthProvider] Calling GIDSignIn.sharedInstance.signIn")
		
		do {
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
			
			print("[GoogleAuthProvider] Sign-in successful, processing result")
			
			guard let profile = result.user.profile else {
				print("[GoogleAuthProvider] No profile data in result")
				throw AuthError.unknownError("No user profile data")
			}
			
			print("[GoogleAuthProvider] Creating credential for user: \(result.user.userID ?? "unknown")")
			
			let credential = AuthCredential(
				provider: .google,
				providerID: result.user.userID ?? "",
				email: profile.email,
				fullName: profile.name,
				photoURL: profile.imageURL(withDimension: 200)?.absoluteString,
				idToken: result.user.idToken?.tokenString,
				accessToken: result.user.accessToken.tokenString
			)
			
			print("[GoogleAuthProvider] Credential created successfully")
			return credential
		} catch {
			print("[GoogleAuthProvider] Sign-in failed with error: \(error)")
			print("[GoogleAuthProvider] Error type: \(type(of: error))")
			print("[GoogleAuthProvider] Error localized: \(error.localizedDescription)")
			
			// Check if it's a keychain error from Google Sign-In
			let nsError = error as NSError
			if nsError.domain == "com.google.GIDSignIn" && nsError.code == -2 {
				print("[GoogleAuthProvider] Google Sign-In keychain error detected, attempting workaround...")
				
				// Try to clear Google's keychain and retry
				await MainActor.run {
					GIDSignIn.sharedInstance.signOut()
					// Reset configuration to force fresh start
					GIDSignIn.sharedInstance.configuration = nil
					configureGoogleSignIn()
				}
				
				// Try sign-in one more time
				do {
					print("[GoogleAuthProvider] Retrying sign-in after clearing state...")
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
					
					print("[GoogleAuthProvider] Retry successful!")
					
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
					print("[GoogleAuthProvider] Retry also failed: \(error)")
					print("[GoogleAuthProvider] Falling back to web-based authentication...")
					
					// Use web-based flow as last resort
					do {
						let credential = try await signInWithWebFlow()
						print("[GoogleAuthProvider] Web-based authentication successful!")
						return credential
					} catch {
						print("[GoogleAuthProvider] Web-based authentication also failed: \(error)")
						throw AuthError.custom(code: "GOOGLE_AUTH_FAILED", 
							message: "Unable to sign in with Google. Please try again later.")
					}
				}
			}
			
			throw error
		}
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
		print("[GoogleAuthProvider] Configuring Google Sign-In...")
		
		// First, try to clear any existing keychain state
		print("[GoogleAuthProvider] Clearing any existing Google Sign-In state...")
		GIDSignIn.sharedInstance.signOut()
		
		// Check if GIDClientID is in Info.plist (new way)
		if let bundleId = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
			print("[GoogleAuthProvider] Found GIDClientID in Info.plist: \(bundleId)")
			GIDSignIn.sharedInstance.configuration = GIDConfiguration(
				clientID: bundleId,
				serverClientID: webClientID
			)
			print("[GoogleAuthProvider] Configuration set successfully")
			return
		}
		
		// Fallback: Extract client ID from URL schemes (old way)
		print("[GoogleAuthProvider] GIDClientID not found, trying URL schemes...")
		guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
			  let plist = NSDictionary(contentsOfFile: path),
			  let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]],
			  let urlSchemes = urlTypes.first?["CFBundleURLSchemes"] as? [String],
			  let reversedClientId = urlSchemes.first(where: { $0.hasPrefix("com.googleusercontent.apps.") }) else {
			print("[GoogleAuthProvider] Error: Google Sign-In client ID not found in Info.plist")
			return
		}
		
		// Extract client ID from reversed client ID
		let components = reversedClientId.replacingOccurrences(of: "com.googleusercontent.apps.", with: "")
		let clientId = components + ".apps.googleusercontent.com"
		
		print("[GoogleAuthProvider] Extracted client ID: \(clientId)")
		
		GIDSignIn.sharedInstance.configuration = GIDConfiguration(
			clientID: clientId,
			serverClientID: webClientID // Use web client ID for ID token
		)
		print("[GoogleAuthProvider] Configuration set successfully (from URL scheme)")
	}
	
	private func mapError(_ error: Error) -> AuthError {
		let nsError = error as NSError
		
		print("[GoogleAuthProvider] Mapping error - Domain: \(nsError.domain), Code: \(nsError.code)")
		print("[GoogleAuthProvider] Error userInfo: \(nsError.userInfo)")
		
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