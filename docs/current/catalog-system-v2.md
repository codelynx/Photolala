# Photolala Catalog System v2 (SwiftData)

Last Updated: June 23, 2025

## Overview

The Photolala catalog system has been refactored to use SwiftData for local storage while maintaining CSV format for S3 compatibility. This hybrid approach provides better performance, richer metadata, and seamless synchronization with cloud storage.

## Architecture Overview

### Two-Tier System

1. **Local SwiftData Catalog**: Rich metadata storage with 16-shard architecture
2. **S3 CSV Catalog**: Master catalog in simple CSV format for cross-platform compatibility

### Key Principles

- **S3 as Master**: S3 catalog is always the source of truth
- **Local as Cache**: SwiftData catalog serves as a performance-optimized cache
- **Shard-Based Sync**: 16 independent shards enable efficient incremental updates
- **CSV Headers**: All CSV files include headers for future-proofing

## Catalog Format v5.1

### CSV Format

All CSV files now include headers:
```csv
md5,filename,size,photodate,modified,width,height,applephotoid
3a1b2c3d...,DSC_0001.jpg,2456789,1710504600,1710504600,4000,3000,
3f4e5d6c...,IMG_1234.jpg,1987654,1710598920,1710598920,3200,2400,apple-photo-abc123
```

Fields:
- `md5`: MD5 hash of file contents (hex string)
- `filename`: Original filename (CSV-escaped if needed)
- `size`: File size in bytes
- `photodate`: Photo taken date (Unix timestamp)
- `modified`: File modification date (Unix timestamp)
- `width`: Image width in pixels (optional)
- `height`: Image height in pixels (optional)
- `applephotoid`: Apple Photo Library ID (optional, v5.1 addition)

### Directory Structure

```
# Local SwiftData (hidden from user)
Application Support/com.electricwoods.photolala/
└── Photolala.sqlite

# S3 Structure
s3://photolala-photos/
└── catalogs/
    └── {userId}/
        └── .photolala/
            ├── manifest.plist
            ├── 0.csv
            ├── 1.csv
            ├── ...
            └── f.csv
```

## SwiftData Models

### PhotoCatalog
- Root entity representing a catalog for a directory
- Contains 16 CatalogShard properties (shard0-shardF)
- Tracks sync state and S3 manifest ETag

### CatalogShard
- Represents one of 16 shards (based on MD5 prefix)
- Contains PhotoEntry objects
- Tracks modification state and S3 checksum
- Enables per-shard sync operations

### PhotoEntry
- Individual photo metadata
- Core fields sync to S3 CSV
- Extended metadata stored locally only
- Backup status and star tracking

## Services

### PhotolalaCatalogServiceV2

The SwiftData-based catalog service (singleton as of June 23, 2025):

```swift
@MainActor
class PhotolalaCatalogServiceV2: ObservableObject {
    static let shared: PhotolalaCatalogServiceV2
    
    // Core operations
    func loadPhotoCatalog(for directoryURL: URL) async throws -> PhotoCatalog
    func upsertEntry(_ entry: CatalogPhotoEntry, in catalog: PhotoCatalog) throws
    func findPhotoEntry(md5: String, in catalog: PhotoCatalog) -> CatalogPhotoEntry?
    
    // Query methods
    func findByApplePhotoID(_ applePhotoID: String) async throws -> CatalogPhotoEntry?
    func findByMD5(_ md5: String) async throws -> CatalogPhotoEntry?
    
    // S3 sync support
    func exportShardToCSV(shard: CatalogShard) async throws -> String
    func importShardFromS3(shard: CatalogShard, s3Entries: [CatalogEntry]) throws
    
    // Persistence
    func save() async throws
    func findOrCreateCatalog(directoryPath: String) async throws -> PhotoCatalog
}
```

Key features:
- Singleton pattern to avoid SwiftData context issues
- Thread-safe with @MainActor
- Automatic shard selection based on MD5
- CSV export includes headers
- Support for Apple Photo ID queries

### S3CatalogSyncServiceV2

Manages synchronization between local SwiftData and S3:

```swift
actor S3CatalogSyncServiceV2 {
    // Main sync operation
    func syncCatalog(
        userId: String,
        forceRefresh: Bool = false,
        onProgress: @escaping (Double, String) -> Void
    ) async throws -> PhotoCatalog
    
    // S3 operations
    private func downloadManifest(userId: String) async throws -> CatalogManifest
    private func downloadShard(userId: String, shardName: String) async throws -> Data
    private func parseCSV(_ csv: String) -> [CatalogEntry]
}
```

