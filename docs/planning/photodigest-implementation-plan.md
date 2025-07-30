# PhotoDigest Implementation Plan

## Overview

Implement the two-level cache architecture for PhotoDigest (unified thumbnail + metadata) across iOS, macOS, and Android platforms.

## Phase 1: Core Infrastructure (1-2 weeks)

### 1.1 Define PhotoDigest Data Structure

**iOS/macOS (Swift)**
```swift
struct PhotoDigest: Codable {
    let md5Hash: String
    let thumbnailData: Data
    let metadata: PhotoMetadata
    let createdAt: Date
    let lastAccessedAt: Date
}

struct PhotoMetadata: Codable {
    let filename: String
    let fileSize: Int64
    let pixelWidth: Int?
    let pixelHeight: Int?
    let creationDate: Date?
    let modificationTimestamp: Int  // Unix seconds
    let exifData: [String: Any]?
}
```

**Android (Kotlin)**
```kotlin
data class PhotoDigest(
    val md5Hash: String,
    val thumbnailData: ByteArray,
    val metadata: PhotoMetadata,
    val createdAt: Instant,
    val lastAccessedAt: Instant
)

data class PhotoMetadata(
    val filename: String,
    val fileSize: Long,
    val pixelWidth: Int?,
    val pixelHeight: Int?,
    val creationDate: Instant?,
    val modificationTimestamp: Long,  // Unix seconds
    val exifData: Map<String, Any>?
)
```

### 1.2 Path Identity Management

Create platform-specific implementations for path normalization:

**iOS/macOS**
```swift
extension String {
    var normalizedPath: String {
        return (self as NSString).standardizingPath
    }
    
    var pathMD5: String {
        return self.normalizedPath.lowercased().md5Hash
    }
}
```

**Android**
```kotlin
fun String.normalizedPath(): String {
    return File(this).canonicalPath
}

fun String.pathMD5(): String {
    return this.normalizedPath().lowercase().md5()
}
```

### 1.3 Cache Key Generation

Implement consistent cache key generation:
- Level 1: `{pathMD5}|{fileSize}|{modTimestamp}`
- Level 2: Content MD5 hash

## Phase 2: Level 1 Cache - Path to MD5 (1 week)

### 2.1 Memory Cache

**iOS/macOS**
```swift
class PathToMD5Cache {
    private var memoryCache: [String: String] = [:]
    private let cacheQueue = DispatchQueue(label: "path-md5-cache")
}
```

**Android**
```kotlin
class PathToMD5Cache {
    private val memoryCache = ConcurrentHashMap<String, String>()
}
```

### 2.2 Disk Persistence

Store as JSON file:
- iOS/macOS: `~/Library/Caches/com.electricwoods.photolala/path-to-md5-cache.json`
- Android: `context.cacheDir/path-to-md5-cache.json`

### 2.3 Cache Operations

- Get MD5 for path identity
- Set MD5 for path identity
- Invalidate on file change
- Batch save to disk

## Phase 3: Level 2 Cache - MD5 to PhotoDigest (1 week)

### 3.1 Memory Cache

**iOS/macOS**
```swift
class PhotoDigestCache {
    private let memoryCache = NSCache<NSString, PhotoDigest>()
}
```

**Android**
```kotlin
class PhotoDigestCache {
    private val memoryCache = LruCache<String, PhotoDigest>(maxSize)
}
```

### 3.2 Sharded Disk Storage

Directory structure:
```
photos/{first-2-chars}/
  ├── {md5}.dat     # Thumbnail data
  └── {md5}.json    # Metadata
```

### 3.3 Cache Operations

- Get PhotoDigest by MD5
- Store PhotoDigest
- Eviction policies
- Cleanup strategies

## Phase 4: Source-Specific Integration (2 weeks)

### 4.1 Local Files

- Direct file access
- Immediate MD5 computation
- Standard PhotoDigest creation

### 4.2 Apple Photos (iOS/macOS only)

- Temporary cache by localIdentifier
- Full PhotoDigest on star/backup
- Migration to MD5-based cache

### 4.3 S3 Photos

- Use catalog MD5
- Download and cache
- Separate cloud cache location

### 4.4 Android MediaStore

- Use content URI as identifier
- Handle permission changes
- Cache invalidation on updates

## Phase 5: Migration & Compatibility (1 week)

### 5.1 Existing Cache Migration

- Detect old cache structure
- Migrate thumbnails to new location
- Preserve user data
- Clean up old files

### 5.2 Backward Compatibility

- Support reading old cache
- Gradual migration
- Version detection

## Phase 6: Performance Optimization (1 week)

### 6.1 Concurrent Operations

- Increase loading concurrency (4 → 12)
- Parallel cache checks
- Async I/O operations

### 6.2 Memory Management

- Configure cache sizes
- Memory pressure handling
- Background cleanup

### 6.3 Startup Optimization

- Pre-warm recent folders
- Lazy initialization
- Progressive loading

## Phase 7: Testing & Monitoring (1 week)

### 7.1 Unit Tests

- Cache key generation
- Path normalization
- MD5 computation
- Cache operations

### 7.2 Integration Tests

- Cross-source deduplication
- Migration scenarios
- Performance benchmarks

### 7.3 Monitoring

- Cache hit rates
- Load times
- Memory usage
- Disk usage

## Platform-Specific Considerations

### iOS/macOS

- Use NSCache for automatic memory management
- FileManager for disk operations
- DispatchQueue for thread safety
- Photos framework integration

### Android

- Use LruCache for memory management
- File/Context APIs for disk operations
- Coroutines for async operations
- MediaStore integration

## Success Metrics

1. **Performance**
   - Thumbnail display < 100ms (cached)
   - Initial folder load < 2 seconds
   - 60 FPS scroll performance

2. **Efficiency**
   - Cache hit rate > 90%
   - Memory usage < 100MB
   - Disk cache < 1GB

3. **Reliability**
   - Zero data loss during migration
   - Graceful degradation
   - Cross-platform consistency

## Timeline Summary

- Week 1-2: Core infrastructure
- Week 3: Level 1 cache
- Week 4: Level 2 cache
- Week 5-6: Source integration
- Week 7: Migration
- Week 8: Optimization
- Week 9: Testing

Total: 9 weeks for full implementation across all platforms

## Next Steps

1. Review and approve design
2. Set up development branches
3. Implement Phase 1 data structures
4. Create unit test framework
5. Begin incremental implementation