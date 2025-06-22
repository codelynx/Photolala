# SwiftData Local Catalog Refactoring Design

## Executive Summary

This design refactors Photolala's local catalog from CSV files to SwiftData while maintaining S3 compatibility. Key features:
- 16 individual CatalogShard entities (shard0-shardF) for clear sync tracking
- S3 remains the master catalog with 16 sharded CSV files
- Local SwiftData provides rich metadata and performance benefits
- Per-shard sync enables efficient incremental updates

## Overview

This document outlines the plan to refactor Photolala's local catalog system from the current CSV-based implementation to SwiftData. The local catalog serves as a cache of the S3 master catalog, with S3 always being the source of truth. This design uses 16 separate CatalogShard entities as individual properties for clearer tracking of which shards need S3 sync.

## Current Architecture

### Local Catalog (PhotolalaCatalogService)
- **Storage**: 16 sharded CSV files + binary plist manifest
- **Structure**: `.photolala/` directory containing:
  - `manifest.plist`: Binary plist with version, UUID, checksums, photo count
  - `0.csv` to `f.csv`: 16 sharded CSV files based on MD5 hash prefix
- **CSV Format**: `md5,filename,size,photodate,modified,width,height,applePhotoID`
- **Version**: v6.0 (always includes Apple Photo ID field - either empty or contains apple-photo-id)

### S3 Catalog
- **Storage**: 16 sharded CSV files per user (matching local structure)
- **Format**: Same CSV format as local catalog
- **Location**: `s3://bucket/catalogs/{userId}/shards/{0-f}.csv`
- **Manifest**: `s3://bucket/catalogs/{userId}/manifest.json`
- **Sync**: Managed by S3CatalogSyncService
- **Note**: S3 uses 16 sharded catalog (no backward compatibility concerns since not released yet)

## Proposed SwiftData Architecture

### Design Principles

1. **S3 as Master**: S3 catalog is always the source of truth, local is a cache
2. **S3 Compatibility**: S3 catalogs remain as CSV for simplicity and cross-platform compatibility
3. **No Migration**: Fresh implementation with no legacy support needed
4. **Performance**: Leverage SwiftData's indexing and query capabilities
5. **Metadata Rich**: Store additional metadata locally that doesn't sync to S3
6. **Conflict Resolution**: S3 always wins in case of conflicts
7. **Shard-Level Tracking**: Each of 16 shards is a separate SwiftData entity

### SwiftData Models