Key features:
- Actor-based for thread safety
- Progress reporting during sync
- ETag-based change detection
- Handles legacy .photolala directory structure
- Automatic CSV header detection and skipping

### S3CatalogGenerator

Generates S3 catalogs with v5.1 format:

```swift
class S3CatalogGenerator {
    func generateCatalog(
        for photos: [S3Photo],
        userId: String,
        s3Service: S3BackupService
    ) async throws
}
```

Key changes:
- Always includes CSV headers
- Uses lowercase "applephotoid" field name
- Maintains 16-shard structure

## Sync Protocol

### Pull-First Strategy

1. Check S3 manifest for updates (ETag comparison)
2. Download only changed shards
3. Import S3 data into SwiftData (S3 wins conflicts)
4. Mark local shards as synced

### Change Detection

- **Manifest Level**: ETag comparison for quick change detection
- **Shard Level**: SHA256 checksum for content verification
- **Entry Level**: MD5 as unique identifier

### Conflict Resolution

S3 always wins:
- Local modifications are overwritten by S3 data
- Backup status determined by presence in S3
- Extended metadata is local-only

## UI Integration

### Sync Progress Display

S3PhotoBrowserView shows sync progress:
```swift
.overlay(alignment: .bottom) {
    if provider.isSyncing {
        VStack {
            ProgressView(value: provider.syncProgress)
            Text(provider.syncStatusText)
        }
        .padding()
        .background(.regularMaterial)
    }
}
```

### Observable Updates

Provider exposes sync state:
- `@Published var isSyncing: Bool`
- `@Published var syncProgress: Double`
- `@Published var syncStatusText: String`
- `@Published var lastSyncDate: Date?`
- `@Published var lastSyncError: Error?`

## Migration Path

### From CSV to SwiftData

1. **Detection**: Check for existing CSV catalog
2. **Import**: Parse CSV files into SwiftData
3. **Verify**: Compare counts and checksums
4. **Cleanup**: Remove old CSV files after successful import

### Backward Compatibility

- S3 catalogs remain in CSV format
- Headers added for forward compatibility
- Legacy catalogs without headers still supported

## Performance Optimizations

### Shard-Based Loading
- Load only needed shards
- 16-way distribution reduces memory usage
- Parallel shard processing

### Efficient Queries
- SwiftData indexing on MD5
- Direct shard access via computed property
- Batch updates with single save

### Background Processing
- Catalog generation off main thread
- Progressive photo loading continues during sync
- UI remains responsive

## Error Handling

### Network Errors
- Cached catalog used when offline
- Retry logic for transient failures
- User-friendly error messages

### Data Integrity
- Atomic shard updates
- Checksum verification
- Automatic catalog regeneration on corruption

### SwiftData Errors
- Context save retries
- Constraint violation handling
- Graceful degradation to CSV

## Testing Considerations

### Unit Testing
- Mock S3Service for sync logic
- In-memory SwiftData for fast tests
- CSV parsing edge cases

### Integration Testing
- Real S3 bucket testing
- Large catalog performance
- Concurrent access scenarios

### Manual Testing
- Upload photos and verify catalog generation
- Test offline mode with cached data
- Verify sync progress UI

## Future Enhancements

### Near Term
- Incremental sync (only changed entries)
- Compression for large catalogs
- Background sync scheduling

### Long Term
- CloudKit backup option
- Spotlight integration
- Advanced search queries
- Export to other formats

## Implementation Status

### Completed
- ✅ SwiftData models with 16-shard architecture
- ✅ PhotolalaCatalogServiceV2 implementation
- ✅ S3CatalogSyncServiceV2 with progress tracking
- ✅ CSV headers in all catalog files
- ✅ UI integration with sync progress
- ✅ S3PhotoProvider using V2 services

### In Progress
- 🔄 Conflict resolution UI
- 🔄 Migration from CSV to SwiftData

### Planned
- ⏳ Incremental sync optimization
- ⏳ Background sync scheduler
- ⏳ Performance monitoring

## Summary

The v2 catalog system successfully combines SwiftData's rich local storage with S3's simple CSV format. The 16-shard architecture enables efficient sync while maintaining compatibility with the existing S3 infrastructure. This hybrid approach provides the best of both worlds: performance and simplicity.