//
//  PhotolalaCatalogServiceV2.swift
//  Photolala
//
//  SwiftData-based implementation of PhotolalaCatalogService
//

import Foundation
import SwiftData
import CryptoKit

@MainActor
class PhotolalaCatalogServiceV2 {
	static let shared: PhotolalaCatalogServiceV2 = {
		do {
			return try PhotolalaCatalogServiceV2()
		} catch {
			fatalError("Failed to create PhotolalaCatalogServiceV2: \(error)")
		}
	}()
	
	private let modelContainer: ModelContainer
	private let modelContext: ModelContext

	private init() throws {
		let schema = Schema([
			PhotoCatalog.self,
			CatalogShard.self,
			CatalogPhotoEntry.self
		])

		let modelConfiguration = ModelConfiguration(
			schema: schema,
			isStoredInMemoryOnly: false,
			allowsSave: true,
			groupContainer: .automatic,
			cloudKitDatabase: .none // No CloudKit sync
		)

		self.modelContainer = try ModelContainer(
			for: schema,
			configurations: [modelConfiguration]
		)

		self.modelContext = modelContainer.mainContext
	}

	// MARK: - Public Methods
	
	// Save any pending changes
	func save() async throws {
		try modelContext.save()
	}
	
	// Find or create catalog for a directory path
	func findOrCreateCatalog(directoryPath: String) async throws -> PhotoCatalog {
		let descriptor = FetchDescriptor<PhotoCatalog>(
			predicate: #Predicate { $0.directoryPath == directoryPath }
		)
		
		if let existing = try modelContext.fetch(descriptor).first {
			return existing
		}
		
		// Create new catalog
		let catalog = PhotoCatalog(directoryPath: directoryPath)
		modelContext.insert(catalog)
		
		// Insert all shards
		for shard in catalog.allShards {
			modelContext.insert(shard)
		}
		
		try modelContext.save()
		return catalog
	}
	
	// Add or update entry
	func upsertEntry(_ entry: CatalogPhotoEntry, in catalog: PhotoCatalog) throws {
		// Get the appropriate shard
		guard let shard = catalog.shard(for: entry.md5) else {
			throw CatalogError.invalidMD5
		}
		
		// Check if entry exists (single fetch)
		let md5Value = entry.md5
		let descriptor = FetchDescriptor<CatalogPhotoEntry>(
			predicate: #Predicate { $0.md5 == md5Value }
		)
		
		let existingEntry = try modelContext.fetch(descriptor).first
		
		if let existing = existingEntry {
			// Update existing
			existing.filename = entry.filename
			existing.fileSize = entry.fileSize
			existing.photoDate = entry.photoDate
			existing.fileModifiedDate = entry.fileModifiedDate
			existing.pixelWidth = entry.pixelWidth
			existing.pixelHeight = entry.pixelHeight
			existing.applePhotoID = entry.applePhotoID
		} else {
			// Insert new
			entry.shard = shard
			modelContext.insert(entry)
			shard.photoCount += 1
		}

		// Mark shard as modified
		shard.markModified()
		catalog.modifiedDate = Date()

		try modelContext.save()
	}
	
	// Find entry by MD5 (renamed to avoid ambiguity)
	func findPhotoEntry(md5: String) async throws -> CatalogPhotoEntry? {
		let descriptor = FetchDescriptor<CatalogPhotoEntry>(
			predicate: #Predicate { $0.md5 == md5 }
		)
		return try modelContext.fetch(descriptor).first
	}
	
	// Find entry by Apple Photo ID
	func findByApplePhotoID(_ applePhotoID: String) async throws -> CatalogPhotoEntry? {
		let descriptor = FetchDescriptor<CatalogPhotoEntry>(
			predicate: #Predicate { $0.applePhotoID == applePhotoID }
		)
		return try modelContext.fetch(descriptor).first
	}
	
	// Find entry by MD5
	func findByMD5(_ md5: String) async throws -> CatalogPhotoEntry? {
		let descriptor = FetchDescriptor<CatalogPhotoEntry>(
			predicate: #Predicate { $0.md5 == md5 }
		)
		return try modelContext.fetch(descriptor).first
	}
	
