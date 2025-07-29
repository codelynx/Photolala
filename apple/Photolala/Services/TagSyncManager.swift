//
//  TagSyncManager.swift
//  Photolala
//
//  Created by Photolala on 2025/06/25.
//

import Foundation
import SwiftUI

/// Manages tag synchronization across devices using iCloud Documents
@MainActor
class TagSyncManager: ObservableObject {
	static let shared = TagSyncManager()
	
	// MARK: - Properties
	
	/// Device ID for delta files
	let deviceID: String = {
		// Generate a unique device ID based on device name and model
		let deviceName = ProcessInfo.processInfo.hostName
			.replacingOccurrences(of: " ", with: "-")
			.replacingOccurrences(of: "'", with: "")
			.replacingOccurrences(of: "'", with: "")
		
		#if os(macOS)
		return "Mac-\(deviceName)"
		#elseif os(iOS)
		return UIDevice.current.userInterfaceIdiom == .pad ? "iPad-\(deviceName)" : "iPhone-\(deviceName)"
		#endif
	}()
	
	/// iCloud Documents container URL
	private var iCloudDocumentsURL: URL? {
		FileManager.default.url(forUbiquityContainerIdentifier: nil)?
			.appendingPathComponent("Documents")
	}
	
	/// Master tags file URL
	private var masterFileURL: URL? {
		iCloudDocumentsURL?.appendingPathComponent("tags.csv")
	}
	
	/// Delta file URL for this device
	private var deltaFileURL: URL? {
		iCloudDocumentsURL?.appendingPathComponent("tags-delta-\(deviceID).csv")
	}
	
	/// File coordinator for iCloud operations
	private let fileCoordinator = NSFileCoordinator(filePresenter: nil)
	
	// MARK: - Initialization
	
