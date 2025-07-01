//
//  TagManager.swift
//  Photolala
//
//  Created by Photolala on 2025/06/24.
//

import Foundation
import CryptoKit
import SwiftUI
import Photos

@MainActor
class TagManager: ObservableObject {
	static let shared = TagManager()
	
	// Notification name
	static let tagsChangedNotification = Notification.Name("TagsChanged")
	
	// Published properties
	@Published private(set) var tags: [String: PhotoTag] = [:]
	
	// File paths
	private var tagsURL: URL {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala")
		
		// Create directory if needed
		if !FileManager.default.fileExists(atPath: photolalaDir.path) {
			try? FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true, attributes: nil)
		}
		
		return photolalaDir.appendingPathComponent("tags.json")
	}
	
	private init() {
		loadTags()
	}
	
	// MARK: - Core API
	
	/// Toggle a specific flag for a photo
	func toggleFlag(_ flag: ColorFlag, for photo: any PhotoItem) async {
		guard let identifier = await getIdentifier(for: photo) else {
			print("[TagManager] Cannot get identifier for photo")
			return
		}
		
		if var tag = tags[identifier] {
			// Toggle the flag
			if tag.flags.contains(flag) {
				tag.flags.remove(flag)
				// Write delta operation for removal
				Task {
					try? await TagSyncManager.shared.writeDeltaOperation(
						DeltaOperation(operation: "-", photoID: identifier, tag: flag.rawValue, timestamp: Date().timeIntervalSince1970, deviceID: TagSyncManager.shared.deviceID)
					)
				}
			} else {
				tag.flags.insert(flag)
				// Write delta operation for addition
				Task {
					try? await TagSyncManager.shared.writeDeltaOperation(
						DeltaOperation(operation: "+", photoID: identifier, tag: flag.rawValue, timestamp: Date().timeIntervalSince1970, deviceID: TagSyncManager.shared.deviceID)
					)
				}
			}
			
			// Remove tag if no flags remain
			if tag.isEmpty {
				tags.removeValue(forKey: identifier)
			} else {
				tags[identifier] = tag
			}
		} else {
			// Create new tag with the flag
			let tag = PhotoTag(photoIdentifier: identifier, flags: [flag])
			tags[identifier] = tag
			// Write delta operation for addition
			Task {
				try? await TagSyncManager.shared.writeDeltaOperation(
					DeltaOperation(operation: "+", photoID: identifier, tag: flag.rawValue, timestamp: Date().timeIntervalSince1970, deviceID: TagSyncManager.shared.deviceID)
				)
			}
		}
		
		saveTags()
		
		// Post notification for UI updates
		NotificationCenter.default.post(
			name: Self.tagsChangedNotification,
			object: nil,
			userInfo: ["photoIdentifier": identifier]
		)
	}
	
	/// Clear all flags for a photo
	func clearFlags(for photo: any PhotoItem) async {
		guard let identifier = await getIdentifier(for: photo) else { return }
		
		// Get existing flags before removal for delta operations
		if let existingTag = tags[identifier] {
			// Write delta operations for each flag removal
			for flag in existingTag.flags {
				Task {
					try? await TagSyncManager.shared.writeDeltaOperation(
						DeltaOperation(operation: "-", photoID: identifier, tag: flag.rawValue, timestamp: Date().timeIntervalSince1970, deviceID: TagSyncManager.shared.deviceID)
					)
				}
			}
		}
		
		tags.removeValue(forKey: identifier)
		saveTags()
		
		// Post notification for UI updates
		NotificationCenter.default.post(
			name: Self.tagsChangedNotification,
			object: nil,
			userInfo: ["photoIdentifier": identifier]
		)
	}
	
	/// Get tag for a photo
	func getTag(for photo: any PhotoItem) async -> PhotoTag? {
		guard let identifier = await getIdentifier(for: photo) else { return nil }
		return tags[identifier]
	}
	
	/// Check if photo has any flags
	func hasFlags(_ photo: any PhotoItem) async -> Bool {
		guard let identifier = await getIdentifier(for: photo) else { return false }
		return tags[identifier] != nil
	}
	
	/// Check if photo has a specific flag
	func hasFlag(_ flag: ColorFlag, for photo: any PhotoItem) async -> Bool {
		guard let identifier = await getIdentifier(for: photo) else { return false }
		return tags[identifier]?.flags.contains(flag) ?? false
	}
	
	/// Get all photos with a specific flag
	func photosWithFlag(_ flag: ColorFlag) -> [String] {
		tags.values
			.filter { $0.flags.contains(flag) }
			.map { $0.photoIdentifier }
			.sorted()
	}
	
	/// Get count of tags by flag
	func countByFlag() -> [ColorFlag: Int] {
		var counts: [ColorFlag: Int] = [:]
		for tag in tags.values {
			for flag in tag.flags {
				counts[flag, default: 0] += 1
			}
		}
		return counts
	}
	
	/// Get total number of tagged photos
	func taggedPhotoCount() -> Int {
		tags.count
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
			
			// Generate MD5 and cache it
			let url = URL(fileURLWithPath: photoFile.filePath)
			guard let data = try? Data(contentsOf: url) else { return nil }
			let digest = Insecure.MD5.hash(data: data)
			let md5 = digest.map { String(format: "%02x", $0) }.joined()
			
			// Note: For local files, we don't cache MD5 due to unstable paths
			// The MD5 will be cached in PhotoFile's metadata instead
			return "md5#\(md5)"
		}
		
		// For Apple Photos, check if iCloud Photos is enabled
		if let applePhoto = photo as? PhotoApple {
			// Check if this photo has a cloud identifier (iCloud Photos)
			// Note: cloudIdentifier is not currently available in PHAsset API
			// For now, we'll detect iCloud by checking if the photo needs network access
			let asset = applePhoto.asset
			
			// Check if photo is in iCloud by requesting minimal data
			let isICloud = await checkIfPhotoIsInICloud(asset: asset)
			
			if isICloud {
				// Use icl# prefix for iCloud photos
				// Since cloudIdentifier is not available, we'll use localIdentifier
				// but with icl# prefix to indicate it's an iCloud photo
				return "icl#\(applePhoto.id)"
			} else {
				// Use md5# for local Apple Photos
				// This ensures consistency across devices
				
				// Build cache key with modification date
				let modUnix = Int(asset.modificationDate?.timeIntervalSince1970 ?? 0)
				let cacheKey = "\(applePhoto.id):\(modUnix)"
				
				// Check MD5 cache first
				if let cachedMD5 = await MD5CacheManager.shared.getCachedMD5(for: cacheKey) {
					return "md5#\(cachedMD5)"
				}
				
				// Compute and cache MD5
				do {
					let md5 = try await applePhoto.computeMD5Hash()
					await MD5CacheManager.shared.storeMD5(md5, for: cacheKey)
					return "md5#\(md5)"
				} catch {
					// Fallback to apl# if MD5 computation fails
					print("[TagManager] Failed to compute MD5 for Apple Photo: \(error)")
					return "apl#\(applePhoto.id)"
				}
			}
		}
		
		// For S3 photos, use MD5-based identifier
		if let s3Photo = photo as? PhotoS3 {
			return "md5#\(s3Photo.md5)"
		}
		
		return nil
	}
	
	/// Check if a PHAsset is stored in iCloud
	private func checkIfPhotoIsInICloud(asset: PHAsset) async -> Bool {
		return await withCheckedContinuation { continuation in
			let options = PHImageRequestOptions()
			options.isNetworkAccessAllowed = false
			options.deliveryMode = .fastFormat
			
			PHImageManager.default().requestImageDataAndOrientation(
				for: asset,
				options: options
			) { data, _, _, info in
				// Check if the photo is in iCloud
				let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool ?? false
				let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
				
				// If isInCloud is true or we get no data with network disabled, it's in iCloud
				continuation.resume(returning: isInCloud || (data == nil && !isDegraded))
			}
		}
	}
	
	// MARK: - Persistence
	
	/// Save tags to JSON file
	private func saveTags() {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(Array(tags.values))
			try data.write(to: tagsURL)
			print("[TagManager] Saved \(tags.count) tags")
		} catch {
			print("[TagManager] Failed to save tags: \(error)")
		}
	}
	
	/// Load tags from JSON file
	private func loadTags() {
		guard FileManager.default.fileExists(atPath: tagsURL.path) else {
			print("[TagManager] No tags file found")
			return
		}
		
		do {
			let data = try Data(contentsOf: tagsURL)
			let decoder = JSONDecoder()
			let tagArray = try decoder.decode([PhotoTag].self, from: data)
			
			// Convert array to dictionary
			tags = Dictionary(uniqueKeysWithValues: tagArray.map { ($0.photoIdentifier, $0) })
			print("[TagManager] Loaded \(tags.count) tags")
		} catch {
			print("[TagManager] Failed to load tags: \(error)")
		}
	}
	
	// MARK: - CSV Export/Import
	
	/// Export tags to CSV format
	/// Format: photoID,tags,timestamp
	/// Example: icl#SUNSET-123,1:4:5,1704067600
	func exportToCSV() -> String {
		var csvLines: [String] = []
		
		// Sort by photo identifier for consistent output
		let sortedTags = tags.values.sorted { $0.photoIdentifier < $1.photoIdentifier }
		
		for tag in sortedTags {
			let flagString = tag.sortedFlags.map { String($0.rawValue) }.joined(separator: ":")
			let timestamp = Int(Date().timeIntervalSince1970)
			let line = "\(tag.photoIdentifier),\(flagString),\(timestamp)"
			csvLines.append(line)
		}
		
		return csvLines.joined(separator: "\n")
	}
	
	/// Import tags from CSV format
	/// Format: photoID,tags,timestamp
	/// Example: icl#SUNSET-123,1:4:5,1704067600
	@discardableResult
	func importFromCSV(_ csvContent: String) -> (imported: Int, errors: Int) {
		var imported = 0
		var errors = 0
		
		let lines = csvContent.components(separatedBy: .newlines)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		
		for line in lines {
			let components = line.components(separatedBy: ",")
			guard components.count >= 2 else {
				errors += 1
				continue
			}
			
			let photoID = components[0]
			let flagString = components[1]
			
			// Parse flags
			var flags: Set<ColorFlag> = []
			if !flagString.isEmpty {
				for flagStr in flagString.components(separatedBy: ":") {
					if let flagInt = Int(flagStr),
					   let flag = ColorFlag(rawValue: flagInt) {
						flags.insert(flag)
					}
				}
			}
			
			// Create or update tag
			if !flags.isEmpty {
				let tag = PhotoTag(photoIdentifier: photoID, flags: flags)
				tags[photoID] = tag
				imported += 1
			}
		}
		
		// Save after import
		saveTags()
		
		// Post notification for UI updates
		NotificationCenter.default.post(
			name: Self.tagsChangedNotification,
			object: nil
		)
		
		print("[TagManager] CSV Import: \(imported) tags imported, \(errors) errors")
		return (imported, errors)
	}
	
	/// Save tags to CSV file in app support directory
	func saveToCSVFile() throws -> URL {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala")
		
		// Create directory if needed
		if !FileManager.default.fileExists(atPath: photolalaDir.path) {
			try FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true, attributes: nil)
		}
		
		let csvURL = photolalaDir.appendingPathComponent("tags.csv")
		let csvContent = exportToCSV()
		
		try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)
		print("[TagManager] Saved tags to CSV: \(csvURL.path)")
		
		return csvURL
	}
	
	/// Load tags from CSV file in app support directory
	func loadFromCSVFile() throws {
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let photolalaDir = appSupport.appendingPathComponent("Photolala")
		let csvURL = photolalaDir.appendingPathComponent("tags.csv")
		
		guard FileManager.default.fileExists(atPath: csvURL.path) else {
			print("[TagManager] No CSV file found at: \(csvURL.path)")
			return
		}
		
		let csvContent = try String(contentsOf: csvURL, encoding: .utf8)
		let result = importFromCSV(csvContent)
		print("[TagManager] Loaded from CSV: \(result.imported) tags, \(result.errors) errors")
	}
	
	// MARK: - iCloud Sync
	
	/// Sync tags from iCloud Documents
	func syncFromICloud() async {
		guard TagSyncManager.shared.isICloudAvailable else {
			print("[TagManager] iCloud Documents not available")
			return
		}
		
		do {
			// Read master tags from iCloud
			let iCloudTags = try await TagSyncManager.shared.readMasterTags()
			
			// Clear current tags and import from iCloud
			tags.removeAll()
			
			for entry in iCloudTags {
				var flags: Set<ColorFlag> = []
				for tagInt in entry.tags {
					if let flag = ColorFlag(rawValue: tagInt) {
						flags.insert(flag)
					}
				}
				
				if !flags.isEmpty {
					let tag = PhotoTag(photoIdentifier: entry.photoID, flags: flags)
					tags[entry.photoID] = tag
				}
			}
			
			// Save to local storage
			saveTags()
			
			// Post notification for UI updates
			NotificationCenter.default.post(
				name: Self.tagsChangedNotification,
				object: nil
			)
			
			print("[TagManager] Synced \(tags.count) tags from iCloud")
		} catch {
			print("[TagManager] Failed to sync from iCloud: \(error)")
		}
	}
	
	/// Trigger a merge of all delta files
	func triggerICloudMerge() async {
		guard TagSyncManager.shared.isICloudAvailable else {
			print("[TagManager] iCloud Documents not available")
			return
		}
		
		do {
			// Merge delta files into master
			try await TagSyncManager.shared.mergeAndUpdateMaster()
			
			// Reload from merged master
			await syncFromICloud()
			
			print("[TagManager] iCloud merge completed")
		} catch {
			print("[TagManager] Failed to merge iCloud data: \(error)")
		}
	}
	
	/// Export current tags to iCloud master file (overwrites existing)
	func exportToICloudMaster() async {
		guard TagSyncManager.shared.isICloudAvailable else {
			print("[TagManager] iCloud Documents not available")
			return
		}
		
		do {
			// Convert tags to format for sync manager
			var tagsByID: [String: Set<Int>] = [:]
			
			for (photoID, tag) in tags {
				tagsByID[photoID] = Set(tag.flags.map { $0.rawValue })
			}
			
			// Write directly to master (use with caution!)
			// This is mainly for initial setup or recovery
			try await TagSyncManager.shared.writeMasterFile(tagsByID)
			
			print("[TagManager] Exported \(tags.count) tags to iCloud master")
		} catch {
			print("[TagManager] Failed to export to iCloud: \(error)")
		}
	}
}