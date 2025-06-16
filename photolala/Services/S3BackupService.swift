import AWSClientRuntime
import AWSS3
import AWSSDKIdentity
import CryptoKit
import Foundation
import SmithyIdentity

/// Statistics for backup storage
@MainActor
class BackupStats: ObservableObject {
	/// Size of photos in bytes (counts against quota)
	@Published var photoSize: Int64 = 0

	/// Size of thumbnails in bytes (free bonus storage)
	@Published var thumbnailSize: Int64 = 0

	/// Size of metadata in bytes (free bonus storage)
	@Published var metadataSize: Int64 = 0

	/// Total size of all storage
	var totalSize: Int64 {
		self.photoSize + self.thumbnailSize + self.metadataSize
	}

	/// Amount of quota used (only photos count)
	var quotaUsed: Int64 {
		self.photoSize
	}

	/// Formatted string for photo storage
	var photoSizeFormatted: String {
		ByteCountFormatter.string(fromByteCount: self.photoSize, countStyle: .file)
	}

	/// Formatted string for bonus storage
	var bonusSizeFormatted: String {
		let bonusSize = self.thumbnailSize + self.metadataSize
		return ByteCountFormatter.string(fromByteCount: bonusSize, countStyle: .file)
	}

	/// Formatted string for total storage
	var totalSizeFormatted: String {
		ByteCountFormatter.string(fromByteCount: self.totalSize, countStyle: .file)
	}
}

@MainActor
class S3BackupService: ObservableObject {
	@Published var backupStats = BackupStats()
	@Published var isCalculatingStats = false
	@Published var lastError: Error?

	private let client: S3Client
	private let bucketName = "photolala"
	private let region = "us-east-1"
	private let identityManager = IdentityManager.shared

	init(accessKey: String, secretKey: String) async throws {
		// Create static credentials
		let credentialIdentity = AWSCredentialIdentity(accessKey: accessKey, secret: secretKey)
		let credentialIdentityResolver = try StaticAWSCredentialIdentityResolver(credentialIdentity)

		// Create S3 configuration with static credentials
		let configuration = try await S3Client.S3ClientConfiguration(
			awsCredentialIdentityResolver: credentialIdentityResolver,
			region: self.region
		)

		self.client = S3Client(config: configuration)
	}

