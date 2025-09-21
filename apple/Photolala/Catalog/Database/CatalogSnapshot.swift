//
//  CatalogSnapshot.swift
//  Photolala
//
//  Immutable catalog snapshot management with MD5-named CSV files
//

import Foundation
import OSLog
import CryptoKit

/// Manages immutable catalog snapshots and pointer files
public actor CatalogSnapshot {
	private let logger = Logger(subsystem: "com.photolala", category: "CatalogSnapshot")
	private let fileManager = FileManager.default

	// Constants
	private let catalogPrefix = ".photolala"
	private let pointerFile = ".photolala.md5"
	private let catalogExtension = "csv"
	private let workingFileName = ".photolala.csv"

	// Current directory
	private let directory: URL

	// MARK: - Initialization

	public init(directory: URL) {
		self.directory = directory
	}

	// MARK: - Snapshot Operations

	/// Publish a new immutable snapshot from working CSV
	public func publishSnapshot(from sourcePath: URL) async throws -> CatalogInfo {
		// Read CSV content
		let csvContent = try String(contentsOf: sourcePath, encoding: .utf8)

		// Compute MD5 of CSV content
		let data = Data(csvContent.utf8)
		let digest = Insecure.MD5.hash(data: data)
		let catalogMD5 = digest.map { String(format: "%02hhx", $0) }.joined()

		// Create snapshot filename
		let snapshotName = "\(catalogPrefix).\(catalogMD5).\(catalogExtension)"
		let snapshotURL = directory.appendingPathComponent(snapshotName)

		logger.info("Publishing snapshot: \(snapshotName)")

		// Check if snapshot already exists
		if fileManager.fileExists(atPath: snapshotURL.path) {
			logger.info("Snapshot already exists: \(snapshotName)")

			// Count entries in existing snapshot
			let entryCount = countCSVEntries(at: snapshotURL)

			return CatalogInfo(
				md5: catalogMD5,
				path: snapshotURL,
				createdDate: getFileCreationDate(at: snapshotURL),
				fileSize: getFileSize(at: snapshotURL),
				entryCount: entryCount
			)
		}

		// Copy CSV to snapshot location
		try csvContent.write(to: snapshotURL, atomically: true, encoding: .utf8)

		// Make snapshot read-only
		try fileManager.setAttributes(
			[.posixPermissions: 0o444],
			ofItemAtPath: snapshotURL.path
		)

		// Update pointer file
		try updatePointer(to: catalogMD5)

		// Count entries
		let entryCount = countCSVEntries(at: snapshotURL)

		let info = CatalogInfo(
			md5: catalogMD5,
			path: snapshotURL,
			createdDate: Date(),
			fileSize: getFileSize(at: snapshotURL),
			entryCount: entryCount
		)

		logger.info("Created snapshot: \(snapshotName) with \(info.entryCount) entries")
		return info
	}

	/// Read the current catalog from pointer
	public func readCurrentCatalog() async throws -> CatalogInfo {
		let pointerURL = directory.appendingPathComponent(pointerFile)

		guard fileManager.fileExists(atPath: pointerURL.path) else {
			throw SnapshotError.pointerReadError
		}

		// Read MD5 from pointer file
		let md5 = try String(contentsOf: pointerURL, encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !md5.isEmpty else {
			throw SnapshotError.invalidPointer
		}

		// Find catalog file
		let catalogName = "\(catalogPrefix).\(md5).\(catalogExtension)"
		let catalogURL = directory.appendingPathComponent(catalogName)

		guard fileManager.fileExists(atPath: catalogURL.path) else {
			throw SnapshotError.catalogNotFound
		}

		// Count entries
		let entryCount = countCSVEntries(at: catalogURL)

		return CatalogInfo(
			md5: md5,
			path: catalogURL,
			createdDate: getFileCreationDate(at: catalogURL),
			fileSize: getFileSize(at: catalogURL),
			entryCount: entryCount
		)
	}

	/// List all available catalog snapshots
	public func listSnapshots() async throws -> [CatalogInfo] {
		let contents = try fileManager.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
			options: [.skipsHiddenFiles]
		)

		var snapshots: [CatalogInfo] = []

		for url in contents {
			let filename = url.lastPathComponent

			// Check if it matches catalog pattern
			if filename.hasPrefix(catalogPrefix) && url.pathExtension == catalogExtension {
				// Extract MD5 from filename
				let components = filename.split(separator: ".")
				if components.count == 3 {
					let md5 = String(components[1])

					// Count entries
					let entryCount = countCSVEntries(at: url)

					let info = CatalogInfo(
						md5: md5,
						path: url,
						createdDate: getFileCreationDate(at: url),
						fileSize: getFileSize(at: url),
						entryCount: entryCount
					)

					snapshots.append(info)
				}
			}
		}

		return snapshots.sorted { $0.createdDate > $1.createdDate }
	}

	/// Open a catalog database from snapshot
	public func openCatalog(md5: String) async throws -> CatalogDatabase {
		let catalogName = "\(catalogPrefix).\(md5).\(catalogExtension)"
		let catalogURL = directory.appendingPathComponent(catalogName)

		guard fileManager.fileExists(atPath: catalogURL.path) else {
			throw SnapshotError.catalogNotFound
		}

		// Open database in read-only mode
		let database = try await CatalogDatabase(path: catalogURL, readOnly: true)
		return database
	}

	/// Open a snapshot (alias for compatibility)
	public func openSnapshot(md5: String) async throws -> CatalogDatabase {
		return try await openCatalog(md5: md5)
	}

	/// Create a snapshot from working database
	public func createSnapshot(from database: CatalogDatabase) async throws -> CatalogInfo {
		// Save current CSV as a new snapshot
		let workingPath = await database.csvPath

		// Read the working CSV content
		guard let csvContent = try? String(contentsOf: workingPath, encoding: .utf8) else {
			throw SnapshotError.databaseNotFound(workingPath)
		}

		// Calculate MD5 of the CSV content
		let data = Data(csvContent.utf8)
		let digest = Insecure.MD5.hash(data: data)
		let catalogMD5 = digest.map { String(format: "%02hhx", $0) }.joined()

		// Create snapshot filename
		let snapshotName = "\(catalogPrefix).\(catalogMD5).\(catalogExtension)"
		let snapshotURL = directory.appendingPathComponent(snapshotName)

		// Check if snapshot already exists
		if fileManager.fileExists(atPath: snapshotURL.path) {
			logger.info("Snapshot already exists: \(snapshotName)")
			let entryCount = countCSVEntries(at: snapshotURL)

			return CatalogInfo(
				md5: catalogMD5,
				path: snapshotURL,
				createdDate: getFileCreationDate(at: snapshotURL),
				fileSize: getFileSize(at: snapshotURL),
				entryCount: entryCount
			)
		}

		// Copy CSV to snapshot location
		try csvContent.write(to: snapshotURL, atomically: true, encoding: .utf8)

		// Make snapshot read-only
		try fileManager.setAttributes(
			[.posixPermissions: 0o444],
			ofItemAtPath: snapshotURL.path
		)

		// Update pointer file
		try updatePointer(to: catalogMD5)

		// Count entries
		let entryCount = countCSVEntries(at: snapshotURL)

		let info = CatalogInfo(
			md5: catalogMD5,
			path: snapshotURL,
			createdDate: Date(),
			fileSize: getFileSize(at: snapshotURL),
			entryCount: entryCount
		)

		logger.info("Created snapshot: \(snapshotName) with \(info.entryCount) entries")
		return info
	}

	/// Prune old snapshots, keeping the most recent N
	public func pruneSnapshots(keepCount: Int) async throws -> Int {
		guard keepCount > 0 else {
			throw SnapshotError.invalidPruneCount
		}

		let snapshots = try await listSnapshots()

		// Keep the most recent snapshots
		let snapshotsToDelete = snapshots.dropFirst(keepCount)

		var deletedCount = 0
		for snapshot in snapshotsToDelete {
			// Don't delete the currently pointed snapshot
			if let current = try? await readCurrentCatalog(), current.md5 == snapshot.md5 {
				logger.warning("Skipping deletion of current snapshot: \(snapshot.md5)")
				continue
			}

			do {
				try fileManager.removeItem(at: snapshot.path)
				deletedCount += 1
				logger.info("Deleted old snapshot: \(snapshot.path.lastPathComponent)")
			} catch {
				logger.error("Failed to delete snapshot: \(error)")
			}
		}

		logger.info("Pruned \(deletedCount) old snapshots")
		return deletedCount
	}

	/// Update the pointer file with new MD5
	private func updatePointer(to md5: String) throws {
		let pointerURL = directory.appendingPathComponent(pointerFile)

		// Write MD5 to pointer file
		try md5.write(to: pointerURL, atomically: true, encoding: .utf8)

		logger.info("Updated pointer to: \(md5)")
	}

	/// Validate a snapshot's MD5
	public func validateSnapshot(at url: URL, expectedMD5: String) throws -> Bool {
		guard fileManager.fileExists(atPath: url.path) else {
			throw SnapshotError.databaseNotFound(url)
		}

		let csvContent = try String(contentsOf: url, encoding: .utf8)
		let data = Data(csvContent.utf8)
		let digest = Insecure.MD5.hash(data: data)
		let actualMD5 = digest.map { String(format: "%02hhx", $0) }.joined()

		if actualMD5 != expectedMD5 {
			logger.error("Catalog checksum mismatch for \(url.lastPathComponent). Expected \(expectedMD5), got \(actualMD5)")
			return false
		}

		return true
	}

	/// Copy working CSV to create a new database
	public func copyWorkingDatabase(from source: URL, to destination: URL) async throws {
		// For CSV, just copy the file
		if fileManager.fileExists(atPath: destination.path) {
			try fileManager.removeItem(at: destination)
		}

		try fileManager.copyItem(at: source, to: destination)
		logger.info("Copied working CSV from \(source.lastPathComponent) to \(destination.lastPathComponent)")
	}

	// MARK: - Helper Methods

	private func countCSVEntries(at url: URL) -> Int {
		guard let content = try? String(contentsOf: url, encoding: .utf8) else {
			return 0
		}

		let lines = content.components(separatedBy: .newlines)
		// Subtract 1 for header, and don't count empty lines
		let dataLines = lines.dropFirst().filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
		return dataLines.count
	}

	private func getFileSize(at path: URL) -> Int64 {
		do {
			let attributes = try fileManager.attributesOfItem(atPath: path.path)
			return attributes[.size] as? Int64 ?? 0
		} catch {
			return 0
		}
	}

	private func getFileCreationDate(at path: URL) -> Date {
		do {
			let attributes = try fileManager.attributesOfItem(atPath: path.path)
			return attributes[.creationDate] as? Date ?? Date()
		} catch {
			return Date()
		}
	}

	private func removeIfExists(_ path: String) throws {
		if fileManager.fileExists(atPath: path) {
			try fileManager.removeItem(atPath: path)
		}
	}
}

