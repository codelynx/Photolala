//
//  DigestPipeline.swift
//  Photolala
//
//  Full processing pipeline for photos (MD5, metadata, thumbnails)
//

import Foundation
import ImageIO
import CoreImage
import OSLog
import Combine

/// Pipeline for processing photos with full MD5, metadata extraction, and thumbnail generation
public actor DigestPipeline {
	private let logger = Logger(subsystem: "com.photolala", category: "DigestPipeline")

	// Dependencies
	private let database: CatalogDatabase
	private let thumbnailCache = ThumbnailCache.shared
	private let metadataCache = MetadataCache.shared

	// Pipeline configuration
	private let maxConcurrentOperations = 4
	private let batchSize = 20

	// Progress tracking
	private var isProcessing = false
	private var cancelRequested = false
	private var processedCount = 0
	private var totalCount = 0

	// Progress publisher
	private let progressSubject = PassthroughSubject<DigestProgress, Never>()
	public var progressPublisher: AnyPublisher<DigestProgress, Never> {
		progressSubject.eraseToAnyPublisher()
	}

	// MARK: - Initialization

	public init(database: CatalogDatabase) {
		self.database = database
	}

	// MARK: - Public API

	/// Process discovered files through the full pipeline
	public func processFiles(_ files: [DiscoveredFile]) async throws {
		guard !isProcessing else {
			throw PipelineError.alreadyProcessing
		}

		isProcessing = true
		cancelRequested = false
		processedCount = 0
		totalCount = files.count
		defer { isProcessing = false }

		logger.info("Starting pipeline processing for \(files.count) files")
		let startTime = Date()

		// Process files in batches
		for batchStart in stride(from: 0, to: files.count, by: batchSize) {
			guard !cancelRequested else {
				throw PipelineError.cancelled
			}

			let batchEnd = min(batchStart + batchSize, files.count)
			let batch = Array(files[batchStart..<batchEnd])

			// Process batch concurrently
			try await withThrowingTaskGroup(of: Void.self) { group in
				for file in batch {
					group.addTask { [weak self] in
						try await self?.processFile(file)
					}
				}

				// Wait for batch completion
				try await group.waitForAll()
			}

			// Update progress
			processedCount = batchEnd
			sendProgress()
		}

		let duration = Date().timeIntervalSince(startTime)
		logger.info("Pipeline completed: \(self.processedCount) files in \(String(format: "%.2f", duration))s")

		// Send completion
		progressSubject.send(DigestProgress(
			processed: processedCount,
			total: totalCount,
			currentFile: nil,
			stage: .complete,
			isComplete: true
		))
	}

	/// Process a single file through all stages
	public func processFile(_ file: DiscoveredFile) async throws {
		logger.debug("Processing file: \(file.url.lastPathComponent)")

		// Stage 1: Validate
		sendProgress(currentFile: file.url, stage: .validating)
		let validation = try await PhotoValidator.validatePhoto(at: file.url)
		guard validation.isValid else {
			throw PipelineError.validationFailed(file.url)
		}

		// Get photo date (EXIF date taken preferred, file creation date as fallback)
		let attributes = try FileManager.default.attributesOfItem(atPath: file.url.path)
		let fileCreationDate = attributes[.creationDate] as? Date ?? Date()

		// Will be updated with EXIF date if available
		var photoDate = fileCreationDate

		// Use format already detected during scanning
		let format = file.detectedFormat

		// Create initial catalog entry with fast key only
		let catalogEntry = CatalogEntry(
			photoHeadMD5: file.fastKey.headMD5,
			fileSize: file.fileSize,
			photoMD5: nil, // Will be computed in Stage 2
			photoDate: photoDate,
			format: format
		)

		// Store initial entry
		try await database.upsertEntry(catalogEntry)

		// Stage 2: Compute full MD5
		sendProgress(currentFile: file.url, stage: .computingMD5)
		let fullMD5 = try await PhotoMD5(contentsOf: file.url)

		// Update entry with full MD5
		let fastKey = file.fastKey.stringValue
		try await database.updatePhotoMD5(fastKey: fastKey, photoMD5: fullMD5.value)

		// Stage 3: Extract metadata
		sendProgress(currentFile: file.url, stage: .extractingMetadata)
		let metadata = try await extractMetadata(from: file.url, md5: fullMD5, validation: validation)

		// Store metadata in cache (not in database - CSV only has minimal data)
		try await metadataCache.storeMetadata(metadata)

		// Update entry with metadata capture date if available
		if let captureDate = metadata.captureDate {
			photoDate = captureDate
			// Update the catalog entry with the EXIF date
			let updatedEntry = CatalogEntry(
				photoHeadMD5: file.fastKey.headMD5,
				fileSize: file.fileSize,
				photoMD5: fullMD5.value,
				photoDate: photoDate,
				format: format
			)
			try await database.upsertEntry(updatedEntry)
		}

		// Stage 4: Generate thumbnail
		sendProgress(currentFile: file.url, stage: .generatingThumbnail)
		_ = try await thumbnailCache.getThumbnail(for: fullMD5, sourceURL: file.url)

		logger.debug("Completed processing: \(file.url.lastPathComponent)")
	}

	/// Cancel ongoing processing
	public func cancelProcessing() {
		cancelRequested = true
		logger.info("Pipeline cancellation requested")
	}

	// MARK: - Metadata Extraction

	private func extractMetadata(
		from url: URL,
		md5: PhotoMD5,
		validation: PhotoValidation
	) async throws -> PhotoMetadata {
		return try await Task.detached(priority: .utility) {
			guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
				throw PipelineError.cannotReadImage(url)
			}

			guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
				throw PipelineError.cannotReadMetadata(url)
			}

			var metadata = PhotoMetadata(
				photoMD5: md5,
				width: Int(validation.dimensions.width),
				height: Int(validation.dimensions.height)
			)

			// Extract EXIF data
			if let exifDict = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
				// Capture date
				if let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal] as? String {
					metadata.captureDate = self.parseExifDate(dateString)
				}

				// Camera info
				if let tiffDict = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
					metadata.cameraMake = tiffDict[kCGImagePropertyTIFFMake] as? String
					metadata.cameraModel = tiffDict[kCGImagePropertyTIFFModel] as? String
				}

				// Lens info
				if let lensModel = exifDict[kCGImagePropertyExifLensModel] as? String {
					metadata.lensModel = lensModel
				}

				// Camera settings
				if let focalLength = exifDict[kCGImagePropertyExifFocalLength] as? NSNumber {
					metadata.focalLength = focalLength.doubleValue
				}

				if let aperture = exifDict[kCGImagePropertyExifFNumber] as? NSNumber {
					metadata.aperture = aperture.doubleValue
				}

				if let shutterSpeed = exifDict[kCGImagePropertyExifExposureTime] as? NSNumber {
					let speed = shutterSpeed.doubleValue
					if speed < 1.0 {
						metadata.shutterSpeed = "1/\(Int(1.0/speed))"
					} else {
						metadata.shutterSpeed = "\(speed)s"
					}
				}

				if let iso = exifDict[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber] {
					metadata.iso = iso.first?.intValue
				}

				// Store full EXIF data as JSON
				if let exifData = try? JSONSerialization.data(withJSONObject: exifDict, options: []) {
					metadata.exifData = exifData
				}
			}

			// Extract GPS data
			if let gpsDict = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
				if let latitude = gpsDict[kCGImagePropertyGPSLatitude] as? NSNumber,
				   let latitudeRef = gpsDict[kCGImagePropertyGPSLatitudeRef] as? String {
					metadata.gpsLatitude = latitude.doubleValue * (latitudeRef == "S" ? -1 : 1)
				}

				if let longitude = gpsDict[kCGImagePropertyGPSLongitude] as? NSNumber,
				   let longitudeRef = gpsDict[kCGImagePropertyGPSLongitudeRef] as? String {
					metadata.gpsLongitude = longitude.doubleValue * (longitudeRef == "W" ? -1 : 1)
				}
			}

			return metadata
		}.value
	}

	private nonisolated func parseExifDate(_ dateString: String) -> Date? {
		// EXIF date format: "yyyy:MM:dd HH:mm:ss"
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		return formatter.date(from: dateString)
	}

	// MARK: - Progress Tracking

	private func sendProgress(
		currentFile: URL? = nil,
		stage: ProcessingStage? = nil
	) {
		progressSubject.send(DigestProgress(
			processed: processedCount,
			total: totalCount,
			currentFile: currentFile?.lastPathComponent,
			stage: stage ?? .processing,
			isComplete: false
		))
	}
}

