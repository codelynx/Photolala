//
//  AccountManagerExtensions.swift
//  Photolala
//
//  Extensions for testing and diagnostics
//

import Foundation
import AuthenticationServices

#if os(macOS) && DEVELOPER
extension AccountManager {
	// MARK: - Diagnostic Support

	/// Authentication flow hooks for diagnostics
	struct DiagnosticHooks {
		var onStepChange: ((String) -> Void)?
		var onNetworkRequest: ((String, [String: String]?) -> Void)?
		var onNetworkResponse: ((String, [String: String]?) -> Void)?
		var onError: ((Error) -> Void)?
	}

	internal static var diagnosticHooks: DiagnosticHooks?

	/// Set diagnostic hooks for testing
	static func setDiagnosticHooks(_ hooks: DiagnosticHooks?) {
		diagnosticHooks = hooks
	}

	/// Log a diagnostic step change
	static func logStep(_ step: String) {
		#if DEVELOPER
		diagnosticHooks?.onStepChange?(step)
		#endif
	}

	/// Log a network request
	static func logRequest(_ message: String, details: [String: String]? = nil) {
		#if DEVELOPER
		diagnosticHooks?.onNetworkRequest?(message, details)
		#endif
	}

	/// Log a network response
	static func logResponse(_ message: String, details: [String: String]? = nil) {
		#if DEVELOPER
		diagnosticHooks?.onNetworkResponse?(message, details)
		#endif
	}

	/// Log an error
	static func logError(_ error: Error) {
		#if DEVELOPER
		diagnosticHooks?.onError?(error)
		#endif
	}

	// MARK: - Enhanced Sign-In Methods with Diagnostics

	func signInWithAppleWithDiagnostics() async throws -> AuthResult {
		Self.logStep("Starting Apple Sign-In")

		do {
			// Use the test method which is accessible
			let (credential, nonce) = try await performTestAppleSignIn()
			Self.logStep("Apple OAuth Complete")

			guard let identityToken = credential.identityToken,
				  let tokenString = String(data: identityToken, encoding: .utf8) else {
				throw AccountError.invalidCredential
			}

			Self.logStep("Preparing Lambda request")

			// Create payload
			var payload: [String: Any] = [
				"provider": "apple",
				"token": tokenString,
				"environment": EnvironmentHelper.currentEnvironmentName,
				"nonce": nonce  // Include the nonce
			]

			// Add optional user info
			if let authCode = credential.authorizationCode,
			   let codeString = String(data: authCode, encoding: .utf8) {
				payload["authorizationCode"] = codeString
			}

			if let email = credential.email {
				payload["email"] = email
			}

			if let fullName = credential.fullName {
				var name: [String: String] = [:]
				if let given = fullName.givenName { name["given"] = given }
				if let family = fullName.familyName { name["family"] = family }
				if !name.isEmpty {
					payload["name"] = name
				}
			}

			let jsonData = try JSONSerialization.data(withJSONObject: payload)

			Self.logRequest("Calling Lambda: photolala-auth-signin", details: [
				"provider": "apple",
				"environment": EnvironmentHelper.currentEnvironmentName
			])

			let result = try await testCallAuthLambdaWithData("photolala-auth-signin", payloadData: jsonData)

			Self.logResponse("Authentication successful", details: [
				"userId": result.user.id.uuidString,
				"isNewUser": "\(result.isNewUser)"
			])

			Self.logStep("Authentication Complete")

			// Store credentials
			await self.updateTestCredentials(user: result.user, credentials: result.credentials)

			return result
		} catch {
			Self.logError(error)
			Self.logStep("Authentication Failed: \(error.localizedDescription)")
			throw error
		}
	}

	func signInWithGoogleWithDiagnostics() async throws -> AuthResult {
		Self.logStep("Starting Google Sign-In")

		do {
			print("[AccountManager] Starting Google Sign-In")

			let coordinator = GoogleSignInCoordinator()
			Self.logStep("Google OAuth In Progress")

			let credential = try await coordinator.performSignIn()
			Self.logStep("Google OAuth Complete")

			print("[AccountManager] Google sign-in successful")
			print("[AccountManager] ID Token length: \(credential.idToken.count)")

			Self.logStep("Preparing Lambda request")

			// Create payload for Lambda
			let payload: [String: Any] = [
				"provider": "google",
				"token": credential.idToken,
				"environment": EnvironmentHelper.currentEnvironmentName,
				// Google doesn't use nonce
				// "nonce": credential.nonce
			]

			print("[AccountManager] Preparing Lambda payload for environment: \(EnvironmentHelper.currentEnvironmentName)")

			let jsonData = try JSONSerialization.data(withJSONObject: payload)

			Self.logRequest("Calling Lambda: photolala-web-auth", details: [
				"provider": "google",
				"environment": EnvironmentHelper.currentEnvironmentName
			])

			print("[AccountManager] Sending to Lambda for validation...")
			let result = try await testCallAuthLambdaWithData("photolala-web-auth", payloadData: jsonData)

			Self.logResponse("Authentication successful", details: [
				"userId": result.user.id.uuidString,
				"isNewUser": "\(result.isNewUser)",
				"email": result.user.email ?? "N/A"
			])

			Self.logStep("Authentication Complete")

			print("[AccountManager] Lambda validation successful")
			print("[AccountManager] User ID: \(result.user.id)")
			print("[AccountManager] Is new user: \(result.isNewUser)")

			// Store credentials
			await self.updateTestCredentials(user: result.user, credentials: result.credentials)

			return result
		} catch {
			Self.logError(error)
			Self.logStep("Authentication Failed: \(error.localizedDescription)")
			print("[AccountManager] Google sign-in failed: \(error)")
			throw error
		}
	}

	// MARK: - Test Helper Methods

	/// Test-only method to update credentials
	@MainActor
	func updateTestCredentials(user: PhotolalaUser, credentials: STSCredentials) {
		self.setTestCredentials(user: user, credentials: credentials)
		Task {
			await saveSession()
		}
	}

	/// Test-only method to call Lambda
	func testCallAuthLambdaWithData(_ functionName: String, payloadData: Data) async throws -> AuthResult {
		let functionFullName = getFunctionName(functionName)
		let responseData = try await invokeLambda(functionName: functionFullName, payload: payloadData)

		// Parse the response
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let result = try decoder.decode(AuthResult.self, from: responseData)

		return result
	}
}
#endif