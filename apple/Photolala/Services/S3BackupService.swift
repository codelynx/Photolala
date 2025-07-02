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
	
	/// Public getter for S3 client (for catalog generation)
	var s3Client: S3Client? {
		return client
	}

	// Convenience init that reads from Keychain, environment, or encrypted credentials
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

		// Third, try encrypted credentials (built-in development fallback)
		if let accessKey = Credentials.decryptCached(.AWS_ACCESS_KEY_ID),
		   let secretKey = Credentials.decryptCached(.AWS_SECRET_ACCESS_KEY),
		   !accessKey.isEmpty, !secretKey.isEmpty
		{
			print("Using AWS credentials from encrypted storage")
			try await self.init(accessKey: accessKey, secretKey: secretKey)
			return
		}

		// No credentials found
		print("AWS credentials not found in any source")
		print("Please configure credentials via:")
		print("1. Settings > AWS S3 Configuration (for custom credentials)")
		print("2. Environment variables (for development)")
		throw S3BackupError.credentialsNotFound
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

			// Calculate photo storage
			let photoPrefix = "photos/\(userId)/"
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
			let thumbPrefix = "thumbnails/\(userId)/"
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
			let metadataPrefix = "metadata/\(userId)/"
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
		let key = "photos/\(userId)/\(md5).dat"

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
	
	// MARK: - Generic Upload/Download
	
	func uploadData(_ data: Data, to key: String) async throws {
		let putObjectInput = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "text/plain",
			key: key,
			storageClass: .standard
		)
		
		_ = try await self.client.putObject(input: putObjectInput)
		print("Uploaded data to: \(key)")
	}
	
	func downloadData(from key: String) async throws -> Data {
		let getObjectInput = GetObjectInput(
			bucket: bucketName,
			key: key
		)
		
		let response = try await self.client.getObject(input: getObjectInput)
		
		guard let body = response.body else {
			throw S3BackupError.downloadFailed
		}
		
		return try await body.readData() ?? Data()
	}

	// MARK: - Upload Thumbnail

	func uploadThumbnail(data: Data, md5: String, userId: String) async throws {
		let key = "thumbnails/\(userId)/\(md5).dat"

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
	
	// MARK: - Upload Metadata
	
	func uploadMetadata(_ metadata: PhotoMetadata, md5: String, userId: String) async throws {
		let key = "metadata/\(userId)/\(md5).plist"
		
		// Encode metadata to plist
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let plistData = try encoder.encode(metadata)
		
		let putObjectInput = PutObjectInput(
			body: .data(plistData),
			bucket: bucketName,
			contentType: "application/x-plist",
			key: key,
			storageClass: .standard // Metadata stays in Standard for quick access
		)
		
		_ = try await self.client.putObject(input: putObjectInput)
		print("Uploaded metadata: \(md5)")
		
		// Update stats
		self.backupStats.metadataSize += Int64(plistData.count)
	}
	
	// MARK: - Delete Photo
	
	func deletePhoto(md5: String, userId: String) async throws {
		// Delete photo
		let photoKey = "photos/\(userId)/\(md5).dat"
		do {
			_ = try await client.deleteObject(input: DeleteObjectInput(
				bucket: bucketName,
				key: photoKey
			))
			print("Deleted photo: \(md5)")
		} catch {
			print("Failed to delete photo \(md5): \(error)")
			throw S3BackupError.uploadFailed // Use existing error for now
		}
		
		// Delete thumbnail
		let thumbnailKey = "thumbnails/\(userId)/\(md5).dat"
		do {
			_ = try await client.deleteObject(input: DeleteObjectInput(
				bucket: bucketName,
				key: thumbnailKey
			))
			print("Deleted thumbnail: \(md5)")
		} catch {
			// Thumbnail might not exist, ignore error
			print("Failed to delete thumbnail \(md5): \(error)")
		}
		
		// Delete metadata
		let metadataKey = "metadata/\(userId)/\(md5).plist"
		do {
			_ = try await client.deleteObject(input: DeleteObjectInput(
				bucket: bucketName,
				key: metadataKey
			))
			print("Deleted metadata: \(md5)")
		} catch {
			// Metadata might not exist, ignore error
			print("Failed to delete metadata \(md5): \(error)")
		}
	}
	
	func deletePhotos(md5Hashes: [String], userId: String) async throws {
		// AWS S3 supports batch delete up to 1000 objects at once
		let maxBatchSize = 1000
		
		// Process in batches
		for startIndex in stride(from: 0, to: md5Hashes.count, by: maxBatchSize) {
			let endIndex = min(startIndex + maxBatchSize, md5Hashes.count)
			let batch = Array(md5Hashes[startIndex..<endIndex])
			
			// Build delete objects for this batch
			var deleteObjects: [S3ClientTypes.ObjectIdentifier] = []
			
			for md5 in batch {
				// Add photo, thumbnail, and metadata keys
				deleteObjects.append(S3ClientTypes.ObjectIdentifier(key: "photos/\(userId)/\(md5).dat"))
				deleteObjects.append(S3ClientTypes.ObjectIdentifier(key: "thumbnails/\(userId)/\(md5).dat"))
				deleteObjects.append(S3ClientTypes.ObjectIdentifier(key: "metadata/\(userId)/\(md5).plist"))
			}
			
			// Perform batch delete
			let deleteInput = DeleteObjectsInput(
				bucket: bucketName,
				delete: S3ClientTypes.Delete(objects: deleteObjects)
			)
			
			do {
				let result = try await client.deleteObjects(input: deleteInput)
				if let deleted = result.deleted {
					print("Batch deleted \(deleted.count) objects")
				}
				if let errors = result.errors, !errors.isEmpty {
					print("Batch delete had \(errors.count) errors")
					for error in errors {
						print("  Error deleting \(error.key ?? "unknown"): \(error.message ?? "unknown error")")
					}
				}
			} catch {
				print("Failed to batch delete: \(error)")
				throw S3BackupError.uploadFailed
			}
		}
	}
	
	// MARK: - Download Metadata
	
	func downloadMetadata(md5: String, userId: String) async throws -> PhotoMetadata? {
		let key = "metadata/\(userId)/\(md5).plist"
		
		do {
			let response = try await client.getObject(input: GetObjectInput(
				bucket: bucketName,
				key: key
			))
			
			guard let data = try await response.body?.readData() else {
				return nil
			}
			
			let decoder = PropertyListDecoder()
			return try decoder.decode(PhotoMetadata.self, from: data)
		} catch {
			// Metadata might not exist for older uploads
			print("Failed to download metadata for \(md5): \(error)")
			return nil
		}
	}

	// MARK: - Get Photo Info

	func getPhotoInfo(md5: String, userId: String) async throws -> (size: Int64, storageClass: String) {
		let key = "photos/\(userId)/\(md5).dat"

		let response = try await client.headObject(input: HeadObjectInput(
			bucket: self.bucketName,
			key: key
		))

		let size = response.contentLength ?? 0
		let storageClass = response.storageClass?.rawValue ?? "STANDARD"

		return (size: Int64(size), storageClass: storageClass)
	}

	// MARK: - List User Photos

	func listUserPhotos(userId: String) async throws -> [S3PhotoEntry] {
		let prefix = "photos/\(userId)/"

		let listObjectsInput = ListObjectsV2Input(
			bucket: bucketName,
			prefix: prefix
		)

		let response = try await client.listObjectsV2(input: listObjectsInput)

		var photos: [S3PhotoEntry] = []

		for object in response.contents ?? [] {
			guard let key = object.key,
			      let lastModified = object.lastModified,
			      let size = object.size else { continue }

			// Extract MD5 from key
			let md5 = key
				.replacingOccurrences(of: prefix, with: "")
				.replacingOccurrences(of: ".dat", with: "")

			photos.append(S3PhotoEntry(
				md5: md5,
				size: Int64(size),
				lastModified: Date(timeIntervalSince1970: lastModified.timeIntervalSince1970),
				storageClass: object.storageClass?.rawValue ?? "STANDARD"
			))
		}

		return photos
	}
	
	// MARK: - List Photos with Metadata
	
	func listUserPhotosWithMetadata(userId: String) async throws -> [S3PhotoEntry] {
		// Get photos and metadata in parallel
		async let photosTask = listUserPhotos(userId: userId)
		async let metadataTask = listUserMetadata(userId: userId)
		
		var photos = try await photosTask
		let metadataDict = try await metadataTask
		
		// Attach metadata to photos
		for i in photos.indices {
			if let metadata = metadataDict[photos[i].md5] {
				photos[i].metadata = metadata
			}
		}
		
		return photos
	}
	
	// MARK: - List User Metadata
	
	func listUserMetadata(userId: String) async throws -> [String: PhotoMetadata] {
		let prefix = "metadata/\(userId)/"
		var metadataDict: [String: PhotoMetadata] = [:]
		var continuationToken: String? = nil
		
		repeat {
			let listObjectsInput = ListObjectsV2Input(
				bucket: bucketName,
				continuationToken: continuationToken,
				prefix: prefix
			)
			
			let response = try await client.listObjectsV2(input: listObjectsInput)
			
			// Process metadata files in parallel
			await withTaskGroup(of: (String, PhotoMetadata?).self) { group in
				for object in response.contents ?? [] {
					guard let key = object.key else { continue }
					
					// Extract MD5 from key
					let md5 = key
						.replacingOccurrences(of: prefix, with: "")
						.replacingOccurrences(of: ".plist", with: "")
					
					group.addTask {
						let metadata = try? await self.downloadMetadata(md5: md5, userId: userId)
						return (md5, metadata)
					}
				}
				
				// Collect results
				for await (md5, metadata) in group {
					if let metadata = metadata {
						metadataDict[md5] = metadata
					}
				}
			}
			
			continuationToken = response.nextContinuationToken
		} while continuationToken != nil
		
		return metadataDict
	}
	
	// MARK: - Restore Operations
	
	/// Initiate restore for an archived photo
	func restorePhoto(md5: String, userId: String, rushDelivery: Bool = false) async throws {
		let key = "photos/\(userId)/\(md5).dat"
		
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
		let key = "photos/\(userId)/\(md5).dat"
		
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

struct S3PhotoEntry {
	let md5: String
	let size: Int64
	let lastModified: Date
	let storageClass: String
	var metadata: PhotoMetadata?
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
	case downloadFailed
	case photoNotFound
	case batchRestoreFailed(errors: [Error])
	case notConfigured
	case notAuthenticated

	var errorDescription: String? {
		switch self {
		case .credentialsNotFound:
			"AWS credentials not found. Please configure your AWS credentials in Settings."
		case .uploadFailed:
			"Failed to upload file to S3"
		case .downloadFailed:
			"Failed to download file from S3"
		case .photoNotFound:
			"Photo not found in S3"
		case .batchRestoreFailed(let errors):
			"Failed to restore \(errors.count) photos"
		case .notConfigured:
			"S3 backup service is not configured"
		case .notAuthenticated:
			"User is not authenticated"
		}
	}
}
