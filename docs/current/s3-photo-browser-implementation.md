# S3 Photo Browser Implementation

## Overview

The S3 photo browser provides a catalog-first browsing experience for photos stored in Amazon S3, avoiding expensive ListObjects API calls by using pre-generated .photolala catalog files.

## Architecture

### Core Components

1. **PhotolalaCatalogService** (`/Services/PhotolalaCatalogService.swift`)
   - Manages reading/writing of .photolala catalog files
   - Handles 16 sharded CSV files with MD5-based distribution
   - Maintains binary plist manifest with metadata
   - Thread-safe with actor-based implementation

2. **S3CatalogSyncService** (`/Services/S3CatalogSyncService.swift`)
   - Syncs catalog files from S3 using ETag-based change detection
   - Downloads only changed shards for efficiency
   - Manages local cache in `~/Library/Caches/com.electricwoods.photolala/cloud.s3/{userId}/`
   - Handles ByteStream data from AWS SDK properly

3. **S3DownloadService** (`/Services/S3DownloadService.swift`)
   - Downloads thumbnails and full photos from S3
   - Implements LRU cache with size-based eviction
   - Properly handles AWS SDK ByteStream (.data and .stream cases)
   - Thread-safe actor implementation

4. **S3PhotoBrowserView** (`/Views/S3PhotoBrowserView.swift`)
   - Main UI for browsing S3 photos
   - Grid layout with adjustable thumbnail sizes
   - Shows archive status badges
   - Supports multi-selection and context menus
   - Proper window sizing on macOS

### Data Models

1. **S3Photo** (`/Models/S3Photo.swift`)
   - Combines catalog entry data with S3 metadata
   - Computed properties for archive status and S3 paths
   - Implements Identifiable, Hashable, and Equatable

2. **S3MasterCatalog** (`/Models/S3MasterCatalog.swift`)
   - Tracks S3-specific metadata (storage class, archive dates)
   - JSON format for easy updates

## Debug Mode Implementation

For development without AWS credentials:

1. **TestCatalogGenerator** (`/Services/TestCatalogGenerator.swift`)
   - Generates test catalog with 10 sample photos
   - Creates realistic metadata with random dates and sizes
   - Randomly assigns some photos to DEEP_ARCHIVE status

2. **Debug Mode Features**
   - Hardcoded userId: "test-user-123"
   - Colored placeholder thumbnails based on MD5 hash
   - Simulated download delays
   - No AWS API calls required

## Key Implementation Details

### ByteStream Handling

Proper handling of AWS SDK v2 ByteStream responses:

```swift
switch body {
case .data(let data):
    resultData = data
case .stream(let stream):
    var result = Data()
    while true {
        guard let chunk = try await stream.readAsync(upToCount: 65536) else {
            break
        }
        result.append(chunk)
    }
    resultData = result
@unknown default:
    throw DownloadError.downloadFailed("Unknown ByteStream type")
}
```

### Window Sizing Fix

To allow proper window resizing on macOS:

```swift
// In S3PhotoBrowserView
#if os(macOS)
.frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
#endif

// In PhotolalaCommands
window.minSize = NSSize(width: 600, height: 400)
// No maxSize constraint
```

### Catalog Storage Paths (v5.0)

- **macOS**: `~/Library/Caches/com.electricwoods.photolala/cloud.s3/{userId}/.photolala/`
- **iOS**: `~/Library/Caches/cloud.s3/{userId}/.photolala/`
- **Sandboxed**: `~/Library/Containers/com.electricwoods.photolala/Data/Library/Caches/.../{userId}/.photolala/`

All catalog files are stored within the `.photolala/` subdirectory for cleaner organization.

### Manifest Updates (v5.0)

The catalog service now uses string version and includes directoryUUID:

```swift
struct CatalogManifest: Codable {
    let version: String           // "5.0"
    let directoryUUID: String?    // For cache invalidation
    let photoCount: Int
    let lastUpdated: Date
    let shardFiles: [String]
    let shardChecksums: [String: String]?
}
```

CSV format uses lowercase `photodate`:
```
md5,filename,size,photodate,modified,width,height
```

## Current Limitations

1. Archive restoration not yet implemented (placeholder in context menu)
2. Real S3 downloads only work with proper AWS credentials
3. No batch operations UI yet
4. Photo detail view not fully implemented

## Testing

To test the S3 browser in debug mode:

1. Build and run the app
2. Choose "Browse Cloud Backup" from File menu (⇧⌘O)
3. View will show 10 test photos with colored thumbnails
4. 3 photos will show as archived (gray badge)
5. Window can be resized freely
6. Context menus available via right-click

## Next Steps

1. Implement archive restoration functionality
2. Add batch operations for selected photos
3. Complete photo detail view implementation
4. Add progress indicators for downloads
5. Implement real-time sync status updates