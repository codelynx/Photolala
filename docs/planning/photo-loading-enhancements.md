# Photo Loading Enhancement Plan

Created: June 14, 2025

## Overview

This document outlines planned improvements to the photo and thumbnail loading system in Photolala to enhance performance, reduce memory usage, and improve user experience when browsing large photo collections.

## Current Issues

1. **Limited Cache**: Only 16 full images cached in memory
2. **No Prefetching**: Images load only when needed, causing delays
3. **MD5 Overhead**: Full file read for hash computation
4. **No Cancellation**: Wasted resources on off-screen cells
5. **Sequential Loading**: No parallel processing optimization

## Proposed Enhancements

### Phase 1: Quick Wins (Immediate)

#### 1.1 Increase Cache Limits
- **Image Cache**: Increase from 16 to dynamic based on available memory
- **Thumbnail Cache**: Set reasonable limit (500-1000)
- **Implementation**: Update PhotoManager cache configuration

#### 1.2 Add Collection View Prefetching
- **macOS**: Implement NSCollectionViewDelegate prefetching
- **iOS**: Implement UICollectionViewDataSourcePrefetching
- **Benefit**: Smooth scrolling with pre-loaded thumbnails

#### 1.3 Preview Image Preloading
- **Strategy**: Load previous and next images in background
- **Cache**: Keep ±2 images ready in preview
- **Memory**: Monitor and adjust based on available RAM

### Phase 2: Performance Optimization

#### 2.1 Operation Management
- **Queue**: Track pending operations per cell/image
- **Cancellation**: Cancel when scrolling or switching images
- **Priority**: Visible items get higher priority

#### 2.2 Efficient Thumbnail Generation
- **Method 1**: Use ImageIO for built-in thumbnail extraction
- **Method 2**: Generate once and cache permanently
- **Fallback**: Current CoreGraphics implementation

#### 2.3 Smart Cache Key
- **Current**: MD5 of entire file (expensive)
- **Proposed**: File path + size + modification date
- **Benefit**: Instant key generation, no file read

### Phase 3: Advanced Features

#### 3.1 Progressive Loading
- **Preview**: Show low-res immediately, load high-res in background
- **Collection**: Multiple thumbnail sizes for different views
- **Implementation**: Two-stage loading process

#### 3.2 Memory-Aware Caching
- **Monitor**: Respond to memory warnings
- **Adaptive**: Adjust cache size based on device
- **Eviction**: LRU (Least Recently Used) policy

#### 3.3 Background Processing
- **Thumbnail Pre-generation**: Process new folders in background
- **Cache Warming**: Preload likely-to-view images
- **Indexing**: Build metadata cache for instant access

## Implementation Status

### ✅ Phase 1: Quick Wins (Completed - June 14, 2025)

#### 1.1 Smart Cache Limits
- **Implemented**: Memory-aware cache configuration
- **Image Cache**: Scales from 16-64 based on RAM (16 base × memory scale factor)
  - 8GB RAM: 16 images (original design)
  - 16GB RAM: 32 images
  - 32GB+ RAM: 64 images max
- **Thumbnail Cache**: 1000 items, 100MB total cost limit
- **Design Rationale**: Image cache is for preview navigation only (±2-3 images), not bulk browsing

#### 1.2 Collection View Prefetching  
- **Implemented**: Native prefetching delegates for both platforms
- **macOS**: NSCollectionViewPrefetching protocol
- **iOS**: UICollectionViewDataSourcePrefetching
- **Result**: Thumbnails load before cells become visible

#### 1.3 Preview Image Preloading
- **Implemented**: Preloads ±2 images from current index
- **Priority**: Low priority to not interfere with current image
- **Concurrency**: Limited to 2 simultaneous loads
- **Result**: Adjacent images ready when user navigates

#### 1.4 Cache Statistics & Monitoring (Bonus)
- **Implemented**: Comprehensive cache statistics tracking
- **Metrics**: Hit/miss rates, disk operations, load times
- **UI**: View → Cache Statistics menu (⌘⇧I)
- **Real-time monitoring**: Live updates of cache performance

## Implementation Plan

