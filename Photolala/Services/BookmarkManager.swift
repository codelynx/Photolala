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
	
	// Published properties
	@Published private(set) var bookmarks: [String: PhotoBookmark] = [:]
	
	// Quick emoji set (11 emojis - star removed to avoid confusion with starring feature)
	static let quickEmojis = [
		"❤️", "👍", "👎",      // Rating
		"✏️", "🗑️", "📤", "🖨️",  // Actions
		"✅", "🔴", "📌", "💡"   // Status
	]
	
	// File paths
	private var localBookmarksURL: URL {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala")
		
		// Create directory if needed
		if !FileManager.default.fileExists(atPath: photolalaDir.path) {
			try? FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true, attributes: nil)
		}
		
		return photolalaDir.appendingPathComponent("bookmarks.csv")
	}
	
	private init() {
		loadFromCSV()
	}
	
	// MARK: - Core API
	
	/// Set or remove a bookmark for a photo
	func setBookmark(photo: any PhotoItem, emoji: String?) async {
		guard let md5 = await getMD5(for: photo) else {
			print("[BookmarkManager] Cannot bookmark photo without MD5")
			return
		}
		
		if let emoji = emoji {
			// Validate emoji - check it's a single emoji (may have multiple unicode scalars)
			guard !emoji.isEmpty && emoji.unicodeScalars.count <= 4 else {
				print("[BookmarkManager] Invalid emoji: \(emoji) (scalars: \(emoji.unicodeScalars.count))")
				return
			}
			
			// Add or update bookmark
			let bookmark = PhotoBookmark(md5: md5, emoji: emoji, modifiedDate: Date())
			bookmarks[md5] = bookmark
			print("[BookmarkManager] Added bookmark \(emoji) for MD5: \(md5)")
		} else {
			// Remove bookmark
			bookmarks.removeValue(forKey: md5)
			print("[BookmarkManager] Removed bookmark for MD5: \(md5)")
		}
		
		// Save changes
		saveToCSV()
	}
	
	/// Get bookmark for a photo
	func getBookmark(for photo: any PhotoItem) async -> PhotoBookmark? {
		guard let md5 = await getMD5(for: photo) else { return nil }
		return bookmarks[md5]
	}
	
	/// Check if photo is bookmarked
	func isBookmarked(_ photo: any PhotoItem) async -> Bool {
		guard let md5 = await getMD5(for: photo) else { return false }
		return bookmarks[md5] != nil
	}
	
	/// Get total bookmark count
	func bookmarksCount() -> Int {
		bookmarks.count
	}
	
	/// Get all MD5s for photos with a specific emoji
	func photosByEmoji(_ emoji: String) -> [String] {
		bookmarks.values
			.filter { $0.emoji == emoji }
			.map { $0.md5 }
			.sorted()
	}
	
	/// Get count of bookmarks by emoji
	func countByEmoji() -> [String: Int] {
		var counts: [String: Int] = [:]
		for bookmark in bookmarks.values {
			counts[bookmark.emoji, default: 0] += 1
		}
		return counts
	}
	
	// MARK: - Private Methods
	
	/// Get MD5 hash for a photo
	private func getMD5(for photo: any PhotoItem) async -> String? {
		// For directory photos, use PhotoManager's MD5
		if let photoFile = photo as? PhotoFile {
			// Try to get from cache first
			if let md5 = photoFile.md5Hash {
				return md5
			}
			
			// Generate if needed
			let url = URL(fileURLWithPath: photoFile.filePath)
			guard let data = try? Data(contentsOf: url) else { return nil }
			let digest = Insecure.MD5.hash(data: data)
			return digest.map { String(format: "%02x", $0) }.joined()
		}
		
		// For Apple Photos, use cached MD5 or generate
		if let applePhoto = photo as? PhotoApple {
			do {
				let (data, md5, _, _) = try await PhotoManager.shared.processApplePhoto(applePhoto)
				return md5
			} catch {
				// Failed to get MD5 for Apple Photo
				return nil
			}
		}
		
		// For S3 photos, use the MD5 from metadata
		if let s3Photo = photo as? PhotoS3 {
			return s3Photo.md5
		}
		
		return nil
	}
	
	// MARK: - CSV Persistence
	
	/// Save bookmarks to CSV file
	private func saveToCSV() {
		var csv = "md5,emoji,note,modifiedDate\n"
		
		// Sort by MD5 for consistent output
		for bookmark in bookmarks.values.sorted(by: { $0.md5 < $1.md5 }) {
			let note = escapeCSVField(bookmark.note)
			let timestamp = Int(bookmark.modifiedDate.timeIntervalSince1970)
			csv += "\(bookmark.md5),\(bookmark.emoji),\(note),\(timestamp)\n"
		}
		
		do {
			let url = localBookmarksURL
			try csv.write(to: url, atomically: true, encoding: .utf8)
			print("[BookmarkManager] Saved \(bookmarks.count) bookmarks to \(url.path)")
		} catch {
			print("[BookmarkManager] Failed to save bookmarks: \(error)")
		}
	}
	
	/// Load bookmarks from CSV file
	private func loadFromCSV() {
		let path = localBookmarksURL.path
		print("[BookmarkManager] Looking for bookmarks at: \(path)")
		
		guard FileManager.default.fileExists(atPath: path) else {
			print("[BookmarkManager] No bookmarks file found at \(path)")
			return
		}
		
		do {
			let csv = try String(contentsOf: localBookmarksURL, encoding: .utf8)
			print("[BookmarkManager] Read CSV content: \(csv.count) characters")
			let lines = csv.components(separatedBy: .newlines)
			print("[BookmarkManager] CSV has \(lines.count) lines")
			
			// Skip header if present
			let dataLines = if lines.first == "md5,emoji,note,modifiedDate" {
				Array(lines.dropFirst())
			} else {
				lines
			}
			print("[BookmarkManager] Processing \(dataLines.count) data lines")
			
			// Parse bookmarks
			var loadedBookmarks: [String: PhotoBookmark] = [:]
			for line in dataLines where !line.isEmpty {
				print("[BookmarkManager] Parsing line: \(line)")
				if let bookmark = PhotoBookmark(csvRow: line) {
					loadedBookmarks[bookmark.md5] = bookmark
					print("[BookmarkManager] Parsed bookmark: \(bookmark.emoji) for MD5: \(bookmark.md5)")
				} else {
					print("[BookmarkManager] Failed to parse line: \(line)")
				}
			}
			
			bookmarks = loadedBookmarks
			print("[BookmarkManager] Loaded \(bookmarks.count) bookmarks from CSV")
		} catch {
			print("[BookmarkManager] Failed to load bookmarks: \(error)")
		}
	}
	
	/// Escape CSV field if needed
	private func escapeCSVField(_ field: String?) -> String {
		guard let field = field else { return "" }
		
		// If field contains comma, newline, or quotes, wrap in quotes and escape quotes
		if field.contains(",") || field.contains("\n") || field.contains("\"") {
			let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
			return "\"\(escaped)\""
		}
		
		return field
	}
}