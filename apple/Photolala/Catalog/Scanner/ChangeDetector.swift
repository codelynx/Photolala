//
//  ChangeDetector.swift
//  Photolala
//
//  Incremental change detection for catalog updates
//

import Foundation
import OSLog
import Combine

/// Detects changes between current file system and catalog
public actor ChangeDetector {
	private let logger = Logger(subsystem: "com.photolala", category: "ChangeDetector")
	
	// Dependencies
	private let database: CatalogDatabase
	private let scanner: DirectoryScanner
	private let pipeline: DigestPipeline
	
	// Progress tracking
	private var isDetecting = false
	private let changeSubject = PassthroughSubject<DetectedChanges, Never>()
	public var changePublisher: AnyPublisher<DetectedChanges, Never> {
		changeSubject.eraseToAnyPublisher()
	}
	
	// MARK: - Initialization
	
	public init(
		database: CatalogDatabase,
		scanner: DirectoryScanner? = nil,
		pipeline: DigestPipeline? = nil
	) {
		self.database = database
		self.scanner = scanner ?? DirectoryScanner()
		self.pipeline = pipeline ?? DigestPipeline(database: database)
	}
	
	// MARK: - Change Detection
	
	/// Detect all changes in a directory
	public func detectChanges(in directory: URL) async throws -> DetectedChanges {
		guard !isDetecting else {
			throw ChangeDetectorError.alreadyDetecting
		}
		
		isDetecting = true
		defer { isDetecting = false }
		
		logger.info("Starting change detection in: \(directory.path)")
		let startTime = Date()
		
		// Get current catalog entries
		let catalogEntries = try await database.getEntries(directory: directory)
		let catalogMap = Dictionary(
			uniqueKeysWithValues: catalogEntries.map { ($0.id.fastKey.stringValue, $0) }
		)

		logger.debug("Found \(catalogEntries.count) entries in catalog")

		// Scan current file system
		let currentFiles = try await scanner.scanDirectory(directory)
		logger.debug("Found \(currentFiles.count) files on disk")

		var added: [DiscoveredFile] = []
		var modified: [ModifiedFile] = []
		var unchanged: [FastPhotoKey] = []
		var removed: [RemovedFile] = []

		// Build lookup for current files
		let currentFilesMap = Dictionary(
			uniqueKeysWithValues: currentFiles.map { ($0.fastKey.stringValue, $0) }
		)

		// Check each current file
		for file in currentFiles {
			if let catalogEntry = catalogMap[file.fastKey.stringValue] {
				// File exists in catalog - check if modified
				if file.modifiedDate > catalogEntry.modifiedDate ||
				   file.url.path != catalogEntry.path.path {
					// File has been modified or moved
					modified.append(ModifiedFile(
						file: file,
						oldEntry: catalogEntry,
						changeType: file.url.path != catalogEntry.path.path ? .moved : .contentChanged
					))
				} else {
					// File unchanged
					unchanged.append(file.fastKey)
				}
			} else {
				// New file
				added.append(file)
			}
		}
		
		// Check for removed files
		for (fastKeyString, entry) in catalogMap {
			if currentFilesMap[fastKeyString] == nil {
				removed.append(RemovedFile(
					fastKey: entry.id.fastKey,
					photoMD5: entry.id.fullMD5,
					originalPath: entry.path
				))
			}
		}
		
		let duration = Date().timeIntervalSince(startTime)
		logger.info("""
			Change detection completed in \(String(format: "%.2f", duration))s:
			Added: \(added.count), Modified: \(modified.count), \
			Unchanged: \(unchanged.count), Removed: \(removed.count)
			""")
		
		let changes = DetectedChanges(
			directory: directory,
			added: added,
			modified: modified,
			unchanged: unchanged,
			removed: removed,
			detectedAt: Date()
		)
		
		// Publish changes
		changeSubject.send(changes)
		
		return changes
	}
	
	/// Apply detected changes to catalog
	public func applyChanges(_ changes: DetectedChanges) async throws {
		logger.info("Applying \(changes.totalChanges) changes to catalog")
		let startTime = Date()
		
		// Process new files
		if !changes.added.isEmpty {
			logger.info("Processing \(changes.added.count) new files")
			try await pipeline.processFiles(changes.added)
		}
		
		// Process modified files
		if !changes.modified.isEmpty {
			logger.info("Processing \(changes.modified.count) modified files")
			let modifiedDiscoveredFiles = changes.modified.map { $0.file }
			try await pipeline.processFiles(modifiedDiscoveredFiles)
		}
		
		// Mark removed files as deleted
		if !changes.removed.isEmpty {
			logger.info("Removing \(changes.removed.count) files from catalog")
			for removed in changes.removed {
				// Remove entry from CSV catalog
				try await database.removeEntry(fastKey: removed.fastKey.stringValue)
			}
		}
		
		let duration = Date().timeIntervalSince(startTime)
		logger.info("Changes applied in \(String(format: "%.2f", duration))s")
	}
	
	/// Quick check if directory has changes
	public func hasChanges(in directory: URL) async throws -> Bool {
		let changes = try await detectChanges(in: directory)
		return changes.hasChanges
	}
	
	// MARK: - Incremental Updates
	
	/// Process only files that changed since a specific date
	public func processChangesSince(
		date: Date,
		in directory: URL
	) async throws -> IncrementalUpdate {
		logger.info("Processing changes since \(date)")
		
		// Scan directory
		let allFiles = try await scanner.scanDirectory(directory)
		
		// Filter files modified after date
		let changedFiles = allFiles.filter { $0.modifiedDate > date }
		
		if changedFiles.isEmpty {
			logger.info("No changes found since \(date)")
			return IncrementalUpdate(
				processedFiles: [],
				sinceDate: date,
				processedAt: Date()
			)
		}
		
		logger.info("Found \(changedFiles.count) files changed since \(date)")
		
		// Process changed files
		try await pipeline.processFiles(changedFiles)
		
		return IncrementalUpdate(
			processedFiles: changedFiles.map { $0.fastKey },
			sinceDate: date,
			processedAt: Date()
		)
	}
	
	// MARK: - Smart Detection
	
	/// Detect potential duplicates based on file size and partial content
	public func detectPotentialDuplicates(
		in directory: URL
	) async throws -> [DuplicateGroup] {
		logger.info("Detecting potential duplicates in: \(directory.path)")
		
		let entries = try await database.getEntries(directory: directory)
		
		// Group by file size first
		var sizeGroups: [Int64: [PhotoEntry]] = [:]
		for entry in entries {
			sizeGroups[entry.fileSize, default: []].append(entry)
		}
		
		// Find groups with multiple files of same size
		var duplicateGroups: [DuplicateGroup] = []
		
		for (size, group) in sizeGroups where group.count > 1 {
			// Group by fast key (head MD5) using string keys
			var fastKeyGroups: [String: [PhotoEntry]] = [:]
			for entry in group {
				fastKeyGroups[entry.id.fastKey.stringValue, default: []].append(entry)
			}

			// Create duplicate groups for files with same fast key
			for (fastKeyString, entries) in fastKeyGroups where entries.count > 1 {
				let fastKey = entries.first!.id.fastKey  // Use the fastKey from an entry
				let duplicateGroup = DuplicateGroup(
					fastKey: fastKey,
					fileSize: size,
					entries: entries,
					confidenceLevel: entries.allSatisfy { $0.id.hasFullMD5 } ? .high : .medium
				)
				duplicateGroups.append(duplicateGroup)
			}
		}
		
		logger.info("Found \(duplicateGroups.count) potential duplicate groups")
		return duplicateGroups
	}
	
	/// Verify duplicates by computing full MD5
	public func verifyDuplicates(
		_ group: DuplicateGroup
	) async throws -> VerifiedDuplicateGroup {
		logger.info("Verifying duplicate group with \(group.entries.count) files")
		
		var verifiedEntries: [(PhotoEntry, PhotoMD5)] = []
		
		for entry in group.entries {
			if let fullMD5 = entry.id.fullMD5 {
				// Already have full MD5
				verifiedEntries.append((entry, fullMD5))
			} else {
				// Compute full MD5
				let fullMD5 = try await PhotoMD5(contentsOf: entry.path)
				try await database.updatePhotoMD5(fastKey: entry.id.fastKey.stringValue, photoMD5: fullMD5.value)
				verifiedEntries.append((entry, fullMD5))
			}
		}
		
		// Group by actual MD5 using string keys
		var md5Groups: [String: [PhotoEntry]] = [:]
		for (entry, md5) in verifiedEntries {
			md5Groups[md5.value, default: []].append(entry)
		}

		// Create verified groups
		var trueDuplicates: [(PhotoMD5, [PhotoEntry])] = []
		for (md5String, entries) in md5Groups where entries.count > 1 {
			trueDuplicates.append((PhotoMD5(md5String), entries))
		}
		
		return VerifiedDuplicateGroup(
			originalGroup: group,
			trueDuplicates: trueDuplicates,
			verifiedAt: Date()
		)
	}
}