// MARK: - Supporting Types

/// Information about a catalog snapshot
public struct CatalogInfo: Sendable {
	public let md5: String
	public let path: URL
	public let createdDate: Date
	public let fileSize: Int64
	public let entryCount: Int

	nonisolated public init(md5: String, path: URL, createdDate: Date, fileSize: Int64, entryCount: Int) {
		self.md5 = md5
		self.path = path
		self.createdDate = createdDate
		self.fileSize = fileSize
		self.entryCount = entryCount
	}
}

/// Catalog statistics
public struct CatalogStatistics: Sendable {
	public let totalEntries: Int
	public let entriesWithFullMD5: Int
	public let totalFileSize: Int64
	public let lastUpdated: Date
}

/// Snapshot-related errors
public enum SnapshotError: LocalizedError {
	case invalidDirectory
	case databaseNotFound(URL)
	case databaseError(String)
	case hashMismatch(expected: String, actual: String)
	case pointerReadError
	case pointerWriteError
	case invalidPointer
	case catalogNotFound
	case invalidPruneCount

	public var errorDescription: String? {
		switch self {
		case .invalidDirectory:
			return "Invalid directory for snapshot operations"
		case .databaseNotFound(let url):
			return "Database not found at \(url.path)"
		case .databaseError(let message):
			return "Database error: \(message)"
		case .hashMismatch(let expected, let actual):
			return "Hash mismatch: expected \(expected), got \(actual)"
		case .pointerReadError:
			return "Failed to read pointer file"
		case .pointerWriteError:
			return "Failed to write pointer file"
		case .invalidPointer:
			return "Invalid pointer file content"
		case .catalogNotFound:
			return "Catalog snapshot not found"
		case .invalidPruneCount:
			return "Invalid prune count specified"
		}
	}
}