### Step 1: Cache and Prefetching (1-2 days) ✅ COMPLETED
```swift
// PhotoManager.swift
init() {
    let memoryBudget = ProcessInfo.processInfo.physicalMemory / 4
    let imageSize = 4 * 1024 * 1024 // Assume 4MB average
    imageCache.countLimit = Int(memoryBudget / imageSize)
    imageCache.totalCostLimit = Int(memoryBudget)
    
    thumbnailCache.countLimit = 1000
    thumbnailCache.totalCostLimit = 100 * 1024 * 1024 // 100MB
}

// Add prefetch methods
func prefetchImages(for photos: [PhotoReference]) async { }
func prefetchThumbnails(for photos: [PhotoReference]) async { }
```

### Step 2: Collection View Integration (1 day)
```swift
// PhotoCollectionViewController.swift
#if os(macOS)
extension PhotoCollectionViewController: NSCollectionViewPrefetchingDelegate {
    func collectionView(_ collectionView: NSCollectionView, 
                       prefetchItemsAt indexPaths: [IndexPath]) {
        let photos = indexPaths.map { photos[$0.item] }
        Task { await PhotoManager.shared.prefetchThumbnails(for: photos) }
    }
}
#endif
```

### Step 3: Preview Preloading (1 day)
```swift
// PhotoPreviewView.swift
private func preloadAdjacentImages() {
    let indices = [currentIndex - 2, currentIndex - 1, 
                   currentIndex + 1, currentIndex + 2]
    let validIndices = indices.filter { $0 >= 0 && $0 < photos.count }
    let photosToPreload = validIndices.map { photos[$0] }
    
    Task { await PhotoManager.shared.prefetchImages(for: photosToPreload) }
}
```

## Success Metrics

1. **Scroll Performance**: 60 FPS while scrolling large collections
2. **Preview Navigation**: <100ms to show next/previous image
3. **Memory Usage**: Stay under 50% of available RAM
4. **Cache Hit Rate**: >80% for visible thumbnails
5. **User Experience**: No visible loading delays during normal use

## Technical Considerations

### Memory Management
- Use `autoreleasepool` for batch operations
- Monitor `didReceiveMemoryWarning` notifications
- Implement cache purging strategies

### Thread Safety
- Keep existing concurrent queue approach
- Use async/await for cleaner code
- Avoid main thread blocking

### Error Recovery
- Retry failed loads with backoff
- Provide fallback images
- Log errors for debugging

## Testing Strategy

1. **Performance Tests**: Measure load times, FPS
2. **Memory Tests**: Profile with large collections
3. **Stress Tests**: Rapid scrolling, quick navigation
4. **Edge Cases**: Corrupted files, missing images

### ✅ Phase 2: Performance Optimization (Completed - June 20, 2025)

#### 2.1 Progressive Loading
- **Implemented**: DirectoryPhotoProvider with ProgressivePhotoLoader
- **Initial Batch**: First 200 photos load immediately
- **Background Loading**: Remaining photos in 100-photo batches
- **UI Feedback**: Progress bar shows loading status
- **Result**: Near-instant UI response for large directories

#### 2.2 Priority Thumbnail Loading
- **Implemented**: PriorityThumbnailLoader with dynamic priority updates
- **Priority Levels**: visible, nearVisible, prefetch, background
- **Scroll Monitoring**: Collection view tracks visible items
- **Cancellation**: Non-visible requests cancelled during fast scrolling
- **Result**: Visible thumbnails load first, smooth scrolling

#### 2.3 Thread Safety Improvements
- **Fixed**: CatalogAwarePhotoLoader UUID dictionary thread safety
- **Fixed**: Diffable data source duplicate identifier crash
- **Incremental Updates**: Proper snapshot management for progressive loading
- **Result**: Stable concurrent operation

## Next Steps

### Recommended Phase 3 Improvements

1. **Memory Pressure Handling**
   - Monitor memory warnings
   - Implement cache purging strategy
   - Adaptive limits based on available memory

2. **Smart Cache Keys** (Optional - current MD5 works well with catalog)
   - Consider filepath + size + modification date for non-cataloged dirs
   - Instant key generation without file read
   - May not be needed with catalog system

3. **Operation Cancellation** (Partially implemented)
   - Already cancelling non-visible thumbnails
   - Could extend to other operations

## Future Enhancements

1. **Cloud Integration**: Load from iCloud Photos
2. **Smart Predictions**: ML-based prefetch predictions
3. **Format Optimization**: HEIF/WebP support
4. **Network Loading**: Remote image sources