// MARK: - Metadata Cache

/// Cache for photo metadata
public actor MetadataCache {
	static let shared = MetadataCache()
	private let logger = Logger(subsystem: "com.photolala", category: "MetadataCache")
	private let cacheManager = CacheManager.shared

	private init() {}

	/// Store metadata in cache
	public func storeMetadata(_ metadata: PhotoMetadata) async throws {
		let cachePath = await cacheManager.getMetadataPath(
			photoMD5: metadata.photoMD5,
			cacheType: .md5
		)

		let data = try await Task { @MainActor in
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			return try encoder.encode(metadata)
		}.value

		try await cacheManager.storeData(data, at: cachePath)
		logger.debug("Cached metadata for: \(metadata.photoMD5.value)")
	}

	/// Retrieve metadata from cache
	public func getMetadata(for photoMD5: PhotoMD5) async throws -> PhotoMetadata? {
		let cachePath = await cacheManager.getMetadataPath(
			photoMD5: photoMD5,
			cacheType: .md5
		)

		guard FileManager.default.fileExists(atPath: cachePath.path) else {
			return nil
		}

		let data = try Data(contentsOf: cachePath)
		return try await Task { @MainActor in
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .iso8601
			return try decoder.decode(PhotoMetadata.self, from: data)
		}.value
	}
}

