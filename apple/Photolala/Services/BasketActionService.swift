//
//  BasketActionService.swift
//  Photolala
//
//  Service for orchestrating basket actions including star/unstar for upload
//

import Foundation
import Combine
import OSLog
import CryptoKit

/// Progress update for basket actions
struct BasketActionProgress {
	let action: BasketAction
	let currentItem: Int
	let totalItems: Int
	let currentItemName: String
	let message: String
	let isComplete: Bool
	let error: Error?

	var percentComplete: Double {
		guard totalItems > 0 else { return 0 }
		return Double(currentItem) / Double(totalItems)
	}
}

/// Service for executing basket actions
@MainActor
final class BasketActionService: ObservableObject {
	private let logger = Logger(subsystem: "com.photolala", category: "BasketActionService")

	// Progress publisher
	@Published private(set) var currentProgress: BasketActionProgress?

	// Dependencies
	private let catalogService: CatalogService?
	private let s3Service: S3Service?
	private var uploadCoordinator: BasketUploadCoordinator?
	private let catalogCache: LocalCatalogCache?
	private let checkpointManager: StarCheckpointManager

	// Current operation
	private var currentTask: Task<Void, Error>?

	init(catalogService: CatalogService? = nil, s3Service: S3Service? = nil) {
		self.catalogService = catalogService
		self.s3Service = s3Service
		self.checkpointManager = StarCheckpointManager()

		// Initialize catalog cache if catalog service is available
		if let catalogService = catalogService {
			self.catalogCache = LocalCatalogCache(catalogService: catalogService)
		} else {
			self.catalogCache = nil
		}
	}

	// MARK: - Public API

	/// Execute a basket action on the given items
	func executeAction(_ action: BasketAction, items: [BasketItem]) async throws {
		// Cancel any existing operation
		currentTask?.cancel()

		// Start new operation
		currentTask = Task {
			switch action {
			case .star:
				try await starItems(items)
			case .unstar:
				try await unstarItems(items)
			case .export:
				try await exportItems(items)
			default:
				throw BasketActionError.unsupportedAction(action.rawValue)
			}
		}

		try await currentTask!.value
	}

	/// Cancel the current operation
	func cancelCurrentOperation() {
		currentTask?.cancel()
		currentTask = nil
		currentProgress = nil
		checkpointManager.pauseCheckpoint()
	}

	/// Resume from a checkpoint
	func resumeFromCheckpoint(_ checkpointId: UUID, originalItems: [BasketItem]) async throws {
		guard let checkpoint = try await checkpointManager.resumeCheckpoint(checkpointId) else {
			throw BasketActionError.checkpointNotFound
		}

		// Get unprocessed items
		let unprocessedItems = checkpointManager.getUnprocessedItems(for: checkpoint, from: originalItems)

		logger.info("Resuming checkpoint with \(unprocessedItems.count) unprocessed items")

		// Resume the appropriate action
		if let action = BasketAction(rawValue: checkpoint.action) {
			// Execute action with the resumed checkpoint (don't create a new one)
			try await executeActionWithCheckpoint(action, items: unprocessedItems, checkpoint: checkpoint)
		} else {
			throw BasketActionError.unsupportedAction(checkpoint.action)
		}
	}

	/// Get available checkpoints
	var availableCheckpoints: [StarCheckpoint] {
		checkpointManager.availableCheckpoints
	}

	// MARK: - Star Implementation

	/// Execute action with existing checkpoint (for resume)
	private func executeActionWithCheckpoint(_ action: BasketAction, items: [BasketItem], checkpoint: StarCheckpoint) async throws {
		switch action {
		case .star:
			try await starItemsWithCheckpoint(items, checkpoint: checkpoint)
		default:
			throw BasketActionError.unsupportedAction(action.rawValue)
		}
	}

