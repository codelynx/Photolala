# Thumbnail Performance Optimization Plan

## Current Grand Design

### Three-Tier Caching Architecture

1. **Memory Cache (NSCache)**
   - Key: File path
   - Value: XThumbnail (NSImage/UIImage)
   - Lifetime: Until app termination or memory pressure
   - Purpose: Fastest possible access for visible items

2. **Metadata Cache (ThumbnailMetadataCache)**
   - Key: File path
   - Value: MD5 hash + file attributes
   - Storage: `~/Library/Application Support/Photolala/thumbnail-metadata.json`
   - Lifetime: Persistent (30-day cleanup for unused entries)
   - Purpose: Avoid recomputing MD5 for unchanged files

3. **Disk Cache**
   - Key: MD5 hash
   - Value: Thumbnail image data
   - Storage: `~/Library/Caches/Photolala/local/thumbnails/{md5}.dat`
   - Lifetime: Persistent until manual cleanup
   - Purpose: Survive app restarts, global deduplication

### Loading Flow

```
1. Request thumbnail for file path
   ↓
2. Check memory cache (file path) → HIT: Return immediately
   ↓ MISS
3. Get file attributes (size, modification date)
   ↓
4. Check metadata cache → HIT: Get cached MD5
   ↓ MISS                 ↓
5. Read file & compute MD5
   ↓
6. Check disk cache (MD5) → HIT: Load from disk
   ↓ MISS                   ↓
7. Generate thumbnail      ↓
   ↓                      ↓
8. Save to disk cache     ↓
   ↓                      ↓
9. Update metadata cache  ↓
   ↓                      ↓
10. Store in memory cache ↓
    ↓                     ↓
11. Return thumbnail ←────┘
```

### Key Design Principles

1. **Content-Based Deduplication**: MD5 ensures identical photos share thumbnails
2. **Lazy Computation**: MD5 only computed when necessary
3. **Multi-Level Validation**: File attributes validate metadata cache entries
4. **Global Sharing**: MD5-based disk cache works across windows/folders
5. **Performance First**: Memory cache provides instant access when possible

## Current Performance Issues

### Observed Symptoms
- Thumbnails show spinning indicators even on 2nd/3rd launch
- Each photo takes noticeable time to display
- Scrolling performance degrades with many photos

### Root Causes Analysis

1. **Limited Concurrency**
   - Only 4 concurrent thumbnail loads (PriorityThumbnailLoader)
   - Modern SSDs can handle much higher concurrency

2. **Cell Loading Overhead**
   Each UnifiedPhotoCell performs multiple async operations:
   - Load thumbnail (primary)
   - Compute MD5 for backup status check (secondary)
   - Query catalog for Apple Photos (secondary)
   - Load tags from TagManager (secondary)

3. **No Memory Cache Pre-warming**
   - Memory cache empty on each app launch
   - Must hit disk cache for every thumbnail initially

4. **Synchronous Bottlenecks**
   - File attribute checks are synchronous
   - Metadata cache lookups are synchronous but could batch

## Proposed Optimizations

### Phase 1: Quick Wins (Minimal Risk)

1. **Increase Concurrent Loads**
   - Raise from 4 to 12 concurrent operations
   - Adaptive based on system capabilities

2. **Defer Secondary Operations**
   - Load thumbnail first
   - Queue backup status/tags for after thumbnail displays
   - Use dedicated low-priority queue for secondary data

3. **Add Performance Metrics**
   - Time each cache level
   - Track hit rates
   - Identify slowest operations

### Phase 2: Cache Optimization

1. **Memory Cache Pre-warming**
   - Track recently viewed folders
   - Pre-load thumbnails on app launch
   - Background operation with low priority

2. **Batch Operations**
   - Group metadata cache lookups
   - Batch file attribute checks
   - Reduce syscall overhead

3. **Smarter Cache Keys**
   - Consider using file path for disk cache too
   - Fallback to MD5 for deduplication
   - Faster lookups for common case

### Phase 3: Architecture Improvements

1. **Progressive Loading**
   - Show low-quality preview immediately
   - Load full quality in background
   - Similar to web image loading

2. **Predictive Pre-fetching**
   - Load thumbnails for likely next items
   - Based on scroll direction and speed
   - Larger buffer for prefetch

3. **Cache Compression**
   - Compress disk cache entries
   - Trade CPU for disk I/O
   - Especially beneficial for HDDs

## Implementation Priority

1. **Immediate**: Increase concurrent loads (safe, big impact)
2. **Next Sprint**: Defer secondary operations (medium complexity)
3. **Future**: Pre-warming and progressive loading (higher complexity)

## Success Metrics

- Thumbnail display time: < 100ms for cached items
- Initial folder open: < 2 seconds for 200 photos
- Scroll performance: 60 FPS maintained
- Cache hit rate: > 90% on subsequent views

## Risks and Mitigations

1. **Memory Usage**: Monitor NSCache behavior under pressure
2. **Disk I/O**: Ensure we don't overwhelm slower drives
3. **Compatibility**: Test on various macOS/iOS versions