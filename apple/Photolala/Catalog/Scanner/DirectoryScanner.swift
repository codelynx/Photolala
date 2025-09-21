//
//  DirectoryScanner.swift
//  Photolala
//
//  Recursive directory scanner for photo discovery
//

import Foundation
import OSLog
import Combine

/// Directory scanner for discovering photo files
public actor DirectoryScanner {
	private let logger = Logger(subsystem: "com.photolala", category: "DirectoryScanner")

	// Configuration
	private let supportedExtensions = Set<String>([
		"jpg", "jpeg", "heic", "heif", "png", "tiff", "tif",
		"raw", "cr2", "cr3", "nef", "arw", "orf", "dng", "raf"
	])

	private let excludedDirectories = Set<String>([
		".Trash", ".git", ".svn", "node_modules", ".cache",
		"Library", "System", ".photolala"
	])

	private let maxConcurrentScans = 4
	private let batchSize = 100

	// Progress tracking
	private var isScanning = false
	private var cancelRequested = false
	private var scannedFileCount = 0
	private var totalBytesScanned: Int64 = 0

	// Progress publisher
	private let progressSubject = PassthroughSubject<ScanProgress, Never>()
	public var progressPublisher: AnyPublisher<ScanProgress, Never> {
		progressSubject.eraseToAnyPublisher()
	}

	// MARK: - Public API

	/// Scan directory for photo files
	public func scanDirectory(
		_ directoryURL: URL,
		recursive: Bool = true,
		skipHidden: Bool = true
	) async throws -> [DiscoveredFile] {
		guard !isScanning else {
			throw ScannerError.alreadyScanning
		}

		isScanning = true
		cancelRequested = false
		scannedFileCount = 0
		totalBytesScanned = 0
		defer { isScanning = false }

		logger.info("Starting scan of: \(directoryURL.path)")
		let startTime = Date()

		var discoveredFiles: [DiscoveredFile] = []
		let fileManager = FileManager.default

		// Check directory exists and is readable
		var isDirectory: ObjCBool = false
		guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
			  isDirectory.boolValue else {
			throw ScannerError.notDirectory(directoryURL)
		}

		// Start recursive scan
		let files = try await scanDirectoryRecursive(
			directoryURL,
			recursive: recursive,
			skipHidden: skipHidden,
			fileManager: fileManager
		)

		discoveredFiles = files

		let duration = Date().timeIntervalSince(startTime)
		logger.info("""
			Scan completed: \(discoveredFiles.count) files, \
			\(self.formatBytes(self.totalBytesScanned)) in \(String(format: "%.2f", duration))s
			""")

		// Send completion progress
		progressSubject.send(ScanProgress(
			scannedFiles: discoveredFiles.count,
			totalBytes: totalBytesScanned,
			currentPath: nil,
			isComplete: true
		))

		return discoveredFiles
	}

	/// Cancel ongoing scan
	public func cancelScan() {
		cancelRequested = true
		logger.info("Scan cancellation requested")
	}

	// MARK: - Private Methods

	private func scanDirectoryRecursive(
		_ directoryURL: URL,
		recursive: Bool,
		skipHidden: Bool,
		fileManager: FileManager,
		currentDepth: Int = 0
	) async throws -> [DiscoveredFile] {
		guard !cancelRequested else {
			throw ScannerError.cancelled
		}

		// Check if directory should be excluded
		let dirName = directoryURL.lastPathComponent
		if excludedDirectories.contains(dirName) {
			logger.debug("Skipping excluded directory: \(dirName)")
			return []
		}

		if skipHidden && dirName.hasPrefix(".") && currentDepth > 0 {
			logger.debug("Skipping hidden directory: \(dirName)")
			return []
		}

		var discoveredFiles: [DiscoveredFile] = []

		// Send progress update
		progressSubject.send(ScanProgress(
			scannedFiles: scannedFileCount,
			totalBytes: totalBytesScanned,
			currentPath: directoryURL.path,
			isComplete: false
		))

		// Enumerate directory contents
		let resourceKeys: [URLResourceKey] = [
			.isDirectoryKey,
			.fileSizeKey,
			.contentModificationDateKey,
			.isHiddenKey,
			.isPackageKey
		]

		guard let enumerator = fileManager.enumerator(
			at: directoryURL,
			includingPropertiesForKeys: resourceKeys,
			options: skipHidden ? [.skipsHiddenFiles] : []
		) else {
			throw ScannerError.enumerationFailed(directoryURL)
		}

		// Process files in batches
		var batch: [DiscoveredFile] = []

		while let element = enumerator.nextObject() {
			guard let fileURL = element as? URL else { continue }
			guard !cancelRequested else {
				throw ScannerError.cancelled
			}

			// Skip subdirectory enumeration if not recursive
			if !recursive {
				enumerator.skipDescendants()
			}

			do {
				let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))

				// Skip directories and packages
				if resourceValues.isDirectory == true || resourceValues.isPackage == true {
					continue
				}

				// Skip hidden files if requested
				if skipHidden && (resourceValues.isHidden == true) {
					continue
				}

				// Check file extension
				let fileExtension = fileURL.pathExtension.lowercased()
				guard supportedExtensions.contains(fileExtension) else {
					continue
				}

				// Get file attributes
				let fileSize = Int64(resourceValues.fileSize ?? 0)
				let modifiedDate = resourceValues.contentModificationDate ?? Date()

				// Compute fast photo key
				let fastKey = try await FastPhotoKey(contentsOf: fileURL)

				let discoveredFile = DiscoveredFile(
					url: fileURL,
					fastKey: fastKey,
					fileSize: fileSize,
					modifiedDate: modifiedDate,
					format: fastKey.detectedFormat ?? .unknown
				)

				batch.append(discoveredFile)
				scannedFileCount += 1
				totalBytesScanned += fileSize

				// Process batch if full
				if batch.count >= batchSize {
					discoveredFiles.append(contentsOf: batch)
					batch.removeAll(keepingCapacity: true)

					// Yield to prevent blocking
					try await Task.sleep(nanoseconds: 1_000_000) // 1ms
				}

			} catch {
				logger.warning("Error processing file \(fileURL): \(error)")
				continue
			}
		}

		// Add remaining batch items
		if !batch.isEmpty {
			discoveredFiles.append(contentsOf: batch)
		}

		return discoveredFiles
	}

	/// Scan directory changes since last catalog
	public func scanForChanges(
		directory: URL,
		previousEntries: [String: PhotoEntry]  // Use String key instead
	) async throws -> ScanChanges {
		let currentFiles = try await scanDirectory(directory)

		var added: [DiscoveredFile] = []
		var modified: [DiscoveredFile] = []
		var removed: [FastPhotoKey] = []

		// Create lookup map for current files using string keys
		let currentFilesMap = Dictionary(
			uniqueKeysWithValues: currentFiles.map { ($0.fastKey.stringValue, $0) }
		)

		// Check for added and modified files
		for file in currentFiles {
			let keyString = file.fastKey.stringValue
			if let previousEntry = previousEntries[keyString] {
				// Check if modified
				if file.modifiedDate > previousEntry.modifiedDate {
					modified.append(file)
				}
			} else {
				// New file
				added.append(file)
			}
		}

		// Check for removed files
		for (fastKeyString, entry) in previousEntries {
			if currentFilesMap[fastKeyString] == nil {
				if let fastKey = FastPhotoKey(string: fastKeyString) {
					removed.append(fastKey)
				}
			}
		}

		logger.info("""
			Changes detected - Added: \(added.count), \
			Modified: \(modified.count), Removed: \(removed.count)
			""")

		return ScanChanges(
			added: added,
			modified: modified,
			removed: removed
		)
	}

	// MARK: - Utility Methods

	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
}