```swift
import SwiftData
import Foundation

@Model
final class PhotoCatalog {
    // Identity
    var directoryUUID: String
    var directoryPath: String

    // Metadata
    var version: String = "6.0"
    var createdDate: Date
    var modifiedDate: Date
    
    // Relationships - 16 separate shards
    @Relationship(deleteRule: .cascade) var shard0: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard1: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard2: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard3: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard4: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard5: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard6: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard7: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard8: CatalogShard?
    @Relationship(deleteRule: .cascade) var shard9: CatalogShard?
    @Relationship(deleteRule: .cascade) var shardA: CatalogShard?
    @Relationship(deleteRule: .cascade) var shardB: CatalogShard?
    @Relationship(deleteRule: .cascade) var shardC: CatalogShard?
    @Relationship(deleteRule: .cascade) var shardD: CatalogShard?
    @Relationship(deleteRule: .cascade) var shardE: CatalogShard?
    @Relationship(deleteRule: .cascade) var shardF: CatalogShard?

    // Sync metadata
    var lastS3SyncDate: Date?
    var s3ManifestETag: String? // S3 manifest ETag for change detection

    init(directoryPath: String) {
        self.directoryUUID = UUID().uuidString
        self.directoryPath = directoryPath
        self.createdDate = Date()
        self.modifiedDate = Date()
        
        // Initialize 16 empty shards
        self.shard0 = CatalogShard(index: 0, catalog: self)
        self.shard1 = CatalogShard(index: 1, catalog: self)
        self.shard2 = CatalogShard(index: 2, catalog: self)
        self.shard3 = CatalogShard(index: 3, catalog: self)
        self.shard4 = CatalogShard(index: 4, catalog: self)
        self.shard5 = CatalogShard(index: 5, catalog: self)
        self.shard6 = CatalogShard(index: 6, catalog: self)
        self.shard7 = CatalogShard(index: 7, catalog: self)
        self.shard8 = CatalogShard(index: 8, catalog: self)
        self.shard9 = CatalogShard(index: 9, catalog: self)
        self.shardA = CatalogShard(index: 10, catalog: self)
        self.shardB = CatalogShard(index: 11, catalog: self)
        self.shardC = CatalogShard(index: 12, catalog: self)
        self.shardD = CatalogShard(index: 13, catalog: self)
        self.shardE = CatalogShard(index: 14, catalog: self)
        self.shardF = CatalogShard(index: 15, catalog: self)
    }
    
    // Computed property for total photo count
    var photoCount: Int {
        let counts = [
            shard0?.photoCount ?? 0, shard1?.photoCount ?? 0, shard2?.photoCount ?? 0, shard3?.photoCount ?? 0,
            shard4?.photoCount ?? 0, shard5?.photoCount ?? 0, shard6?.photoCount ?? 0, shard7?.photoCount ?? 0,
            shard8?.photoCount ?? 0, shard9?.photoCount ?? 0, shardA?.photoCount ?? 0, shardB?.photoCount ?? 0,
            shardC?.photoCount ?? 0, shardD?.photoCount ?? 0, shardE?.photoCount ?? 0, shardF?.photoCount ?? 0
        ]
        return counts.reduce(0, +)
    }
    
    // Get shard for a given MD5
    func shard(for md5: String) -> CatalogShard? {
        guard let firstChar = md5.first,
              let hexValue = Int(String(firstChar), radix: 16) else {
            return nil
        }
        
        // Direct access by index - no searching needed
        switch hexValue {
        case 0: return shard0
        case 1: return shard1
        case 2: return shard2
        case 3: return shard3
        case 4: return shard4
        case 5: return shard5
        case 6: return shard6
        case 7: return shard7
        case 8: return shard8
        case 9: return shard9
        case 10: return shardA
        case 11: return shardB
        case 12: return shardC
        case 13: return shardD
        case 14: return shardE
        case 15: return shardF
        default: return nil
        }
    }
}

@Model
final class CatalogShard {
    // Identity
    var index: Int // 0-15
    
    // Content
    @Relationship(deleteRule: .cascade)
    var entries: [PhotoEntry]? = []
    
    // Sync tracking
    var isModified: Bool = false
    var lastModifiedDate: Date?
    var lastS3SyncDate: Date?
    var s3Checksum: String? // SHA256 of shard content on S3
    
    // Statistics
    var photoCount: Int = 0
    
    // Relationships
    var catalog: PhotoCatalog?
    
    **[CONCERN]**: Inverse relationship not explicitly defined. SwiftData should infer it, but may need @Relationship(inverse: \PhotoCatalog.shards)
    
    init(index: Int, catalog: PhotoCatalog? = nil) {
        self.index = index
        self.catalog = catalog
    }
    
    // Mark shard as modified
    func markModified() {
        self.isModified = true
        self.lastModifiedDate = Date()
    }
    
    // Clear modification flag after successful sync
    func clearModified() {
        self.isModified = false
        self.lastS3SyncDate = Date()
    }
}

**[CONCERN]**: PhotoEntry needs initializer for creating from code. SwiftData requires explicit init for non-optional properties
@Model
final class PhotoEntry {
    // Core fields (synced to S3)
    @Attribute(.unique) var md5: String
    var filename: String
    var fileSize: Int64
    var photoDate: Date
    var fileModifiedDate: Date
    var pixelWidth: Int?
    var pixelHeight: Int?
    var applePhotoID: String? // Only for Apple Photos source

    // Extended metadata (local only)
    var cameraMake: String?
    var cameraModel: String?
    var orientation: Int?
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var aperture: Double?
    var shutterSpeed: String?
    var iso: Int?
    var focalLength: Double?

    // Backup status (local only)
    var isStarred: Bool = false
    var backupStatus: BackupStatus = .notBackedUp
    var lastBackupAttempt: Date?
    var backupError: String?

    // Cached display values
    var cachedThumbnailDate: Date?
    var cachedPreviewDate: Date?

    // Relationships
    var shard: CatalogShard? // Direct relationship to shard

    // Computed properties
    var shardIndex: Int {
        guard let firstChar = md5.first,
              let hexValue = Int(String(firstChar), radix: 16) else {
            return 0
        }
        return hexValue
    }

    // CSV export support
    var csvLine: String {
        let widthStr = pixelWidth.map(String.init) ?? ""
        let heightStr = pixelHeight.map(String.init) ?? ""
        let photodateStr = String(Int(photoDate.timeIntervalSince1970))
        let modifiedStr = String(Int(fileModifiedDate.timeIntervalSince1970))
        let applePhotoIDStr = applePhotoID ?? ""

        let escapedFilename = filename.contains(",") || filename.contains("\"")
            ? "\"\(filename.replacingOccurrences(of: "\"", with: "\"\""))\""
            : filename

        return "\(md5),\(escapedFilename),\(fileSize),\(photodateStr),\(modifiedStr),\(widthStr),\(heightStr),\(applePhotoIDStr)"
    }
}

enum BackupStatus: Int, Codable {
    case notBackedUp = 0
    case queued = 1
    case uploading = 2
    case uploaded = 3
    case error = 4
}

// PhotoEntry initializer for SwiftData
extension PhotoEntry {
    init(md5: String, filename: String, fileSize: Int64, photoDate: Date, fileModifiedDate: Date) {
        self.md5 = md5
        self.filename = filename
        self.fileSize = fileSize
        self.photoDate = photoDate
        self.fileModifiedDate = fileModifiedDate
    }
}

// CatalogEntry for CSV parsing
struct CatalogEntry {
    let md5: String
    let filename: String
    let size: Int64
    let photodate: Date
    let modified: Date
    let width: Int?
    let height: Int?
    let applePhotoID: String?
    
    init?(csvLine: String) {
        // Parse CSV line into properties
        // Implementation from existing PhotolalaCatalogService
        // Return nil if parsing fails
        // ... (actual parsing logic to be implemented)
        return nil // Placeholder
    }
}
```