	// Remove entry by MD5
	func removeEntry(md5: String, from catalog: PhotoCatalog) async throws {
		guard let shard = catalog.shard(for: md5) else {
			throw CatalogError.invalidMD5
		}
		
		let descriptor = FetchDescriptor<CatalogPhotoEntry>(
			predicate: #Predicate { $0.md5 == md5 }
		)
		
		if let entry = try modelContext.fetch(descriptor).first {
			modelContext.delete(entry)
			shard.photoCount -= 1
			shard.markModified()
			catalog.modifiedDate = Date()
			try modelContext.save()
		}
	}
	
	// Export specific shard to CSV for S3 sync
	func exportShardToCSV(shard: CatalogShard) async throws -> String {
		// Always include CSV header for future-proofing
		let header = "md5,filename,size,photodate,modified,width,height,applephotoid"
		
		let entries = shard.entries ?? []
		
		if entries.isEmpty {
			// Return just the header for empty shards
			return header
		}
		
		let sortedEntries = entries.sorted { $0.md5 < $1.md5 }
		let csvLines = sortedEntries.map { $0.csvLine }
		
		// Combine header with data
		return ([header] + csvLines).joined(separator: "\n")
	}
	
	// Calculate checksum for content
	func calculateChecksum(_ content: String) -> String {
		let data = Data(content.utf8)
		let hash = SHA256.hash(data: data)
		return hash.compactMap { String(format: "%02x", $0) }.joined()
	}

	// Get all modified shards
	func getModifiedShards(catalog: PhotoCatalog) -> [CatalogShard] {
		return catalog.allShards.filter { $0.isModified }
	}

	// Reset modifications for specific shards after successful S3 sync
	func clearShardModifications(shards: [CatalogShard]) throws {
		for shard in shards {
			shard.clearModified()
		}
		
		if let catalog = shards.first?.catalog {
			catalog.lastS3SyncDate = Date()
		}
		
		try modelContext.save()
	}
	
	// Import specific shard from S3 (S3 is master)
	func importShardFromS3(shard: CatalogShard, s3Entries: [PhotolalaCatalogService.CatalogEntry], checksum: String) throws {
		// Ensure shard is in our context
		guard modelContext.model(for: shard.persistentModelID) != nil else {
			print("[PhotolalaCatalog] Shard not in current context, skipping import")
			return
		}
		
		// Clear existing entries in this shard only
		// Note: Star status means photo has copy in S3, so S3 catalog wins - clearing is correct
		if let entries = shard.entries {
			for entry in entries {
				modelContext.delete(entry)
			}
		}
		shard.entries?.removeAll()
		shard.photoCount = 0
		
		// Import all S3 entries for this shard
		for s3Entry in s3Entries {
			let entry = CatalogPhotoEntry(
				md5: s3Entry.md5,
				filename: s3Entry.filename,
				fileSize: s3Entry.size,
				photoDate: s3Entry.photodate,
				fileModifiedDate: s3Entry.modified
			)
			entry.pixelWidth = s3Entry.width
			entry.pixelHeight = s3Entry.height
			entry.applePhotoID = s3Entry.applePhotoID
			entry.shard = shard
			
			modelContext.insert(entry)
		}
		
		shard.photoCount = s3Entries.count
		shard.s3Checksum = checksum
		shard.clearModified()
		
		try modelContext.save()
	}
	
	// Load all entries from catalog
	func loadAllEntries(from catalog: PhotoCatalog) async throws -> [CatalogPhotoEntry] {
		var allEntries: [CatalogPhotoEntry] = []
		
		for shard in catalog.allShards {
			if let entries = shard.entries {
				allEntries.append(contentsOf: entries)
			}
		}
		
		return allEntries
	}
	
	// Save context helper
	func saveContext() throws {
		try modelContext.save()
	}
	
	// MARK: - Migration Support
	
	// Import from legacy CSV catalog
	func importFromLegacyCatalog(at directoryURL: URL) async throws -> PhotoCatalog {
		// Use the typed method
		let catalog = try await self.loadPhotoCatalog(for: directoryURL)
		
		// Load legacy catalog
		let legacyService = PhotolalaCatalogService(catalogURL: directoryURL)
		let entries = try await legacyService.loadAllEntries()
		
		// Import entries
		for legacyEntry in entries {
			let entry = CatalogPhotoEntry(
				md5: legacyEntry.md5,
				filename: legacyEntry.filename,
				fileSize: legacyEntry.size,
				photoDate: legacyEntry.photodate,
				fileModifiedDate: legacyEntry.modified
			)
			entry.pixelWidth = legacyEntry.width
			entry.pixelHeight = legacyEntry.height
			entry.applePhotoID = legacyEntry.applePhotoID
			
			try upsertEntry(entry, in: catalog)
		}
		
		return catalog
	}
	
