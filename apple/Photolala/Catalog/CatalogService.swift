//
//  CatalogService.swift
//  Photolala
//
//  Main API interface for Photolala Directory Catalog System
//

import Foundation
import OSLog
import Combine
import CoreImage
import CryptoKit
/// Main service for managing photo catalogs
@MainActor
public final class CatalogService: ObservableObject {
	private let logger = Logger(subsystem: "com.photolala", category: "CatalogService")

	// Constants
	private let pointerFileName = ".photolala.md5"
	private let snapshotPrefix = ".photolala"
	private let snapshotExtension = "csv"

	// Published state
	@Published public private(set) var isScanning = false
	@Published public private(set) var isProcessing = false
	@Published public private(set) var currentOperation: String?
	@Published public private(set) var catalogInfo: CatalogInfo?
	@Published public private(set) var statistics: CatalogStatistics?
	@Published public private(set) var lastError: Error?
	
	// Progress tracking
	@Published public private(set) var scanProgress: ScanProgress?
	@Published public private(set) var digestProgress: DigestProgress?
	
	// Core components (actors)
	private var database: CatalogDatabase?
	private var snapshot: CatalogSnapshot?
	private var scanner: DirectoryScanner?
	private var pipeline: DigestPipeline?
	private var changeDetector: ChangeDetector?
	
	// Configuration
	private let catalogDirectory: URL
	private let cacheDirectory: URL
	private let directoryMD5: String
	
	// Subscriptions
	private var cancellables = Set<AnyCancellable>()
	
	// MARK: - Initialization
	
	public init(
		catalogDirectory: URL,
		cacheDirectory: URL? = nil
	) {
		self.catalogDirectory = catalogDirectory
		self.cacheDirectory = cacheDirectory ?? FileManager.default.urls(
			for: .cachesDirectory,
			in: .userDomainMask
		).first!.appendingPathComponent("com.photolala.catalog")
		self.directoryMD5 = Self.computeDirectoryMD5(for: catalogDirectory)
		
		logger.info("CatalogService initialized for: \(catalogDirectory.path)")
	}
	
	// MARK: - Catalog Operations
	
	/// Initialize or load existing catalog
	public func initializeCatalog() async throws {
		currentOperation = "Initializing catalog"
		defer { currentOperation = nil }
		
		snapshot = CatalogSnapshot(directory: catalogDirectory)
		let bootstrapResult: (database: CatalogDatabase, catalog: CatalogInfo?)
		do {
			bootstrapResult = try await bootstrapWorkingDatabase()
		} catch {
			logger.error("Bootstrap failed: \(error.localizedDescription)")
			throw error
		}
		database = bootstrapResult.database
		catalogInfo = bootstrapResult.catalog
		
		guard let database = database else {
			throw CatalogServiceError.databaseNotInitialized
		}
		
		scanner = DirectoryScanner()
		pipeline = DigestPipeline(database: database)
		changeDetector = ChangeDetector(
			database: database,
			scanner: scanner,
			pipeline: pipeline
		)
		
		setupProgressMonitoring()
		try await updateStatistics()
		
		logger.info("Catalog initialized successfully")
	}
	
	/// Scan directory and build catalog
	public func scanAndBuildCatalog(
		recursive: Bool = true,
		processImmediately: Bool = true
	) async throws {
		guard let scanner = scanner else {
			throw CatalogServiceError.notInitialized
		}
		
		isScanning = true
		defer { isScanning = false }
		
		currentOperation = "Scanning directory"
		
		// Scan directory
		let discoveredFiles = try await scanner.scanDirectory(
			catalogDirectory,
			recursive: recursive
		)
		
		logger.info("Scan complete: \(discoveredFiles.count) files found")
		
		if processImmediately && !discoveredFiles.isEmpty {
			try await processDiscoveredFiles(discoveredFiles)
		}
		
		// Create snapshot
		try await createSnapshot()
		
		// Update statistics
		try await updateStatistics()
	}
	
	/// Process discovered files through digest pipeline
	public func processDiscoveredFiles(_ files: [DiscoveredFile]) async throws {
		guard let pipeline = pipeline else {
			throw CatalogServiceError.notInitialized
		}
		
		isProcessing = true
		defer { isProcessing = false }
		
		currentOperation = "Processing \(files.count) files"
		
		try await pipeline.processFiles(files)
		
		logger.info("Processing complete for \(files.count) files")
	}
	
