//
//  S3BackupService.swift
//  Photolala
//
//  Sequential backup processor for uploading photos to S3
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import OSLog
import CryptoKit

/// Service for backing up photos to S3
actor S3BackupService {
	private let logger = Logger(subsystem: "com.photolala", category: "S3BackupService")
	private let s3Service: S3Service
	private let catalogDatabase: CatalogDatabase?

	// Progress tracking
	private var uploadResults: [String: UploadResult] = [:]
	private var isUploading = false

	// PTM-256 configuration
	private let thumbnailSize = CGSize(width: 256, height: 256)
	private let jpegQuality: CGFloat = 0.85

	// MARK: - Initialization

	init(s3Service: S3Service, catalogDatabase: CatalogDatabase? = nil) {
		self.s3Service = s3Service
		self.catalogDatabase = catalogDatabase
	}

	// MARK: - Public API

	/// Backup photos to S3 sequentially
	func backupPhotos(_ items: [PhotoItem], userID: String) async -> [String: UploadResult] {
		guard !isUploading else {
			logger.warning("Backup already in progress")
			return [:]
		}

		isUploading = true
		uploadResults.removeAll()
		defer { isUploading = false }

		logger.info("Starting backup of \(items.count) photos")
		let startTime = Date()

		for item in items {
			// Capture properties outside the do block
			let itemID = item.id
			let itemDisplayName = item.displayName
			let itemFormat = item.format ?? .unknown

			do {

				// 1. Compute MD5 (may require loading full data for Apple Photos)
				let md5 = try await item.computeMD5()
				logger.debug("Computed MD5 for \(itemDisplayName): \(md5)")

				// 2. Check if exists (deduplication)
				let exists = await s3Service.checkPhotoExists(md5: md5, userID: userID)
				if exists {
					uploadResults[itemID] = .skipped
					logger.info("Photo already exists in S3, skipping: \(md5)")
					continue
				}

				// 3. Load photo data
				let photoData = try await item.loadFullData()
				logger.debug("Loaded photo data: \(photoData.count) bytes")

				// 4. Generate PTM-256 thumbnail
				let thumbnailData = try await generatePTM256Thumbnail(from: photoData)
				logger.debug("Generated thumbnail: \(thumbnailData.count) bytes")

				// 5. Upload photo with format preservation
				try await s3Service.uploadPhoto(
					data: photoData,
					md5: md5,
					format: itemFormat,
					userID: userID
				)

				// 6. Upload thumbnail
				try await s3Service.uploadThumbnail(
					data: thumbnailData,
					md5: md5,
					userID: userID
				)

				uploadResults[itemID] = .completed
				logger.info("Successfully uploaded: \(itemDisplayName)")

			} catch {
				uploadResults[itemID] = .failed(error)
				logger.error("Failed to upload \(itemDisplayName): \(error)")
			}
		}

		// 7. Upload catalog snapshot if database available
		if let database = catalogDatabase {
			do {
				try await uploadCatalogSnapshot(database: database, userID: userID)
				logger.info("Catalog snapshot uploaded")
			} catch {
				logger.error("Failed to upload catalog: \(error)")
			}
		}

		let duration = Date().timeIntervalSince(startTime)
		let successCount = uploadResults.values.filter { $0.isSuccess }.count
		logger.info("Backup completed: \(successCount)/\(items.count) successful in \(String(format: "%.2f", duration))s")

		return uploadResults
	}

	/// Get current upload status
	func getUploadResults() -> [String: UploadResult] {
		uploadResults
	}

	/// Check if upload is in progress
	func isBackupInProgress() -> Bool {
		isUploading
	}

	// MARK: - Private Methods

	/// Generate PTM-256 thumbnail from image data
	private func generatePTM256Thumbnail(from imageData: Data) async throws -> Data {
		return try await Task.detached(priority: .utility) { [thumbnailSize, jpegQuality] in
			// Create image source
			guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
				  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
				throw PhotoUploadError.thumbnailGenerationFailed
			}

			// Create context for 256x256 thumbnail
			let size = thumbnailSize.width
			guard let context = CGContext(
				data: nil,
				width: Int(size),
				height: Int(size),
				bitsPerComponent: 8,
				bytesPerRow: 0,
				space: CGColorSpaceCreateDeviceRGB(),
				bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
			) else {
				throw PhotoUploadError.thumbnailGenerationFailed
			}

			// Configure high-quality interpolation
			context.interpolationQuality = .high

			// Calculate crop rect for aspect-fill
			let imageWidth = CGFloat(image.width)
			let imageHeight = CGFloat(image.height)
			let scale = max(size / imageWidth, size / imageHeight)

			let scaledWidth = imageWidth * scale
			let scaledHeight = imageHeight * scale
			let x = (size - scaledWidth) / 2
			let y = (size - scaledHeight) / 2

			// Draw scaled and cropped image
			let drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
			context.draw(image, in: drawRect)

			// Get thumbnail CGImage
			guard let thumbnail = context.makeImage() else {
				throw PhotoUploadError.thumbnailGenerationFailed
			}

			// Encode as JPEG with quality 85
			let data = NSMutableData()
			guard let destination = CGImageDestinationCreateWithData(
				data as CFMutableData,
				UTType.jpeg.identifier as CFString,
				1,
				nil
			) else {
				throw PhotoUploadError.thumbnailGenerationFailed
			}

			let options: [CFString: Any] = [
				kCGImageDestinationLossyCompressionQuality: jpegQuality,
				kCGImageDestinationOptimizeColorForSharing: true
			]

			CGImageDestinationAddImage(destination, thumbnail, options as CFDictionary)

			guard CGImageDestinationFinalize(destination) else {
				throw PhotoUploadError.thumbnailGenerationFailed
			}

			// Validate size
			let resultData = data as Data
			if resultData.count > 50_000 {
				// Too large, try lower quality
				return try Self.recompressThumbnail(thumbnail, targetSize: 50_000)
			}

			return resultData
		}.value
	}

	/// Recompress thumbnail if too large
	private static func recompressThumbnail(_ image: CGImage, targetSize: Int) throws -> Data {
		// Try progressively lower quality
		let qualities: [CGFloat] = [0.75, 0.70, 0.65, 0.60]

		for quality in qualities {
			let data = NSMutableData()
			guard let destination = CGImageDestinationCreateWithData(
				data as CFMutableData,
				UTType.jpeg.identifier as CFString,
				1,
				nil
			) else {
				continue
			}

			let options: [CFString: Any] = [
				kCGImageDestinationLossyCompressionQuality: quality,
				kCGImageDestinationOptimizeColorForSharing: true
			]

			CGImageDestinationAddImage(destination, image, options as CFDictionary)
			CGImageDestinationFinalize(destination)

			let resultData = data as Data
			if resultData.count <= targetSize {
				return resultData
			}
		}

		throw PhotoUploadError.thumbnailGenerationFailed
	}

	/// Upload catalog snapshot to S3
	private func uploadCatalogSnapshot(database: CatalogDatabase, userID: String) async throws {
		// Export catalog to CSV
		let entries = await database.getAllEntries()

		var csvContent = "photo_head_md5,file_size,photo_md5,photo_date,format\n"
		for entry in entries {
			let dateString = String(Int(entry.photoDate.timeIntervalSince1970))
			let md5String = entry.photoMD5 ?? ""
			csvContent += "\(entry.photoHeadMD5),\(entry.fileSize),\(md5String),\(dateString),\(entry.format.rawValue)\n"
		}

		guard let csvData = csvContent.data(using: .utf8) else {
			throw PhotoUploadError.invalidData
		}

		// Compute MD5 of catalog
		let digest = Insecure.MD5.hash(data: csvData)
		let catalogMD5 = digest.map { String(format: "%02x", $0) }.joined()

		// Upload catalog
		try await s3Service.uploadCatalog(
			csvData: csvData,
			catalogMD5: catalogMD5,
			userID: userID
		)

		// Update pointer
		try await s3Service.updateCatalogPointer(
			catalogMD5: catalogMD5,
			userID: userID
		)

		logger.info("Uploaded catalog with MD5: \(catalogMD5)")
	}
}

// MARK: - Progress Reporting

extension S3BackupService {
	struct BackupProgress {
		let totalItems: Int
		let completedItems: Int
		let skippedItems: Int
		let failedItems: Int

		var percentComplete: Double {
			guard totalItems > 0 else { return 0 }
			return Double(completedItems + skippedItems + failedItems) / Double(totalItems) * 100
		}

		var isComplete: Bool {
			completedItems + skippedItems + failedItems >= totalItems
		}
	}

	/// Calculate current progress
	func calculateProgress(totalItems: Int) -> BackupProgress {
		let completed = uploadResults.values.filter {
			if case .completed = $0 { return true }
			return false
		}.count

		let skipped = uploadResults.values.filter {
			if case .skipped = $0 { return true }
			return false
		}.count

		let failed = uploadResults.values.filter {
			if case .failed = $0 { return true }
			return false
		}.count

		return BackupProgress(
			totalItems: totalItems,
			completedItems: completed,
			skippedItems: skipped,
			failedItems: failed
		)
	}
}