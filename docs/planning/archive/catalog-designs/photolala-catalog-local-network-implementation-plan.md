# .photolala Catalog Implementation Plan for Local/Network Directories

## Executive Summary

This document outlines the implementation plan for enhancing the `.photolala` catalog format to better support local and network directories in Photolala. The plan focuses on performance optimization, network resilience, and seamless integration with the existing photo browsing experience.

## Current State Analysis

### Existing Implementation
- **PhotolalaCatalogService**: Fully functional catalog system with 16-way MD5-based sharding
- **CSV Format**: `md5,filename,size,photoDate,modified,width,height`
- **DirectoryScanner**: Currently scans directories in real-time without catalog caching
- **PhotoManager**: Manages photo references and thumbnail generation

### Identified Gaps
1. No caching mechanism for network directories
2. No network-aware retry logic
3. No support for offline browsing of network locations
4. DirectoryScanner doesn't utilize catalog files

## Implementation Goals

### Primary Objectives
1. **Performance**: Instant photo browsing from catalog files instead of directory scanning
2. **Network Resilience**: Handle network latency, timeouts, and disconnections gracefully
3. **Offline Support**: Enable browsing of previously accessed network directories
4. **Backward Compatibility**: Maintain support for directories without catalogs

### Success Metrics
- Directory load time < 100ms for 10K photos (from catalog)
- Network catalog updates handle 200ms+ latency gracefully
- Zero data loss during network interruptions
- Seamless fallback to directory scanning when no catalog exists

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        PhotoBrowserView                          │
├─────────────────────────────────────────────────────────────────┤
│                    PhotoCollectionViewController                 │
├─────────────────────────────────────────────────────────────────┤
│                      CatalogAwarePhotoLoader                     │
│  ┌─────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │ NetworkAware    │  │ CachedCatalog    │  │ Directory     │ │
│  │ CatalogService  │  │ Service          │  │ Scanner       │ │
│  └─────────────────┘  └──────────────────┘  └───────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    PhotolalaCatalogService                       │
└─────────────────────────────────────────────────────────────────┘
```

## Detailed Implementation Plan

### Phase 1: Core Infrastructure (Week 1)

#### 1.1 CatalogAwarePhotoLoader
Create a new service that intelligently loads photos using catalogs when available:

```swift
class CatalogAwarePhotoLoader {
    func loadPhotos(from directory: URL) async throws -> [PhotoReference] {
        // 1. Check if .photolala catalog exists
        // 2. If yes, use NetworkAwareCatalogService
        // 3. If no, fall back to DirectoryScanner
        // 4. Optionally create catalog for future use
    }
}
```

**Files to create:**
- `/Photolala/Services/CatalogAwarePhotoLoader.swift`

**Files to modify:**
- `/Photolala/Views/PhotoCollectionViewController.swift` - Replace DirectoryScanner with CatalogAwarePhotoLoader

#### 1.2 Integration with Existing Services
Already created:
- ✅ `NetworkAwareCatalogService.swift` - Network-aware wrapper with retry logic
- ✅ `CachedCatalogService.swift` - Smart caching for network locations

**Integration points:**
1. Modify `PhotoCollectionViewController` to use `CatalogAwarePhotoLoader`
2. Update `PhotoBrowserView` to pass catalog metadata to collection view
3. Ensure `PhotoManager` can work with catalog-loaded photos

### Phase 2: Catalog Generation (Week 1-2)

#### 2.1 Automatic Catalog Creation
Implement background catalog generation for directories without catalogs:

```swift
extension CatalogAwarePhotoLoader {
    func generateCatalogInBackground(for directory: URL) {
        Task.detached(priority: .background) {
            // 1. Scan directory
            // 2. Generate MD5 hashes
            // 3. Extract photo metadata
            // 4. Write catalog files
        }
    }
}
```

#### 2.2 Catalog Update Detection
Monitor directories for changes and update catalogs:
- File system events monitoring
- Periodic refresh for network directories
- Smart invalidation based on directory modification time

### Phase 3: User Experience Enhancements (Week 2)

#### 3.1 Visual Feedback
- Loading indicator: "Reading catalog..." vs "Scanning directory..."
- Network status indicator for remote directories
- Catalog generation progress (subtle, non-blocking)

#### 3.2 Settings Integration
Add user preferences:
```swift
struct PhotolalaSettings {
    var enableCatalogGeneration: Bool = true
    var catalogCacheDuration: TimeInterval = 300 // 5 minutes
    var preferCatalogOverScan: Bool = true
}
```

#### 3.3 Context Menu Options
Right-click menu additions:
- "Generate Catalog" - Manual catalog creation
- "Update Catalog" - Force refresh
- "Clear Catalog Cache" - For troubleshooting

### Phase 4: Performance Optimization (Week 2-3)

#### 4.1 Parallel Processing
- Load catalog shards in parallel
- Generate thumbnails while loading catalog
- Prefetch commonly accessed shards

#### 4.2 Memory Management
- Stream large CSV files instead of loading entirely
- Implement catalog data pagination
- Cache eviction strategy for memory pressure

#### 4.3 Network Optimization
- Implement ETag-based conditional requests
- Use compression for network transfers
- Batch updates to reduce write operations

### Phase 5: Testing & Validation (Week 3)

#### 5.1 Unit Tests
- Catalog reading/writing accuracy
- Network retry logic
- Cache invalidation logic
- CSV parsing edge cases

#### 5.2 Integration Tests
- End-to-end photo loading scenarios
- Network failure simulation
- Concurrent access handling
- Large catalog performance

#### 5.3 Manual Testing Scenarios
1. **Local Directory**
   - First access (no catalog)
   - Subsequent access (with catalog)
   - After adding/removing photos

2. **Network Directory (NAS)**
   - Fast network (< 10ms latency)
   - Slow network (> 200ms latency)
   - Intermittent connection
   - Offline access after initial load

3. **Edge Cases**
   - Corrupted catalog files
   - Partially written catalogs
   - Permission issues
   - Extremely large directories (100K+ photos)

## Migration Strategy

### For Existing Users
1. **Transparent Upgrade**: No action required
2. **Opt-in Features**: Advanced features available in preferences
3. **Background Migration**: Catalogs generated automatically over time

### Rollback Plan
- Keep DirectoryScanner as fallback
- Disable catalog usage via feature flag
- Clear cache to force directory scanning

## Risk Mitigation

### Technical Risks
1. **Catalog Corruption**
   - Mitigation: Checksums, atomic writes, backup copies

2. **Network Timeouts**
   - Mitigation: Aggressive caching, timeout tuning, offline mode

3. **Memory Usage**
   - Mitigation: Streaming, pagination, smart eviction

### User Experience Risks
1. **Confusion about catalog state**
   - Mitigation: Clear UI indicators, help documentation

2. **Performance regression**
   - Mitigation: A/B testing, gradual rollout

## Implementation Timeline

```
Week 1: Core Infrastructure
- Day 1-2: Integrate CatalogAwarePhotoLoader
- Day 3-4: Wire up UI connections
- Day 5: Initial testing

