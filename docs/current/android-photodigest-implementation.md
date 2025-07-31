# Android PhotoDigest Implementation

**Status**: ✅ Implemented (July 31, 2025)

## Overview

The PhotoDigest two-level cache architecture has been implemented for Android, providing the same performance benefits and cross-source deduplication as the iOS/macOS implementation.

## Implementation Components

### 1. Data Models (`models/PhotoDigest.kt`)
- **PhotoDigest**: Unified thumbnail + metadata representation
- **PhotoDigestMetadata**: Essential metadata for display
- **FileIdentityKey**: Level 1 cache key (path MD5 + size + timestamp)
- Custom serializers for ByteArray and Instant

### 2. Level 1 Cache (`services/PathToMD5Cache.kt`)
- Maps file identity to content MD5
- In-memory ConcurrentHashMap
- JSON disk persistence at `cacheDir/path-to-md5-cache.json`
- Singleton pattern with thread-safe access

### 3. Level 2 Cache (`services/PhotoDigestCache.kt`)
- Maps MD5 to PhotoDigest (thumbnail + metadata)
- Android LruCache for memory management (500 items max)
- Sharded disk storage: `cacheDir/photos/{first-2-chars}/{md5}.dat` and `.json`
- Automatic eviction and disk persistence

### 4. PhotoManagerV2 (`services/PhotoManagerV2.kt`)
- Central manager for two-level cache operations
- Supports multiple photo sources:
  - **PhotoFile**: Direct file access with MD5 computation
  - **PhotoMediaStore**: Fast browsing without MD5 (like Apple Photos)
  - **PhotoS3**: Uses catalog MD5 directly
- 12 concurrent loading workers (up from 4 with Coil)
- Proper EXIF orientation handling
- Thumbnail generation: 256px short side, max 512px long side

### 5. UI Integration
- **PhotoDigestViewModel**: ViewModel wrapper for UI usage
- **PhotoDigestImage**: Composable for displaying cached photos
- Drop-in replacement for Coil's AsyncImage
- Maintains loading/error states

## Key Features

### Performance Improvements
- Two-level caching prevents redundant MD5 computation
- 12 concurrent loads (3x improvement)
- Cross-source photo deduplication
- Sharded storage prevents filesystem bottlenecks

### Smart Source Handling
- **MediaStore**: Fast browsing without MD5 computation
- **Local Files**: Full MD5 computation and caching
- **S3 Photos**: Direct MD5 usage from catalog

### Memory Management
- LruCache with configurable limits
- Automatic eviction on memory pressure
- Disk persistence for cache survival

## Usage Example

```kotlin
// In a Composable
@Composable
fun PhotoGrid() {
    val photoDigestViewModel: PhotoDigestViewModel = viewModel()
    
    // Replace AsyncImage with PhotoDigestImage
    PhotoDigestImage(
        photo = photoMediaStore,
        contentDescription = "Photo",
        contentScale = ContentScale.Crop,
        modifier = Modifier.fillMaxSize()
    )
}

// Or use specific wrappers
PhotoDigestImageMediaStore(
    photo = mediaStorePhoto,
    contentScale = ContentScale.Crop
)
```

## Cache Statistics

The implementation provides detailed cache statistics:
- Level 1: Entry count and memory usage
- Level 2: Memory entries, disk entries, and sizes
- Accessible via `PhotoManagerV2.getCacheStats()`

## No Migration Needed

Since Photolala hasn't released v1 yet, there's no need for cache migration. The new PhotoDigest system starts fresh without compatibility concerns.

## Next Steps

1. Replace Coil image loading with PhotoDigestImage in UI components
2. Remove Coil configuration from PhotolalaApplication
3. Add cache statistics to debug/settings UI
4. Test performance with large photo collections