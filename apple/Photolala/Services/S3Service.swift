//
//  S3Service.swift
//  Photolala
//
//  S3 service with environment-based initialization
//

import Foundation
@preconcurrency import AWSS3
@preconcurrency import AWSClientRuntime
@preconcurrency import AWSSTS
@preconcurrency import AWSSDKIdentity
@preconcurrency import Smithy
@preconcurrency import SmithyIdentity
import OSLog

/// S3 service with explicit environment configuration
public actor S3Service {
	private let logger = Logger(subsystem: "com.photolala", category: "S3Service")
	private nonisolated(unsafe) var client: S3Client?
	private let environment: Environment
	private var awsCredentials: AWSCredentials?
	private let bucketName: String
	private var isInitialized = false

	/// Initialize S3Service with explicit environment and credentials
	init(environment: Environment, credentials: AWSCredentials) {
		self.environment = environment
		self.awsCredentials = credentials
		// Compute bucket name based on environment
		switch environment {
		case .development:
			self.bucketName = "photolala-dev"
		case .staging:
			self.bucketName = "photolala-stage"
		case .production:
			self.bucketName = "photolala-prod"
		}
	}

	/// Initialize S3Service with environment (fetches credentials automatically)
	init(environment: Environment) async throws {
		self.environment = environment
		// Compute bucket name based on environment
		switch environment {
		case .development:
			self.bucketName = "photolala-dev"
		case .staging:
			self.bucketName = "photolala-stage"
		case .production:
			self.bucketName = "photolala-prod"
		}

		// Get credentials for the specified environment
		guard let credentials = await S3Service.getCredentials(for: environment) else {
			throw S3Error.credentialsNotFound
		}
		self.awsCredentials = credentials
	}

	/// Initialize S3Service for lazy loading (backward compatibility)
	private init(environment: Environment, lazy: Bool) {
		self.environment = environment
		// Compute bucket name based on environment
		switch environment {
		case .development:
			self.bucketName = "photolala-dev"
		case .staging:
			self.bucketName = "photolala-stage"
		case .production:
			self.bucketName = "photolala-prod"
		}
		// Credentials will be loaded on first use
		self.awsCredentials = nil
	}

	/// Initialize the S3 client connection
	private func ensureInitialized() async throws {
		guard !isInitialized else { return }

		// Fetch credentials if not already loaded (for lazy initialization)
		if awsCredentials == nil {
			guard let credentials = await S3Service.getCredentials(for: environment) else {
				throw S3Error.credentialsNotFound
			}
			self.awsCredentials = credentials
		}

		guard let credentials = awsCredentials else {
			throw S3Error.credentialsNotFound
		}

		logger.info("Initializing S3 client for environment: \(self.environment.rawValue)")
		logger.info("Using bucket: \(self.bucketName)")

		// Create S3 client with credentials
		let credentialIdentity = AWSCredentialIdentity(
			accessKey: credentials.accessKey,
			secret: credentials.secretKey
		)
		let credentialResolver = StaticAWSCredentialIdentityResolver(credentialIdentity)

		let config = try await S3Client.S3ClientConfiguration(
			awsCredentialIdentityResolver: credentialResolver,
			region: credentials.region
		)

		self.client = S3Client(config: config)
		self.isInitialized = true
		logger.info("S3 client initialized for \(self.bucketName)")
	}

	/// List objects in a prefix
	func listObjects(prefix: String, maxKeys: Int = 1000) async throws -> [S3ClientTypes.Object] {
		try await ensureInitialized()
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
		try await ensureInitialized()
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
		try await ensureInitialized()
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
		try await ensureInitialized()
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
		try await ensureInitialized()
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

	/// Get the current bucket name
	func getBucketName() -> String {
		return bucketName
	}

	/// Get the current environment
	func getEnvironment() -> Environment {
		return environment
	}

	// MARK: - Photo Upload Methods

	/// Check if a photo exists in S3
	func checkPhotoExists(md5: String, userID: String) async -> Bool {
		try? await ensureInitialized()

		// Check for .dat file (unified extension for deduplication)
		let key = "photos/\(userID)/\(md5).dat"
		do {
			_ = try await client?.headObject(input: HeadObjectInput(
				bucket: bucketName,
				key: key
			))
			return true
		} catch {
			return false
		}
	}

	/// Upload photo with format preservation (using .dat extension)
	func uploadPhoto(data: Data, md5: String, format: ImageFormat, userID: String) async throws {
		try await ensureInitialized()

		// Always use .dat for perfect deduplication
		let key = "photos/\(userID)/\(md5).dat"

		let input = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: format.mimeType,
			key: key,
			metadata: ["original-format": format.rawValue]
			// Note: Tagging removed as it requires s3:PutObjectTagging permission
			// Format is preserved in metadata instead
		)

		guard let client = client else { throw S3Error.clientNotInitialized }
		_ = try await client.putObject(input: input)
		logger.info("Uploaded photo: \(key) with Format=\(format.rawValue)")
	}

	/// Upload PTM-256 thumbnail
	func uploadThumbnail(data: Data, md5: String, userID: String) async throws {
		try await ensureInitialized()

		let key = "thumbnails/\(userID)/\(md5).jpg"

		let input = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "image/jpeg",
			key: key
		)

		guard let client = client else { throw S3Error.clientNotInitialized }
		_ = try await client.putObject(input: input)
		logger.info("Uploaded thumbnail: \(key)")
	}

	/// Upload catalog CSV
	func uploadCatalog(csvData: Data, catalogMD5: String, userID: String) async throws {
		try await ensureInitialized()

		let key = "catalogs/\(userID)/.photolala.\(catalogMD5).csv"

		let input = PutObjectInput(
			body: .data(csvData),
			bucket: bucketName,
			contentType: "text/csv",
			key: key
		)

		guard let client = client else { throw S3Error.clientNotInitialized }
		_ = try await client.putObject(input: input)
		logger.info("Uploaded catalog: \(key)")
	}

	/// Update catalog pointer
	func updateCatalogPointer(catalogMD5: String, userID: String) async throws {
		try await ensureInitialized()

		let key = "catalogs/\(userID)/.photolala.md5"
		let data = catalogMD5.data(using: .utf8)!

		let input = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "text/plain",
			key: key
		)

		guard let client = client else { throw S3Error.clientNotInitialized }
		_ = try await client.putObject(input: input)
		logger.info("Updated catalog pointer to: \(catalogMD5)")
	}

	// MARK: - Photo Download Methods

	/// Download catalog pointer
	func downloadCatalogPointer(userID: String) async throws -> String {
		try await ensureInitialized()

		let key = "catalogs/\(userID)/.photolala.md5"
		logger.info("[S3Service] Attempting to download catalog pointer")
		logger.info("[S3Service]   Bucket: \(self.bucketName)")
		logger.info("[S3Service]   Key: \(key)")
		logger.info("[S3Service]   User ID: \(userID)")

		let input = GetObjectInput(
			bucket: bucketName,
			key: key
		)

		guard let client = client else {
			logger.error("[S3Service] Client not initialized")
			throw S3Error.clientNotInitialized
		}

		do {
			let response = try await client.getObject(input: input)
			logger.info("[S3Service] Successfully got object response")

			guard let data = try await response.body?.readData() else {
				logger.error("[S3Service] Failed to read response body")
				throw S3Error.downloadFailed
			}
			logger.info("[S3Service] Read \(data.count) bytes from catalog pointer")

			guard let pointer = String(data: data, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines) else {
				logger.error("[S3Service] Failed to decode pointer as UTF-8")
				throw S3Error.invalidData
			}

			logger.info("[S3Service] Successfully retrieved catalog pointer: \(pointer)")
			return pointer

		} catch let error as AWSS3.NoSuchKey {
			logger.error("[S3Service] NoSuchKey error - catalog pointer not found")
			logger.error("[S3Service]   Expected location: s3://\(self.bucketName)/\(key)")
			logger.error("[S3Service]   This means the user has no catalog uploaded yet")
			throw error
		} catch {
			logger.error("[S3Service] Failed to download catalog pointer: \(error)")
			throw error
		}
	}

	/// Download catalog CSV
	func downloadCatalog(catalogMD5: String, userID: String) async throws -> Data {
		try await ensureInitialized()
		logger.info("[S3Service] Downloading catalog CSV")
		logger.info("[S3Service]   Catalog MD5: \(catalogMD5)")
		logger.info("[S3Service]   User ID: \(userID)")

		let key = "catalogs/\(userID)/.photolala.\(catalogMD5).csv"

		let input = GetObjectInput(
			bucket: bucketName,
			key: key
		)

		guard let client = client else { throw S3Error.clientNotInitialized }
		let response = try await client.getObject(input: input)
		guard let data = try await response.body?.readData() else {
			throw S3Error.downloadFailed
		}

		return data
	}

	/// Download thumbnail
	func downloadThumbnail(md5: String, userID: String) async throws -> Data {
		try await ensureInitialized()

		let key = "thumbnails/\(userID)/\(md5).jpg"

		let input = GetObjectInput(
			bucket: bucketName,
			key: key
		)

		guard let client = client else { throw S3Error.clientNotInitialized }
		let response = try await client.getObject(input: input)
		guard let data = try await response.body?.readData() else {
			throw S3Error.downloadFailed
		}

		return data
	}

	/// Download photo (always stored as .dat)
	func downloadPhoto(md5: String, userID: String) async throws -> Data {
		try await ensureInitialized()

		// Photos are always stored as .dat
		let key = "photos/\(userID)/\(md5).dat"

		let input = GetObjectInput(
			bucket: bucketName,
			key: key
		)

		guard let client = client else { throw S3Error.clientNotInitialized }
		let response = try await client.getObject(input: input)
		guard let data = try await response.body?.readData() else {
			throw S3Error.downloadFailed
		}

		// Note: Format can be determined from object tags if needed
		return data
	}
}

