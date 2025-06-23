//
//  S3CatalogSyncServiceV2.swift
//  Photolala
//
//  S3 sync service for SwiftData-based catalog
//

import Foundation
import CryptoKit
import AWSS3

@MainActor
class S3CatalogSyncServiceV2: ObservableObject {
	private let catalogService: PhotolalaCatalogServiceV2
	private let s3Service: S3BackupService?
	
	// Sync state
	@Published var isSyncing = false
	@Published var syncProgress: Double = 0.0
	@Published var syncStatusText = ""
	@Published var lastSyncDate: Date?
	@Published var lastError: Error?
	
	// S3 configuration
	private let bucketName: String
	private var s3Client: S3Client
	
	init(catalogService: PhotolalaCatalogServiceV2, s3Service: S3BackupService) {
		self.catalogService = catalogService
		self.s3Service = s3Service
		
		// Get S3 configuration from backup service
		// For now, we'll use environment variables
		self.bucketName = ProcessInfo.processInfo.environment["S3_BUCKET_NAME"] ?? "photolala"
		
		// Initialize S3 client (reuse from backup service if possible)
		do {
			self.s3Client = try S3Client(region: ProcessInfo.processInfo.environment["AWS_DEFAULT_REGION"] ?? "us-east-1")
		} catch {
			fatalError("Failed to initialize S3 client: \(error)")
		}
	}
	
	// Alternative initializer that takes S3 client directly
	init(s3Client: S3Client, userId: String) throws {
		// Create services inline
		self.catalogService = try PhotolalaCatalogServiceV2()
		self.s3Service = nil  // We don't need the backup service when using direct S3 client
		self.s3Client = s3Client
		self.bucketName = ProcessInfo.processInfo.environment["S3_BUCKET_NAME"] ?? "photolala"
	}

	// MARK: - Public Methods
	
	// Sync with S3 master catalog
	func syncWithS3(catalog: PhotoCatalog, userId: String) async throws {
		guard !isSyncing else { return }
		
		isSyncing = true
		syncProgress = 0.0
		syncStatusText = "Starting sync..."
		lastError = nil
		
		defer {
			isSyncing = false
			lastSyncDate = Date()
		}
		
		do {
			// Download S3 manifest
			syncStatusText = "Downloading manifest..."
			print("[S3CatalogSync] Downloading manifest for user: \(userId)")
			var s3Manifest = try await downloadManifest(userId: userId)
			print("[S3CatalogSync] Downloaded manifest with \(s3Manifest.shardChecksums.count) shards")
			
			// Check each shard for updates
			let allShards = catalog.allShards
			let totalShards = Double(allShards.count)
			var processedShards = 0.0
			var manifestUpdated = false
			
			for shard in allShards {
				let shardIndex = shard.index
				let shardKey = String(format: "%x", shardIndex)
				let s3ShardChecksum = s3Manifest.shardChecksums[shardKey]
				let localChecksum = shard.s3Checksum
				let isModified = shard.isModified
				
				// Download if S3 has newer data
				if let s3Checksum = s3ShardChecksum, s3Checksum != localChecksum {
					do {
						syncStatusText = "Downloading shard \(shardKey.uppercased())..."
						let shardData = try await downloadShard(userId: userId, shardIndex: shardIndex)
						
						// Skip empty shards
						if !shardData.csv.isEmpty {
							let entries = parseCSV(shardData.csv)
							
							try catalogService.importShardFromS3(
								shard: shard,
								s3Entries: entries,
								checksum: shardData.checksum
							)
						}
					} catch {
						print("[S3CatalogSync] Failed to download shard \(shardIndex): \(error)")
						// Continue with other shards
					}
				}
				// Upload if we have local changes
				else if isModified {
					do {
						syncStatusText = "Uploading shard \(shardKey.uppercased())..."
						let csvContent = try await catalogService.exportShardToCSV(shard: shard)
						let checksum = catalogService.calculateChecksum(csvContent)
						
						try await uploadShard(
							userId: userId,
							shardIndex: shardIndex,
							csv: csvContent,
							checksum: checksum
						)
						
						// Update manifest
						s3Manifest.shardChecksums[shardKey] = checksum
						manifestUpdated = true
						
						// Update local state
						shard.s3Checksum = checksum
						try catalogService.clearShardModifications(shards: [shard])
					} catch {
						print("[S3CatalogSync] Failed to upload shard \(shardIndex): \(error)")
						// Continue with other shards
					}
				}
				
				processedShards += 1.0
				syncProgress = processedShards / totalShards
			}
			
			// Upload updated manifest if needed
			if manifestUpdated {
				syncStatusText = "Updating manifest..."
				s3Manifest.lastModified = Date()
				s3Manifest.photoCount = catalog.photoCount
				let newETag = try await uploadManifest(userId: userId, manifest: s3Manifest)
				s3Manifest.eTag = newETag
			}
			
			// Update catalog metadata
			catalog.s3ManifestETag = s3Manifest.eTag
			catalog.lastS3SyncDate = Date()
			try catalogService.saveContext()
			
			syncStatusText = "Sync complete"
			syncProgress = 1.0
		} catch {
			print("[S3CatalogSync] Failed to sync catalog: \(error)")
			lastError = error
			syncStatusText = "Sync failed: \(error.localizedDescription)"
			throw error
		}
	}
	
