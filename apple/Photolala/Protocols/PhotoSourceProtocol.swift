//
//  PhotoSourceProtocol.swift
//  Photolala
//
//  Protocol for photo sources in the unified browser
//

import Foundation
import Combine

// MARK: - Photo Source Protocol

/// Protocol for any photo source (local, Apple Photos, S3, etc.)
protocol PhotoSourceProtocol: AnyObject {
	/// Load all photos from the source
	func loadPhotos() async throws -> [PhotoBrowserItem]

	/// Load metadata for a specific photo
	func loadMetadata(for itemId: String) async throws -> PhotoBrowserMetadata

	/// Load thumbnail image
	func loadThumbnail(for itemId: String) async throws -> PlatformImage?

	/// Load full-resolution image data
	func loadFullImage(for itemId: String) async throws -> Data

	/// Publisher for photo updates
	var photosPublisher: AnyPublisher<[PhotoBrowserItem], Never> { get }

	/// Publisher for loading state
	var isLoadingPublisher: AnyPublisher<Bool, Never> { get }

	/// Source capabilities
	var capabilities: PhotoSourceCapabilities { get }
}

// MARK: - Photo Source Capabilities

/// Capabilities that a photo source supports
struct PhotoSourceCapabilities {
	/// Can delete photos from source
	let canDelete: Bool

	/// Can upload new photos to source
	let canUpload: Bool

	/// Can create albums/collections
	let canCreateAlbums: Bool

	/// Can export photos
	let canExport: Bool

	/// Can modify metadata
	let canEditMetadata: Bool

	/// Supports search functionality
	let supportsSearch: Bool

	/// Default capabilities for read-only sources
	static let readOnly = PhotoSourceCapabilities(
		canDelete: false,
		canUpload: false,
		canCreateAlbums: false,
		canExport: true,
		canEditMetadata: false,
		supportsSearch: false
	)

	/// Full capabilities for writable sources
	static let full = PhotoSourceCapabilities(
		canDelete: true,
		canUpload: true,
		canCreateAlbums: true,
		canExport: true,
		canEditMetadata: true,
		supportsSearch: true
	)
}

// MARK: - Photo Browser Configuration

/// Configuration for photo browser appearance and behavior
protocol PhotoBrowserConfiguration {
	/// Size for thumbnail images
	var thumbnailSize: CGSize { get }

	/// Spacing between grid items
	var gridSpacing: CGFloat { get }

	/// Minimum number of columns
	var minimumColumns: Int { get }

	/// Maximum number of columns
	var maximumColumns: Int { get }

	/// Enable multi-selection
	var allowsMultipleSelection: Bool { get }

	/// Show file info overlay
	var showsItemInfo: Bool { get }
}

/// Default configuration implementation
struct DefaultPhotoBrowserConfiguration: PhotoBrowserConfiguration {
	let thumbnailSize = CGSize(width: 256, height: 256)
	let gridSpacing: CGFloat = 8
	let minimumColumns = 3
	let maximumColumns = 10
	let allowsMultipleSelection = true
	let showsItemInfo = false
}

// MARK: - Photo Browser Environment

/// Environment container for dependency injection
struct PhotoBrowserEnvironment {
	let source: any PhotoSourceProtocol
	let configuration: PhotoBrowserConfiguration
	let cacheManager: CacheManager?

	init(
		source: any PhotoSourceProtocol,
		configuration: PhotoBrowserConfiguration = DefaultPhotoBrowserConfiguration(),
		cacheManager: CacheManager? = nil
	) {
		self.source = source
		self.configuration = configuration
		self.cacheManager = cacheManager
	}
}