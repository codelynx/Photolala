# Photo Loading Architecture

## Overview

Photolala uses a multi-layered approach to handle photo loading from directories, optimized for both small personal folders and large collections with 100K+ photos. The system combines immediate directory scanning, lazy loading, intelligent caching, and a catalog system for performance.

## Core Components

### 1. Directory Scanning Pipeline

```
User Opens Directory → CatalogAwarePhotoLoader
                            ↓
                    [.photolala catalog exists?]
                       ↙ Yes        ↘ No
              Load from Catalog    DirectoryScanner
                     ↓                    ↓
                PhotoFile[]          PhotoFile[]
                     ↓                    ↓
                Display Grid      Display Grid +
                                  Generate Catalog (background)
```

### 2. PhotoFile Lifecycle

#### Initial Creation (Lightweight)
```swift
PhotoFile(directoryPath: "/path", filename: "photo.jpg")
// Only stores paths - no I/O operations
```

#### On-Demand Loading
1. **Thumbnail Request** → Load/Generate thumbnail → Compute MD5 → Cache
2. **Metadata Request** → Extract EXIF → Cache to disk
3. **Full Image Request** → Load from disk → Memory cache

### 3. Catalog System (.photolala)

The catalog provides near-instant loading for previously scanned directories:

```
.photolala/
├── manifest.plist       # Version, UUID, checksums, stats
├── 0.csv               # Photos with MD5 starting with 0
├── 1.csv               # Photos with MD5 starting with 1
├── ...                 # 16 shards total (0-f)
└── f.csv               # Photos with MD5 starting with f
```

**CSV Format**: `md5,filename,size,photodate,modified,width,height`

### 4. Loading Flow for Large Directories

#### First Visit (No Catalog)
1. **Scan Phase** (synchronous)
   - FileManager lists all files
   - Filter by image extensions
   - Create PhotoFile objects (no I/O)
   - Display grid immediately

2. **Background Processing** (asynchronous)
   - Generate thumbnails for visible items
   - Compute MD5 hashes
   - Extract metadata
   - Create catalog for all directories

#### Subsequent Visits (With Catalog)
1. Load manifest.plist
2. Load CSV shards (parallel)
3. Create PhotoFile objects with pre-computed MD5
4. Display grid with cached thumbnails

### 5. Caching Strategy

#### Memory Caches (NSCache)
- **Images**: 16-64 items (RAM dependent)
- **Thumbnails**: 1000 items, 100MB max
- **Metadata**: Automatic sizing

#### Disk Cache

Target cache structure (to match S3):
```
~/Library/Caches/Photolala/cache/
├── [md5].dat                 # Thumbnail file (JPEG data in .dat container)
└── [md5].metadata.plist      # EXIF data
```

S3 storage structure:
```
s3://photolala-user-photos/
├── photos/
│   └── [userId]/
│       └── [md5].dat         # Original photo (encrypted)
└── thumbnails/
    └── [userId]/
        └── [md5].dat         # Thumbnail (encrypted)
```

Note: S3 requires userId in path for access control policies, while local cache uses flat structure with MD5 as unique identifier.

Future optimization for large local cache (from past discussions):
```
~/Library/Caches/Photolala/cache/
├── 00/                       # First 2 chars of MD5
│   ├── 00a1b2c3d4e5f6....dat           # Thumbnail
│   └── 00a1b2c3d4e5f6....metadata.plist # EXIF data
├── 01/
│   ├── 01d4e5f6789abc....dat
│   └── 01d4e5f6789abc....metadata.plist
└── ff/
    ├── ffa9b8c7d6e5f4....dat
    └── ffa9b8c7d6e5f4....metadata.plist
```
This reduces directory entry count for better filesystem performance with 256 subdirectories (00-ff).

### 6. Performance Optimizations

#### Lazy Loading
- File dates: Loaded on first sort/display
- MD5: Computed on first thumbnail generation
- Metadata: Extracted on inspector view

#### Concurrent Operations
- Thumbnail prefetch: 4 concurrent (low priority)
- Image prefetch: 2 concurrent (medium priority)
- Catalog generation: Background thread

#### Network Directories
- 5-minute cache for remote volumes
- Detect mounted volumes via `/Volumes/` prefix
- Directory UUID-based caching strategy:
  1. If `.photolala/manifest.plist` exists, use its `directoryUUID`
  2. Otherwise, use MD5 hash of canonical path
  3. Cache invalidated when UUID changes (directory modified elsewhere)
- Handles multiple mount points to same network location

### 7. Scalability Considerations

#### Current Limits
- **Good**: Up to 10K photos
- **Acceptable**: 10K-50K photos
- **Challenging**: 100K+ photos

#### Bottlenecks for Large Directories
1. **Initial scan is synchronous** - UI may freeze
2. **All PhotoFile objects in memory** - High RAM usage
3. **No pagination** - Entire directory loaded at once
4. **MD5 requires full file read** - Slow for large files

### 8. Priority System

Currently **implicit** rather than explicit:
- Collection view requests thumbnails for visible cells
- Each cell manages its own loading task
- Prefetching happens in background for off-screen items

## Proposed Improvements for 100K+ Photos

### 1. Progressive Loading
```swift
// Load in chunks
func loadDirectoryProgressive(batchSize: Int = 1000) async {
    for batch in files.chunked(by: batchSize) {
        let photoFiles = batch.map { PhotoFile(...) }
        await updateUI(append: photoFiles)
    }
}
```

### 2. Visible Item Priority Queue with Unified Processing
```swift
class PhotoProcessor {
    private var visibleQueue = PriorityQueue<PhotoFile>()
    private var backgroundQueue = Queue<PhotoFile>()

    func processPhoto(for photo: PhotoFile, priority: Priority) async {
        // Single file read for all operations
        let data = try await Data(contentsOf: photo.fileURL)

        // Process everything in one pass
        async let thumbnail = generateThumbnail(from: data)
        async let md5 = computeMD5(from: data)
        async let metadata = extractMetadata(from: data)

        // Store results
        photo.thumbnail = try await thumbnail
        photo.md5Hash = try await md5
        photo.metadata = try await metadata

        // Cache to disk
        saveThumbnail(photo.md5Hash, thumbnail)
        saveMetadata(photo.md5Hash, metadata)
    }
}
```
This unified approach reads the file once instead of three times, significantly improving I/O efficiency.

### 3. Virtual Scrolling
- Only create PhotoFile objects for visible range ± buffer
- Load additional items as user scrolls
- Unload items far from visible range

### 4. Streaming Catalog Generation
- Generate catalog while scanning
- Allow partial catalog usage
- Update catalog incrementally

## Network Directory Handling

### Remote Volume Detection
```swift
func isNetworkLocation(_ url: URL) -> Bool {
    // For v1, only check mounted volumes
    return url.path.hasPrefix("/Volumes/")
}
```

### Caching Strategy
- Cache catalog and thumbnails locally
- 5-minute validity for remote catalogs
- Directory UUID for change detection
- Invalidate on UUID mismatch

## Summary

The current architecture handles typical photo collections well through:
- Lightweight initial scanning
- Lazy loading of expensive operations
- Comprehensive caching system
- Catalog-based fast subsequent loads

For truly massive collections (100K+), the system would benefit from:
- Progressive/streaming directory loading
- Explicit visible item prioritization
- Virtual scrolling with object recycling
- Parallel catalog generation

The catalog system is the key enabler for performance across devices and network locations, turning expensive directory scans into simple CSV parsing operations.
