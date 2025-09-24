//
//  PhotoSourceFactory.swift
//  Photolala
//
//  Factory for creating photo sources with platform-aware behavior
//

import Foundation
import SwiftUI
import Combine

/// Protocol for creating photo sources
protocol PhotoSourceFactory {
	func makeLocalSource(url: URL?) async -> any PhotoSourceProtocol
	func makeApplePhotosSource() -> any PhotoSourceProtocol
	func makeCloudSource() async throws -> any PhotoSourceProtocol

	// Platform-specific helpers
	func getDefaultLocalURL() -> URL?
	func saveLocalSourceURL(_ url: URL)
	func getLastLocalSourceURL() -> URL?
}

/// Default implementation with platform-aware behavior
@MainActor
final class DefaultPhotoSourceFactory: PhotoSourceFactory {
	static let shared = DefaultPhotoSourceFactory()

	// UserDefaults key for storing security-scoped bookmarks
	// Used on both iOS and sandboxed macOS
	private let lastLocalSourceBookmarkKey = "lastLocalSourceBookmark"

	func makeLocalSource(url: URL? = nil) async -> any PhotoSourceProtocol {
		// Use provided URL, or last saved URL, or platform default
		let sourceURL: URL

		if let url = url {
			// Use explicitly provided URL
			sourceURL = url
			saveLocalSourceURL(url)
		} else if let lastURL = getLastLocalSourceURL() {
			// Use last successful URL
			sourceURL = lastURL
		} else if let defaultURL = getDefaultLocalURL() {
			// Use platform default
			sourceURL = defaultURL
		} else {
			// Fallback to empty source (shouldn't happen on macOS)
			#if os(macOS)
			sourceURL = FileManager.default.homeDirectoryForCurrentUser
			#else
			// On iOS, return a source that will show empty state
			return EmptyPhotoSource()
			#endif
		}

		// Both iOS and sandboxed macOS require security scope for folder access
		return LocalPhotoSource(directoryURL: sourceURL, requiresSecurityScope: true)
	}

	func makeApplePhotosSource() -> any PhotoSourceProtocol {
		return ApplePhotosSource()
	}

	func makeCloudSource() async throws -> any PhotoSourceProtocol {
		return try await S3PhotoSource()
	}

	func getDefaultLocalURL() -> URL? {
		#if os(macOS)
		// macOS: Use Pictures directory
		return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first ??
			   FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
		#else
		// iOS: No default accessible directory in sandbox
		return nil
		#endif
	}

	func saveLocalSourceURL(_ url: URL) {
		// Save security-scoped bookmark for both iOS and sandboxed macOS
		do {
			// Start accessing to create bookmark
			let didStart = url.startAccessingSecurityScopedResource()
			defer {
				if didStart {
					url.stopAccessingSecurityScopedResource()
				}
			}

			#if os(macOS)
			let bookmarkData = try url.bookmarkData(
				options: [.withSecurityScope, .minimalBookmark],
				includingResourceValuesForKeys: nil,
				relativeTo: nil
			)
			#else
			let bookmarkData = try url.bookmarkData(
				options: .minimalBookmark,
				includingResourceValuesForKeys: nil,
				relativeTo: nil
			)
			#endif
			UserDefaults.standard.set(bookmarkData, forKey: lastLocalSourceBookmarkKey)
			print("[PhotoSourceFactory] Saved security-scoped bookmark for \(url.lastPathComponent)")
		} catch {
			print("[PhotoSourceFactory] Failed to create bookmark: \(error)")
		}
	}

	func getLastLocalSourceURL() -> URL? {
		// Resolve security-scoped bookmark for both iOS and sandboxed macOS
		guard let bookmarkData = UserDefaults.standard.data(forKey: lastLocalSourceBookmarkKey) else {
			print("[PhotoSourceFactory] No saved bookmark found")
			return nil
		}

		do {
			var isStale = false
			#if os(macOS)
			let url = try URL(
				resolvingBookmarkData: bookmarkData,
				options: .withSecurityScope,
				relativeTo: nil,
				bookmarkDataIsStale: &isStale
			)
			#else
			let url = try URL(
				resolvingBookmarkData: bookmarkData,
				options: [],
				relativeTo: nil,
				bookmarkDataIsStale: &isStale
			)
			#endif

			if isStale {
				print("[PhotoSourceFactory] Bookmark is stale, attempting to refresh")
				// Try to refresh the bookmark
				saveLocalSourceURL(url)
			}

			// Verify the URL still exists
			if FileManager.default.fileExists(atPath: url.path) {
				print("[PhotoSourceFactory] Resolved bookmark to \(url.lastPathComponent)")
				return url
			} else {
				print("[PhotoSourceFactory] Bookmarked path no longer exists")
				// Clear the invalid bookmark
				UserDefaults.standard.removeObject(forKey: lastLocalSourceBookmarkKey)
			}
		} catch {
			print("[PhotoSourceFactory] Failed to resolve bookmark: \(error)")
			// Clear the invalid bookmark
			UserDefaults.standard.removeObject(forKey: lastLocalSourceBookmarkKey)
		}

		return nil
	}
}

/// Empty photo source for when no valid source is available
@MainActor
final class EmptyPhotoSource: PhotoSourceProtocol {
	func loadPhotos() async throws -> [PhotoBrowserItem] {
		return []
	}

	func loadMetadata(for itemId: String) async throws -> PhotoBrowserMetadata {
		throw PhotoSourceError.itemNotFound
	}

	func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
		return nil
	}

	func loadFullImage(for itemId: String) async throws -> Data {
		throw PhotoSourceError.itemNotFound
	}

	var photosPublisher: AnyPublisher<[PhotoBrowserItem], Never> {
		Just([]).eraseToAnyPublisher()
	}

	var isLoadingPublisher: AnyPublisher<Bool, Never> {
		Just(false).eraseToAnyPublisher()
	}

	var capabilities: PhotoSourceCapabilities {
		.readOnly
	}
}