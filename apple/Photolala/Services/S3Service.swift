//
//  S3Service.swift
//  Photolala
//
//  Simplified S3 service for apple-x
//

import Foundation
@preconcurrency import AWSS3
@preconcurrency import AWSClientRuntime
@preconcurrency import AWSSTS
@preconcurrency import AWSSDKIdentity
@preconcurrency import Smithy
@preconcurrency import SmithyIdentity
import OSLog

/// Simplified S3 service
actor S3Service {
	static let shared = S3Service()
	private let logger = Logger(subsystem: "com.photolala", category: "S3Service")
	private nonisolated(unsafe) var client: S3Client?
	private var bucketName: String = ""

	private init() {}

	/// Initialize the S3 client
	func initialize() async throws {
		guard client == nil else { return }

		// Get credentials and bucket from CredentialManager
		let credentialManager = await CredentialManager.shared

		guard let awsCredentials = await credentialManager.currentAWSCredentials else {
			throw S3Error.credentialsNotFound
		}

		self.bucketName = await credentialManager.currentAWSBucket
		let envDisplayName = await credentialManager.environmentDisplayName
		logger.info("Using bucket: \(self.bucketName)")
		logger.info("Environment: \(envDisplayName)")

		// Create S3 client with credentials
		let credentialIdentity = AWSCredentialIdentity(
			accessKey: awsCredentials.accessKey,
			secret: awsCredentials.secretKey
		)
		let credentialResolver = StaticAWSCredentialIdentityResolver(credentialIdentity)

		let config = try await S3Client.S3ClientConfiguration(
			awsCredentialIdentityResolver: credentialResolver,
			region: awsCredentials.region
		)

		self.client = S3Client(config: config)
		logger.info("S3 client initialized for \(self.bucketName)")
	}

	/// List objects in a prefix
	func listObjects(prefix: String, maxKeys: Int = 1000) async throws -> [S3ClientTypes.Object] {
		try await initialize()
		guard let client = client else { throw S3Error.clientNotInitialized }

		let input = ListObjectsV2Input(
			bucket: bucketName,
			maxKeys: maxKeys,
			prefix: prefix
		)

		let output = try await client.listObjectsV2(input: input)
		return output.contents ?? []
	}

	/// Get object data
	func getObject(key: String) async throws -> Data {
		try await initialize()
		guard let client = client else { throw S3Error.clientNotInitialized }

		let input = GetObjectInput(
			bucket: bucketName,
			key: key
		)

		let output = try await client.getObject(input: input)
		guard let body = output.body else {
			throw S3Error.noData
		}

		return try await body.readData() ?? Data()
	}

	/// Put object data
	func putObject(key: String, data: Data, contentType: String? = nil) async throws {
		try await initialize()
		guard let client = client else { throw S3Error.clientNotInitialized }

		let input = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: contentType,
			key: key
		)

		_ = try await client.putObject(input: input)
		logger.info("Uploaded object: \(key)")
	}

	/// Delete object
	func deleteObject(key: String) async throws {
		try await initialize()
		guard let client = client else { throw S3Error.clientNotInitialized }

		let input = DeleteObjectInput(
			bucket: bucketName,
			key: key
		)

		_ = try await client.deleteObject(input: input)
		logger.info("Deleted object: \(key)")
	}

	/// Generate presigned URL for download
	func presignedURLForGet(key: String, expiresIn: TimeInterval = 3600) async throws -> URL {
		try await initialize()
		guard let client = client else { throw S3Error.clientNotInitialized }

		let input = GetObjectInput(
			bucket: bucketName,
			key: key
		)

		let presignedRequest = try await client.presignedRequestForGetObject(
			input: input,
			expiration: TimeInterval(expiresIn)
		)

		guard let url = presignedRequest.url else {
			throw S3Error.urlGenerationFailed
		}

		return url
	}
}

// MARK: - Error Types
enum S3Error: LocalizedError {
	case credentialsNotFound
	case clientNotInitialized
	case noData
	case urlGenerationFailed

	var errorDescription: String? {
		switch self {
		case .credentialsNotFound:
			return "AWS credentials not found"
		case .clientNotInitialized:
			return "S3 client not initialized"
		case .noData:
			return "No data returned from S3"
		case .urlGenerationFailed:
			return "Failed to generate presigned URL"
		}
	}
}