	/// Detect and apply changes
	public func detectAndApplyChanges() async throws {
		guard let changeDetector = changeDetector else {
			throw CatalogServiceError.notInitialized
		}
		
		currentOperation = "Detecting changes"
		
		let changes = try await changeDetector.detectChanges(in: catalogDirectory)
		
		if changes.hasChanges {
			logger.info("Applying changes: \(changes.summary)")
			currentOperation = "Applying \(changes.totalChanges) changes"
			try await changeDetector.applyChanges(changes)
			
			// Create new snapshot after changes
			try await createSnapshot()
		} else {
			logger.info("No changes detected")
		}
		
		currentOperation = nil
		try await updateStatistics()
	}
	
	/// Create catalog snapshot
	public func createSnapshot() async throws {
		guard let database = database,
			  let snapshot = snapshot else {
			throw CatalogServiceError.notInitialized
		}
		
		currentOperation = "Creating snapshot"
		
		let newCatalog = try await snapshot.createSnapshot(from: database)
		catalogInfo = newCatalog

		let cacheManager = CacheManager.shared
		let cacheSnapshotURL = await cacheManager.getCatalogPath(directoryMD5: directoryMD5, catalogMD5: newCatalog.md5)
		try mirrorSnapshotIfNeeded(from: newCatalog.path, to: cacheSnapshotURL, expectedMD5: newCatalog.md5)
		let cachePointerURL = await cacheManager.getCatalogPointerPath(directoryMD5: directoryMD5)
		try writePointer(newCatalog.md5, to: cachePointerURL)
		logger.debug("Mirrored snapshot to cache for md5: \(newCatalog.md5, privacy: .public)")
		
		logger.info("Created snapshot: \(newCatalog.md5)")
		currentOperation = nil
	}
	
	/// List available catalog snapshots
	public func listSnapshots() async throws -> [CatalogInfo] {
		guard let snapshot = snapshot else {
			throw CatalogServiceError.notInitialized
		}
		
		return try await snapshot.listSnapshots()
	}
	
	/// Load a specific snapshot
	public func loadSnapshot(md5: String) async throws {
		guard let snapshot = snapshot else {
			throw CatalogServiceError.notInitialized
		}
		
		currentOperation = "Loading snapshot \(md5)"
		
		database = try await snapshot.openSnapshot(md5: md5)
		catalogInfo = try await snapshot.listSnapshots().first { $0.md5 == md5 }
		
		// Reinitialize components with new database
		guard let database = database else {
			throw CatalogServiceError.databaseNotInitialized
		}
		
		pipeline = DigestPipeline(database: database)
		changeDetector = ChangeDetector(
			database: database,
			scanner: scanner,
			pipeline: pipeline
		)
		
		try await updateStatistics()
		currentOperation = nil
	}
	
	// MARK: - Query Operations
	
	/// Get photo entry by fast key
	public func getEntry(fastKey: String) async throws -> CatalogEntry? {
		guard let database = database else {
			throw CatalogServiceError.notInitialized
		}

		return try await database.getEntry(fastKey: fastKey)
	}
	
	/// Get all entries in catalog
	public func getEntries() async throws -> [CatalogEntry] {
		guard let database = database else {
			throw CatalogServiceError.notInitialized
		}

		return try await database.getAllEntries()
	}

	// MARK: - Star Operations (Catalog Membership)

	/// Check if a photo is starred (exists in catalog) by MD5
	public func isStarred(md5: String) async throws -> Bool {
		guard let database = database else {
			throw CatalogServiceError.notInitialized
		}

		return await database.containsMD5(md5)
	}

	/// Star a photo by adding/updating its entry in the catalog
	public func starEntry(_ entry: CatalogEntry) async throws {
		guard let database = database else {
			throw CatalogServiceError.notInitialized
		}

		try await database.upsertEntry(entry)
	}

	/// Unstar a photo by removing it from the catalog
	public func unstarEntry(md5: String) async throws {
		guard let database = database else {
			throw CatalogServiceError.notInitialized
		}

		try await database.removeByMD5(md5)
	}