// MARK: - Supporting Types

/// Processing progress information
public struct DigestProgress: Sendable {
	public let processed: Int
	public let total: Int
	public let currentFile: String?
	public let stage: ProcessingStage
	public let isComplete: Bool

	nonisolated public var percentComplete: Double {
		guard total > 0 else { return 0 }
		return Double(processed) / Double(total) * 100
	}
}

/// Processing stages
public enum ProcessingStage {
	case validating
	case computingMD5
	case extractingMetadata
	case generatingThumbnail
	case processing
	case complete

	var description: String {
		switch self {
		case .validating: return "Validating"
		case .computingMD5: return "Computing MD5"
		case .extractingMetadata: return "Extracting metadata"
		case .generatingThumbnail: return "Generating thumbnail"
		case .processing: return "Processing"
		case .complete: return "Complete"
		}
	}
}

/// Pipeline errors
public enum PipelineError: LocalizedError {
	case alreadyProcessing
	case cancelled
	case validationFailed(URL)
	case cannotReadImage(URL)
	case cannotReadMetadata(URL)

	public var errorDescription: String? {
		switch self {
		case .alreadyProcessing:
			return "Pipeline is already processing"
		case .cancelled:
			return "Pipeline was cancelled"
		case .validationFailed(let url):
			return "Validation failed for: \(url.lastPathComponent)"
		case .cannotReadImage(let url):
			return "Cannot read image: \(url.lastPathComponent)"
		case .cannotReadMetadata(let url):
			return "Cannot read metadata: \(url.lastPathComponent)"
		}
	}
}

// PhotoMetadata already conforms to Codable in CatalogDatabase.swift
