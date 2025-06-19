# .photolala Catalog Enhancement for Local/Network Directories

## Overview

This document outlines enhancements to the `.photolala` catalog format to better support local and network directories, with a focus on performance, reliability, and multi-user scenarios.

## Current Implementation Status

The PhotolalaCatalogService already implements:
- ✅ 16-way hash-based sharding for scalability
- ✅ CSV format for human readability
- ✅ Binary plist manifest with checksums
- ✅ Atomic updates using FileManager.replaceItem
- ✅ Location-agnostic design (works with any storage)

## Proposed Enhancements

### 1. Network Performance Optimization

#### A. Smart Caching Layer
```swift
class CachedCatalogService {
    private let cache: URL = .cachesDirectory
        .appendingPathComponent("com.electricwoods.photolala")
        .appendingPathComponent("catalogs")

    func getCachedCatalog(for directory: URL) -> PhotolalaCatalog? {
        let cacheKey = directory.path.md5Hash
        let cachedURL = cache.appendingPathComponent("\(cacheKey).cache")

        // Check if cached version is still valid
        if let cached = loadCachedCatalog(from: cachedURL),
           isStillValid(cached, for: directory) {
            return cached
        }

        return nil
    }
}
```

#### B. Differential Sync
Instead of rewriting entire shards for small changes:
```
.photolala#0.delta    # Contains only changes since last full write
```

[KY] we have discussion that not .delta this time

### 2. Multi-User Support

#### A. File Locking Strategy
```swift
extension PhotolalaCatalogService {
    func updateWithLocking(_ updates: [PhotoMetadata]) throws {
        let lockFile = catalogURL.appendingPathExtension("lock")

        // Acquire lock with timeout
        try acquireLock(lockFile, timeout: 5.0)
        defer { releaseLock(lockFile) }

        // Perform update
        try update(updates)
    }
}
```

[KY] i like to start wil simple,may be for future version

#### B. Conflict Resolution
- Track last-modified timestamps per entry
- Implement three-way merge for concurrent edits
- Optional: user-specific delta files

[KY] no worry for simultanious access for this version, if corrupted then just recreate policty for the first release

### 3. Network Resilience

#### A. Retry Logic
```swift
func readFromNetwork(url: URL, maxRetries: Int = 3) throws -> Data {
    var lastError: Error?

    for attempt in 0..<maxRetries {
        do {
            return try Data(contentsOf: url)
        } catch {
            lastError = error
            if attempt < maxRetries - 1 {
                Thread.sleep(forTimeInterval: pow(2.0, Double(attempt))) // Exponential backoff
            }
        }
    }

    throw NetworkError.retriesFailed(lastError!)
}
```

#### B. Partial Read Support
For slow networks, read only needed shards:
```swift
func getPhotosInShard(_ shardIndex: Int) throws -> [PhotoMetadata] {
    let shardURL = baseURL.appendingPathComponent(".photolala#\(String(format: "%x", shardIndex))")
    return try parseCSVShard(at: shardURL)
}
```

### 4. Enhanced Metadata

#### A. Extended Attributes
Store network-specific metadata:
```csv
# photolala v5.0
filename,size,modified,md5,width,height,photodate,owner,permissions
IMG_0129.jpg,2048576,1718445000,d41d8cd98f00b204e9800998ecf8427e,4032,3024,1718445000,user1,rw-r--r--
```

[KY] CSV format should be the same, drop unnecessary attributes where possible

#### B. Directory Metadata
New `.photolala.meta` file for directory-level info:
```json
{
    "version": "5.0",
    "location": {
        "type": "network",
        "protocol": "smb",
        "server": "nas.local",
        "share": "Photos"
    },
    "capabilities": {
        "supportsConcurrentAccess": true,
        "supportsExtendedAttributes": false
    },
    "performance": {
        "averageLatency": 25,
        "recommendedCacheStrategy": "aggressive"
    }
}
```

[KY] less important, can be added for future version

### 5. Performance Monitoring

#### A. Catalog Statistics
Track performance metrics:
```swift
struct CatalogStats {
    let totalPhotos: Int
    let catalogSize: Int
    let lastFullScan: Date
    let averageReadTime: TimeInterval
    let networkLatency: TimeInterval?
}
```

[KY] is this necessary? size can be from csv, count can be form csv, drop if we can

#### B. Adaptive Behavior
- Switch to cached mode if network latency > 100ms
- Use delta files if catalog > 10MB
- Enable compression for slow networks

## Implementation Plan

### Phase 1: Core Network Enhancements (Week 1)
1. Implement smart caching layer
2. Add retry logic with exponential backoff
3. Create network performance monitoring

[KY] i like to know the mechnims of cachiing a bit more detail write in somwhere in this doc

### Phase 2: Multi-User Support (Week 2)
1. Implement file locking mechanism
2. Add conflict detection
3. Create merge resolution UI

[KY] drop if we can, i necessary very last phase

### Phase 3: Advanced Features (Week 3)
1. Delta file support
2. Extended metadata attributes
3. Directory metadata file

[KY] no delta, no extended metadata attributes (show me if there)

### Phase 4: Testing & Optimization (Week 4)
1. Test with various network conditions
2. Optimize for common NAS devices
3. Create performance benchmarks

## Testing Strategy

### Network Simulation
```bash
# Simulate slow network
sudo tc qdisc add dev en0 root netem delay 100ms

# Simulate packet loss
sudo tc qdisc add dev en0 root netem loss 5%
```
[KY] ???

### Test Scenarios
1. **High Latency**: 200ms+ round trip
2. **Unstable Connection**: 10% packet loss
3. **Concurrent Access**: 5 users editing simultaneously
4. **Large Catalogs**: 1M+ photos
5. **Mixed Storage**: Local + Network in same session

## Migration Path

1. Existing v4.0 catalogs remain compatible
2. New features are opt-in via preferences
3. Automatic upgrade when first network issue detected
4. Backward compatibility maintained

## Success Metrics

- Network catalog read time < 500ms for 10K photos
- Zero data loss in multi-user scenarios
- 90% reduction in network traffic via caching
- Graceful degradation when offline

## Future Considerations

- WebDAV support for cloud storage
- Distributed catalog sync (peer-to-peer)
- Real-time collaboration features
- Blockchain-based conflict resolution (just kidding)