Week 2: Feature Development
- Day 1-2: Catalog generation
- Day 3-4: Update detection
- Day 5: UI enhancements

Week 3: Polish & Testing
- Day 1-2: Performance optimization
- Day 3-4: Comprehensive testing
- Day 5: Documentation & release prep
```

## Next Steps

1. **Immediate Actions**
   - Create `CatalogAwarePhotoLoader.swift`
   - Modify `PhotoCollectionViewController` to use new loader
   - Add feature flag for gradual rollout

2. **Team Communication**
   - Review plan with stakeholders
   - Identify any additional requirements
   - Confirm timeline and priorities

3. **Documentation**
   - Update user documentation
   - Create troubleshooting guide
   - Document catalog format for developers

## Appendix

### A. CSV Format Specification
```
md5,filename,size,photoDate,modified,width,height
d41d8cd98f00b204e9800998ecf8427e,IMG_0129.jpg,2048576,1718445000,1718445000,4032,3024
```

### B. Network Path Detection
```swift
func isNetworkLocation(_ url: URL) -> Bool {
    // /Volumes/ paths (except Macintosh HD)
    // smb://, afp://, nfs:// protocols
    // Custom detection logic
}
```

### C. Cache Directory Structure
```
~/Library/Caches/com.electricwoods.photolala/catalogs/
├── {md5_of_path}.cache     # Cached catalog data
├── {md5_of_path}.meta      # Metadata about cache
└── {md5_of_path}.lock      # Lock file for updates
```