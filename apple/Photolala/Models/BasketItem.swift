//
//  BasketItem.swift
//  Photolala
//
//  Represents a photo item in the basket with source tracking
//

import Foundation

/// Represents a photo item stored in the basket
struct BasketItem: Identifiable, Hashable, Codable {
	let id: String                     // Photo ID (typically MD5)
	let displayName: String            // Display name for UI
	let sourceType: PhotoSourceType    // Where it came from
	let sourceIdentifier: String?      // Source-specific identifier (e.g., file path, S3 key)
	let sourceBookmark: Data?          // Security-scoped bookmark for iOS/macOS sandbox
	let fileSize: Int64?               // File size in bytes
	let photoDate: Date?               // Photo creation/modification date
	let addedDate: Date                // When added to basket

	init(
		id: String,
		displayName: String,
		sourceType: PhotoSourceType,
		sourceIdentifier: String? = nil,
		sourceBookmark: Data? = nil,
		fileSize: Int64? = nil,
		photoDate: Date? = nil,
		addedDate: Date = Date()
	) {
		self.id = id
		self.displayName = displayName
		self.sourceType = sourceType
		self.sourceIdentifier = sourceIdentifier
		self.sourceBookmark = sourceBookmark
		self.fileSize = fileSize
		self.photoDate = photoDate
		self.addedDate = addedDate
	}

	/// Resolve the URL from bookmark if available (for local files)
	/// Returns tuple of (url, didStartAccessing) - caller must call stopAccessingSecurityScopedResource if didStartAccessing is true
	func resolveURL() -> (url: URL, didStartAccessing: Bool)? {
		guard let bookmark = sourceBookmark else { return nil }

		do {
			var isStale = false
			// Use security scope only when in sandboxed environment
			let options: URL.BookmarkResolutionOptions = BasketItem.isSandboxed() ? .withSecurityScope : []
			let url = try URL(
				resolvingBookmarkData: bookmark,
				options: options,
				relativeTo: nil,
				bookmarkDataIsStale: &isStale
			)

			// Start accessing security-scoped resource if sandboxed
			let didStart = BasketItem.isSandboxed() ? url.startAccessingSecurityScopedResource() : false

			// Note: If stale, the basket service should refresh the bookmark
			if isStale {
				print("[BasketItem] Bookmark is stale for \(id)")
			}

			return (url, didStart)
		} catch {
			print("[BasketItem] Failed to resolve bookmark: \(error)")
			return nil
		}
	}

	/// Create a security-scoped bookmark from a URL
	static func createBookmark(from url: URL) -> Data? {
		do {
			// Use security scope only when in sandboxed environment
			let options: URL.BookmarkCreationOptions = isSandboxed() ?
				[.withSecurityScope, .minimalBookmark] : [.minimalBookmark]
			let bookmark = try url.bookmarkData(
				options: options,
				includingResourceValuesForKeys: nil,
				relativeTo: nil
			)
			return bookmark
		} catch {
			print("[BasketItem] Failed to create bookmark: \(error)")
			return nil
		}
	}

	/// Check if the app is running in a sandboxed environment
	static func isSandboxed() -> Bool {
		#if os(iOS) || os(visionOS)
		// iOS is always sandboxed
		return true
		#else
		// macOS: Check for sandbox container
		return ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
		#endif
	}
}

/// Photo source types for basket items
enum PhotoSourceType: String, Codable, CaseIterable, Sendable {
	case local = "local"
	case cloud = "cloud"
	case applePhotos = "applePhotos"

	var displayName: String {
		switch self {
		case .local: return "Local"
		case .cloud: return "Cloud"
		case .applePhotos: return "Photos"
		}
	}

	var icon: String {
		switch self {
		case .local: return "folder"
		case .cloud: return "icloud"
		case .applePhotos: return "photo.on.rectangle"
		}
	}
}

/// Protocol for converting various photo types to basket items
protocol BasketItemConvertible {
	var basketItemId: String { get }
	var basketDisplayName: String { get }
	var basketFileSize: Int64? { get }
	var basketPhotoDate: Date? { get }

	func toBasketItem(sourceType: PhotoSourceType, sourceIdentifier: String?, bookmark: Data?) -> BasketItem
}

// MARK: - PhotoBrowserItem Extension

extension PhotoBrowserItem: BasketItemConvertible {
	var basketItemId: String { id }
	var basketDisplayName: String { displayName }
	var basketFileSize: Int64? { nil } // Will be resolved via metadata
	var basketPhotoDate: Date? { nil } // Will be resolved via metadata

	func toBasketItem(sourceType: PhotoSourceType, sourceIdentifier: String? = nil, bookmark: Data? = nil) -> BasketItem {
		BasketItem(
			id: basketItemId,
			displayName: basketDisplayName,
			sourceType: sourceType,
			sourceIdentifier: sourceIdentifier,
			sourceBookmark: bookmark,
			fileSize: basketFileSize,
			photoDate: basketPhotoDate
		)
	}
}