	/// Get entry by MD5
	public func getEntryByMD5(_ md5: String) async throws -> CatalogEntry? {
		guard let database = database else {
			throw CatalogServiceError.notInitialized
		}

		return await database.getEntryByMD5(md5)
	}

	/// Get photo metadata from cache
	public func getMetadata(for photoMD5: PhotoMD5) async throws -> PhotoMetadata? {
		// Metadata is stored in cache, not in CSV database
		let metadataCache = MetadataCache.shared
		return try await metadataCache.getMetadata(for: photoMD5)
	}
	
	/// Get thumbnail for photo
	public func getThumbnail(for photoMD5: PhotoMD5) async throws -> CGImage? {
		let cache = ThumbnailCache.shared

		// Need source URL to generate thumbnail if not cached
		guard let database = database else {
			throw CatalogServiceError.notInitialized
		}

		// Find entry with this MD5
		let entries = try await database.getAllEntries()
		guard let entry = entries.first(where: { $0.photoMD5 == photoMD5.value }) else {
			return nil
		}

		// For thumbnail generation, we need the actual file URL
		// This would need to be resolved from the catalog directory and the entry
		// For now, return nil as we can't determine the source URL from CSV alone
		logger.warning("Thumbnail generation requires file path tracking not available in CSV")
		return nil
	}
	
	// MARK: - Duplicate Detection
	
	/// Find potential duplicates
	public func findDuplicates() async throws -> [DuplicateGroup] {
		guard let changeDetector = changeDetector else {
			throw CatalogServiceError.notInitialized
		}
		
		currentOperation = "Finding duplicates"
		defer { currentOperation = nil }
		
		return try await changeDetector.detectPotentialDuplicates(in: catalogDirectory)
	}
	
	/// Verify duplicate group
	public func verifyDuplicates(_ group: DuplicateGroup) async throws -> VerifiedDuplicateGroup {
		guard let changeDetector = changeDetector else {
			throw CatalogServiceError.notInitialized
		}
		
		currentOperation = "Verifying duplicates"
		defer { currentOperation = nil }
		
		return try await changeDetector.verifyDuplicates(group)
	}
	
	// MARK: - Maintenance
	
	/// Clean old snapshots
	public func cleanOldSnapshots(keepCount: Int = 5) async throws -> Int {
		guard let snapshot = snapshot else {
			throw CatalogServiceError.notInitialized
		}
		
		currentOperation = "Cleaning old snapshots"
		defer { currentOperation = nil }
		
		return try await snapshot.pruneSnapshots(keepCount: keepCount)
	}
	
	/// Optimize database (no-op for CSV)
	public func optimizeDatabase() async throws {
		// CSV doesn't need optimization like SQLite vacuum
		currentOperation = "Optimizing database"
		defer { currentOperation = nil }

		logger.info("CSV catalog does not require optimization")
	}
	
	/// Clean cache if needed
	public func cleanCache() async {
		currentOperation = "Cleaning cache"
		defer { currentOperation = nil }
		
		let cacheManager = CacheManager.shared
		await cacheManager.cleanCacheIfNeeded()
	}
	
	// MARK: - Control
	
	/// Cancel current scanning operation
	public func cancelScan() async {
		await scanner?.cancelScan()
		isScanning = false
		currentOperation = nil
	}
	
	/// Cancel current processing operation
	public func cancelProcessing() async {
		await pipeline?.cancelProcessing()
		isProcessing = false
		currentOperation = nil
	}
	
	// MARK: - Private Helpers

	private enum SnapshotSource {
		case root
		case cache
	}

