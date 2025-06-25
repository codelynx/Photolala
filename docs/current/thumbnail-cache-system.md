# Thumbnail Cache System

## Overview

The thumbnail cache system in Photolala uses a three-tier architecture to provide fast thumbnail loading while minimizing redundant computation. The system is designed to handle large photo collections efficiently by avoiding unnecessary MD5 hash calculations and file I/O operations.

## Architecture

### Three-Tier Cache Hierarchy

1. **Memory Cache (NSCache)**
   - Fastest access
   - Stores thumbnails by file path
   - Limited by available RAM
   - Cleared on memory pressure

2. **Metadata Cache (ThumbnailMetadataCache)**
   - Persistent JSON storage
   - Maps file paths to MD5 hashes
   - Validates using file size and modification date
   - Prevents redundant MD5 computation

3. **Disk Cache**
   - Stores actual thumbnail images
   - Organized by MD5 hash
   - Located in `~/Library/Caches/Photolala/`
   - Survives app restarts

## Key Components

### ThumbnailMetadataCache

A singleton service that manages persistent metadata for thumbnails:

```swift
struct ThumbnailMetadata: Codable {
    let filePath: String
    let md5Hash: String
    let fileSize: Int64
    let modificationDate: Date
    let lastAccessDate: Date
}
```

**Features:**
- Thread-safe with @MainActor
- Automatic cleanup of entries older than 30 days
- Validates metadata against current file attributes
- Batch saves to reduce disk I/O

### PhotoProcessor Integration

The PhotoProcessor checks for cached MD5 before reading files:

1. Check ThumbnailMetadataCache for valid MD5
2. If found, only read file for thumbnail generation
3. If not found, read file once for both MD5 and thumbnail
4. Store computed MD5 in metadata cache

### PhotoManager Enhancement

PhotoManager's `syncThumbnail` method now:
1. Checks memory cache first (by file path)
2. Checks metadata cache for MD5
3. Uses cached MD5 to check disk cache
4. Only computes MD5 if necessary

## Performance Characteristics

### Before Optimization
- Full file read for every cache miss
- MD5 computation on every thumbnail load
- ~1.0s per photo when reopening directories

### After Optimization
- File read only for thumbnail generation
- MD5 computation only for new/modified files
- ~0.1s per photo when reopening directories
- 10x performance improvement

## Cache Flow

```
1. Request thumbnail for file path
   ↓
2. Check memory cache (NSCache)
   ↓ (miss)
3. Check metadata cache for MD5
   ↓ (hit)
4. Use MD5 to check disk cache
   ↓ (hit)
5. Load thumbnail from disk
   ↓
6. Store in memory cache
   ↓
7. Return thumbnail
```

## File Locations

- **Metadata Cache**: `~/Library/Application Support/Photolala/thumbnail-metadata.json`
- **Disk Cache**: `~/Library/Caches/Photolala/local/thumbnails/{md5}`
- **Memory Cache**: In-process NSCache

## Maintenance

The system includes automatic maintenance:
- Metadata entries are validated on access
- Stale entries (30+ days) are cleaned up hourly
- Invalid entries (deleted files) are removed
- Cache size limits prevent unbounded growth

## Benefits

1. **Performance**: Near-instant thumbnail display for previously viewed photos
2. **Efficiency**: Minimal CPU usage for unchanged files
3. **Reliability**: Survives app restarts with persistent caches
4. **Scalability**: Handles large photo collections efficiently
5. **User Experience**: Smooth, responsive browsing

## Future Improvements

- Background pre-warming of frequently accessed directories
- Configurable cache size limits
- Export/import of metadata cache for backup
- Integration with cloud sync for shared caches