	// Convenience init that reads from Keychain, environment, or credentials file
	convenience init() async throws {
		// First, try Keychain (production)
		if let credentials = try? KeychainManager.shared.loadAWSCredentials() {
			print("Using AWS credentials from Keychain")
			try await self.init(accessKey: credentials.accessKey, secretKey: credentials.secretKey)
			return
		}

		// Second, try environment variables (development)
		if let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
		   let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"],
		   !accessKey.isEmpty, !secretKey.isEmpty
		{
			print("Using AWS credentials from environment variables")
			try await self.init(accessKey: accessKey, secretKey: secretKey)
			return
		}

		// Third, try the credentials file (fallback)
		// For sandboxed apps, this will be in the container directory
		#if os(macOS)
			let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
		#else
			let homeDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		#endif
		let credentialsPath = homeDirectory.appendingPathComponent(".aws/credentials").path
		print("Looking for credentials at: \(credentialsPath)")

		// Check if file exists
		let fileManager = FileManager.default
		guard fileManager.fileExists(atPath: credentialsPath) else {
			print("Credentials file does not exist at: \(credentialsPath)")
			print("For sandboxed apps, you can:")
			print("1. Set environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
			print("2. Copy your credentials to: \(credentialsPath)")
			throw S3BackupError.credentialsNotFound
		}

		// Try to read the file
		let credentialsData: String
		do {
			credentialsData = try String(contentsOfFile: credentialsPath)
			print("Successfully read credentials file, length: \(credentialsData.count)")
		} catch {
			print("Failed to read credentials file: \(error)")
			throw S3BackupError.credentialsNotFound
		}

		var accessKey: String?
		var secretKey: String?

		// Parse the credentials file
		let lines = credentialsData.components(separatedBy: .newlines)
		var inDefaultSection = false

		print("Parsing \(lines.count) lines from credentials file")

		for (index, line) in lines.enumerated() {
			let trimmed = line.trimmingCharacters(in: .whitespaces)

			if trimmed == "[default]" {
				print("Found [default] section at line \(index + 1)")
				inDefaultSection = true
			} else if trimmed.hasPrefix("[") {
				print("Found new section at line \(index + 1): \(trimmed)")
				inDefaultSection = false
			} else if inDefaultSection, !trimmed.isEmpty {
				if trimmed.hasPrefix("aws_access_key_id") {
					let parts = trimmed.components(separatedBy: "=")
					if parts.count >= 2 {
						accessKey = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
						print("Found access key: \(String(repeating: "*", count: accessKey?.count ?? 0))")
					}
				} else if trimmed.hasPrefix("aws_secret_access_key") {
					let parts = trimmed.components(separatedBy: "=")
					if parts.count >= 2 {
						secretKey = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
						print("Found secret key: \(String(repeating: "*", count: secretKey?.count ?? 0))")
					}
				}
			}
		}

		guard let accessKey, !accessKey.isEmpty else {
			print("Access key not found or empty")
			throw S3BackupError.credentialsNotFound
		}

		guard let secretKey, !secretKey.isEmpty else {
			print("Secret key not found or empty")
			throw S3BackupError.credentialsNotFound
		}

		print("Credentials parsed successfully, initializing S3 client...")
		try await self.init(accessKey: accessKey, secretKey: secretKey)
	}

	// MARK: - MD5 Calculation

	private func calculateMD5(for data: Data) -> String {
		let digest = Insecure.MD5.hash(data: data)
		return digest.map { String(format: "%02hhx", $0) }.joined()
	}

	// MARK: - Quota Management

	/// Check if user has enough quota to upload a photo
	func canUploadPhoto(size: Int64) -> Bool {
		let newPhotoSize = self.backupStats.photoSize + size
		let quotaLimit = self.identityManager.currentUser?.subscription?.quotaBytes ?? SubscriptionTier.free
			.storageLimit
		return newPhotoSize <= quotaLimit
	}

	/// Calculate storage statistics from S3
	func calculateStorageStats(userId: String) async {
		self.isCalculatingStats = true
		defer { isCalculatingStats = false }

		do {
			// Reset stats
			self.backupStats.photoSize = 0
			self.backupStats.thumbnailSize = 0
			self.backupStats.metadataSize = 0

			// List all objects for the user
			let userPrefix = "users/\(userId)/"

			// Calculate photo storage
			let photoPrefix = "\(userPrefix)photos/"
			let photoResponse = try await client.listObjectsV2(input: ListObjectsV2Input(
				bucket: self.bucketName,
				prefix: photoPrefix
			))

			for object in photoResponse.contents ?? [] {
				if let size = object.size {
					self.backupStats.photoSize += Int64(size)
				}
			}

			// Calculate thumbnail storage
			let thumbPrefix = "\(userPrefix)thumbs/"
			let thumbResponse = try await client.listObjectsV2(input: ListObjectsV2Input(
				bucket: self.bucketName,
				prefix: thumbPrefix
			))

			for object in thumbResponse.contents ?? [] {
				if let size = object.size {
					self.backupStats.thumbnailSize += Int64(size)
				}
			}

			// Calculate metadata storage
			let metadataPrefix = "\(userPrefix)metadata/"
			let metadataResponse = try await client.listObjectsV2(input: ListObjectsV2Input(
				bucket: self.bucketName,
				prefix: metadataPrefix
			))

			for object in metadataResponse.contents ?? [] {
				if let size = object.size {
					self.backupStats.metadataSize += Int64(size)
				}
			}

			print(
				"Storage stats calculated - Photos: \(self.backupStats.photoSizeFormatted), Bonus: \(self.backupStats.bonusSizeFormatted)"
			)
		} catch {
			self.lastError = error
			print("Failed to calculate storage stats: \(error)")
		}
	}

	// MARK: - Upload Photo

	func uploadPhoto(data: Data, userId: String) async throws -> String {
		// Check quota before uploading
		let photoSize = Int64(data.count)
		guard self.canUploadPhoto(size: photoSize) else {
			throw S3BackupError.quotaExceeded
		}

		let md5 = self.calculateMD5(for: data)
		let key = "users/\(userId)/photos/\(md5).dat"

		// Check if already exists
		do {
			_ = try await self.client.headObject(input: HeadObjectInput(
				bucket: self.bucketName,
				key: key
			))
			print("Photo already exists: \(md5)")
			return md5
		} catch {
			// Photo doesn't exist, proceed with upload
		}

		// Upload photo
		let putObjectInput = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "image/jpeg",
			key: key,
			metadata: ["original-md5": md5],
			storageClass: .deepArchive // Use Deep Archive for photos
		)

		_ = try await self.client.putObject(input: putObjectInput)
		print("Uploaded photo: \(md5)")

		// Update stats
		self.backupStats.photoSize += photoSize

		return md5
	}

	// MARK: - Upload Thumbnail

	func uploadThumbnail(data: Data, md5: String, userId: String) async throws {
		let key = "users/\(userId)/thumbs/\(md5).dat"

		let putObjectInput = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "image/jpeg",
			key: key,
			storageClass: .standard // Use Standard for thumbnails (frequently accessed)
		)

		_ = try await self.client.putObject(input: putObjectInput)
		print("Uploaded thumbnail for: \(md5)")