	private func bootstrapWorkingDatabase() async throws -> (database: CatalogDatabase, catalog: CatalogInfo?) {
		let cacheManager = CacheManager.shared
		let fileManager = FileManager.default

		let rootPointerURL = catalogDirectory.appendingPathComponent(pointerFileName)
		let cachePointerURL = await cacheManager.getCatalogPointerPath(directoryMD5: directoryMD5)
		let workingPath = await cacheManager.getWorkingCatalogPath(directoryMD5: directoryMD5)
		logger.debug("Bootstrapping working DB at \(workingPath.path, privacy: .public)")

		let rootPointer = readPointer(at: rootPointerURL)
		let cachePointer = readPointer(at: cachePointerURL)
		logger.debug("Root pointer: \(rootPointer ?? "nil", privacy: .public), cache pointer: \(cachePointer ?? "nil", privacy: .public)")

		var activeMD5: String?
		var sourceURL: URL?
		var activeSource: SnapshotSource?

		if let md5 = rootPointer, !md5.isEmpty {
			logger.debug("Evaluating root pointer md5: \(md5, privacy: .public)")
			let rootSnapshotURL = snapshotURL(md5: md5, base: catalogDirectory)
			do {
				let exists = fileManager.fileExists(atPath: rootSnapshotURL.path)
				logger.debug("Root snapshot exists: \(exists), path: \(rootSnapshotURL.path, privacy: .public)")
				let isValid = try validateSnapshot(at: rootSnapshotURL, expectedMD5: md5)
				logger.debug("Root snapshot valid: \(isValid)")
				if exists && isValid {
					activeMD5 = md5
					sourceURL = rootSnapshotURL
					activeSource = .root
				}
			} catch {
				logger.error("Failed to validate root snapshot for md5 \(md5): \(error.localizedDescription)")
			}
		} else if rootPointer != nil {
			logger.warning("Root pointer exists but is empty; ignoring")
		}

		if activeMD5 == nil, let md5 = cachePointer, !md5.isEmpty {
			logger.debug("Evaluating cache pointer md5: \(md5, privacy: .public)")
			let cacheSnapshotURL = await cacheManager.getCatalogPath(directoryMD5: directoryMD5, catalogMD5: md5)
			do {
				let exists = fileManager.fileExists(atPath: cacheSnapshotURL.path)
				logger.debug("Cache snapshot exists: \(exists), path: \(cacheSnapshotURL.path, privacy: .public)")
				let isValid = try validateSnapshot(at: cacheSnapshotURL, expectedMD5: md5)
				logger.debug("Cache snapshot valid: \(isValid)")
				if exists && isValid {
					activeMD5 = md5
					sourceURL = cacheSnapshotURL
					activeSource = .cache
				}
			} catch {
				logger.error("Failed to validate cache snapshot for md5 \(md5): \(error.localizedDescription)")
			}
		} else if cachePointer != nil && (cachePointer?.isEmpty ?? false) {
			logger.warning("Cache pointer exists but is empty; ignoring")
		}

		if let md5 = activeMD5, let sourceURL = sourceURL, let activeSource = activeSource {
			let rootSnapshotURL = snapshotURL(md5: md5, base: catalogDirectory)
			let cacheSnapshotURL = await cacheManager.getCatalogPath(directoryMD5: directoryMD5, catalogMD5: md5)

			switch activeSource {
			case .root:
				try mirrorSnapshotIfNeeded(from: sourceURL, to: cacheSnapshotURL, expectedMD5: md5)
				if cachePointer != md5 {
					try writePointer(md5, to: cachePointerURL)
				}
			case .cache:
				try mirrorSnapshotIfNeeded(from: sourceURL, to: rootSnapshotURL, expectedMD5: md5)
				if rootPointer != md5 {
					try writePointer(md5, to: rootPointerURL)
				}
			}

			try prepareWorkingDatabase(from: sourceURL, to: workingPath)

			let database = try await CatalogDatabase(path: workingPath)
			let info = try catalogInfo(forSnapshotAt: rootSnapshotURL, md5: md5)
			return (database, info)
		}

		logger.info("No existing catalog snapshot detected; starting with empty working database")
		try prepareEmptyWorkingDatabase(at: workingPath)
		let database = try await CatalogDatabase(path: workingPath)
		return (database, nil)
	}

	private func readPointer(at url: URL) -> String? {
		guard FileManager.default.fileExists(atPath: url.path) else { return nil }
		do {
			let contents = try String(contentsOf: url, encoding: .utf8)
			let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
			return trimmed.isEmpty ? nil : trimmed
		} catch {
			logger.error("Failed to read pointer at \(url.path): \(error.localizedDescription)")
			return nil
		}
	}

	private func writePointer(_ md5: String, to url: URL) throws {
		let directory = url.deletingLastPathComponent()
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		try md5.write(to: url, atomically: true, encoding: .utf8)
	}

	private func snapshotURL(md5: String, base: URL) -> URL {
		base.appendingPathComponent("\(snapshotPrefix).\(md5).\(snapshotExtension)")
	}

