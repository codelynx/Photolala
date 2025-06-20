# Refactoring Implementation Plan

## Overview

This plan addresses the gaps identified in the implementation gap analysis, prioritizing high-impact changes that improve performance without breaking existing functionality.

## Phase 1: Foundation Fixes (Week 1)

### 1.1 Universal Catalog Generation
**File**: `CatalogAwarePhotoLoader.swift`
**Change**: Remove 100+ photo threshold
```swift
// Before:
if photos.count >= 100 {
    Task.detached(priority: .background) {
        try? await self.generateCatalog(for: directory, photos: photos)
    }
}

// After:
Task.detached(priority: .background) {
    try? await self.generateCatalog(for: directory, photos: photos)
}
```
**Impact**: Consistent behavior, better network performance

### 1.2 Fix Thumbnail File Extension
**File**: `PhotoManager.swift`
**Change**: Use `.dat` extension to match S3
```swift
// Before:
func thumbnailURL(for identifier: Identifier) -> URL {
    let fileName = identifier.string + ".jpg"
    
// After:
func thumbnailURL(for identifier: Identifier) -> URL {
    let fileName = identifier.string.replacingOccurrences(of: "#", with: "_") + ".dat"
```
**Impact**: Consistency with S3 storage format

### 1.3 Create PhotoProcessor Base
**New File**: `PhotoProcessor.swift`
```swift
import Foundation
import CryptoKit

@MainActor
class PhotoProcessor {
    struct ProcessedData {
        let thumbnail: XImage
        let md5: String
        let metadata: PhotoMetadata
    }
    
    static func processPhoto(_ photo: PhotoFile) async throws -> ProcessedData {
        // Single file read
        let data = try Data(contentsOf: photo.fileURL)
        
        // Parallel processing
        async let thumbnail = generateThumbnail(from: data)
        async let md5 = computeMD5(from: data)
        async let metadata = extractMetadata(from: data)
        
        return ProcessedData(
            thumbnail: try await thumbnail,
            md5: try await md5,
            metadata: try await metadata
        )
    }
}
```

## Phase 2: Performance Core (Week 2)

### 2.1 Priority Queue System
**New File**: `ThumbnailLoader.swift`
```swift
actor ThumbnailLoader {
    private var visibleQueue: [(PhotoFile, CheckedContinuation<XImage?, Error>)] = []
    private var prefetchQueue: [(PhotoFile, CheckedContinuation<XImage?, Error>)] = []
    private var activeTasks = 0
    private let maxConcurrent = 4
    
    enum Priority {
        case visible    // User can see
        case adjacent   // Next to visible
        case prefetch   // Background loading
    }
    
    func requestThumbnail(for photo: PhotoFile, priority: Priority) async throws -> XImage? {
        // Implementation
    }
}
```

### 2.2 Progressive Directory Loading
**File**: `DirectoryScanner.swift`
**Enhancement**: Add batch loading support
```swift
static func scanDirectoryProgressive(
    atPath path: NSString,
    batchSize: Int = 1000,
    onBatch: @escaping ([PhotoFile]) async -> Void
) async throws {
    let enumerator = FileManager.default.enumerator(atPath: path as String)
    var batch: [PhotoFile] = []
    
    while let filename = enumerator?.nextObject() as? String {
        if isImageFile(filename) {
            let photo = PhotoFile(directoryPath: path, filename: filename)
            batch.append(photo)
            
            if batch.count >= batchSize {
                await onBatch(batch)
                batch.removeAll(keepingCapacity: true)
            }
        }
    }
    
    if !batch.isEmpty {
        await onBatch(batch)
    }
}
```

### 2.3 Integrate PhotoProcessor
**Update**: `PhotoManager.swift`
```swift
func loadThumbnail(for photo: PhotoFile) async throws -> XThumbnail? {
    // Check cache first
    if let md5 = photo.md5Hash,
       let cached = thumbnailCache.object(forKey: md5 as NSString) {
        return cached
    }
    
    // Use PhotoProcessor for unified loading
    let processed = try await PhotoProcessor.processPhoto(photo)
    
    // Update photo object
    photo.md5Hash = processed.md5
    photo.metadata = processed.metadata
    
    // Cache results
    cacheThumbnail(processed.thumbnail, for: processed.md5)
    cacheMetadata(processed.metadata, for: photo.filePath)
    
    return processed.thumbnail
}
```

