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
	// Singleton instance - configured at app startup
	static let shared = BasketActionService()

	/// Configure/update the shared instance with dependencies
	/// Can be called multiple times to update dependencies
	static func configure(s3Service: S3Service?, catalogService: CatalogService? = nil) {
		shared.updateDependencies(s3Service: s3Service, catalogService: catalogService)
	}

	private let logger = Logger(subsystem: "com.photolala", category: "BasketActionService")

	// Progress publisher
	@Published private(set) var currentProgress: BasketActionProgress?

	// Dependencies (mutable for configuration)
	private var s3Service: S3Service?
	private var catalogService: CatalogService?
	private var uploadCoordinator: BasketUploadCoordinator?
	private var catalogCache: LocalCatalogCache?
	private let identityCache = LocalPhotoIdentityCache()
	private let checkpointManager: StarCheckpointManager

	// Current operation
	private var currentTask: Task<Void, Error>?

	// MD5 mapping persistence for Apple Photos
	private let md5MappingURL: URL = {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala", isDirectory: true)
		try? FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true)
		return photolalaDir.appendingPathComponent("starred-md5-mapping.json")
	}()
	// Mapping of original item IDs to MD5s (for Apple Photos unstar)
	private var starredItemsMapping: [String: String] = [:]  // originalID -> MD5

	private init() {
		self.checkpointManager = StarCheckpointManager()
		// Dependencies will be configured later
		self.s3Service = nil
		self.catalogService = nil
		self.catalogCache = nil

		// Load existing MD5 mappings
		if let data = try? Data(contentsOf: md5MappingURL),
		   let mapping = try? JSONDecoder().decode([String: String].self, from: data) {
			self.starredItemsMapping = mapping
		}
	}

	/// Update dependencies (can be called multiple times)
	private func updateDependencies(s3Service: S3Service?, catalogService: CatalogService?) {
		self.s3Service = s3Service
		self.catalogService = catalogService

		// Update catalog cache if catalog service is available
		if let catalogService = catalogService {
			self.catalogCache = LocalCatalogCache(catalogService: catalogService)
			// Start sync immediately
			Task {
				try? await self.catalogCache?.syncWithS3()
				await self.catalogCache?.startPeriodicSync()
			}
		} else {
			self.catalogCache = nil
		}

		// Reset upload coordinator to use new dependencies
		self.uploadCoordinator = nil

		logger.info("Updated dependencies - S3: \(s3Service != nil), Catalog: \(catalogService != nil)")
	}

	// MARK: - Private Helpers

	/// Save MD5 mapping for items (particularly Apple Photos)
	func saveMD5Mapping(originalID: String, md5: String) {
		starredItemsMapping[originalID] = md5
		// Persist to disk
		if let data = try? JSONEncoder().encode(starredItemsMapping) {
			try? data.write(to: md5MappingURL)
		}
	}

	/// Remove MD5 mapping when item is unstarred
	func removeMD5Mapping(originalID: String) {
		starredItemsMapping.removeValue(forKey: originalID)
		// Persist to disk
		if let data = try? JSONEncoder().encode(starredItemsMapping) {
			try? data.write(to: md5MappingURL)
		}
	}

	// MARK: - Public API

	/// Check if an item is starred (exists in catalog)
	func isStarred(md5: String) async -> Bool {
		guard let cache = catalogCache else { return false }
		return await cache.isStarred(md5: md5)
	}

	/// Check if an item is starred by Fast Photo Key
	func isStarredByFastKey(headMD5: String, fileSize: Int64) async -> Bool {
		guard let cache = catalogCache else { return false }
		return await cache.isStarredByFastKey(headMD5: headMD5, fileSize: fileSize)
	}

	/// Check if an item is starred by Fast Photo Key string
	func isStarredByFastKey(_ fastKey: String) async -> Bool {
		guard let cache = catalogCache else { return false }
		return await cache.isStarredByFastKey(fastKey)
	}

	/// Check if a local file is starred using cached identity if available
	func isLocalFileStarred(path: String) async -> Bool {
		// First check identity cache for fast lookup
		if let identity = await identityCache.getIdentity(for: path) {
			// Check by full MD5 if available
			if let fullMD5 = identity.fullMD5 {
				return await isStarred(md5: fullMD5)
			}
			// Check by Fast Photo Key if available
			if let headMD5 = identity.headMD5, let fileSize = identity.fileSize {
				return await isStarredByFastKey(headMD5: headMD5, fileSize: fileSize)
			}
		}

		// No cached identity, need to compute Fast Photo Key (faster than full MD5)
		let url = URL(fileURLWithPath: path)
		if let fastKey = try? await FastPhotoKey(contentsOf: url) {
			// Cache the identity for future use
			let identity = PhotoIdentity(
				headMD5: fastKey.headMD5,
				fileSize: fastKey.fileSize,
				fullMD5: nil
			)
			await identityCache.cacheIdentity(identity, for: path)

			// Check using Fast Photo Key
			return await isStarredByFastKey(headMD5: fastKey.headMD5, fileSize: fastKey.fileSize)
		}

		return false
	}

	/// Get cached photo identity for a file path (public for photo sources)
	func getCachedIdentity(for path: String) async -> PhotoIdentity? {
		return await identityCache.getIdentity(for: path)
	}

	/// Cache photo identity for a file path (public for photo sources)
	func cachePhotoIdentity(_ identity: PhotoIdentity, for path: String) async {
		await identityCache.cacheIdentity(identity, for: path)
	}

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

		// Also cancel any ongoing uploads
		Task {
			await uploadCoordinator?.cancelUpload()
		}
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

	/// Get the current authenticated user ID, throwing if not signed in
	private func getAuthenticatedUserID() async throws -> String {
		let user = await MainActor.run {
			AccountManager.shared.getCurrentUser()
		}

		guard let user = user else {
			throw BasketActionError.notAuthenticated
		}

		return user.id.uuidString
	}

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

		// Ensure both S3 and catalog services are available
		guard s3Service != nil else {
			throw BasketActionError.missingDependency("S3Service not initialized")
		}
		guard catalogService != nil else {
			throw BasketActionError.missingDependency("CatalogService not initialized")
		}

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

		// Get authenticated user ID upfront
		let userID = try await getAuthenticatedUserID()

		// Initialize or update upload coordinator
		guard let s3Service = s3Service else {
			throw BasketActionError.missingDependency("S3Service")
		}

		if uploadCoordinator == nil {
			uploadCoordinator = BasketUploadCoordinator(
				s3Service: s3Service,
				catalogService: catalogService,
				catalogCache: catalogCache,
				checkpointManager: checkpointManager,
				checkpointId: checkpoint.id,
				userID: userID
			)
		} else {
			// Update checkpoint ID for existing coordinator
			await uploadCoordinator?.updateCheckpointId(checkpoint.id)
			await uploadCoordinator?.updateUserID(userID)
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

		// Upload will start automatically when items are queued
	}

	private func unstarItems(_ items: [BasketItem]) async throws {
		logger.info("Starting unstar operation for \(items.count) items")

		// Get authenticated user ID upfront
		let userID = try await getAuthenticatedUserID()

		// Ensure both S3 and catalog services are available
		guard let s3Service = s3Service else {
			throw BasketActionError.missingDependency("S3Service not initialized")
		}
		guard catalogService != nil else {
			throw BasketActionError.missingDependency("CatalogService not initialized")
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
				// For unstar, we delete from S3
				if item.sourceType == .local || item.sourceType == .applePhotos || item.sourceType == .cloud {
					// Use the userID from the beginning of the function

					// Compute or determine MD5 based on source type
					var md5: String?

					if item.sourceType == .cloud {
						// For cloud items, the ID is already the MD5
						md5 = item.id
					} else if item.sourceType == .local {
						// For local files, compute MD5 from the file
						let resolved = item.resolveURL()
						if let resolved = resolved {
							defer {
								if resolved.didStartAccessing {
									resolved.url.stopAccessingSecurityScopedResource()
								}
							}
							// Compute MD5 for the item
							md5 = try await computeFullMD5(for: resolved.url)
							logger.info("Computed MD5 for local file \(item.displayName): \(md5 ?? "nil")")
						} else if let sourceIdentifier = item.sourceIdentifier {
							// Try using sourceIdentifier as file path
							let url = URL(fileURLWithPath: sourceIdentifier)
							if FileManager.default.fileExists(atPath: url.path) {
								md5 = try await computeFullMD5(for: url)
								logger.info("Computed MD5 from sourceIdentifier for \(item.displayName): \(md5 ?? "nil")")
							} else {
								logger.error("Cannot access local file for MD5 computation: \(sourceIdentifier)")
							}
						} else {
							logger.error("No URL or sourceIdentifier available for local file \(item.displayName)")
						}
					} else if item.sourceType == .applePhotos {
						// For Apple Photos, look up the MD5 from our mapping
						if let mappedMD5 = starredItemsMapping[item.id] {
							md5 = mappedMD5
							logger.info("Found mapped MD5 for Apple Photos item \(item.displayName): \(md5 ?? "nil")")
						} else {
							logger.warning("Cannot unstar Apple Photos item \(item.displayName) - MD5 mapping not found for ID: \(item.id)")
						}
					}

					// Check if we have an MD5
					guard let photoMD5 = md5 else {
						logger.error("No MD5 found for \(item.displayName) - cannot unstar")
						continue
					}

					// Delete photo from S3
					let s3Key = "photos/\(userID)/\(photoMD5).dat"
					try await s3Service.deleteObject(key: s3Key)
					logger.info("Deleted \(item.displayName) from S3 at \(s3Key)")

					// Delete thumbnail from S3
					let thumbnailKey = "thumbnails/\(userID)/\(photoMD5).jpg"
					do {
						try await s3Service.deleteObject(key: thumbnailKey)
						logger.info("Deleted thumbnail for \(item.displayName) from S3")
					} catch {
						logger.warning("Failed to delete thumbnail for \(item.displayName): \(error)")
						// Continue even if thumbnail deletion fails
					}

					// Remove from upload queue if present
					await uploadCoordinator?.removeFromQueue(md5: photoMD5)

					// Remove from catalog to update star state
					if let catalogService = catalogService {
						do {
							// Remove from catalog
							try await catalogService.unstarEntry(md5: photoMD5)
							logger.info("Removed \(item.displayName) from catalog")

							// Create snapshot after modification to update pointer
							try await catalogService.createSnapshot()
							logger.info("Created catalog snapshot after unstar")
						} catch {
							logger.error("Failed to remove from catalog: \(error)")
							// Continue even if catalog update fails - S3 deletion succeeded
						}
					}

					// Update cache if available
					if let cache = catalogCache {
						await cache.removeFromCache(md5: photoMD5)
					}

					// Remove MD5 mapping
					if item.sourceType == .applePhotos {
						removeMD5Mapping(originalID: item.id)
					}
				} else {
					logger.info("Skipping \(item.sourceType.rawValue) item \(item.displayName) - not supported for unstar")
				}
			} catch {
				logger.error("Failed to unstar item \(item.displayName): \(error)")
				// Continue with next item
			}
		}

		// Upload catalog to S3 after all unstar operations complete
		// This ensures the cloud catalog is in sync with local catalog
		if let catalogService = catalogService {
			do {
				// Get the current catalog info (contains MD5 and path)
				if let catalogInfo = await MainActor.run(body: { catalogService.catalogInfo }) {
					// Read the CSV data from the snapshot file
					let csvData = try Data(contentsOf: catalogInfo.path)

					// userID already available from start of function

					// Upload catalog CSV to S3
					try await s3Service.uploadCatalog(csvData: csvData, catalogMD5: catalogInfo.md5, userID: userID)
					logger.info("Uploaded updated catalog to S3 after unstar: .photolala.\(catalogInfo.md5).csv")

					// Update the catalog pointer on S3
					try await s3Service.updateCatalogPointer(catalogMD5: catalogInfo.md5, userID: userID)
					logger.info("Updated catalog pointer on S3 to: \(catalogInfo.md5)")
				} else {
					logger.warning("No catalog info available after unstar operation - catalog not uploaded to S3")
				}
			} catch {
				logger.error("Failed to upload catalog to S3 after unstar: \(error)")
				// Don't throw - catalog upload failure shouldn't fail the unstar operation
				// Photos are already removed from S3 and local catalog is updated
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
		let path = url.path

		// Check cache first
		if let cachedIdentity = await identityCache.getIdentity(for: path),
		   let cachedMD5 = cachedIdentity.fullMD5 {
			logger.debug("Using cached MD5 for \(path)")
			return cachedMD5
		}

		// Compute full file MD5 with streaming
		logger.debug("Computing MD5 for \(path)")
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
		let md5 = digest.map { String(format: "%02x", $0) }.joined()

		// Also compute Fast Photo Key while we're at it
		let fastKey = try await FastPhotoKey(contentsOf: url)

		// Cache the complete identity
		let identity = PhotoIdentity(
			headMD5: fastKey.headMD5,
			fileSize: fastKey.fileSize,
			fullMD5: md5
		)
		await identityCache.cacheIdentity(identity, for: path)

		return md5
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
	private var userID: String

	// Upload queue - stores items with their computed MD5s
	private var uploadQueue: [(item: BasketItem, md5: String?)] = []
	private var isUploading = false
	private var uploadTask: Task<Void, Error>?

	// Progress tracking
	private var uploadProgress = PassthroughSubject<BasketActionProgress, Never>()

	init(s3Service: S3Service,
	     catalogService: CatalogService? = nil,
	     catalogCache: LocalCatalogCache? = nil,
	     checkpointManager: StarCheckpointManager? = nil,
	     checkpointId: UUID? = nil,
	     userID: String) {
		self.s3Service = s3Service
		self.catalogService = catalogService
		self.catalogCache = catalogCache
		self.checkpointManager = checkpointManager
		self.checkpointId = checkpointId
		self.userID = userID
	}

	func updateCheckpointId(_ newId: UUID) {
		self.checkpointId = newId
		logger.debug("Updated checkpoint ID to: \(newId)")
	}

	func updateUserID(_ newID: String) {
		self.userID = newID
		logger.debug("Updated user ID to: \(newID)")
	}

	func queueForUpload(item: BasketItem) {
		// MD5 will be computed during upload process
		uploadQueue.append((item, nil))
		logger.debug("Queued item for upload: \(item.displayName)")

		// If not currently uploading, start the upload process
		if !isUploading {
			startUploadInBackground()
		}
	}

	func removeFromQueue(md5: String) {
		uploadQueue.removeAll { tuple in tuple.md5 == md5 }
		logger.debug("Removed items with MD5 from queue: \(md5)")
	}

	func cancelUpload() {
		uploadTask?.cancel()
		uploadTask = nil
		isUploading = false
		logger.info("Upload cancelled")
	}

	func startUploadInBackground() {
		uploadTask?.cancel() // Cancel any existing task
		uploadTask = Task {
			do {
				try await startUpload()
			} catch {
				if !Task.isCancelled {
					logger.error("Upload failed: \(error)")
				}
			}
		}
	}

	func startUpload() async throws {
		guard !isUploading else {
			logger.info("Upload already in progress")
			return
		}

		isUploading = true
		defer {
			isUploading = false

			// If there are still items in queue after this batch, start another upload
			if !self.uploadQueue.isEmpty {
				logger.info("Queue has \(self.uploadQueue.count) new items, starting another upload batch")
				self.startUploadInBackground()
			}
		}

		// Process items one at a time, removing from queue as we go
		while !self.uploadQueue.isEmpty {
			// Check for cancellation before processing next item
			do {
				try Task.checkCancellation()
			} catch {
				// On cancellation, items remain in queue for next upload
				logger.info("Upload cancelled with \(self.uploadQueue.count) items remaining")
				throw error
			}

			// Remove and process first item
			let (item, _) = self.uploadQueue.removeFirst()
			logger.debug("Processing item: \(item.displayName) (\(self.uploadQueue.count) remaining)")

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
					do {
						// Ensure cleanup happens after MD5 computation
						defer {
							if resolved.didStartAccessing {
								resolved.url.stopAccessingSecurityScopedResource()
							}
						}
						// Compute MD5 and detect format before releasing
						md5 = try await computeFullMD5(for: resolved.url)
						detectedFormat = detectImageFormat(from: resolved.url) ?? .jpeg
					} catch {
						logger.error("Failed to compute MD5 for \(item.displayName): \(error)")
						throw error
					}
				} else if let sourceIdentifier = item.sourceIdentifier {
					// Fallback to sourceIdentifier (file path) if bookmark resolution fails
					logger.warning("Bookmark resolution failed for \(item.displayName), trying sourceIdentifier: \(sourceIdentifier)")
					let url = URL(fileURLWithPath: sourceIdentifier)

					// Check if file is accessible
					if FileManager.default.isReadableFile(atPath: url.path) {
						do {
							md5 = try await computeFullMD5(for: url)
							detectedFormat = detectImageFormat(from: url) ?? .jpeg
							logger.info("Successfully computed MD5 using sourceIdentifier fallback for \(item.displayName)")
						} catch {
							logger.error("Failed to compute MD5 using sourceIdentifier for \(item.displayName): \(error)")
							// Mark as failed in checkpoint
							if let checkpointManager = checkpointManager, let checkpointId = checkpointId {
								await MainActor.run {
									checkpointManager.markItemFailed(
										checkpointId: checkpointId,
										basketItemId: item.id,
										displayName: item.displayName,
										error: "Failed to compute MD5: \(error.localizedDescription)"
									)
								}
							}
						}
					} else {
						logger.error("File not accessible at path: \(sourceIdentifier)")
						// Mark as failed in checkpoint
						if let checkpointManager = checkpointManager, let checkpointId = checkpointId {
							await MainActor.run {
								checkpointManager.markItemFailed(
									checkpointId: checkpointId,
									basketItemId: item.id,
									displayName: item.displayName,
									error: "File not accessible at path: \(sourceIdentifier)"
								)
							}
						}
					}
				} else {
					logger.error("Could not resolve URL for local item \(item.displayName) - no bookmark or sourceIdentifier")
					// Mark as failed in checkpoint
					if let checkpointManager = checkpointManager, let checkpointId = checkpointId {
						await MainActor.run {
							checkpointManager.markItemFailed(
								checkpointId: checkpointId,
								basketItemId: item.id,
								displayName: item.displayName,
								error: "No bookmark or sourceIdentifier available"
							)
						}
					}
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

					// Clean up exported Apple Photos asset before continuing
					if let exportedAsset = exportedAsset {
						await MainActor.run {
							exportedAsset.cleanup()
						}
					}
					continue
				}
			}

			// Prepare to compute actual Fast Photo Key
			var actualHeadMD5: String = String(photoMD5.prefix(8)) // fallback to first 8 chars
			var actualFileSize: Int64 = item.fileSize ?? 0

			// Try to compute actual Fast Photo Key from file
			if item.sourceType == .local {
				// For local files, try to compute from the file path
				if let sourceIdentifier = item.sourceIdentifier {
					let url = URL(fileURLWithPath: sourceIdentifier)
					do {
						let fastKey = try await FastPhotoKey(contentsOf: url)
						actualHeadMD5 = fastKey.headMD5
						actualFileSize = fastKey.fileSize
						logger.info("Computed Fast Photo Key for \(item.displayName): \(actualHeadMD5):\(actualFileSize)")
					} catch {
						logger.warning("Failed to compute Fast Photo Key, using fallback: \(error)")
					}
				}
			} else if item.sourceType == .applePhotos, let exportedAsset = exportedAsset {
				// For Apple Photos, compute from exported file
				do {
					let fastKey = try await FastPhotoKey(contentsOf: exportedAsset.temporaryURL)
					actualHeadMD5 = fastKey.headMD5
					actualFileSize = fastKey.fileSize
					logger.info("Computed Fast Photo Key for Apple Photos \(item.displayName): \(actualHeadMD5):\(actualFileSize)")
				} catch {
					logger.warning("Failed to compute Fast Photo Key for Apple Photos, using fallback: \(error)")
				}
			}

			// Create catalog entry with actual Fast Photo Key
			let entry = CatalogEntry(
				photoHeadMD5: actualHeadMD5,
				fileSize: actualFileSize,
				photoMD5: photoMD5,
				photoDate: item.photoDate ?? Date(),
				format: detectedFormat
			)

			if let catalogService = catalogService {
				try await catalogService.starEntry(entry)
				logger.info("Added \(item.displayName) to catalog (starred)")

				// Create snapshot after modification
				try await catalogService.createSnapshot()
				logger.info("Created catalog snapshot after star")

				// Update local cache
				await self.catalogCache?.addToCache(md5: photoMD5)
			}

			// Upload photo to S3
			var uploadSucceeded = false
			if item.sourceType == .local {
				// Try to get URL from bookmark first
				let resolved = await MainActor.run { item.resolveURL() }
				var uploadURL: URL?
				var needsCleanup = false

				if let resolved = resolved {
					uploadURL = resolved.url
					needsCleanup = resolved.didStartAccessing
				} else if let sourceIdentifier = item.sourceIdentifier {
					// Fallback to sourceIdentifier (file path) if bookmark resolution fails
					logger.warning("Bookmark resolution failed for upload, using sourceIdentifier: \(sourceIdentifier)")
					let url = URL(fileURLWithPath: sourceIdentifier)
					if FileManager.default.isReadableFile(atPath: url.path) {
						uploadURL = url
					} else {
						logger.error("File not accessible for upload at path: \(sourceIdentifier)")
					}
				}

				if let uploadURL = uploadURL {
					defer {
						if needsCleanup {
							uploadURL.stopAccessingSecurityScopedResource()
						}
					}

					let fileData = try Data(contentsOf: uploadURL)
					try await s3Service.uploadPhoto(
						data: fileData,
						md5: photoMD5,
						format: detectedFormat,
						userID: self.userID
					)
					uploadSucceeded = true
					logger.info("Uploaded local file \(item.displayName) to S3")

					// Generate and upload thumbnail
					do {
						let thumbnailCache = ThumbnailCache.shared
						let photoMD5Obj = PhotoMD5(photoMD5)
						let thumbnailData = try await thumbnailCache.getThumbnailData(
							for: photoMD5Obj,
							sourceURL: uploadURL
						)

						try await s3Service.uploadThumbnail(
							data: thumbnailData,
							md5: photoMD5,
							userID: self.userID
						)
						logger.info("Uploaded PTM-256 thumbnail for \(item.displayName) (\(thumbnailData.count) bytes)")
					} catch {
						logger.error("Failed to generate/upload thumbnail for \(item.displayName): \(error)")
						// Don't fail the star operation if thumbnail fails
					}
				} else {
					logger.error("Could not get upload URL for \(item.displayName) - no bookmark or accessible sourceIdentifier")
				}
			} else if item.sourceType == .applePhotos && exportedAsset != nil {
				// Upload exported Apple Photos item
				let fileData = try Data(contentsOf: exportedAsset!.temporaryURL)
				try await s3Service.uploadPhoto(
					data: fileData,
					md5: photoMD5,
					format: detectedFormat,
					userID: self.userID
				)
				uploadSucceeded = true
				logger.info("Uploaded Apple Photos item \(item.displayName) to S3")

				// Generate and upload thumbnail
				do {
					let thumbnailCache = ThumbnailCache.shared
					let photoMD5Obj = PhotoMD5(photoMD5)
					let thumbnailData = try await thumbnailCache.getThumbnailData(
						for: photoMD5Obj,
						sourceURL: exportedAsset!.temporaryURL
					)

					try await s3Service.uploadThumbnail(
						data: thumbnailData,
						md5: photoMD5,
						userID: self.userID
					)
					logger.info("Uploaded PTM-256 thumbnail for \(item.displayName) (\(thumbnailData.count) bytes)")
				} catch {
					logger.error("Failed to generate/upload thumbnail for \(item.displayName): \(error)")
					// Don't fail the star operation if thumbnail fails
				}

				// Save MD5 mapping for Apple Photos items
				await MainActor.run {
					BasketActionService.shared.saveMD5Mapping(originalID: item.id, md5: photoMD5)
				}
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

			// Clean up exported Apple Photos asset
			if let exportedAsset = exportedAsset {
				await MainActor.run {
					exportedAsset.cleanup()
				}
			}

		}

		logger.info("Upload complete")

		// Upload catalog to S3 after all star operations complete
		// This ensures the cloud catalog is in sync with local catalog
		if let catalogService = catalogService {
			do {
				// Get the current catalog info (contains MD5 and path)
				if let catalogInfo = await MainActor.run(body: { catalogService.catalogInfo }) {
					// Read the CSV data from the snapshot file
					let csvData = try Data(contentsOf: catalogInfo.path)

					// userID already available from start of function

					// Upload catalog CSV to S3
					try await s3Service.uploadCatalog(csvData: csvData, catalogMD5: catalogInfo.md5, userID: userID)
					logger.info("Uploaded catalog to S3: .photolala.\(catalogInfo.md5).csv")

					// Update the catalog pointer on S3
					try await s3Service.updateCatalogPointer(catalogMD5: catalogInfo.md5, userID: userID)
					logger.info("Updated catalog pointer on S3 to: \(catalogInfo.md5)")
				} else {
					logger.warning("No catalog info available after star operation - catalog not uploaded to S3")
				}
			} catch {
				logger.error("Failed to upload catalog to S3: \(error)")
				// Don't throw - catalog upload failure shouldn't fail the star operation
				// Photos are already uploaded and local catalog is updated
			}
		}
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
	case notAuthenticated

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
		case .notAuthenticated:
			return "Please sign in to star photos to the cloud"
		}
	}
}

