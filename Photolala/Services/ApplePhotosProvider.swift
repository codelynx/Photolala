//
//  ApplePhotosProvider.swift
//  Photolala
//
//  Photo provider for Apple Photos Library
//

import Foundation
import Photos
import Combine
import OSLog

/// Provides photos from Apple Photos Library
@MainActor
class ApplePhotosProvider: BasePhotoProvider {
	private var photoLibrary: PHPhotoLibrary?
	private var fetchResult: PHFetchResult<PHAsset>?
	private var currentAlbum: PHAssetCollection?
	private let cachingImageManager = PHCachingImageManager()
	private let logger = Logger(subsystem: "com.photolala", category: "ApplePhotosProvider")
	
	// MARK: - Capabilities
	
	override var capabilities: PhotoProviderCapabilities {
		[.albums, .search, .sorting, .grouping, .preview]
	}
	
	override var displayTitle: String { 
		currentAlbum?.localizedTitle ?? "All Photos" 
	}
	
	override var displaySubtitle: String {
		let count = photos.count
		if count == 1 {
			return "1 photo"
		} else {
			return "\(count) photos"
		}
	}
	
	// MARK: - Initialization
	
	override init() {
		super.init()
		setupPhotoLibrary()
	}
	
	private func setupPhotoLibrary() {
		// Check authorization status
		Task {
			await checkAndRequestAuthorization()
		}
	}
	
	func checkAndRequestAuthorization() async {
		let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
		
		switch status {
		case .authorized, .limited:
			photoLibrary = PHPhotoLibrary.shared()
			logger.info("Photos Library access authorized")
		case .notDetermined:
			logger.info("Requesting Photos Library authorization")
			let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
			if newStatus == .authorized || newStatus == .limited {
				photoLibrary = PHPhotoLibrary.shared()
				logger.info("Photos Library access granted")
			} else {
				logger.warning("Photos Library access denied")
			}
		case .denied:
			logger.warning("Photos Library access denied by user")
		case .restricted:
			logger.warning("Photos Library access restricted")
		@unknown default:
			logger.warning("Unknown Photos Library authorization status")
		}
	}
	
	// MARK: - Loading
	
	override func loadPhotos() async throws {
		guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized ||
			  PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited else {
			logger.error("Photos Library access not authorized")
			throw ApplePhotosProviderError.unauthorized
		}
		
		setLoading(true)
		defer { setLoading(false) }
		
		logger.info("Loading photos from Photos Library")
		
		// Fetch all photos if no album selected
		let fetchOptions = PHFetchOptions()
		fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
		fetchOptions.includeHiddenAssets = false
		
		if let album = currentAlbum {
			logger.info("Loading photos from album: \(album.localizedTitle ?? "Untitled")")
			fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
		} else {
			logger.info("Loading all photos")
			fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
		}
		
		// Convert to PhotoApple items
		var photos: [PhotoApple] = []
		fetchResult?.enumerateObjects { asset, _, _ in
			photos.append(PhotoApple(asset: asset))
		}
		
		logger.info("Loaded \(photos.count) photos")
		updatePhotos(photos)
		
		// Start caching thumbnails for visible range
		startCachingThumbnails()
	}
	
	override func refresh() async throws {
		logger.info("Refreshing Photos Library")
		try await loadPhotos()
	}
	
	// MARK: - Album Management
	
	func fetchAlbums() async -> [PHAssetCollection] {
		logger.info("Fetching albums")
		var albums: [PHAssetCollection] = []
		
		// Smart albums
		let smartAlbums = PHAssetCollection.fetchAssetCollections(
			with: .smartAlbum,
			subtype: .any,
			options: nil
		)
		
		// Filter smart albums we want to show
		let desiredSmartAlbumSubtypes: [PHAssetCollectionSubtype] = [
			.smartAlbumUserLibrary,
			.smartAlbumFavorites,
			.smartAlbumRecentlyAdded,
			.smartAlbumScreenshots,
			.smartAlbumSelfPortraits,
			.smartAlbumLivePhotos,
			.smartAlbumPanoramas
		]
		
		smartAlbums.enumerateObjects { collection, _, _ in
			if desiredSmartAlbumSubtypes.contains(collection.assetCollectionSubtype) {
				// Check if album has photos
				let assets = PHAsset.fetchAssets(in: collection, options: nil)
				if assets.count > 0 {
					albums.append(collection)
				}
			}
		}
		
		// User albums
		let userAlbums = PHAssetCollection.fetchAssetCollections(
			with: .album,
			subtype: .any,
			options: nil
		)
		
		userAlbums.enumerateObjects { collection, _, _ in
			// Check if album has photos
			let assets = PHAsset.fetchAssets(in: collection, options: nil)
			if assets.count > 0 {
				albums.append(collection)
			}
		}
		
		logger.info("Found \(albums.count) albums")
		return albums
	}
	
	func selectAlbum(_ album: PHAssetCollection?) async throws {
		logger.info("Selecting album: \(album?.localizedTitle ?? "All Photos")")
		currentAlbum = album
		try await loadPhotos()
	}
	
	// MARK: - Caching
	
	private func startCachingThumbnails() {
		guard let assets = fetchResult else { return }
		
		let thumbnailSize = CGSize(width: 256, height: 256)
		let options = PHImageRequestOptions()
		options.isSynchronous = false
		options.deliveryMode = .opportunistic
		
		// Cache first 100 thumbnails
		let count = min(100, assets.count)
		var assetsToCache: [PHAsset] = []
		
		for i in 0..<count {
			assetsToCache.append(assets.object(at: i))
		}
		
		logger.info("Starting to cache \(assetsToCache.count) thumbnails")
		
		cachingImageManager.startCachingImages(
			for: assetsToCache,
			targetSize: thumbnailSize,
			contentMode: .aspectFill,
			options: options
		)
	}
	
	func updateVisibleRange(_ range: Range<Int>) {
		// Update caching based on visible range
		guard let assets = fetchResult else { return }
		
		let thumbnailSize = CGSize(width: 256, height: 256)
		let options = PHImageRequestOptions()
		options.isSynchronous = false
		options.deliveryMode = .opportunistic
		
		// Stop caching all
		cachingImageManager.stopCachingImagesForAllAssets()
		
		// Cache visible range + buffer
		let buffer = 50
		let start = max(0, range.lowerBound - buffer)
		let end = min(assets.count, range.upperBound + buffer)
		
		var assetsToCache: [PHAsset] = []
		for i in start..<end {
			assetsToCache.append(assets.object(at: i))
		}
		
		logger.debug("Updating cache for range: \(start)-\(end)")
		
		cachingImageManager.startCachingImages(
			for: assetsToCache,
			targetSize: thumbnailSize,
			contentMode: .aspectFill,
			options: options
		)
	}
	
	// MARK: - Authorization Status
	
	static func authorizationStatus() -> PHAuthorizationStatus {
		PHPhotoLibrary.authorizationStatus(for: .readWrite)
	}
	
	static func isAuthorized() -> Bool {
		let status = authorizationStatus()
		return status == .authorized || status == .limited
	}
}

// MARK: - Errors

enum ApplePhotosProviderError: LocalizedError {
	case unauthorized
	case loadFailed
	
	var errorDescription: String? {
		switch self {
		case .unauthorized:
			return "Photo Library access is required to browse your photos"
		case .loadFailed:
			return "Failed to load photos from library"
		}
	}
}