### S3 Master Catalog Strategy

Since S3 is the master catalog with 16 shards:

1. **Pull-First**: Always check S3 manifest for updates before local modifications
2. **Shard-Level Tracking**: Each CatalogShard tracks its own modification state
3. **Conflict Resolution**: S3 always wins - local changes are discarded if S3 has newer data
4. **Efficient Sync**: Only sync modified shards, compare checksums to detect changes

### New PhotolalaCatalogService Implementation

```swift
@MainActor
class PhotolalaCatalogService {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init() throws {
        let schema = Schema([
            PhotoCatalog.self,
            CatalogShard.self,
            PhotoEntry.self
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
    func upsertEntry(_ entry: PhotoEntry, in catalog: PhotoCatalog) throws {
        // Get the appropriate shard
        guard let shard = catalog.shard(for: entry.md5) else {
            throw CatalogError.invalidMD5
        }
        
        // Check if entry exists (single fetch)
        let descriptor = FetchDescriptor<PhotoEntry>(
            predicate: #Predicate { $0.md5 == entry.md5 }
        )
        
        // Note: Single fetch to avoid performance issues, but if this adds complexity, optimize later
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
            **[CONCERN]**: photoCount increment not atomic. If save fails, count could be incorrect
            shard.photoCount += 1
        }

        // Mark shard as modified
        shard.markModified()
        catalog.modifiedDate = Date()

        try modelContext.save()
    }
    
    // Export specific shard to CSV for S3 sync
    func exportShardToCSV(shard: CatalogShard) async throws -> String {
        let entries = shard.entries ?? []
        
        let sortedEntries = entries.sorted { $0.md5 < $1.md5 }
        let csvLines = sortedEntries.map { $0.csvLine }
        
        return csvLines.joined(separator: "\n")
    }

    // Get all modified shards
    func getModifiedShards(catalog: PhotoCatalog) -> [CatalogShard] {
        let allShards = [
            catalog.shard0, catalog.shard1, catalog.shard2, catalog.shard3,
            catalog.shard4, catalog.shard5, catalog.shard6, catalog.shard7,
            catalog.shard8, catalog.shard9, catalog.shardA, catalog.shardB,
            catalog.shardC, catalog.shardD, catalog.shardE, catalog.shardF
        ]
        return allShards.compactMap { $0 }.filter { $0.isModified }
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
    func importShardFromS3(shard: CatalogShard, s3Entries: [CatalogEntry], checksum: String) throws {
        // Clear existing entries in this shard only
        // Note: Star status means photo has copy in S3, so S3 catalog wins - clearing is correct
        shard.entries?.removeAll()
        shard.photoCount = 0
        
        // Import all S3 entries for this shard
        for s3Entry in s3Entries {
            **[ERROR]**: PhotoEntry() won't compile - needs proper initializer with required fields
            let entry = PhotoEntry()
            entry.md5 = s3Entry.md5
            entry.filename = s3Entry.filename
            entry.fileSize = s3Entry.size
            entry.photoDate = s3Entry.photodate
            entry.fileModifiedDate = s3Entry.modified
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
    
    // Save context helper
    func saveContext() async throws {
        try modelContext.save()
    }
    
    enum CatalogError: Error {
        case invalidMD5
    }
}
```