	// MARK: - Error Types
	
	enum CatalogError: Error {
		case invalidMD5
		case catalogNotFound
	}
}

// MARK: - CatalogService Protocol Conformance

extension PhotolalaCatalogServiceV2: CatalogService {
	func loadCatalog(for directoryURL: URL) async throws -> Any {
		// Call the typed version
		return try await self.loadPhotoCatalog(for: directoryURL)
	}
	
	// Renamed method to avoid ambiguity
	func loadPhotoCatalog(for directoryURL: URL) async throws -> PhotoCatalog {
		let directoryPath = directoryURL.path

		// Check for existing catalog
		let descriptor = FetchDescriptor<PhotoCatalog>(
			predicate: #Predicate { $0.directoryPath == directoryPath }
		)

		if let existing = try modelContext.fetch(descriptor).first {
			return existing
		}

		// Create new catalog with 16 shards
		let catalog = PhotoCatalog(directoryPath: directoryPath)
		modelContext.insert(catalog)
		
		// Insert all shards
		modelContext.insert(catalog.shard0!)
		modelContext.insert(catalog.shard1!)
		modelContext.insert(catalog.shard2!)
		modelContext.insert(catalog.shard3!)
		modelContext.insert(catalog.shard4!)
		modelContext.insert(catalog.shard5!)
		modelContext.insert(catalog.shard6!)
		modelContext.insert(catalog.shard7!)
		modelContext.insert(catalog.shard8!)
		modelContext.insert(catalog.shard9!)
		modelContext.insert(catalog.shardA!)
		modelContext.insert(catalog.shardB!)
		modelContext.insert(catalog.shardC!)
		modelContext.insert(catalog.shardD!)
		modelContext.insert(catalog.shardE!)
		modelContext.insert(catalog.shardF!)
		
		try modelContext.save()

		return catalog
	}
	
	func findEntry(md5: String) async throws -> CatalogEntryProtocol? {
		// Call the typed version
		return try await self.findPhotoEntry(md5: md5)
	}
	
	func updateStarStatus(md5: String, isStarred: Bool) async throws {
		// Call the typed version
		guard let entry = try await self.findPhotoEntry(md5: md5) else { return }
		entry.isStarred = isStarred
		try modelContext.save()
	}
	
	func updateBackupStatus(md5: String, status: BackupStatus) async throws {
		// Call the typed version
		guard let entry = try await self.findPhotoEntry(md5: md5) else { return }
		entry.backupStatus = status
		try modelContext.save()
	}
	
	func getStarredEntries() async throws -> [CatalogEntryProtocol] {
		// Query SwiftData for starred entries
		let descriptor = FetchDescriptor<CatalogPhotoEntry>(
			predicate: #Predicate { $0.isStarred == true }
		)
		return try modelContext.fetch(descriptor)
	}
	
	func getCatalogStats() async throws -> CatalogStats {
		// Implement stats for SwiftData
		let totalDescriptor = FetchDescriptor<CatalogPhotoEntry>()
		let total = try modelContext.fetchCount(totalDescriptor)
		
		let starredDescriptor = FetchDescriptor<CatalogPhotoEntry>(
			predicate: #Predicate { entry in
				entry.isStarred == true
			}
		)
		let starred = try modelContext.fetchCount(starredDescriptor)
		
		// For backup status, fetch all and count manually
		// SwiftData predicates have issues with enum comparisons
		let allEntries = try modelContext.fetch(FetchDescriptor<CatalogPhotoEntry>())
		let backedUp = allEntries.filter { $0.backupStatus == .uploaded }.count
		
		return CatalogStats(
			totalPhotos: total,
			starredPhotos: starred,
			backedUpPhotos: backedUp,
			lastModified: Date() // TODO: Track actual modification date
		)
	}
}