		// Update stats (thumbnails don't count against quota)
		self.backupStats.thumbnailSize += Int64(data.count)
	}

	// MARK: - Get Photo Info

	func getPhotoInfo(md5: String, userId: String) async throws -> (size: Int64, storageClass: String) {
		let key = "users/\(userId)/photos/\(md5).dat"

		let response = try await client.headObject(input: HeadObjectInput(
			bucket: self.bucketName,
			key: key
		))

		let size = response.contentLength ?? 0
		let storageClass = response.storageClass?.rawValue ?? "STANDARD"

		return (size: Int64(size), storageClass: storageClass)
	}

	// MARK: - List User Photos

	func listUserPhotos(userId: String) async throws -> [PhotoEntry] {
		let prefix = "users/\(userId)/photos/"

		let listObjectsInput = ListObjectsV2Input(
			bucket: bucketName,
			prefix: prefix
		)

		let response = try await client.listObjectsV2(input: listObjectsInput)

		var photos: [PhotoEntry] = []

		for object in response.contents ?? [] {
			guard let key = object.key,
			      let lastModified = object.lastModified,
			      let size = object.size else { continue }

			// Extract MD5 from key
			let md5 = key
				.replacingOccurrences(of: prefix, with: "")
				.replacingOccurrences(of: ".dat", with: "")

			photos.append(PhotoEntry(
				md5: md5,
				size: Int64(size),
				lastModified: Date(timeIntervalSince1970: lastModified.timeIntervalSince1970),
				storageClass: object.storageClass?.rawValue ?? "STANDARD"
			))
		}

		return photos
	}
	
	// MARK: - Restore Operations
	
	/// Initiate restore for an archived photo
	func restorePhoto(md5: String, userId: String, rushDelivery: Bool = false) async throws {
		let key = "users/\(userId)/photos/\(md5).dat"
		
		// Create restore request
		let input = RestoreObjectInput(
			bucket: bucketName,
			key: key,
			restoreRequest: S3ClientTypes.RestoreRequest(
				days: 30, // Keep restored for 30 days
				glacierJobParameters: S3ClientTypes.GlacierJobParameters(
					tier: rushDelivery ? .expedited : .standard
				)
			)
		)
		
		do {
			_ = try await client.restoreObject(input: input)
			print("[S3BackupService] Restore initiated for \(key)")
		} catch {
			// Check if already restored/restoring
			if error.localizedDescription.contains("RestoreAlreadyInProgress") {
				print("[S3BackupService] Restore already in progress for \(key)")
				return
			}
			throw error
		}
	}
	
	/// Check restore status for a photo
	func checkRestoreStatus(md5: String, userId: String) async throws -> RestoreStatus {
		let key = "users/\(userId)/photos/\(md5).dat"
		
		let input = HeadObjectInput(
			bucket: bucketName,
			key: key
		)
		
		let response = try await client.headObject(input: input)
		
		// Parse restore header
		if let restore = response.restore {
			if restore.contains("ongoing-request=\"true\"") {
				// Extract expiry time if available
				if let expiryRange = restore.range(of: "expiry-date=\"([^\"]+)\"", options: .regularExpression),
				   let dateString = restore[expiryRange].split(separator: "\"").last {
					let formatter = ISO8601DateFormatter()
					if let expiryDate = formatter.date(from: String(dateString)) {
						return .inProgress(estimatedCompletion: expiryDate)
					}
				}
				return .inProgress(estimatedCompletion: nil)
			} else if restore.contains("ongoing-request=\"false\"") {
				// Extract expiry date
				if let expiryRange = restore.range(of: "expiry-date=\"([^\"]+)\"", options: .regularExpression),
				   let dateString = restore[expiryRange].split(separator: "\"").last {
					let formatter = ISO8601DateFormatter()
					if let expiryDate = formatter.date(from: String(dateString)) {
						return .completed(expiresAt: expiryDate)
					}
				}
				return .completed(expiresAt: nil)
			}
		}
		
		// Check storage class
		if let storageClass = response.storageClass,
		   (storageClass == .deepArchive || storageClass == .glacier) {
			return .notStarted
		}
		
		return .available
	}
	
	/// Batch restore multiple photos
	func restorePhotos(md5s: [String], userId: String, rushDelivery: Bool = false) async throws {
		var errors: [Error] = []
		
		for md5 in md5s {
			do {
				try await restorePhoto(md5: md5, userId: userId, rushDelivery: rushDelivery)
			} catch {
				errors.append(error)
			}
		}
		
		if !errors.isEmpty {
			throw S3BackupError.batchRestoreFailed(errors: errors)
		}
	}
}

// MARK: - Supporting Types

struct PhotoEntry {
	let md5: String
	let size: Int64
	let lastModified: Date
	let storageClass: String
}

enum RestoreStatus {
	case notStarted
	case inProgress(estimatedCompletion: Date?)
	case completed(expiresAt: Date?)
	case available // Not archived, immediately available
}

enum S3BackupError: Error, LocalizedError {
	case credentialsNotFound
	case uploadFailed
	case photoNotFound
	case batchRestoreFailed(errors: [Error])

	var errorDescription: String? {
		switch self {
		case .credentialsNotFound:
			"AWS credentials not found. Please configure your AWS credentials in Settings."
		case .uploadFailed:
			"Failed to upload file to S3"
		case .photoNotFound:
			"Photo not found in S3"
		case .batchRestoreFailed(let errors):
			"Failed to restore \(errors.count) photos"
		}
	}
}
