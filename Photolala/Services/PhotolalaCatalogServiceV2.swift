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
	private let modelContainer: ModelContainer
	private let modelContext: ModelContext

	init() throws {
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
	
	// Create or load catalog for directory
	func loadCatalog(for directoryURL: URL) async throws -> PhotoCatalog {
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
	
	// Find entry by MD5
	func findEntry(md5: String) async throws -> CatalogPhotoEntry? {
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
		let entries = shard.entries ?? []
		
		let sortedEntries = entries.sorted { $0.md5 < $1.md5 }
		let csvLines = sortedEntries.map { $0.csvLine }
		
		return csvLines.joined(separator: "\n")
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
		let catalog = try await loadCatalog(for: directoryURL)
		
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