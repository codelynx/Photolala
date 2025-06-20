//
//  PhotoProvider.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

import Foundation
import Combine

/// Protocol for providing photos from different sources (local directory, S3, etc.)
protocol PhotoProvider: AnyObject {
	/// The current list of photos
	var photos: [any PhotoItem] { get }
	
	/// Publisher for photo updates
	var photosPublisher: AnyPublisher<[any PhotoItem], Never> { get }
	
	/// Whether the provider is currently loading
	var isLoading: Bool { get }
	
	/// Publisher for loading state changes
	var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
	
	/// Load photos from the source
	func loadPhotos() async throws
	
	/// Refresh photos from the source
	func refresh() async throws
	
	/// Get display title for the current source
	var displayTitle: String { get }
	
	/// Get subtitle for the current source (e.g., photo count)
	var displaySubtitle: String { get }
	
	/// Whether this provider supports grouping
	var supportsGrouping: Bool { get }
	
	/// Whether this provider supports sorting
	var supportsSorting: Bool { get }
	
	/// Apply grouping option if supported
	func applyGrouping(_ option: PhotoGroupingOption) async
	
	/// Apply sorting option if supported
	func applySorting(_ option: PhotoSortOption) async
}

/// Base implementation with common functionality
@MainActor
class BasePhotoProvider: PhotoProvider, ObservableObject {
	@Published private(set) var photos: [any PhotoItem] = []
	var photosPublisher: AnyPublisher<[any PhotoItem], Never> {
		$photos.eraseToAnyPublisher()
	}
	
	@Published private(set) var isLoading: Bool = false
	var isLoadingPublisher: AnyPublisher<Bool, Never> {
		$isLoading.eraseToAnyPublisher()
	}
	
	var displayTitle: String { "Photos" }
	var displaySubtitle: String { "\(photos.count) photos" }
	
	var supportsGrouping: Bool { true }
	var supportsSorting: Bool { true }
	
	func loadPhotos() async throws {
		// Subclasses implement
		fatalError("Subclasses must implement loadPhotos()")
	}
	
	func refresh() async throws {
		try await loadPhotos()
	}
	
	func applyGrouping(_ option: PhotoGroupingOption) async {
		// Default implementation does nothing
		// Subclasses can override
	}
	
	func applySorting(_ option: PhotoSortOption) async {
		// Default implementation sorts in memory
		switch option {
		case .filename:
			photos.sort { $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending }
		case .dateAscending:
			photos.sort { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }
		case .dateDescending:
			photos.sort { ($0.creationDate ?? Date.distantFuture) > ($1.creationDate ?? Date.distantFuture) }
		}
	}
	
	// Helper method for subclasses to update photos
	func updatePhotos(_ newPhotos: [any PhotoItem]) {
		self.photos = newPhotos
	}
	
	// Helper method for subclasses to update loading state
	func setLoading(_ loading: Bool) {
		self.isLoading = loading
	}
}

/// Local directory photo provider
class LocalPhotoProvider: BasePhotoProvider {
	private let directoryPath: String
	private let photoLoader: CatalogAwarePhotoLoader
	private var loadTask: Task<Void, Never>?
	
	override var displayTitle: String { 
		(directoryPath as NSString).lastPathComponent 
	}
	
	init(directoryPath: String) {
		self.directoryPath = directoryPath
		self.photoLoader = CatalogAwarePhotoLoader()
		super.init()
	}
	
	deinit {
		loadTask?.cancel()
	}
	
	override func loadPhotos() async throws {
		setLoading(true)
		defer { setLoading(false) }
		
		// Cancel any existing load task
		loadTask?.cancel()
		
		// Start new load task
		loadTask = Task {
			do {
				let files = try await photoLoader.loadPhotos(from: URL(fileURLWithPath: directoryPath))
				guard !Task.isCancelled else { return }
				
				// Match photos with backup status BEFORE updating UI
				await BackupQueueManager.shared.matchPhotosWithBackupStatus(files)
				
				// Now update the UI with photos that have MD5 hashes computed
				updatePhotos(files)
			} catch {
				// Handle error silently as the task doesn't throw
				print("Error loading photos: \(error)")
			}
		}
		
		await loadTask?.value
	}
	
	override func refresh() async throws {
		// Reload photos (CatalogAwarePhotoLoader will handle cache invalidation internally)
		try await loadPhotos()
	}
}

/// S3 photo provider
class S3PhotoProvider: BasePhotoProvider {
	private var catalogService: PhotolalaCatalogService?
	private var s3MasterCatalog: S3MasterCatalog?
	private var syncService: S3CatalogSyncService?
	private let userId: String
	private var isOfflineMode: Bool = false
	
	override var displayTitle: String { "Cloud Photos" }
	override var displaySubtitle: String {
		if isOfflineMode {
			return "\(photos.count) photos (Offline)"
		}
		return "\(photos.count) photos"
	}
	
	init(userId: String) {
		self.userId = userId
		super.init()
	}
	
	override func loadPhotos() async throws {
		await setLoading(true)
		defer { Task { await setLoading(false) } }
		
		// Initialize sync service if needed
		if syncService == nil {
			// Get S3 client from backup manager
			guard let s3Client = await S3BackupManager.shared.getS3Client() else {
				throw NSError(domain: "S3PhotoProvider", code: 500, 
							userInfo: [NSLocalizedDescriptionKey: "S3 service not configured"])
			}
			syncService = try S3CatalogSyncService(s3Client: s3Client, userId: userId)
		}
		
		// Try to sync catalog (non-blocking)
		if let syncService = syncService {
			let synced = try await syncService.syncCatalogIfNeeded()
			isOfflineMode = !synced
		} else {
			isOfflineMode = true
		}
		
		// Load from cached catalog
		if let syncService = syncService {
			catalogService = try await syncService.loadCachedCatalog()
			s3MasterCatalog = try await syncService.loadS3MasterCatalog()
		}
		
		// Build photo list from catalog
		guard let catalog = catalogService else { 
			updatePhotos([])
			return 
		}
		
		let entries = try await catalog.loadAllEntries()
		let s3Photos = entries.map { entry in
			PhotoS3(
				from: entry,
				s3Info: s3MasterCatalog?.photos[entry.md5],
				userId: userId
			)
		}
		.sorted { $0.photoDate > $1.photoDate }
		
		updatePhotos(s3Photos)
	}
	
	override func refresh() async throws {
		guard let syncService = syncService else { 
			try await loadPhotos()
			return 
		}
		
		await setLoading(true)
		defer { Task { await setLoading(false) } }
		
		do {
			_ = try await syncService.forceSync()
			try await loadPhotos()
		} catch {
			// Continue with cached data
			isOfflineMode = true
			throw error
		}
	}
}