// MARK: - Supporting Types

/// Discovered file during scanning
public struct DiscoveredFile: Sendable {
	public let url: URL
	public let fastKey: FastPhotoKey
	public let fileSize: Int64
	public let modifiedDate: Date
	public let format: ImageFormat

	public nonisolated var detectedFormat: ImageFormat {
		// Use format from FastPhotoKey detection if available
		fastKey.detectedFormat ?? format
	}
}

/// Scan progress information
public struct ScanProgress: Sendable {
	public let scannedFiles: Int
	public let totalBytes: Int64
	public let currentPath: String?
	public let isComplete: Bool
}

/// Changes detected during incremental scan
public struct ScanChanges: Sendable {
	public let added: [DiscoveredFile]
	public let modified: [DiscoveredFile]
	public let removed: [FastPhotoKey]

	public var hasChanges: Bool {
		!added.isEmpty || !modified.isEmpty || !removed.isEmpty
	}

	public var totalChanges: Int {
		added.count + modified.count + removed.count
	}
}

/// Scanner errors
public enum ScannerError: LocalizedError {
	case alreadyScanning
	case notDirectory(URL)
	case enumerationFailed(URL)
	case cancelled

	public var errorDescription: String? {
		switch self {
		case .alreadyScanning:
			return "A scan is already in progress"
		case .notDirectory(let url):
			return "Path is not a directory: \(url.path)"
		case .enumerationFailed(let url):
			return "Failed to enumerate directory: \(url.path)"
		case .cancelled:
			return "Scan was cancelled"
		}
	}
}