//
//  PhotoProvider.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

import Foundation
import Combine

/// Capabilities that a photo provider can support
struct PhotoProviderCapabilities: OptionSet {
	let rawValue: Int
	
	static let hierarchicalNavigation = PhotoProviderCapabilities(rawValue: 1 << 0)
	static let backup = PhotoProviderCapabilities(rawValue: 1 << 1)
	static let download = PhotoProviderCapabilities(rawValue: 1 << 2)
	static let delete = PhotoProviderCapabilities(rawValue: 1 << 3)
	static let albums = PhotoProviderCapabilities(rawValue: 1 << 4)
	static let search = PhotoProviderCapabilities(rawValue: 1 << 5)
	static let sorting = PhotoProviderCapabilities(rawValue: 1 << 6)
	static let grouping = PhotoProviderCapabilities(rawValue: 1 << 7)
	static let preview = PhotoProviderCapabilities(rawValue: 1 << 8)
	static let star = PhotoProviderCapabilities(rawValue: 1 << 9)
}

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
	
	/// Get the capabilities of this provider
	var capabilities: PhotoProviderCapabilities { get }
	
	/// Progress tracking for loading operations
	var loadingProgress: Double { get }
	var loadingStatusText: String { get }
}

// MARK: - Default implementations

extension PhotoProvider {
	/// Default capabilities based on boolean flags
	var capabilities: PhotoProviderCapabilities {
		var caps: PhotoProviderCapabilities = []
		if supportsGrouping { caps.insert(.grouping) }
		if supportsSorting { caps.insert(.sorting) }
		return caps
	}
	
	/// Default loading progress
	var loadingProgress: Double { 0.0 }
	
	/// Default loading status
	var loadingStatusText: String { "Loading..." }
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
	
	// Default capabilities implementation
	var capabilities: PhotoProviderCapabilities {
		var caps: PhotoProviderCapabilities = []
		if supportsGrouping { caps.insert(.grouping) }
		if supportsSorting { caps.insert(.sorting) }
		return caps
	}
	
	var loadingProgress: Double { 0.0 }
	var loadingStatusText: String { "Loading..." }
	
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

/// S3 photo provider
class S3PhotoProvider: BasePhotoProvider {
	private var catalogService: PhotolalaCatalogServiceV2?
	private var s3MasterCatalog: S3MasterCatalog?
	private var syncService: S3CatalogSyncServiceV2?
	private let userId: String
	private var isOfflineMode: Bool = false
	private var cancellables = Set<AnyCancellable>()
	
	// Sync state exposed for UI
	@Published var isSyncing: Bool = false
	@Published var syncProgress: Double = 0.0
	@Published var syncStatusText: String = ""
	@Published var lastSyncDate: Date?
	@Published var lastSyncError: Error?
	
	// MARK: - Capabilities
	
	override var capabilities: PhotoProviderCapabilities {
		[.download, .search]
	}
	
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
		setLoading(true)
		defer { setLoading(false) }
		
		print("[S3PhotoProvider] Loading photos for user: \(userId)")
		
		// Initialize sync service if needed
		if syncService == nil {
			// Get S3 client from backup manager
			guard let s3Client = await S3BackupManager.shared.getS3Client() else {
				throw NSError(domain: "S3PhotoProvider", code: 500, 
							userInfo: [NSLocalizedDescriptionKey: "S3 service not configured"])
			}
			
			print("[S3PhotoProvider] Creating S3CatalogSyncServiceV2 with userId: \(userId)")
			
			do {
				let service = try S3CatalogSyncServiceV2(s3Client: s3Client, userId: userId)
				syncService = service
				
				// Create catalog service
				catalogService = try PhotolalaCatalogServiceV2()
				
				// Observe sync service state
				service.$isSyncing.sink { [weak self] in self?.isSyncing = $0 }.store(in: &cancellables)
				service.$syncProgress.sink { [weak self] in self?.syncProgress = $0 }.store(in: &cancellables)
				service.$syncStatusText.sink { [weak self] in self?.syncStatusText = $0 }.store(in: &cancellables)
				service.$lastSyncDate.sink { [weak self] in self?.lastSyncDate = $0 }.store(in: &cancellables)
				service.$lastError.sink { [weak self] in self?.lastSyncError = $0 }.store(in: &cancellables)
				
				print("[S3PhotoProvider] S3CatalogSyncServiceV2 created successfully")
			} catch {
				print("[S3PhotoProvider] Failed to create services: \(error)")
				throw error
			}
		}
		
