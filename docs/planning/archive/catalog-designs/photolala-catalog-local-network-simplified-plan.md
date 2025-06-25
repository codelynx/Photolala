# Simplified .photolala Catalog Implementation Plan

## Overview

A focused implementation plan for using `.photolala` catalog files to speed up photo browsing in local and network directories. This plan prioritizes simplicity and essential features for the first release.

## Core Features Only

### 1. Catalog-Based Photo Loading
- Read existing `.photolala` catalog files if present
- Fall back to directory scanning if no catalog exists
- Generate catalogs in background for future use

### 2. Simple Caching for Network Directories
- Cache catalog data to improve performance on network drives
- No complex locking or multi-user support in v1
- If catalog is corrupted, simply regenerate it

### 3. Maintain Existing CSV Format
Keep the current format unchanged:
```
md5,filename,size,photodate,modified,width,height
```

## Caching Mechanism Details

### Cache Strategy
When accessing a network directory:

1. **First Access**
   ```
   Network Directory → Read .photolala → Store in Cache → Display Photos
   ```

2. **Subsequent Access**
   ```
   Check Cache → If valid (< 5 min old) → Use Cache
              → If stale → Read from Network → Update Cache
   ```



### Cache Storage
```
~/Library/Caches/com.electricwoods.photolala/catalogs/
├── {md5_of_directory_path}.cache    # Cached catalog data (JSON)
└── {md5_of_directory_path}.meta     # Cache metadata (timestamp, size)
```

[KY] some network directory points to the same directory but different path

[KY].photolala/
     ├── .manifest.plist         # Binary plist manifest
     ├── .photolala#0            # CSV shard 0
     ├── .photolala#1            # CSV shard 1

[KY] for identify this directory need unique id we may embbed UUID in manifest.plist

### Cache Validation
Cache is considered valid if:
- Cache file exists
- Cache age < 5 minutes (configurable)
- Source catalog file size/modification date unchanged

[KY] how about manual refresh?

### Why Cache?
- Network directories can have 100-500ms latency per file access
- Reading 16 shard files + manifest = 17 network round trips
- With caching: 1 local read vs 17 network reads
- Result: 10x-50x faster load times for network directories

[KY] but once catagog grow larger and larger then shed catalog has advantage
[KY] any browsing couple of hundred photo file, less people complatin about initial loading time, but loading 100K+ catalog, yah advantage i guess

## Implementation Approach

### Phase 1: Core Catalog Reader (3 days)

#### CatalogAwarePhotoLoader
```swift
class CatalogAwarePhotoLoader {
    private let catalogService = PhotolalaCatalogService()
    private let cacheService = CachedCatalogService.shared
    private let scanner = DirectoryScanner()

    func loadPhotos(from directory: URL) async throws -> [PhotoReference] {
        // 1. Check if catalog exists
        let catalogURL = directory.appendingPathComponent(".photolala")

        if FileManager.default.fileExists(atPath: catalogURL.path) {
            // Use catalog (with caching for network dirs)
            return try await loadFromCatalog(directory)
        } else {
            // Fall back to scanning
            let photos = try await scanner.scanDirectory(directory)

            // Generate catalog in background
            Task.detached(priority: .background) {
                try? await self.generateCatalog(for: directory, photos: photos)
            }

            return photos
        }
    }
}
```

### Phase 2: Network Optimization (2 days)

#### Simple Retry Logic
```swift
private func loadFromNetwork(_ url: URL, retries: Int = 3) async throws -> Data {
    for attempt in 0..<retries {
        do {
            return try Data(contentsOf: url)
        } catch {
            if attempt < retries - 1 {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            } else {
                throw error
            }
        }
    }
}
```

### Phase 3: UI Integration (2 days)

#### Loading States
- "Reading catalog..." - When loading from catalog
- "Scanning folder..." - When no catalog exists
- "Generating catalog..." - Background task indicator

#### PhotoCollectionViewController Changes
Replace:
```swift
let photos = try await DirectoryScanner.scan(directory)
```

With:
```swift
let loader = CatalogAwarePhotoLoader()
let photos = try await loader.loadPhotos(from: directory)
```

### Phase 4: Background Catalog Generation (2 days)

Generate catalogs without blocking UI:
1. Scan directory for image files
2. Calculate MD5 hashes
3. Extract image dimensions
4. Write catalog files

Skip catalog generation for:
- Directories with < 100 photos (scanning is fast enough)
- System directories
- Directories without write permission

### Phase 5: Testing (1 day)

Essential tests only:
1. **Local directory** - with/without catalog
2. **Network directory** - with/without catalog
3. **Cache hit/miss** scenarios
4. **Corrupted catalog** - should regenerate

## Success Criteria

1. **Performance**
   - 10K photos load in < 100ms from catalog (local)
   - 10K photos load in < 500ms from cached catalog (network)
   - Graceful fallback to scanning

2. **Reliability**
   - No data loss
   - Corrupted catalogs are regenerated automatically
   - Network timeouts handled gracefully

3. **User Experience**
   - Transparent to users
   - No UI blocking
   - Clear progress indicators

## What We're NOT Doing (v1)

- ❌ Delta files
- ❌ File locking for multi-user scenarios
- ❌ Extended metadata attributes
- ❌ Compression
- ❌ Complex conflict resolution
- ❌ Directory metadata files

## Timeline

**Total: 10 days**

- Days 1-3: Core catalog reader
- Days 4-5: Network optimization & caching
- Days 6-7: UI integration
- Days 8-9: Background generation
- Day 10: Testing & polish

## Next Steps

1. Create `CatalogAwarePhotoLoader.swift`
2. Integrate with `PhotoCollectionViewController`
3. Test with local directories first
4. Add network caching layer
5. Test with network directories

## Future Enhancements (v2+)

- Multi-user support with locking
- Incremental catalog updates
- Compression for network transfers
- Extended metadata (if needed)
