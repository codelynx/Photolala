//
//  S3CatalogSyncServiceV2.swift
//  Photolala
//
//  S3 sync service for SwiftData-based catalog
//

import Foundation
import CryptoKit

class S3CatalogSyncServiceV2 {
	private let catalogService: PhotolalaCatalogServiceV2
	private let s3Service: S3BackupService

	init(catalogService: PhotolalaCatalogServiceV2, s3Service: S3BackupService) {
		self.catalogService = catalogService
		self.s3Service = s3Service
	}

	// MARK: - Public Methods
	
	// Sync with S3 master catalog
	func syncWithS3(catalog: PhotoCatalog, userId: String) async throws {
		// For now, this is a simplified implementation
		// In production, we would need to:
		// 1. Add public methods to S3BackupService for catalog operations
		// 2. Or create a separate S3CatalogService with proper access
		
		// Download S3 manifest
		do {
			let s3Manifest = try await downloadManifest(userId: userId)
			
			// Check each shard for updates
			let allShards = await MainActor.run { catalog.allShards }
			
			for shard in allShards {
				// Note: shardChecksums uses hex format keys "0"-"f"
				let shardIndex = await MainActor.run { shard.index }
				let s3ShardChecksum = s3Manifest.shardChecksums[String(format: "%x", shardIndex)]
				let shardChecksum = await MainActor.run { shard.s3Checksum }
				let isModified = await MainActor.run { shard.isModified }
				
				// Download if S3 has newer data (nil checksum means empty shard)
				if s3ShardChecksum != shardChecksum {
					do {
						let shardData = try await downloadShard(userId: userId, shardIndex: shardIndex)
						let entries = parseCSV(shardData.csv)
						try await MainActor.run {
							try catalogService.importShardFromS3(
								shard: shard,
								s3Entries: entries,
								checksum: shardData.checksum
							)
						}
					} catch {
						print("[S3CatalogSync] Failed to download shard \(shardIndex): \(error)")
					}
				}
				// Upload if we have local changes
				else if isModified {
					do {
						let csvContent = try await catalogService.exportShardToCSV(shard: shard)
						let checksum = await MainActor.run { catalogService.calculateChecksum(csvContent) }
						
						// Note: We upload incrementally at shard level (16 sharded bodies)
						try await uploadShard(
							userId: userId,
							shardIndex: shardIndex,
							csv: csvContent,
							checksum: checksum
						)
						
						await MainActor.run {
							shard.s3Checksum = checksum
						}
						
						try await MainActor.run {
							try catalogService.clearShardModifications(shards: [shard])
						}
					} catch {
						// Note: Just log errors for now
						print("[S3CatalogSync] Failed to upload shard \(shardIndex): \(error)")
					}
				}
			}
			
			// Update manifest
			await MainActor.run {
				catalog.s3ManifestETag = s3Manifest.eTag
				catalog.lastS3SyncDate = Date()
				try? catalogService.saveContext()
			}
		} catch {
			print("[S3CatalogSync] Failed to sync catalog: \(error)")
			throw error
		}
	}
	
	// MARK: - Private Methods
	
	// These methods would need to be implemented with proper S3 access
	// For now, they're stubs that throw errors
	
	private func uploadShard(userId: String, shardIndex: Int, csv: String, checksum: String) async throws {
		// TODO: Implement catalog shard upload
		// This would require adding catalog-specific methods to S3BackupService
		// or creating a new service with appropriate access
		throw S3CatalogError.notImplemented
	}
	
	private func downloadShard(userId: String, shardIndex: Int) async throws -> (csv: String, checksum: String) {
		// TODO: Implement catalog shard download
		throw S3CatalogError.notImplemented
	}
	
	private func downloadManifest(userId: String) async throws -> S3CatalogManifest {
		// TODO: Implement manifest download
		// For now, return a default manifest
		return S3CatalogManifest(
			version: "6.0",
			directoryUUID: UUID().uuidString,
			lastModified: Date(),
			shardChecksums: [:],
			photoCount: 0,
			eTag: nil
		)
	}
	
	private func updateManifestChecksum(userId: String, shardIndex: Int, checksum: String) async throws {
		// TODO: Implement manifest update
		throw S3CatalogError.notImplemented
	}
	
	// Parse CSV into catalog entries
	private func parseCSV(_ csv: String) -> [PhotolalaCatalogService.CatalogEntry] {
		let lines = csv.components(separatedBy: .newlines)
		return lines.compactMap { line in
			guard !line.isEmpty else { return nil }
			return PhotolalaCatalogService.CatalogEntry(csvLine: line)
		}
	}
	
	// Calculate SHA256 checksum
	private func calculateChecksum(_ content: String) -> String {
		let data = Data(content.utf8)
		let hash = SHA256.hash(data: data)
		return hash.compactMap { String(format: "%02x", $0) }.joined()
	}
}

// S3 Catalog Manifest structure
struct S3CatalogManifest: Codable {
	var version: String
	var directoryUUID: String
	var lastModified: Date
	var shardChecksums: [String: String] // hex shard index -> checksum
	var photoCount: Int
	var eTag: String?
	
	enum CodingKeys: String, CodingKey {
		case version
		case directoryUUID = "directory-uuid"
		case lastModified = "last-modified"
		case shardChecksums = "shard-checksums"
		case photoCount = "photo-count"
		case eTag = "etag"
	}
}

// Catalog-specific errors
enum S3CatalogError: Error, LocalizedError {
	case notImplemented
	case downloadFailed
	case uploadFailed
	
	var errorDescription: String? {
		switch self {
		case .notImplemented:
			return "S3 catalog sync not yet implemented"
		case .downloadFailed:
			return "Failed to download from S3"
		case .uploadFailed:
			return "Failed to upload to S3"
		}
	}
}