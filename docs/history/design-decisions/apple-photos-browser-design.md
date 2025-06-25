# Apple Photos Browser Design Decisions

Date: June 21, 2025

## Overview

This document consolidates the design decisions made during the Apple Photos Library browser implementation. It combines the planning documents that guided the implementation.

## Design Goals

1. **Seamless Integration**: Make Apple Photos browsing feel native to Photolala
2. **Code Reuse**: Leverage existing unified browser architecture
3. **Platform Consistency**: Respect platform conventions (macOS menus, iOS navigation)
4. **Performance**: Handle large photo libraries efficiently
5. **User Privacy**: Proper authorization handling with clear communication

## Key Design Decisions

### 1. Architecture Integration

**Decision**: Extend existing PhotoItem/PhotoProvider architecture rather than creating a separate system.

**Rationale**:
- Maintains consistency across all photo sources
- Reduces code duplication
- Allows future features to work with all photo types
- Simplifies maintenance

### 2. Menu Placement

**Decision**: Place "Apple Photos Library" in Window menu, not File menu.

**Rationale**:
- File menu is for file system operations
- Window menu is for accessing different views/browsers
- Follows macOS HIG conventions
- Groups with Cloud Browser for consistency

### 3. Authorization Handling

**Decision**: Request authorization on-demand when user accesses Photos.

**Rationale**:
- Doesn't prompt unnecessarily at app launch
- Clear context for why permission is needed
- Can show custom UI explaining the request
- Graceful handling of denial

### 4. Album Support

**Decision**: Support both smart albums and user albums, with some exclusions.

**Rationale**:
- Users expect to see their album organization
- Some smart albums (like Portrait) don't exist or aren't useful
- Provides familiar navigation structure
- Enables focused browsing

### 5. Implementation Phases

Originally planned three phases but compressed to single implementation:

**Phase 1 (Completed)**:
- Basic PhotoKit integration
- All photos browsing
- Album support
- Menu integration
- Authorization flow

**Phase 2 & 3 (Future)**:
- Search functionality
- Advanced metadata
- Export features
- Shared albums
- People browsing

## Technical Design Choices

### PhotoKit Integration

**Approach**: Direct PHAsset wrapping with PhotoApple struct

```swift
struct PhotoApple: PhotoItem {
    let asset: PHAsset
    // PhotoItem protocol implementation
}
```

**Benefits**:
- Minimal abstraction overhead
- Direct access to PhotoKit features
- Easy to extend with more PHAsset properties

### Thumbnail Loading

**Approach**: Use PHCachingImageManager with aspect fill

```swift
imageManager.requestImage(
    for: asset,
    targetSize: targetSize,
    contentMode: .aspectFill,
    options: options
)
```

**Benefits**:
- PhotoKit handles caching automatically
- Consistent with iOS Photos app behavior
- Efficient memory usage

### Authorization Flow

**Approach**: Check status first, request if needed

```swift
switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
case .authorized, .limited:
    // Proceed with loading
case .notDetermined:
    // Request authorization
default:
    // Show appropriate UI
}
```

**Benefits**:
- Minimizes prompts
- Handles all authorization states
- Clear user communication

## User Experience Decisions

### Platform Differences

**macOS**:
- Window menu access
- Keyboard shortcut (⌘⌥L)
- No button on welcome screen
- New window for each browser

**iOS**:
- Button on welcome screen
- Standard navigation push
- Same navigation patterns as folders

### Visual Consistency

- Same thumbnail sizes (S/M/L)
- Same selection behavior
- Same context menus (where applicable)
- Same loading states

## Implementation Trade-offs

### What We Included
- Basic photo browsing
- Album navigation
- Thumbnail loading
- Authorization handling
- Platform-appropriate UI

### What We Deferred
- Search functionality (can use existing PhotoProvider search later)
- Advanced metadata (EXIF, etc.)
- Export capabilities
- Live Photos support
- Burst photo selection

### Why These Trade-offs
- Faster time to initial implementation
- Proves the architecture works
- Most important features first
- Clean foundation for enhancements

## Lessons Learned

1. **PhotoKit Quirks**: Some documented types (smartAlbumPortrait) don't exist
2. **SwiftUI + PhotoKit**: Need careful handling of async authorization
3. **Performance**: PHCachingImageManager is very efficient
4. **Architecture**: Unified browser pattern proved very flexible

## Future Considerations

1. **Search Integration**: PhotoKit has powerful search capabilities
2. **iCloud Status**: Could show download status for cloud photos
3. **Export Options**: Could add export to match S3 download
4. **Metadata Parity**: Could show same metadata as local files
5. **Performance Monitoring**: Track performance with very large libraries

## Conclusion

The design successfully balanced integration complexity with user experience. By leveraging the existing unified browser architecture and making platform-appropriate choices, we delivered a native-feeling Photos browsing experience that maintains consistency with Photolala's other photo sources.