//
//  AccountManagerExtensions.swift
//  Photolala
//
//  Extensions for testing and diagnostics
//

import Foundation
import AuthenticationServices
@preconcurrency import AWSLambda
import AWSClientRuntime
import SmithyIdentity
import SmithyHTTPAPI

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

	func signInWithAppleWithDiagnostics(environment: TestEnvironment? = nil) async throws -> AuthResult {
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

			// Create payload - Lambda expects id_token with underscore
			var payload: [String: Any] = [
				"provider": "apple",
				"id_token": tokenString,  // Lambda expects "id_token" with underscore
				"environment": EnvironmentHelper.currentEnvironmentName,
				"nonce": nonce  // Include the nonce
			]

			// Add optional user info
			if let authCode = credential.authorizationCode,
			   let codeString = String(data: authCode, encoding: .utf8) {
				payload["authorization_code"] = codeString  // Lambda expects underscore format
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

			// Lambda expects API Gateway format with body as JSON string
			let bodyData = try JSONSerialization.data(withJSONObject: payload)
			let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
			let lambdaPayload = ["body": bodyString]
			let jsonData = try JSONSerialization.data(withJSONObject: lambdaPayload)

			Self.logRequest("Calling Lambda: photolala-auth", details: [
				"provider": "apple",
				"environment": EnvironmentHelper.currentEnvironmentName
			])

			let result = try await testCallAuthLambdaWithData("photolala-auth", payloadData: jsonData, environment: environment)

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

	func signInWithGoogleWithDiagnostics(environment: TestEnvironment? = nil) async throws -> AuthResult {
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

			// Create payload for Lambda - Lambda expects id_token with underscore
			let payload: [String: Any] = [
				"provider": "google",
				"id_token": credential.idToken,  // Lambda expects "id_token" with underscore
				"environment": EnvironmentHelper.currentEnvironmentName,
				// Google doesn't use nonce
				// "nonce": credential.nonce
			]

			print("[AccountManager] Preparing Lambda payload for environment: \(EnvironmentHelper.currentEnvironmentName)")

			// Lambda expects API Gateway format with body as JSON string
			let bodyData = try JSONSerialization.data(withJSONObject: payload)
			let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"
			let lambdaPayload = ["body": bodyString]
			let jsonData = try JSONSerialization.data(withJSONObject: lambdaPayload)

			Self.logRequest("Calling Lambda: photolala-auth", details: [
				"provider": "google",
				"environment": EnvironmentHelper.currentEnvironmentName
			])

			print("[AccountManager] Sending to Lambda for validation...")
			let result = try await testCallAuthLambdaWithData("photolala-auth", payloadData: jsonData, environment: environment)

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

	/// Create Lambda client for specific environment (test only)
	nonisolated private func createTestLambdaClient(for testEnv: TestEnvironment) async throws -> LambdaClient {
		// Map TestEnvironment to Environment
		let environment: Environment = switch testEnv {
		case .development: .development
		case .staging: .staging
		case .production: .production
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

		// Get decrypted credentials
		guard let accessKeyValue = await Task { @MainActor in
			Credentials.decryptCached(accessKey)
		}.value,
		      let secretKeyValue = await Task { @MainActor in
			Credentials.decryptCached(secretKey)
		}.value,
		      let region = await Task { @MainActor in
			Credentials.decryptCached(.AWS_REGION)
		}.value else {
			throw AccountError.lambdaError("AWS credentials not configured for \(environment)")
		}

		let credentialIdentity = AWSCredentialIdentity(
			accessKey: accessKeyValue,
			secret: secretKeyValue
		)

		let credentialsProvider = StaticAWSCredentialIdentityResolver(credentialIdentity)

		let config = try await LambdaClient.Config(
			awsCredentialIdentityResolver: credentialsProvider,
			region: region
		)

		return LambdaClient(config: config)
	}

	/// Invoke Lambda with specific environment (test only)
	nonisolated private func invokeLambdaWithEnvironment(functionName: String, payload: Data, environment: TestEnvironment) async throws -> Data {
		// Create a dedicated client for this environment
		let lambda = try await createTestLambdaClient(for: environment)

		// Log the request for debugging
		if let payloadString = String(data: payload, encoding: .utf8) {
			print("[Lambda] Invoking \(functionName) with payload: \(payloadString.prefix(500))")
		}

		let request = InvokeInput(
			functionName: functionName,
			payload: payload
		)

		do {
			let response = try await lambda.invoke(input: request)

			guard let data = response.payload else {
				throw AccountError.lambdaError("Empty response from Lambda")
			}

			if let errorMessage = response.functionError {
				throw AccountError.lambdaError(errorMessage)
			}

			// Log the response for debugging
			if let responseString = String(data: data, encoding: .utf8) {
				print("[Lambda] Response from \(functionName): \(responseString.prefix(500))")
			}

			return data
		} catch {
			// Log detailed error information
			print("[Lambda] Error invoking \(functionName): \(type(of: error))")
			print("[Lambda] Error details: \(error)")

			// Try to extract more information about the error
			let errorString = String(describing: error)
			if errorString.contains("UnknownAWSHTTPServiceError") {
				print("[Lambda] This appears to be an UnknownAWSHTTPServiceError")
				// Try to extract any additional details from the error description
				print("[Lambda] Full error description: \(errorString)")
			}

			throw error
		}
	}

	/// Test-only method to call Lambda with specific environment
	func testCallAuthLambdaWithData(_ functionName: String, payloadData: Data, environment: TestEnvironment? = nil) async throws -> AuthResult {
		let functionFullName: String
		if let env = environment {
			// Special cases for Lambda functions without environment suffixes
			if functionName == "photolala-auth" {
				// photolala-auth doesn't have environment-specific versions
				functionFullName = functionName
			} else if functionName == "photolala-web-auth" && env == .production {
				// photolala-web-auth is the production version (no suffix)
				functionFullName = functionName
			} else {
				// Use environment suffix for dev/stage versions
				let suffix = env.lambdaSuffix
				functionFullName = "\(functionName)-\(suffix)"
			}
		} else {
			// Fall back to UserDefaults (for backward compatibility)
			functionFullName = getFunctionName(functionName)
		}

		// For test diagnostics with specific environment, we create a dedicated client
		let responseData: Data
		if let env = environment {
			responseData = try await invokeLambdaWithEnvironment(functionName: functionFullName, payload: payloadData, environment: env)
		} else {
			responseData = try await invokeLambda(functionName: functionFullName, payload: payloadData)
		}

		// Log the raw response for debugging
		if let responseString = String(data: responseData, encoding: .utf8) {
			print("[TestLambda] Raw response from \(functionFullName): \(responseString)")
		}

		// Parse the response
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601

		// First check if it's an API Gateway response format
		struct LambdaGatewayResponse: Decodable {
			let statusCode: Int?
			let body: String?
		}

		if let gatewayResponse = try? JSONDecoder().decode(LambdaGatewayResponse.self, from: responseData) {
			print("[TestLambda] Detected API Gateway response format - statusCode: \(gatewayResponse.statusCode ?? 0)")

			// Parse the body if it exists
			if let body = gatewayResponse.body, let bodyData = body.data(using: .utf8) {
				print("[TestLambda] Gateway body: \(body)")

				// Check if it's a successful response
				if gatewayResponse.statusCode == 200 {
					do {
						// Try to decode as AuthResult first
						let result = try decoder.decode(AuthResult.self, from: bodyData)
						return result
					} catch {
						// If that fails, try to decode the simplified Lambda response
						print("[TestLambda] Failed to decode body as AuthResult: \(error)")
						print("[TestLambda] Attempting to parse simplified Lambda response...")

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

							print("[TestLambda] Successfully created AuthResult from simplified response")
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
		do {
			let result = try decoder.decode(AuthResult.self, from: responseData)
			return result
		} catch {
			print("[TestLambda] Failed to decode response: \(error)")
			throw error
		}
	}
}
#endif