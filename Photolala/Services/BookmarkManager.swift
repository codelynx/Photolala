//
//  BookmarkManager.swift
//  Photolala
//
//  Created by Photolala on 2025/06/24.
//

import Foundation
import CryptoKit
import SwiftUI

@MainActor
class BookmarkManager: ObservableObject {
	static let shared = BookmarkManager()
	
	// Notification name
	static let bookmarksChangedNotification = Notification.Name("BookmarksChanged")
	
	// Published properties
	@Published private(set) var bookmarks: [String: PhotoBookmark] = [:]
	
	// File paths
	private var bookmarksURL: URL {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala")
		
		// Create directory if needed
		if !FileManager.default.fileExists(atPath: photolalaDir.path) {
			try? FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true, attributes: nil)
		}
		
		return photolalaDir.appendingPathComponent("bookmarks.json")
	}
	
	private init() {
		loadBookmarks()
	}
	
	// MARK: - Core API
	
	/// Toggle a specific flag for a photo
	func toggleFlag(_ flag: ColorFlag, for photo: any PhotoItem) async {
		guard let identifier = await getIdentifier(for: photo) else {
			print("[BookmarkManager] Cannot get identifier for photo")
			return
		}
		
		if var bookmark = bookmarks[identifier] {
			// Toggle the flag
			if bookmark.flags.contains(flag) {
				bookmark.flags.remove(flag)
			} else {
				bookmark.flags.insert(flag)
			}
			
			// Remove bookmark if no flags remain
			if bookmark.isEmpty {
				bookmarks.removeValue(forKey: identifier)
			} else {
				bookmarks[identifier] = bookmark
			}
		} else {
			// Create new bookmark with the flag
			let bookmark = PhotoBookmark(photoIdentifier: identifier, flags: [flag])
			bookmarks[identifier] = bookmark
		}
		
		saveBookmarks()
		
		// Post notification for UI updates
		NotificationCenter.default.post(
			name: Self.bookmarksChangedNotification,
			object: nil,
			userInfo: ["photoIdentifier": identifier]
		)
	}
	
	/// Clear all flags for a photo
	func clearFlags(for photo: any PhotoItem) async {
		guard let identifier = await getIdentifier(for: photo) else { return }
		bookmarks.removeValue(forKey: identifier)
		saveBookmarks()
		
		// Post notification for UI updates
		NotificationCenter.default.post(
			name: Self.bookmarksChangedNotification,
			object: nil,
			userInfo: ["photoIdentifier": identifier]
		)
	}
	
	/// Get bookmark for a photo
	func getBookmark(for photo: any PhotoItem) async -> PhotoBookmark? {
		guard let identifier = await getIdentifier(for: photo) else { return nil }
		return bookmarks[identifier]
	}
	
	/// Check if photo has any flags
	func hasFlags(_ photo: any PhotoItem) async -> Bool {
		guard let identifier = await getIdentifier(for: photo) else { return false }
		return bookmarks[identifier] != nil
	}
	
	/// Check if photo has a specific flag
	func hasFlag(_ flag: ColorFlag, for photo: any PhotoItem) async -> Bool {
		guard let identifier = await getIdentifier(for: photo) else { return false }
		return bookmarks[identifier]?.flags.contains(flag) ?? false
	}
	
	/// Get all photos with a specific flag
	func photosWithFlag(_ flag: ColorFlag) -> [String] {
		bookmarks.values
			.filter { $0.flags.contains(flag) }
			.map { $0.photoIdentifier }
			.sorted()
	}
	
	/// Get count of bookmarks by flag
	func countByFlag() -> [ColorFlag: Int] {
		var counts: [ColorFlag: Int] = [:]
		for bookmark in bookmarks.values {
			for flag in bookmark.flags {
				counts[flag, default: 0] += 1
			}
		}
		return counts
	}
	
	/// Get total number of bookmarked photos
	func bookmarkedPhotoCount() -> Int {
		bookmarks.count
	}
	
	// MARK: - Private Methods
	
	/// Get identifier for a photo
	private func getIdentifier(for photo: any PhotoItem) async -> String? {
		// For directory photos, use MD5-based identifier
		if let photoFile = photo as? PhotoFile {
			// Try to get from cache first
			if let md5 = photoFile.md5Hash {
				return "md5#\(md5)"
			}
			
			// Generate if needed
			let url = URL(fileURLWithPath: photoFile.filePath)
			guard let data = try? Data(contentsOf: url) else { return nil }
			let digest = Insecure.MD5.hash(data: data)
			let md5 = digest.map { String(format: "%02x", $0) }.joined()
			return "md5#\(md5)"
		}
		
		// For Apple Photos, use Apple Photo Library identifier
		if let applePhoto = photo as? PhotoApple {
			return "apl#\(applePhoto.id)"
		}
		
		// For S3 photos, use MD5-based identifier
		if let s3Photo = photo as? PhotoS3 {
			return "md5#\(s3Photo.md5)"
		}
		
		return nil
	}
	
	// MARK: - Persistence
	
	/// Save bookmarks to JSON file
	private func saveBookmarks() {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(Array(bookmarks.values))
			try data.write(to: bookmarksURL)
			print("[BookmarkManager] Saved \(bookmarks.count) bookmarks")
		} catch {
			print("[BookmarkManager] Failed to save bookmarks: \(error)")
		}
	}
	
	/// Load bookmarks from JSON file
	private func loadBookmarks() {
		guard FileManager.default.fileExists(atPath: bookmarksURL.path) else {
			print("[BookmarkManager] No bookmarks file found")
			return
		}
		
		do {
			let data = try Data(contentsOf: bookmarksURL)
			let decoder = JSONDecoder()
			let bookmarkArray = try decoder.decode([PhotoBookmark].self, from: data)
			
			// Convert array to dictionary
			bookmarks = Dictionary(uniqueKeysWithValues: bookmarkArray.map { ($0.photoIdentifier, $0) })
			print("[BookmarkManager] Loaded \(bookmarks.count) bookmarks")
		} catch {
			print("[BookmarkManager] Failed to load bookmarks: \(error)")
		}
	}
}