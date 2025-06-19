# Photolala Catalog System

Last Updated: June 19, 2025

## Overview

The Photolala catalog system enables fast photo browsing by pre-indexing directory contents into efficient catalog files. This is particularly beneficial for network drives and directories with large numbers of photos.

## Catalog Format v5.0

### Directory Structure

All catalog files are stored in a `.photolala/` subdirectory:

```
/path/to/photos/
└── .photolala/
    ├── manifest.plist
    ├── 0.csv
    ├── 1.csv
    ├── 2.csv
    ├── ...
    └── f.csv
```

### Manifest Format

The `manifest.plist` contains catalog metadata:

```swift
struct CatalogManifest: Codable {
    let version: String           // "5.0"
    let directoryUUID: String     // Unique identifier for cache invalidation
    let photoCount: Int           // Total number of photos
    let lastUpdated: Date         // When catalog was created
    let shardFiles: [String]      // List of shard files (e.g., ["0.csv", "3.csv", "f.csv"])
}
```

### CSV Shard Format

Photos are distributed across 16 CSV files based on MD5 hash:
- Shard selection: First character of MD5 hash (0-f)
- CSV format: `md5,filename,size,photodate,modified,width,height`

Example `3.csv`:
```csv
3a1b2c3d...,DSC_0001.jpg,2456789,2024-03-15T10:30:00,2024-03-15T10:30:00,4000,3000
3f4e5d6c...,IMG_1234.jpg,1987654,2024-03-16T14:22:00,2024-03-16T14:22:00,3200,2400
```

Fields:
- `md5`: MD5 hash of file contents (hex string)
- `filename`: Original filename
- `size`: File size in bytes
- `photodate`: Photo taken date (ISO 8601) or empty
- `modified`: File modification date (ISO 8601)
- `width`: Image width in pixels
- `height`: Image height in pixels

## CatalogAwarePhotoLoader

The `CatalogAwarePhotoLoader` provides intelligent photo loading with automatic fallback:

### Loading Strategy

1. Check if `.photolala/manifest.plist` exists
2. If catalog exists:
   - Load manifest
   - Read only the shard files listed in manifest
   - Create PhotoReference objects from catalog data
3. If no catalog:
   - Fall back to DirectoryScanner
   - For directories with 100+ photos, trigger background catalog generation

### Network Directory Caching

For network directories (SMB, AFP, etc.):
- Cache loaded photos for 5 minutes
- Use directory UUID as cache key
- Automatic cache invalidation on UUID change

### Background Catalog Generation

Triggered when:
- Directory has 100+ photos
- No existing catalog
- Not already generating

Generation process:
- Runs on background queue
- Creates catalog while app continues to work
- Next directory open will use the catalog

## S3 Integration

### S3 Catalog Storage

S3 catalogs use the same v5.0 format:
```
catalogs/
└── {userId}/
    └── .photolala/
        ├── manifest.plist
        ├── 0.csv
        ├── 1.csv
        └── ...
```

### S3CatalogGenerator

- Generates catalogs from S3 photo metadata
- Uploads to `catalogs/{userId}/.photolala/` path
- Updates manifest with shard information

### S3CatalogSyncService

- Downloads catalog from S3 to local cache
- Atomic updates using temporary directory
- Manifest-based change detection
- Supports offline mode

## Performance Benefits

1. **Instant Directory Listing**: No need to scan filesystem
2. **Reduced Network Traffic**: One-time catalog download vs repeated directory scans
3. **Scalability**: 16-way sharding handles millions of photos efficiently
4. **Cache Efficiency**: UUID-based invalidation ensures fresh data
5. **Background Processing**: Catalog generation doesn't block UI

## Implementation Details

### Atomic Updates

Catalog updates are atomic to prevent corruption:
1. Download/generate to temporary directory
2. Verify all files present
3. Atomic rename of directory
4. Clean up old catalog if needed

### Error Handling

- Missing shards are logged but don't fail loading
- Corrupted CSV lines are skipped
- If catalog is unusable, falls back to directory scanning
- "If corrupted then just recreate" policy

### Platform Compatibility

- Works on all platforms (macOS, iOS, tvOS)
- FileManager operations are platform-agnostic
- CSV parsing uses standard Swift APIs

## Future Considerations

- Incremental updates (not in v5.0)
- Compression for large catalogs
- Extended metadata fields
- Catalog integrity verification