	private func validateSnapshot(at url: URL, expectedMD5: String) throws -> Bool {
		let actual = try computeFileMD5(at: url)
		if actual != expectedMD5 {
			logger.error("Catalog checksum mismatch for \(url.lastPathComponent). Expected \(expectedMD5), got \(actual)")
		}
		return actual == expectedMD5
	}

	private func mirrorSnapshotIfNeeded(from source: URL, to destination: URL, expectedMD5: String) throws {
		let fileManager = FileManager.default
		if fileManager.fileExists(atPath: destination.path) {
			if let existingMD5 = try? computeFileMD5(at: destination), existingMD5 == expectedMD5 {
				return
			}
		}

		let parent = destination.deletingLastPathComponent()
		try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

		let temp = parent.appendingPathComponent(destination.lastPathComponent + ".tmp")
		if fileManager.fileExists(atPath: temp.path) {
			try fileManager.removeItem(at: temp)
		}
		if fileManager.fileExists(atPath: destination.path) {
			try fileManager.removeItem(at: destination)
		}

		try fileManager.copyItem(at: source, to: temp)
		try fileManager.setAttributes([.posixPermissions: 0o444], ofItemAtPath: temp.path)
		try fileManager.moveItem(at: temp, to: destination)
	}

	private func prepareWorkingDatabase(from source: URL, to destination: URL) throws {
		let fileManager = FileManager.default
		let parent = destination.deletingLastPathComponent()
		try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
		if fileManager.fileExists(atPath: destination.path) {
			try fileManager.removeItem(at: destination)
		}
		try fileManager.copyItem(at: source, to: destination)
		try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: destination.path)
	}

	private func prepareEmptyWorkingDatabase(at url: URL) throws {
		let fileManager = FileManager.default
		let parent = url.deletingLastPathComponent()
		try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
		if fileManager.fileExists(atPath: url.path) {
			try fileManager.removeItem(at: url)
		}
	}

	private func computeFileMD5(at url: URL) throws -> String {
		let handle = try FileHandle(forReadingFrom: url)
		defer { try? handle.close() }

		var hasher = Insecure.MD5()
		while true {
			let data = try handle.read(upToCount: 1_048_576) ?? Data()
			if data.isEmpty { break }
			hasher.update(data: data)
		}

		let digest = hasher.finalize()
		return digest.map { String(format: "%02x", $0) }.joined()
	}

	private func catalogInfo(forSnapshotAt url: URL, md5: String) throws -> CatalogInfo {
		let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
		let createdDate = attributes[.creationDate] as? Date ?? Date()
		let size = attributes[.size] as? Int64 ?? 0
		let entryCount = countEntries(in: url)

		return CatalogInfo(
			md5: md5,
			path: url,
			createdDate: createdDate,
			fileSize: size,
			entryCount: entryCount
		)
	}

	private func countEntries(in catalogURL: URL) -> Int {
		do {
			let content = try String(contentsOf: catalogURL, encoding: .utf8)
			let lines = content.components(separatedBy: .newlines)
			// Subtract 1 for header line, and don't count empty lines
			let count = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count - 1
			return max(0, count)
		} catch {
			logger.error("Failed to count entries in \(catalogURL.lastPathComponent): \(error.localizedDescription)")
			return 0
		}
	}

	private static func computeDirectoryMD5(for directory: URL) -> String {
		let normalized = directory.standardizedFileURL.path
		let data = Data(normalized.utf8)
		let digest = Insecure.MD5.hash(data: data)
		return digest.map { String(format: "%02x", $0) }.joined()
	}

	private func setupProgressMonitoring() {
		// TODO: Setup progress monitoring with proper actor isolation
		// Progress monitoring requires careful handling of actor boundaries
		// For now, progress will be tracked through state updates
	}

	private func updateStatistics() async throws {
		guard let database = database else { return }
		statistics = try await database.getStatistics()
	}
}

// MARK: - Errors

public enum CatalogServiceError: LocalizedError {
	case notInitialized
	case databaseNotInitialized
	case invalidDirectory
	
	public var errorDescription: String? {
		switch self {
		case .notInitialized:
			return "Catalog service not initialized"
		case .databaseNotInitialized:
			return "Database not initialized"
		case .invalidDirectory:
			return "Invalid directory specified"
		}
	}
}