// MARK: - Supporting Types

/// Detected changes in a directory
public struct DetectedChanges: Sendable {
	public let directory: URL
	public let added: [DiscoveredFile]
	public let modified: [ModifiedFile]
	public let unchanged: [FastPhotoKey]
	public let removed: [RemovedFile]
	public let detectedAt: Date

	nonisolated public var hasChanges: Bool {
		!added.isEmpty || !modified.isEmpty || !removed.isEmpty
	}

	nonisolated public var totalChanges: Int {
		added.count + modified.count + removed.count
	}

	nonisolated public var summary: String {
		"Added: \(added.count), Modified: \(modified.count), Unchanged: \(unchanged.count), Removed: \(removed.count)"
	}
}

/// Modified file information
public struct ModifiedFile: Sendable {
	public let file: DiscoveredFile
	public let oldEntry: PhotoEntry
	public let changeType: ChangeType
	
	public enum ChangeType {
		case contentChanged
		case moved
		case renamed
	}
}

/// Removed file information
public struct RemovedFile: Sendable {
	public let fastKey: FastPhotoKey
	public let photoMD5: PhotoMD5?
	public let originalPath: URL
}

/// Incremental update result
public struct IncrementalUpdate: Sendable {
	public let processedFiles: [FastPhotoKey]
	public let sinceDate: Date
	public let processedAt: Date
}

/// Duplicate group information
public struct DuplicateGroup: Sendable {
	public let fastKey: FastPhotoKey
	public let fileSize: Int64
	public let entries: [PhotoEntry]
	public let confidenceLevel: ConfidenceLevel
	
	public enum ConfidenceLevel {
		case low     // Only file size matches
		case medium  // Fast key matches
		case high    // Full MD5 available
	}
}

/// Verified duplicate group
public struct VerifiedDuplicateGroup: Sendable {
	public let originalGroup: DuplicateGroup
	public let trueDuplicates: [(PhotoMD5, [PhotoEntry])]
	public let verifiedAt: Date
	
	nonisolated public var hasTrueDuplicates: Bool {
		!trueDuplicates.isEmpty
	}
}

/// Change detector errors
public enum ChangeDetectorError: LocalizedError {
	case alreadyDetecting
	
	public var errorDescription: String? {
		switch self {
		case .alreadyDetecting:
			return "Change detection already in progress"
		}
	}
}