// MARK: - Factory Methods and Helpers

extension S3Service {
	/// Create S3Service for the current app environment (reads from UserDefaults)
	static func forCurrentEnvironment() async throws -> S3Service {
		let credentialManager = await CredentialManager.shared
		let environment = await credentialManager.currentEnvironment
		return try await S3Service(environment: environment)
	}

	/// Create S3Service for a specific environment
	static func forEnvironment(_ environment: Environment) async throws -> S3Service {
		return try await S3Service(environment: environment)
	}

	/// Helper to get credentials for a specific environment
	private static func getCredentials(for environment: Environment) async -> AWSCredentials? {
		await MainActor.run {
			let accessKeyEnum: CredentialKey
			let secretKeyEnum: CredentialKey

			switch environment {
			case .development:
				accessKeyEnum = .AWS_ACCESS_KEY_ID_DEV
				secretKeyEnum = .AWS_SECRET_ACCESS_KEY_DEV
			case .staging:
				accessKeyEnum = .AWS_ACCESS_KEY_ID_STAGE
				secretKeyEnum = .AWS_SECRET_ACCESS_KEY_STAGE
			case .production:
				accessKeyEnum = .AWS_ACCESS_KEY_ID_PROD
				secretKeyEnum = .AWS_SECRET_ACCESS_KEY_PROD
			}

			guard let accessKey = Credentials.decryptCached(accessKeyEnum),
				  let secretKey = Credentials.decryptCached(secretKeyEnum),
				  let region = Credentials.decryptCached(.AWS_REGION) else {
				return nil
			}

			return AWSCredentials(
				accessKey: accessKey,
				secretKey: secretKey,
				region: region
			)
		}
	}

	/// Shared instance for the current app environment (backward compatibility)
	/// Note: Uses lazy initialization - credentials fetched on first use
	/// New code should use forEnvironment() or forCurrentEnvironment() instead
	static let shared = S3Service(environment: .development, lazy: true)
}

// MARK: - Error Types
enum S3Error: LocalizedError {
	case credentialsNotFound
	case clientNotInitialized
	case noData
	case urlGenerationFailed
	case downloadFailed
	case invalidData
	case notFound

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
		case .downloadFailed:
			return "Failed to download from S3"
		case .invalidData:
			return "Invalid data format"
		case .notFound:
			return "Object not found in S3"
		}
	}
}