	private func starItems(_ items: [BasketItem]) async throws {
		logger.info("Starting star operation for \(items.count) items")

		// Filter for local and Apple Photos items
		let supportedItems = items.filter {
			$0.sourceType == .local || $0.sourceType == .applePhotos
		}
		guard !supportedItems.isEmpty else {
			throw BasketActionError.noSupportedItems
		}

		// Create checkpoint for resumability
		let checkpoint = checkpointManager.createCheckpoint(action: .star, items: supportedItems)

		try await starItemsWithCheckpoint(supportedItems, checkpoint: checkpoint)
	}

	/// Core star implementation that works with both new and resumed checkpoints
	private func starItemsWithCheckpoint(_ items: [BasketItem], checkpoint: StarCheckpoint) async throws {
		logger.info("Processing star operation with checkpoint \(checkpoint.id)")

		// Initialize or update upload coordinator
		guard let s3Service = s3Service else {
			throw BasketActionError.missingDependency("S3Service")
		}

		if uploadCoordinator == nil {
			uploadCoordinator = await BasketUploadCoordinator(
				s3Service: s3Service,
				catalogService: catalogService,
				catalogCache: catalogCache,
				checkpointManager: checkpointManager,
				checkpointId: checkpoint.id
			)
		} else {
			// Update checkpoint ID for existing coordinator
			await uploadCoordinator?.updateCheckpointId(checkpoint.id)
		}

		// Process each item
		for (index, item) in items.enumerated() {
			// Check for cancellation
			try Task.checkCancellation()

			// Update progress
			currentProgress = BasketActionProgress(
				action: .star,
				currentItem: index + 1,
				totalItems: items.count,
				currentItemName: item.displayName,
				message: "Computing MD5 for \(item.displayName)...",
				isComplete: false,
				error: nil
			)

			// Queue for processing (coordinator will handle MD5 computation and catalog update)
			await uploadCoordinator?.queueForUpload(item: item)
			logger.debug("Queued item for star: \(item.displayName)")
		}

		// Mark complete
		currentProgress = BasketActionProgress(
			action: .star,
			currentItem: items.count,
			totalItems: items.count,
			currentItemName: "",
			message: "Starred \(items.count) items for upload",
			isComplete: true,
			error: nil
		)

		// Start upload process if configured
		if let coordinator = uploadCoordinator {
			Task {
				do {
					try await coordinator.startUpload()
				} catch {
					logger.error("Upload failed: \(error)")
				}
			}
		}
	}

	private func unstarItems(_ items: [BasketItem]) async throws {
		logger.info("Starting unstar operation for \(items.count) items")

		guard let catalogService = catalogService else {
			throw BasketActionError.missingDependency("CatalogService")
		}

		// Process each item
		for (index, item) in items.enumerated() {
			// Check for cancellation
			try Task.checkCancellation()

			// Update progress
			currentProgress = BasketActionProgress(
				action: .unstar,
				currentItem: index + 1,
				totalItems: items.count,
				currentItemName: item.displayName,
				message: "Removing \(item.displayName) from catalog...",
				isComplete: false,
				error: nil
			)

			do {
				// For unstar, we need to find the MD5 in the catalog
				// Try to resolve URL from bookmark for local files
				if item.sourceType == .local {
					let resolved = item.resolveURL()
					if let resolved = resolved {
						defer {
							if resolved.didStartAccessing {
								resolved.url.stopAccessingSecurityScopedResource()
							}
						}

						// Compute MD5 for the item
						let md5 = try await computeFullMD5(for: resolved.url)

						// Remove from catalog (unstar)
						try await catalogService.unstarEntry(md5: md5)

						// Remove from upload queue if present
						await uploadCoordinator?.removeFromQueue(md5: md5)

						logger.debug("Unstarred item: \(item.displayName)")
					}
				} else if item.sourceType == .applePhotos {
					// For Apple Photos, we'd need the exported MD5
					logger.warning("Unstar for Apple Photos items not yet implemented")
				}
			} catch {
				logger.error("Failed to unstar item \(item.displayName): \(error)")
				// Continue with next item
			}
		}

		// Mark complete
		currentProgress = BasketActionProgress(
			action: .unstar,
			currentItem: items.count,
			totalItems: items.count,
			currentItemName: "",
			message: "Unstarred \(items.count) items",
			isComplete: true,
			error: nil
		)
	}