// MARK: - View Model

/// View model for basket actions
@MainActor
@Observable
final class BasketActionViewModel {
	// Action service
	private let service = BasketActionService.shared

	// Published state
	var isProcessing = false
	var progress: ProgressInfo?
	var error: Error?
	private var currentTask: Task<Void, Error>?

	// Progress tracking
	struct ProgressInfo {
		let action: BasketAction
		let totalCount: Int
		let processedCount: Int
		let message: String

		var percentComplete: Double {
			guard totalCount > 0 else { return 0 }
			return Double(processedCount) / Double(totalCount)
		}
	}

	// MARK: - Actions

	/// Execute a basket action
	func executeAction(_ action: BasketAction, items: [BasketItem]) async {
		// Cancel any existing task
		currentTask?.cancel()

		isProcessing = true
		error = nil
		progress = ProgressInfo(
			action: action,
			totalCount: items.count,
			processedCount: 0,
			message: "Starting \(action.rawValue)..."
		)

		currentTask = Task {
			do {
				// Execute the action through the service
				try await service.executeAction(action, items: items)

				// Clear basket after successful action (for star/unstar)
				if action == .star || action == .unstar {
					PhotoBasket.shared.clear()
				}

				// Update progress to complete
				progress = ProgressInfo(
					action: action,
					totalCount: items.count,
					processedCount: items.count,
					message: "Completed"
				)
				isProcessing = false
				progress = nil
			} catch {
				if error is CancellationError {
					// User cancelled, not an error
					self.progress = ProgressInfo(
						action: action,
						totalCount: items.count,
						processedCount: progress?.processedCount ?? 0,
						message: "Cancelled"
					)
				} else {
					self.error = error
				}
				isProcessing = false
			}
		}
	}

	/// Cancel current operation
	func cancel() {
		currentTask?.cancel()
		currentTask = nil
		isProcessing = false
	}

	enum ActionError: LocalizedError {
		case notImplemented

		var errorDescription: String? {
			switch self {
			case .notImplemented:
				return "This action is not yet implemented"
			}
		}
	}
}