	private init() {
		// Ensure iCloud Documents directory exists
		if let iCloudURL = iCloudDocumentsURL {
			try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true, attributes: nil)
		}
	}
	
	// MARK: - Public Methods
	
	/// Check if iCloud Documents is available
	var isICloudAvailable: Bool {
		iCloudDocumentsURL != nil && FileManager.default.ubiquityIdentityToken != nil
	}
	
	/// Write a delta operation
	func writeDeltaOperation(_ operation: DeltaOperation) async throws {
		guard let deltaURL = deltaFileURL else {
			throw SyncError.iCloudNotAvailable
		}
		
		// Format: operation,photoID,tag,timestamp,deviceID
		let line = "\(operation.operation),\(operation.photoID),\(operation.tag),\(Int(operation.timestamp)),\(operation.deviceID)\n"
		
		var error: NSError?
		fileCoordinator.coordinate(writingItemAt: deltaURL, options: .forReplacing, error: &error) { url in
			do {
				// Append to existing file or create new
				if FileManager.default.fileExists(atPath: url.path) {
					let fileHandle = try FileHandle(forWritingTo: url)
					fileHandle.seekToEndOfFile()
					if let data = line.data(using: .utf8) {
						fileHandle.write(data)
					}
					fileHandle.closeFile()
				} else {
					try line.write(to: url, atomically: false, encoding: .utf8)
				}
			} catch {
				print("[TagSyncManager] Failed to write delta operation: \(error)")
			}
		}
		
		if let error = error {
			throw error
		}
	}
	
	/// Read master tags file
	func readMasterTags() async throws -> [TagEntry] {
		guard let masterURL = masterFileURL else {
			throw SyncError.iCloudNotAvailable
		}
		
		var tags: [TagEntry] = []
		var error: NSError?
		
		fileCoordinator.coordinate(readingItemAt: masterURL, options: .withoutChanges, error: &error) { url in
			do {
				let content = try String(contentsOf: url, encoding: .utf8)
				tags = parseMasterCSV(content)
			} catch {
				// File might not exist yet, which is fine
				print("[TagSyncManager] No master file found or read error: \(error)")
			}
		}
		
		if let error = error {
			throw error
		}
		
		return tags
	}
	
	/// Merge all delta files and update master
	func mergeAndUpdateMaster() async throws {
		guard isICloudAvailable else {
			throw SyncError.iCloudNotAvailable
		}
		
		// 1. Read current master
		let currentTags = try await readMasterTags()
		var tagsByID: [String: Set<Int>] = [:]
		
		// Convert to dictionary
		for entry in currentTags {
			tagsByID[entry.photoID] = entry.tags
		}
		
		// 2. Read all delta files
		let deltaOperations = try await readAllDeltaFiles()
		
		// 3. Apply delta operations in timestamp order
		let sortedOperations = deltaOperations.sorted { $0.timestamp < $1.timestamp }
		
		for operation in sortedOperations {
			if operation.operation == "+" {
				// Add tag
				tagsByID[operation.photoID, default: []].insert(operation.tag)
			} else if operation.operation == "-" {
				// Remove tag
				tagsByID[operation.photoID]?.remove(operation.tag)
				// Remove entry if no tags remain
				if tagsByID[operation.photoID]?.isEmpty == true {
					tagsByID.removeValue(forKey: operation.photoID)
				}
			}
		}
		
		// 4. Write new master file
		try await writeMasterFile(tagsByID)
		
		// 5. Delete delta files
		try await deleteAllDeltaFiles()
	}
	
	// MARK: - Private Methods
	
	/// Parse master CSV content
	private func parseMasterCSV(_ content: String) -> [TagEntry] {
		var entries: [TagEntry] = []
		
		let lines = content.components(separatedBy: .newlines)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		
		for line in lines {
			let components = line.components(separatedBy: ",")
			guard components.count >= 3 else { continue }
			
			let photoID = components[0]
			let tagString = components[1]
			let timestamp = TimeInterval(components[2]) ?? Date().timeIntervalSince1970
			
			// Parse tags
			var tags: Set<Int> = []
			for tagStr in tagString.components(separatedBy: ":") {
				if let tag = Int(tagStr) {
					tags.insert(tag)
				}
			}
			
			entries.append(TagEntry(photoID: photoID, tags: tags, timestamp: timestamp))
		}
		
		return entries
	}
	
	/// Read all delta files
	private func readAllDeltaFiles() async throws -> [DeltaOperation] {
		guard let iCloudURL = iCloudDocumentsURL else {
			throw SyncError.iCloudNotAvailable
		}
		
		var allOperations: [DeltaOperation] = []
		
		// List all delta files
		let files = try FileManager.default.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil)
		let deltaFiles = files.filter { $0.lastPathComponent.hasPrefix("tags-delta-") && $0.pathExtension == "csv" }
		
		for deltaURL in deltaFiles {
			var error: NSError?
			fileCoordinator.coordinate(readingItemAt: deltaURL, options: .withoutChanges, error: &error) { url in
				do {
					let content = try String(contentsOf: url, encoding: .utf8)
					let operations = parseDeltaCSV(content)
					allOperations.append(contentsOf: operations)
				} catch {
					print("[TagSyncManager] Failed to read delta file \(url.lastPathComponent): \(error)")
				}
			}
			
			if let error = error {
				print("[TagSyncManager] Coordinator error for \(deltaURL.lastPathComponent): \(error)")
			}
		}
		
		return allOperations
	}
	
	/// Parse delta CSV content
	private func parseDeltaCSV(_ content: String) -> [DeltaOperation] {
		var operations: [DeltaOperation] = []
		
		let lines = content.components(separatedBy: .newlines)
			.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
			.filter { !$0.isEmpty }
		
		for line in lines {
			let components = line.components(separatedBy: ",")
			guard components.count >= 5 else { continue }
			
			let operation = components[0]
			let photoID = components[1]
			let tag = Int(components[2]) ?? 0
			let timestamp = TimeInterval(components[3]) ?? Date().timeIntervalSince1970
			let deviceID = components[4]
			
			operations.append(DeltaOperation(
				operation: operation,
				photoID: photoID,
				tag: tag,
				timestamp: timestamp,
				deviceID: deviceID
			))
		}
		
		return operations
	}
	
	/// Write master file
	func writeMasterFile(_ tagsByID: [String: Set<Int>]) async throws {
		guard let masterURL = masterFileURL else {
			throw SyncError.iCloudNotAvailable
		}
		
		// Build CSV content
		var csvLines: [String] = []
		let timestamp = Int(Date().timeIntervalSince1970)
		
		// Sort by photo ID for consistent output
		let sortedIDs = tagsByID.keys.sorted()
		
		for photoID in sortedIDs {
			guard let tags = tagsByID[photoID], !tags.isEmpty else { continue }
			let tagString = tags.sorted().map(String.init).joined(separator: ":")
			csvLines.append("\(photoID),\(tagString),\(timestamp)")
		}
		
		let content = csvLines.joined(separator: "\n")
		
		var error: NSError?
		fileCoordinator.coordinate(writingItemAt: masterURL, options: .forReplacing, error: &error) { url in
			do {
				try content.write(to: url, atomically: true, encoding: .utf8)
				print("[TagSyncManager] Wrote master file with \(csvLines.count) entries")
			} catch {
				print("[TagSyncManager] Failed to write master file: \(error)")
			}
		}
		
		if let error = error {
			throw error
		}
	}
	
	/// Delete all delta files
	private func deleteAllDeltaFiles() async throws {
		guard let iCloudURL = iCloudDocumentsURL else {
			throw SyncError.iCloudNotAvailable
		}
		
		let files = try FileManager.default.contentsOfDirectory(at: iCloudURL, includingPropertiesForKeys: nil)
		let deltaFiles = files.filter { $0.lastPathComponent.hasPrefix("tags-delta-") && $0.pathExtension == "csv" }
		
		for deltaURL in deltaFiles {
			var error: NSError?
			fileCoordinator.coordinate(writingItemAt: deltaURL, options: .forDeleting, error: &error) { url in
				do {
					try FileManager.default.removeItem(at: url)
					print("[TagSyncManager] Deleted delta file: \(url.lastPathComponent)")
				} catch {
					print("[TagSyncManager] Failed to delete delta file: \(error)")
				}
			}
		}
	}
}

// MARK: - Supporting Types

/// Represents a tag entry in the master file
struct TagEntry {
	let photoID: String
	let tags: Set<Int>
	let timestamp: TimeInterval
}

/// Represents a delta operation
struct DeltaOperation {
	let operation: String  // "+" or "-"
	let photoID: String
	let tag: Int
	let timestamp: TimeInterval
	let deviceID: String
}

/// Sync-related errors
enum SyncError: LocalizedError {
	case iCloudNotAvailable
	
	var errorDescription: String? {
		switch self {
		case .iCloudNotAvailable:
			return "iCloud Documents is not available"
		}
	}
}