	// MARK: - Private Methods
	
	// These methods would need to be implemented with proper S3 access
	// For now, they're stubs that throw errors
	
	private func uploadShard(userId: String, shardIndex: Int, csv: String, checksum: String) async throws {
		// Use legacy format with .photolala subdirectory
		let shardKey = "catalogs/\(userId)/.photolala/\(String(format: "%x", shardIndex)).csv"
		let data = Data(csv.utf8)
		
		let putObjectInput = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "text/csv",
			key: shardKey,
			metadata: ["checksum": checksum]
		)
		
		_ = try await s3Client.putObject(input: putObjectInput)
		
		syncStatusText = "Uploaded shard \(String(format: "%X", shardIndex))"
	}
	
	private func downloadShard(userId: String, shardIndex: Int) async throws -> (csv: String, checksum: String) {
		// Use legacy format with .photolala subdirectory
		let shardKey = "catalogs/\(userId)/.photolala/\(String(format: "%x", shardIndex)).csv"
		
		do {
			let getObjectInput = GetObjectInput(
				bucket: bucketName,
				key: shardKey
			)
			
			let response = try await s3Client.getObject(input: getObjectInput)
			
			guard let body = response.body,
			      let data = try await body.readData() else {
				throw S3CatalogError.downloadFailed
			}
			
			let csv = String(data: data, encoding: .utf8) ?? ""
			let checksum = response.metadata?["checksum"] ?? ""
			
			syncStatusText = "Downloaded shard \(String(format: "%X", shardIndex))"
			
			return (csv, checksum)
		} catch {
			// Check if it's a not found error (shard doesn't exist)
			let errorDescription = error.localizedDescription.lowercased()
			if errorDescription.contains("nosuchkey") || errorDescription.contains("not found") {
				// Return empty shard - this is normal for unused shards
				return ("", "")
			}
			throw error
		}
	}
	
	private func downloadManifest(userId: String) async throws -> S3CatalogManifest {
		// Use legacy format
		let manifestKey = "catalogs/\(userId)/.photolala/manifest.plist"
		
		do {
			let getObjectInput = GetObjectInput(
				bucket: bucketName,
				key: manifestKey
			)
			
			let response = try await s3Client.getObject(input: getObjectInput)
			
			guard let body = response.body,
			      let data = try await body.readData() else {
				throw S3CatalogError.downloadFailed
			}
			
			// Parse legacy plist format
			let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
			
			// Convert legacy format to new format
			let manifest = S3CatalogManifest(
				version: plist?["version"] as? String ?? "6.0",
				directoryUUID: UUID().uuidString,
				lastModified: Date(),
				shardChecksums: plist?["shardChecksums"] as? [String: String] ?? [:],
				photoCount: plist?["photoCount"] as? Int ?? 0,
				eTag: response.eTag
			)
			
			return manifest
		} catch {
			// If manifest doesn't exist, create a new one
			// Check if the error description contains NoSuchKey
			let errorDescription = error.localizedDescription.lowercased()
			if errorDescription.contains("nosuchkey") || errorDescription.contains("not found") {
				return S3CatalogManifest(
					version: "6.0",
					directoryUUID: UUID().uuidString,
					lastModified: Date(),
					shardChecksums: [:],
					photoCount: 0,
					eTag: nil
				)
			}
			throw error
		}
	}
	
	private func uploadManifest(userId: String, manifest: S3CatalogManifest) async throws -> String {
		// Use legacy format
		let manifestKey = "catalogs/\(userId)/.photolala/manifest.plist"
		
		// Convert to plist format for legacy compatibility
		let plistDict: [String: Any] = [
			"version": manifest.version,
			"shardChecksums": manifest.shardChecksums,
			"photoCount": manifest.photoCount
		]
		let data = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
		
		let putObjectInput = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "application/json",
			key: manifestKey
		)
		
		let response = try await s3Client.putObject(input: putObjectInput)
		return response.eTag ?? ""
	}
	
	// Parse CSV into catalog entries
	private func parseCSV(_ csv: String) -> [PhotolalaCatalogService.CatalogEntry] {
		let lines = csv.components(separatedBy: .newlines)
		
		// Skip header if present
		let dataLines = if lines.first?.starts(with: "md5,") == true {
			Array(lines.dropFirst())
		} else {
			lines
		}
		
		return dataLines.compactMap { line in
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