	private func exportItems(_ items: [BasketItem]) async throws {
		// TODO: Implement export functionality
		throw BasketActionError.unsupportedAction("Export")
	}

	// MARK: - Helpers

	private func computeFullMD5(for url: URL) async throws -> String {
		// Compute full file MD5 with streaming
		let handle = try FileHandle(forReadingFrom: url)
		defer { try? handle.close() }

		var hasher = Insecure.MD5()
		let chunkSize = 1024 * 1024 // 1MB chunks

		while true {
			let data = try handle.read(upToCount: chunkSize) ?? Data()
			if data.isEmpty { break }
			hasher.update(data: data)
		}

		let digest = hasher.finalize()
		return digest.map { String(format: "%02x", $0) }.joined()
	}
}

// MARK: - Upload Coordinator

/// Coordinates upload of starred items to S3
actor BasketUploadCoordinator {
	private let logger = Logger(subsystem: "com.photolala", category: "BasketUploadCoordinator")
	private let s3Service: S3Service
	private let catalogService: CatalogService?
	private let catalogCache: LocalCatalogCache?
	private let checkpointManager: StarCheckpointManager?
	private var checkpointId: UUID?

	// Upload queue - stores items with their computed MD5s
	private var uploadQueue: [(item: BasketItem, md5: String?)] = []
	private var isUploading = false

	// Progress tracking
	private var uploadProgress = PassthroughSubject<BasketActionProgress, Never>()

	init(s3Service: S3Service,
	     catalogService: CatalogService? = nil,
	     catalogCache: LocalCatalogCache? = nil,
	     checkpointManager: StarCheckpointManager? = nil,
	     checkpointId: UUID? = nil) {
		self.s3Service = s3Service
		self.catalogService = catalogService
		self.catalogCache = catalogCache
		self.checkpointManager = checkpointManager
		self.checkpointId = checkpointId
	}

	func updateCheckpointId(_ newId: UUID) {
		self.checkpointId = newId
		logger.debug("Updated checkpoint ID to: \(newId)")
	}

	func queueForUpload(item: BasketItem) {
		// MD5 will be computed during upload process
		uploadQueue.append((item, nil))
		logger.debug("Queued item for upload: \(item.displayName)")
	}

	func removeFromQueue(md5: String) {
		uploadQueue.removeAll { tuple in tuple.md5 == md5 }
		logger.debug("Removed items with MD5 from queue: \(md5)")
	}

	func startUpload() async throws {
		guard !isUploading else {
			logger.info("Upload already in progress")
			return
		}

		isUploading = true
		defer { isUploading = false }

		logger.info("Starting upload of \(self.uploadQueue.count) items")

		// Process each item in the queue
		for (index, (item, _)) in self.uploadQueue.enumerated() {
			logger.debug("Processing item \(index + 1)/\(self.uploadQueue.count): \(item.displayName)")

			// Compute MD5 if not already done
			var md5: String?
			var exportedAsset: ExportedAsset? // For Apple Photos cleanup
			var detectedFormat: ImageFormat = .unknown // Track detected format

			if item.sourceType == .local {
				// resolveURL needs to be called on MainActor
				let resolved = await MainActor.run {
					item.resolveURL()
				}

				if let resolved = resolved {
					defer {
						if resolved.didStartAccessing {
							resolved.url.stopAccessingSecurityScopedResource()
						}
					}
					md5 = try await computeFullMD5(for: resolved.url)

					// Detect format for local files
					detectedFormat = detectImageFormat(from: resolved.url) ?? .unknown
				}
			} else if item.sourceType == .applePhotos {
				// Export Apple Photos item and compute MD5
				if let assetId = item.sourceIdentifier {
					do {
						// Create a task to run on MainActor
						let exported: ExportedAsset = try await withCheckedThrowingContinuation { continuation in
							Task { @MainActor in
								do {
									let exporter = ApplePhotoExporter()
									let result = try await exporter.exportAsset(assetId)
									continuation.resume(returning: result)
								} catch {
									continuation.resume(throwing: error)
								}
							}
						}

						// Compute MD5 of exported file
						md5 = try await computeFullMD5(for: exported.temporaryURL)

						// Detect format for exported files
						detectedFormat = detectImageFormat(from: exported.temporaryURL) ?? .heif // Default to HEIF for Apple Photos

						// Store exported asset for later cleanup
						exportedAsset = exported
					} catch {
						logger.error("Failed to export Apple Photos item \(item.displayName): \(error)")

						// Mark as failed in checkpoint
						if let checkpointManager = checkpointManager, let checkpointId = checkpointId {
							await MainActor.run {
								checkpointManager.markItemFailed(
									checkpointId: checkpointId,
									basketItemId: item.id,
									displayName: item.displayName,
									error: error.localizedDescription
								)
							}
						}
						continue
					}
				} else {
					logger.warning("Apple Photos item missing asset identifier")

					// Mark as failed in checkpoint
					if let checkpointManager = checkpointManager, let checkpointId = checkpointId {
						await MainActor.run {
							checkpointManager.markItemFailed(
								checkpointId: checkpointId,
								basketItemId: item.id,
								displayName: item.displayName,
								error: "Missing asset identifier"
							)
						}
					}
					continue
				}
			}

			guard let photoMD5 = md5 else {
				logger.error("Failed to compute MD5 for \(item.displayName)")

				// Mark as failed in checkpoint
				if let checkpointManager = checkpointManager, let checkpointId = checkpointId {
					await MainActor.run {
						checkpointManager.markItemFailed(
							checkpointId: checkpointId,
							basketItemId: item.id,
							displayName: item.displayName,
							error: "Failed to compute MD5"
						)
					}
				}
				continue
			}

			// Check if already in catalog (already starred)
			if let catalogService = catalogService {
				let isStarred = try await catalogService.isStarred(md5: photoMD5)
				if isStarred {
					logger.info("Item \(item.displayName) already starred (in catalog)")

					// Mark as already processed (deduplicated)
					if let checkpointManager = checkpointManager, let checkpointId = checkpointId {
						await MainActor.run {
							checkpointManager.markItemProcessed(
								checkpointId: checkpointId,
								basketItemId: item.id,
								displayName: item.displayName,
								md5: photoMD5,
								uploaded: true // Already in catalog means already uploaded
							)
						}
					}
					continue
				}
			}

			// Create catalog entry with detected format
			let entry = CatalogEntry(
				photoHeadMD5: String(photoMD5.prefix(8)), // Use first 8 chars for head MD5
				fileSize: item.fileSize ?? 0,
				photoMD5: photoMD5,
				photoDate: item.photoDate ?? Date(),
				format: detectedFormat
			)

			// Add to catalog (star)
			if let catalogService = catalogService {
				try await catalogService.starEntry(entry)
				logger.info("Added \(item.displayName) to catalog (starred)")

				// Update local cache
				await self.catalogCache?.addToCache(md5: photoMD5)
			}

			// Upload to S3
			var uploadSucceeded = false
			do {
				if item.sourceType == .local {
					// Get the file data for local files
					let resolved = await MainActor.run {
						item.resolveURL()
					}

					if let resolved = resolved {
						defer {
							if resolved.didStartAccessing {
								resolved.url.stopAccessingSecurityScopedResource()
							}
						}

						let fileData = try Data(contentsOf: resolved.url)
						let format = detectImageFormat(from: resolved.url) ?? .jpeg

						try await s3Service.uploadPhoto(
							data: fileData,
							md5: photoMD5,
							format: format,
							userID: "default" // TODO: Get actual user ID
						)
						uploadSucceeded = true
						logger.info("Uploaded local file \(item.displayName) to S3")
					}
				} else if item.sourceType == .applePhotos && exportedAsset != nil {
					// Upload exported Apple Photos item
					let fileData = try Data(contentsOf: exportedAsset!.temporaryURL)
					let format = detectImageFormat(from: exportedAsset!.temporaryURL) ?? .heif // Default to HEIF for Apple Photos

					try await s3Service.uploadPhoto(
						data: fileData,
						md5: photoMD5,
						format: format,
						userID: "default" // TODO: Get actual user ID
					)
					uploadSucceeded = true
					logger.info("Uploaded Apple Photos item \(item.displayName) to S3")
				}

				// Mark as successfully processed in checkpoint
				if uploadSucceeded, let checkpointManager = checkpointManager, let checkpointId = checkpointId {
					await MainActor.run {
						checkpointManager.markItemProcessed(
							checkpointId: checkpointId,
							basketItemId: item.id,
							displayName: item.displayName,
							md5: photoMD5,
							uploaded: true
						)
					}
				}
			} catch {
				logger.error("Failed to upload \(item.displayName): \(error)")

				// Mark as failed in checkpoint
				if let checkpointManager = checkpointManager, let checkpointId = checkpointId {
					await MainActor.run {
						checkpointManager.markItemFailed(
							checkpointId: checkpointId,
							basketItemId: item.id,
							displayName: item.displayName,
							error: error.localizedDescription
						)
					}
				}
			}

			// Clean up exported Apple Photos asset
			if let exportedAsset = exportedAsset {
				await MainActor.run {
					exportedAsset.cleanup()
				}
			}
		}

		// Clear queue after successful upload
		self.uploadQueue.removeAll()

		logger.info("Upload complete")
	}

	// Helper to detect image format from file extension
	private func detectImageFormat(from url: URL) -> ImageFormat? {
		let ext = url.pathExtension.lowercased()
		switch ext {
		case "jpg", "jpeg", "jpe", "jfif":
			return .jpeg
		case "png":
			return .png
		case "heic", "heif":
			return .heif
		case "gif":
			return .gif
		case "tiff", "tif":
			return .tiff
		case "webp":
			return .webp
		case "bmp":
			return .bmp
		case "cr2":
			return .rawCR2
		case "nef":
			return .rawNEF
		case "arw":
			return .rawARW
		case "dng":
			return .rawDNG
		case "orf":
			return .rawORF
		case "raf":
			return .rawRAF
		default:
			return nil
		}
	}

	// Helper to compute MD5
	private func computeFullMD5(for url: URL) async throws -> String {
		let handle = try FileHandle(forReadingFrom: url)
		defer { try? handle.close() }

		var hasher = Insecure.MD5()
		let chunkSize = 1024 * 1024 // 1MB chunks

		while true {
			let data = try handle.read(upToCount: chunkSize) ?? Data()
			if data.isEmpty { break }
			hasher.update(data: data)
		}

		let digest = hasher.finalize()
		return digest.map { String(format: "%02x", $0) }.joined()
	}
}

// MARK: - Errors

enum BasketActionError: LocalizedError {
	case unsupportedAction(String)
	case noSupportedItems
	case missingDependency(String)
	case uploadFailed(String)
	case checkpointNotFound

	var errorDescription: String? {
		switch self {
		case .unsupportedAction(let action):
			return "Action '\(action)' is not yet supported"
		case .noSupportedItems:
			return "No supported items to process (local or Apple Photos)"
		case .missingDependency(let dependency):
			return "Missing required dependency: \(dependency)"
		case .uploadFailed(let message):
			return "Upload failed: \(message)"
		case .checkpointNotFound:
			return "Checkpoint not found or cannot be resumed"
		}
	}
}