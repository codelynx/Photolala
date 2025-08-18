# PhotoManager to PhotoManagerV2 Migration Plan

## Overview
This document outlines the plan to migrate from the legacy PhotoManager/PhotoProcessor system to the new PhotoManagerV2 with disk-based thumbnail caching.

## Current State Analysis

### PhotoManager (Legacy)
- Uses PhotoProcessor for thumbnail generation
- Reads entire image files for each thumbnail request
- Caches MD5 hashes but regenerates thumbnails
- Memory-based thumbnail cache with NSCache
- Separate metadata handling

### PhotoManagerV2 (New)
- Disk-based thumbnail storage (.dat files)
- Simplified cache key: `path:fileSize`
- Loads thumbnails from disk on demand
- Two-level cache architecture (path→MD5, MD5→PhotoDigest)
- Unified PhotoDigest structure (metadata only, thumbnails on disk)

## API Comparison

### Core Methods

| PhotoManager | PhotoManagerV2 | Status |
|-------------|---------------|---------|
| `thumbnail(for: PhotoFile)` | `thumbnail(for: PhotoFile)` | ✅ Compatible |
| `thumbnail(for: Identifier)` | - | ❌ Missing |
| `loadPhotoData()` → (thumbnail, metadata) | - | ❌ Missing |
| `loadThumbnailUnified()` | - | ❌ Missing |
| `metadata(for: PhotoFile)` | `photoDigest(for:)?.metadata` | 🔄 Different API |
| `thumbnailURL(for: Identifier)` | `PhotoDigest.thumbnailURL(for: md5)` | 🔄 Different approach |
| `thumbnail(for: PhotoApple)` | `thumbnailForBrowsing(for: PhotoApple)` | ✅ Compatible |
| `processApplePhoto()` | `photoDigestForBackup()` | 🔄 Different API |

## Dependencies to Update

### High Priority (Core functionality)
1. **PhotoFile.swift** (18 references)
   - `loadThumbnailUnified()`
   - `loadPhotoData()`
   - Direct thumbnail cache access

2. **S3BackupManager.swift** (4 references)
   - `thumbnail(for: PhotoFile)`
   - `metadata(for: PhotoFile)`

3. **UnifiedMetadataLoader.swift** (2 references)
   - `metadata(for: PhotoFile)`

### Medium Priority
4. **CatalogAwarePhotoLoader.swift** (1 reference)
   - `thumbnailURL(for: Identifier)`

5. **PhotoContextMenuHeaderView.swift** (1 reference)
   - `thumbnail(for: PhotoFile)`

6. **ApplePhotosMetadataCache.swift** (1 reference)
   - Cache coordination

## Migration Steps

### Phase 1: Add Compatibility Layer (Immediate)
Add these methods to PhotoManagerV2 for backward compatibility:

```swift
// PhotoManagerV2+Compatibility.swift
extension PhotoManagerV2 {
    // For PhotoFile.loadPhotoData compatibility
    func loadPhotoData(for photo: PhotoFile) async throws -> (thumbnail: XImage?, metadata: PhotoMetadata?) {
        guard let digest = try await photoDigest(for: photo) else {
            return (nil, nil)
        }
        let thumbnail = digest.loadThumbnail()
        let metadata = PhotoMetadata(from: digest.metadata)
        return (thumbnail, metadata)
    }
    
    // For loadThumbnailUnified compatibility
    func loadThumbnailUnified(for photo: PhotoFile) async throws -> XImage? {
        return try await thumbnail(for: photo)
    }
    
    // For metadata-only requests
    func metadata(for photo: PhotoFile) async throws -> PhotoMetadata? {
        guard let digest = try await photoDigest(for: photo) else {
            return nil
        }
        return PhotoMetadata(from: digest.metadata)
    }
}
```

### Phase 2: Update Core Components

1. **Update PhotoFile.swift**
   ```swift
   // Replace:
   PhotoManager.shared.loadThumbnailUnified(for: self)
   // With:
   PhotoManagerV2.shared.loadThumbnailUnified(for: self)
   ```

2. **Update S3BackupManager.swift**
   ```swift
   // Replace:
   PhotoManager.shared.thumbnail(for: photoRef)
   PhotoManager.shared.metadata(for: photoRef)
   // With:
   PhotoManagerV2.shared.thumbnail(for: photoRef)
   PhotoManagerV2.shared.metadata(for: photoRef)
   ```

3. **Update UnifiedMetadataLoader.swift**
   ```swift
   // Replace:
   PhotoManager.shared.metadata(for: photoFile)
   // With:
   PhotoManagerV2.shared.metadata(for: photoFile)
   ```

### Phase 3: Update Remaining Components

4. Update CatalogAwarePhotoLoader.swift
5. Update PhotoContextMenuHeaderView.swift
6. Update ApplePhotosMetadataCache.swift

### Phase 4: Remove Legacy Code

1. Delete PhotoManager.swift
2. Delete PhotoProcessor.swift
3. Remove old cache directories
4. Update tests

## Implementation Order

1. **Day 1**: Implement compatibility layer
2. **Day 2**: Update PhotoFile and test thumbnail loading
3. **Day 3**: Update S3BackupManager and metadata loading
4. **Day 4**: Update remaining components
5. **Day 5**: Testing and cleanup
6. **Day 6**: Remove legacy code

## Testing Checklist

- [ ] Local photo thumbnail loading
- [ ] Apple Photos thumbnail loading
- [ ] S3 photo thumbnail loading
- [ ] Metadata extraction and display
- [ ] S3 backup with thumbnails
- [ ] Cache persistence across app launches
- [ ] Performance (should be faster)
- [ ] Memory usage (should be lower)

## Rollback Plan

If issues arise:
1. Keep PhotoManager.swift in version control
2. Use feature flag to toggle between implementations
3. Can revert individual components

## Success Metrics

- ✅ No more "Read XXX KB from file for thumbnail" logs
- ✅ Thumbnail loading < 100ms for cached items
- ✅ Reduced memory usage
- ✅ Thumbnails persist across app launches
- ✅ All existing functionality works

## Notes

- The new system uses `.dat` files for thumbnails
- Cache key format changed from `path|size|modDate` to `path:size`
- Thumbnails are stored in sharded directories for performance
- PhotoDigest no longer contains thumbnail data in memory