		// Try to sync catalog (non-blocking)
		if let syncService = syncService, let catalogService = catalogService {
			do {
				// Load or create catalog for this user
				let catalogURL = URL(fileURLWithPath: "/s3/\(userId)")
				// Use the typed method directly
				let catalog = try await catalogService.loadPhotoCatalog(for: catalogURL)
				
				// Sync with S3
				try await syncService.syncWithS3(catalog: catalog, userId: userId)
				isOfflineMode = false
			} catch {
				print("[S3PhotoProvider] Sync failed, continuing with cached data: \(error)")
				isOfflineMode = true
			}
		} else {
			isOfflineMode = true
		}
		
		// Build photo list from catalog
		guard let catalogService = catalogService else { 
			print("[S3PhotoProvider] No catalog service available")
			updatePhotos([])
			return 
		}
		
		// Load catalog for this user
		let catalogURL = URL(fileURLWithPath: "/s3/\(userId)")
		// Use the typed method directly
		guard let catalog = try? await catalogService.loadPhotoCatalog(for: catalogURL) else {
			print("[S3PhotoProvider] No catalog found for user")
			updatePhotos([])
			return
		}
		
		print("[S3PhotoProvider] Loading catalog entries...")
		let entries = try await catalogService.loadAllEntries(from: catalog)
		print("[S3PhotoProvider] Loaded \(entries.count) entries from catalog")
		
		let s3Photos = entries.map { entry in
			PhotoS3(
				from: entry,
				s3Info: s3MasterCatalog?.photos[entry.md5],
				userId: userId
			)
		}
		.sorted { $0.photoDate > $1.photoDate }
		
		print("[S3PhotoProvider] Created \(s3Photos.count) S3 photos")
		updatePhotos(s3Photos)
		print("[S3PhotoProvider] Photos updated successfully")
		
		// Populate backup status for Apple Photos
		await populateBackupStatusForApplePhotos()
	}
	
	private func populateBackupStatusForApplePhotos() async {
		// Mark all S3 photos that have an Apple Photo ID as uploaded
		let s3Photos = photos.compactMap { $0 as? PhotoS3 }
		
		for photo in s3Photos {
			if let applePhotoID = photo.applePhotoID, !applePhotoID.isEmpty {
				// Store the mapping in ApplePhotosBridge
				await ApplePhotosBridge.shared.storeMD5(photo.md5, for: applePhotoID)
				
				// Mark as uploaded in BackupQueueManager
				await MainActor.run {
					BackupQueueManager.shared.backupStatus[photo.md5] = .uploaded
				}
			}
		}
		
		let applePhotoCount = s3Photos.filter { $0.applePhotoID != nil }.count
		if applePhotoCount > 0 {
			print("[S3PhotoProvider] Populated backup status for \(applePhotoCount) Apple Photos")
		}
	}
	
	override func refresh() async throws {
		guard let syncService = syncService else { 
			try await loadPhotos()
			return 
		}
		
		setLoading(true)
		defer { setLoading(false) }
		
		do {
			if let catalogService = catalogService {
				// Load or create catalog for this user
				let catalogURL = URL(fileURLWithPath: "/s3/\(userId)")
				// Use the typed method directly
				let catalog = try await catalogService.loadPhotoCatalog(for: catalogURL)
				
				// Force sync with S3
				try await syncService.syncWithS3(catalog: catalog, userId: userId)
			}
			try await loadPhotos()
		} catch {
			// Continue with cached data
			isOfflineMode = true
			throw error
		}
	}
}