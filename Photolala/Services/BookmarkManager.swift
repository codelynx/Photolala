//
//  BookmarkManager.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/06/18.
//

import Foundation
#if os(macOS)
import AppKit
#endif

/// Manages security-scoped bookmarks for directory access across app launches
@MainActor
class BookmarkManager: ObservableObject {
	static let shared = BookmarkManager()
	
	private let bookmarksKey = "PhotolalaDirectoryBookmarks"
	
	private init() {}
	
	/// Save a security-scoped bookmark for a directory URL
	func saveBookmark(for url: URL) {
		#if os(macOS)
		do {
			// Create security-scoped bookmark
			let bookmarkData = try url.bookmarkData(
				options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
				includingResourceValuesForKeys: nil,
				relativeTo: nil
			)
			
			// Load existing bookmarks
			var bookmarks = loadBookmarks()
			
			// Add or update bookmark
			bookmarks[url.path] = bookmarkData
			
			// Save to UserDefaults
			UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
			
			print("[BookmarkManager] Saved bookmark for: \(url.path)")
		} catch {
			print("[BookmarkManager] Failed to create bookmark: \(error)")
		}
		#endif
	}
	
	/// Restore access to a directory using its bookmark
	func restoreAccess(to path: String) -> URL? {
		#if os(macOS)
		guard let bookmarks = UserDefaults.standard.dictionary(forKey: bookmarksKey),
			  let bookmarkData = bookmarks[path] as? Data else {
			print("[BookmarkManager] No bookmark found for: \(path)")
			return nil
		}
		
		do {
			var isStale = false
			let url = try URL(
				resolvingBookmarkData: bookmarkData,
				options: [.withSecurityScope],
				relativeTo: nil,
				bookmarkDataIsStale: &isStale
			)
			
			if isStale {
				print("[BookmarkManager] Bookmark is stale for: \(path)")
				// Try to recreate bookmark if possible
				if url.startAccessingSecurityScopedResource() {
					defer { url.stopAccessingSecurityScopedResource() }
					saveBookmark(for: url)
				}
			}
			
			// Start accessing the security-scoped resource
			if url.startAccessingSecurityScopedResource() {
				print("[BookmarkManager] Successfully restored access to: \(path)")
				return url
			} else {
				print("[BookmarkManager] Failed to start accessing: \(path)")
				return nil
			}
		} catch {
			print("[BookmarkManager] Failed to resolve bookmark: \(error)")
			return nil
		}
		#else
		return nil
		#endif
	}
	
	/// Remove a bookmark for a directory
	func removeBookmark(for path: String) {
		var bookmarks = loadBookmarks()
		bookmarks.removeValue(forKey: path)
		UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
		print("[BookmarkManager] Removed bookmark for: \(path)")
	}
	
	/// Remove all bookmarks
	func clearAllBookmarks() {
		UserDefaults.standard.removeObject(forKey: bookmarksKey)
		print("[BookmarkManager] Cleared all bookmarks")
	}
	
	/// Get all saved bookmark paths
	func getAllBookmarkPaths() -> [String] {
		return Array(loadBookmarks().keys)
	}
	
	// MARK: - Private
	
	private func loadBookmarks() -> [String: Data] {
		return UserDefaults.standard.dictionary(forKey: bookmarksKey) as? [String: Data] ?? [:]
	}
}

// MARK: - URL Extension

extension URL {
	/// Stop accessing security-scoped resource when done
	func stopAccessingSecurityScopedResourceIfNeeded() {
		#if os(macOS)
		self.stopAccessingSecurityScopedResource()
		#endif
	}
}