## S3 Sync Integration

### Efficient Shard-Based Sync

```swift
class S3CatalogSyncService {
    private let catalogService: PhotolalaCatalogService
    private let s3Service: S3BackupService

    // Sync with S3 master catalog
    func syncWithS3(catalog: PhotoCatalog, userId: String) async throws {
        // Download S3 manifest
        let s3Manifest = try await s3Service.downloadManifest(userId: userId)
        
        // Check each shard for updates
        let allShards = [
            catalog.shard0, catalog.shard1, catalog.shard2, catalog.shard3,
            catalog.shard4, catalog.shard5, catalog.shard6, catalog.shard7,
            catalog.shard8, catalog.shard9, catalog.shardA, catalog.shardB,
            catalog.shardC, catalog.shardD, catalog.shardE, catalog.shardF
        ].compactMap { $0 }
        
        for shard in allShards {
            **[CONCERN]**: shardChecksums uses String keys ("0"-"15") but could use hex format ("0"-"f") - need consistency
        let s3ShardChecksum = s3Manifest.shardChecksums[String(shard.index)]
            
            // Download if S3 has newer data
            **[CONCERN]**: What if S3 shard doesn't exist (nil checksum)? Need to handle empty shards
            if s3ShardChecksum != shard.s3Checksum {
                let shardData = try await downloadShard(userId: userId, shardIndex: shard.index)
                let entries = parseCSV(shardData.csv)
                try catalogService.importShardFromS3(
                    shard: shard,
                    s3Entries: entries,
                    checksum: shardData.checksum
                )
            }
            // Upload if we have local changes
            else if shard.isModified {
                let csvContent = try await catalogService.exportShardToCSV(shard: shard)
                let checksum = calculateChecksum(csvContent)
                
                // Note: We upload incrementally at shard level (16 sharded bodies)
                do {
                    try await uploadShard(
                        userId: userId,
                        shardIndex: shard.index,
                        csv: csvContent,
                        checksum: checksum
                    )
                    
                    shard.s3Checksum = checksum
                    try catalogService.clearShardModifications(shards: [shard])
                } catch {
                    // Note: Just log errors for now
                    print("[S3CatalogSync] Failed to upload shard \(shard.index): \(error)")
                }
            }
        }
        
        // Update manifest
        catalog.s3ManifestETag = s3Manifest.eTag
        catalog.lastS3SyncDate = Date()
        **[CONCERN]**: These updates happen outside modelContext.save() - need to ensure they persist
    }
    
    // Upload individual shard
    private func uploadShard(userId: String, shardIndex: Int, csv: String, checksum: String) async throws {
        let shardKey = "catalogs/\(userId)/shards/\(String(format: "%x", shardIndex)).csv"
        try await s3Service.uploadData(
            Data(csv.utf8),
            key: shardKey,
            contentType: "text/csv"
        )
        
        // Update manifest with new checksum
        try await s3Service.updateManifestChecksum(
            userId: userId,
            shardIndex: shardIndex,
            checksum: checksum
        )
    }
    
    // Download individual shard
    private func downloadShard(userId: String, shardIndex: Int) async throws -> (csv: String, checksum: String) {
        let shardKey = "catalogs/\(userId)/shards/\(String(format: "%x", shardIndex)).csv"
        let data = try await s3Service.downloadData(key: shardKey)
        let csv = String(data: data, encoding: .utf8) ?? ""
        let checksum = calculateChecksum(csv)
        return (csv, checksum)
    }
    
    private func calculateChecksum(_ content: String) -> String {
        // Implementation for SHA256 checksum
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func parseCSV(_ csv: String) -> [CatalogEntry] {
        // Implementation to parse CSV into CatalogEntry objects
        **[MISSING]**: Need actual CSV parsing implementation from PhotolalaCatalogService
        return []
    }
}
```

## Benefits of 16-Shard Design

