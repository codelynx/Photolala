//
//  LambdaService.swift
//  Photolala
//
//  Simplified Lambda service for apple-x
//

import Foundation
@preconcurrency import AWSLambda
@preconcurrency import AWSClientRuntime
@preconcurrency import AWSSDKIdentity
@preconcurrency import SmithyIdentity
import OSLog

/// Simplified Lambda service for invoking functions
actor LambdaService {
	static let shared = LambdaService()
	private let logger = Logger(subsystem: "com.photolala", category: "LambdaService")
	private nonisolated(unsafe) var client: LambdaClient?
	private let region = "us-east-1"

	private init() {}

	/// Initialize the Lambda client
	func initialize() async throws {
		guard client == nil else { return }

		// Get credentials based on environment
		let bucketName = await MainActor.run { EnvironmentHelper.getCurrentBucket() }
		let accessKeyEnum: CredentialKey
		let secretKeyEnum: CredentialKey

		switch bucketName {
		case "photolala-dev":
			accessKeyEnum = .AWS_ACCESS_KEY_ID_DEV
			secretKeyEnum = .AWS_SECRET_ACCESS_KEY_DEV
		case "photolala-stage":
			accessKeyEnum = .AWS_ACCESS_KEY_ID_STAGE
			secretKeyEnum = .AWS_SECRET_ACCESS_KEY_STAGE
		default:
			accessKeyEnum = .AWS_ACCESS_KEY_ID_PROD
			secretKeyEnum = .AWS_SECRET_ACCESS_KEY_PROD
		}

		let credentials = await MainActor.run {
			(
				accessKey: Credentials.decryptCached(accessKeyEnum),
				secretKey: Credentials.decryptCached(secretKeyEnum)
			)
		}

		guard let accessKey = credentials.accessKey,
			  let secretKey = credentials.secretKey else {
			throw LambdaError.credentialsNotFound
		}

		// Create Lambda client
		let credentialIdentity = AWSCredentialIdentity(
			accessKey: accessKey,
			secret: secretKey
		)
		let credentialResolver = StaticAWSCredentialIdentityResolver(credentialIdentity)

		let config = try await LambdaClient.LambdaClientConfiguration(
			awsCredentialIdentityResolver: credentialResolver,
			region: region
		)

		self.client = LambdaClient(config: config)
		logger.info("Lambda client initialized")
	}

	/// Invoke a Lambda function
	func invoke<T: Decodable>(
		functionName: String,
		payload: Encodable,
		responseType: T.Type
	) async throws -> T {
		try await initialize()
		guard let client = client else { throw LambdaError.clientNotInitialized }

		// Get environment-specific function name
		let fullFunctionName = await getFunctionName(functionName)

		// Encode payload
		let encoder = JSONEncoder()
		let payloadData = try encoder.encode(payload)

		// Invoke function
		let input = InvokeInput(
			functionName: fullFunctionName,
			invocationType: LambdaClientTypes.InvocationType.requestresponse,
			payload: payloadData
		)

		let output = try await client.invoke(input: input)

		// Check for errors
		if let errorData = output.functionError {
			throw LambdaError.functionError(errorData)
		}

		// Decode response
		guard let responseData = output.payload else {
			throw LambdaError.noResponse
		}

		let decoder = JSONDecoder()
		return try decoder.decode(T.self, from: responseData)
	}

	/// Invoke a Lambda function with raw JSON
	func invokeRaw(functionName: String, jsonPayload: String) async throws -> Data {
		try await initialize()
		guard let client = client else { throw LambdaError.clientNotInitialized }

		// Get environment-specific function name
		let fullFunctionName = await getFunctionName(functionName)

		// Convert JSON string to Data
		guard let payloadData = jsonPayload.data(using: .utf8) else {
			throw LambdaError.invalidPayload
		}

		// Invoke function
		let input = InvokeInput(
			functionName: fullFunctionName,
			invocationType: LambdaClientTypes.InvocationType.requestresponse,
			payload: payloadData
		)

		let output = try await client.invoke(input: input)

		// Check for errors
		if let errorData = output.functionError {
			throw LambdaError.functionError(errorData)
		}

		// Return raw response
		guard let responseData = output.payload else {
			throw LambdaError.noResponse
		}

		return responseData
	}

	/// Get environment-specific function name
	private func getFunctionName(_ baseName: String) async -> String {
		let bucketName = await MainActor.run { EnvironmentHelper.getCurrentBucket() }

		switch bucketName {
		case "photolala-dev":
			return "\(baseName)-dev"
		case "photolala-stage":
			return "\(baseName)-stage"
		default:
			return "\(baseName)-prod"
		}
	}
}

// MARK: - Common Lambda Payloads
struct IdentityMappingRequest: Encodable {
	let path: String = "/identity/mapping"
	let httpMethod: String = "POST"
	let body: IdentityMappingBody

	struct IdentityMappingBody: Encodable {
		let provider: String
		let providerUserId: String
		let email: String
		let idToken: String?
	}
}

struct CatalogRequest: Encodable {
	let path: String
	let httpMethod: String = "GET"
	let queryStringParameters: [String: String]?
}

// MARK: - Error Types
enum LambdaError: LocalizedError {
	case credentialsNotFound
	case clientNotInitialized
	case invalidPayload
	case noResponse
	case functionError(String)

	var errorDescription: String? {
		switch self {
		case .credentialsNotFound:
			return "AWS credentials not found"
		case .clientNotInitialized:
			return "Lambda client not initialized"
		case .invalidPayload:
			return "Invalid payload data"
		case .noResponse:
			return "No response from Lambda function"
		case .functionError(let error):
			return "Lambda function error: \(error)"
		}
	}
}