## Phase 3: Scale Optimizations (Week 3-4)

### 3.1 Virtual Scrolling Support
**New File**: `VirtualPhotoProvider.swift`
```swift
class VirtualPhotoProvider: PhotoProvider {
    private let windowSize = 5000
    private var allPhotoURLs: [URL] = []
    private var loadedPhotos: [Int: PhotoFile] = [:]
    private var currentRange: Range<Int>?
    
    func photosForRange(_ range: Range<Int>) -> [PhotoFile] {
        // Load only what's needed
    }
}
```

### 3.2 Streaming Catalog Generation
**Update**: `PhotolalaCatalogService.swift`
```swift
func generateCatalogStreaming(
    photos: AsyncSequence<PhotoFile>,
    progress: @escaping (Int) -> Void
) async throws {
    var csvWriters: [String: CSVWriter] = [:]
    var count = 0
    
    for try await photo in photos {
        let entry = await createCatalogEntry(for: photo)
        let shard = shardFile(for: entry.md5)
        
        if csvWriters[shard] == nil {
            csvWriters[shard] = try CSVWriter(url: shardURL(shard))
        }
        
        try csvWriters[shard]?.write(entry)
        count += 1
        
        if count % 100 == 0 {
            progress(count)
        }
    }
}
```

### 3.3 Sharded Cache Implementation
**Update**: `PhotoManager.swift`
```swift
private func thumbnailURL(for identifier: Identifier) -> URL {
    let md5String = identifier.md5String
    let prefix = String(md5String.prefix(2))
    
    // Create subdirectory if needed
    let subdir = cacheDirectoryPath.appendingPathComponent(prefix)
    try? FileManager.default.createDirectory(
        atPath: subdir,
        withIntermediateDirectories: true
    )
    
    return URL(fileURLWithPath: subdir)
        .appendingPathComponent("\(md5String).dat")
}
```

## Implementation Strategy

### Week 1: Foundation
- [ ] Remove catalog threshold
- [ ] Fix file extensions
- [ ] Create PhotoProcessor
- [ ] Write unit tests

### Week 2: Performance
- [ ] Implement priority queue
- [ ] Add progressive loading
- [ ] Integrate unified processing
- [ ] Performance benchmarks

### Week 3: Scale
- [ ] Virtual scrolling prototype
- [ ] Streaming catalog
- [ ] Memory profiling

### Week 4: Polish
- [ ] Sharded cache migration
- [ ] Error handling
- [ ] Documentation updates

## Testing Plan

### Performance Tests
1. **Baseline**: Current 3x file reads
2. **Target**: Single file read
3. **Metrics**: Time, memory, CPU

### Scale Tests
- 1K photos: <1s load time
- 10K photos: <5s load time  
- 100K photos: <30s initial scan

### Memory Tests
- 100K photos: <2GB total
- Virtual scrolling: <500MB active

## Migration Strategy

### Backwards Compatibility
1. Support both .jpg and .dat thumbnails
2. Migrate on access
3. Background migration task

### Rollout Plan
1. Feature flag for new processor
2. A/B test with subset of users
3. Monitor performance metrics
4. Full rollout

## Success Criteria

### Performance
- 66% reduction in file I/O
- 50% faster thumbnail generation
- <100ms UI response time

### Scale
- Handle 100K+ photos
- <2GB memory usage
- Smooth scrolling

### Quality
- No regressions
- Improved test coverage
- Better error handling

## Risk Mitigation

### File Format Change (.jpg → .dat)
- Support both formats during transition
- Automatic migration on thumbnail access
- Clear old cache after 30 days

### Performance Regression
- Feature flags for each optimization
- Comprehensive benchmarks
- Rollback plan

### Memory Issues
- Gradual rollout
- Memory monitoring
- Virtual scrolling fallback

## Conclusion

This plan addresses all major gaps while maintaining backwards compatibility. The phased approach allows for incremental improvements with measurable results at each stage.