### Clear Sync State
1. **Per-Shard Tracking**: Each shard knows if it's modified
2. **No Bitmask Complexity**: Direct boolean flag instead of bit manipulation
3. **Scalable**: Easy to add more shards by changing initialization

### Performance Benefits
1. **Parallel Sync**: Can sync multiple shards concurrently
2. **Minimal Data Transfer**: Only sync modified shards
3. **Efficient Queries**: SwiftData can optimize shard-specific queries

### Developer Experience
1. **Intuitive Model**: Shards are first-class entities
2. **Clear Relationships**: PhotoEntry → CatalogShard → PhotoCatalog
3. **Simple State Management**: Each shard manages its own state

## Implementation Considerations

### Concurrent Sync
```swift
// Sync multiple shards in parallel
await withTaskGroup(of: Void.self) { group in
    for shard in modifiedShards {
        group.addTask {
            await syncShard(shard)
        }
    }
}
```

### Error Recovery
- If a shard sync fails, only that shard remains marked as modified
- Other shards can sync successfully
- Failed shards retry on next sync

### Local-Only Data Preservation
- When importing from S3, star status is determined by presence in S3 (star means photo has copy in S3)
- Extended metadata (EXIF, etc.) is lost on S3 import
- This is acceptable since S3 is the source of truth and wins in all conflicts

## Implementation Plan

### Phase 1: Core Models and Infrastructure
- Define SwiftData models with 16 individual shard properties
- Create PhotoEntry initializer for required fields
- Implement CatalogEntry CSV parsing from existing code
- Set up ModelContainer configuration
- Add unit tests for models

### Phase 2: Catalog Service Implementation
- Rewrite PhotolalaCatalogService with SwiftData
- Implement CRUD operations for entries
- Add shard-based CSV export functionality
- Create helper methods for context management
- Performance testing with large catalogs

### Phase 3: S3 Sync Integration
- Update S3CatalogSyncService for shard-based sync
- Implement checksum calculation and comparison
- Add proper error handling and logging
- Test incremental sync with modified shards
- Verify manifest update process

### Phase 4: System Integration
- Update PhotoProvider implementations
- Modify BackupQueueManager for SwiftData
- Update UI to observe SwiftData changes
- Integration testing across all components
- Performance benchmarking

### Phase 5: Deployment
- Feature flag for gradual rollout
- Beta testing with real data
- Monitor performance and memory usage
- Address any issues before full release

## Risks and Mitigations

### Risk 1: Data Loss During Sync
- **Mitigation**: Always backup local changes before S3 sync

### Risk 2: Performance Regression
- **Mitigation**: Benchmark before/after, optimize queries

### Risk 3: Local Metadata Loss
- **Mitigation**: Accept that S3 is master, star status determined by S3 presence

### Risk 4: Network Interruption
- **Mitigation**: Per-shard sync allows partial success, failed shards retry

### Risk 5: SwiftData Bugs
- **Mitigation**: Thorough testing, gradual rollout

### Risk 6: Concurrent Access
- **Mitigation**: SwiftData handles concurrency, but monitor for issues

## Success Metrics

1. **Performance**: Only modified shards are synced
2. **Clarity**: Clear which shards need sync
3. **Reliability**: Per-shard error handling
4. **Simplicity**: No complex bit manipulation

## Additional Implementation Notes

### Thread Safety
- **[CONCERN]**: @MainActor on PhotolalaCatalogService means all operations on main thread. Consider background processing for large catalogs.

### Memory Management  
- **[CONCERN]**: Loading all entries for a shard into memory. Large shards could cause memory pressure.

### Error States
- **[MISSING]**: No handling for corrupted CSV data or malformed entries.
- **[MISSING]**: No retry mechanism for transient S3 failures.

### Testing Considerations
- **[CONCERN]**: SwiftData models are hard to unit test. Need integration tests.
- **[MISSING]**: Mock S3Service for testing sync logic.

## Future Enhancements

1. **Performance Optimization**: Background context for large operations
2. **CloudKit Sync**: Optional iCloud backup of catalogs
3. **Spotlight Integration**: System-wide photo search
4. **Advanced Queries**: Complex filtering and search capabilities
5. **Export Options**: Support for different catalog formats

## Conclusion

Using 16 separate CatalogShard entities provides a cleaner, more maintainable design that makes it obvious which shards need to be synced with S3. This approach leverages SwiftData's strengths while maintaining compatibility with the S3 sharded catalog structure.