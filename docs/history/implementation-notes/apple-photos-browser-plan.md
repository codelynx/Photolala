# Apple Photos Library Browser Implementation Plan

Date: June 21, 2025

## Overview

Implement a new photo browser that integrates with Apple's Photos Library, allowing users to browse and manage their photos from the system Photos app within Photolala.

## Goals

1. **Read-only access** to Apple Photos Library (initially)
2. **Seamless integration** with existing Photolala architecture
3. **Platform support**: macOS and iOS
4. **Unified browser experience** using existing infrastructure

## Technical Requirements

### 1. Framework Integration

#### macOS
- Use `PhotoKit` framework (Photos.framework)
- Request photo library access permissions
- Handle privacy settings gracefully

#### iOS
- Use `PhotoKit` framework
- Request photo library access permissions
- Support both iPhone and iPad

### 2. PhotoProvider Implementation

Create `ApplePhotosProvider` that implements the `PhotoProvider` protocol:

```swift
class ApplePhotosProvider: BasePhotoProvider {
    // PhotoKit integration
    private var photoLibrary: PHPhotoLibrary?
    private var fetchResult: PHFetchResult<PHAsset>?
    
    // Capabilities
    override var capabilities: PhotoProviderCapabilities {
        [.albums, .search, .sorting, .grouping, .preview]
    }
}
```

### 3. PhotoItem Implementation

Create `PhotoApple` that implements the `PhotoItem` protocol:

```swift
struct PhotoApple: PhotoItem {
    let asset: PHAsset
    let localIdentifier: String
    
    // PhotoItem protocol implementation
    var id: String { localIdentifier }
    var filename: String { /* derive from asset */ }
    var displayName: String { /* derive from asset */ }
    // ... other protocol requirements
}
```

## Implementation Phases

### Phase 1: Core Integration (Week 1)
1. **Set up PhotoKit integration**
   - Add Photos.framework to project
   - Create permission request flow
   - Handle authorization states

2. **Implement ApplePhotosProvider**
   - Basic photo fetching
   - Convert PHAsset to PhotoApple items
   - Implement loading and refresh

3. **Implement PhotoApple**
   - Map PHAsset properties to PhotoItem protocol
   - Implement thumbnail loading via PhotoKit
   - Handle metadata extraction

### Phase 2: Browser UI (Week 1-2)
1. **Create ApplePhotosBrowserView**
   - Reuse UnifiedPhotoCollectionViewRepresentable
   - Add album selection UI
   - Implement smart albums support

2. **Navigation Integration**
   - Add "Photos Library" option to welcome screen
   - Update PhotolalaApp navigation
   - Handle permissions UI flow

### Phase 3: Advanced Features (Week 2)
1. **Album Support**
   - List user albums
   - Smart albums (Favorites, Recently Added, etc.)
   - Album navigation

2. **Search Integration**
   - Search by date
   - Search by location (if available)
   - Search by media type

3. **Performance Optimization**
   - Efficient thumbnail caching
   - Progressive loading for large libraries
   - Memory management for PHAsset references

### Phase 4: Platform-Specific Features (Week 3)
1. **macOS-specific**
   - Integration with system photo picker
   - Drag and drop support
   - Quick Look support

2. **iOS-specific**
   - Integration with system photo picker
   - Share sheet support
   - Live Photos support (display as still)

## Technical Considerations

### 1. Permissions
- Request photo library access on first use
- Handle denied permissions gracefully
- Provide clear explanation why access is needed

### 2. Performance
- PHAsset objects are lightweight references
- Use PHImageManager for efficient image loading
- Cache thumbnails using existing PhotoManager infrastructure

### 3. Memory Management
- PHAsset objects don't hold image data
- Release fetch results when not needed
- Monitor memory usage with large libraries

### 4. Limitations
- Read-only access (no editing/deleting)
- No iCloud Photo Library direct access
- Respect system privacy settings

## UI/UX Design

### 1. Entry Point
- Add "Photos Library" button on welcome screen
- Show Photos icon to differentiate from folder browsing

### 2. Album Selection
- Show album list in sidebar (macOS) or navigation (iOS)
- Display album thumbnails and photo counts
- Support for smart albums

### 3. Photo Display
- Use existing UnifiedPhotoCollectionViewController
- Show Photos-specific metadata in inspector
- Indicate photos are from Photos Library

## Testing Plan

### 1. Unit Tests
- Test PhotoApple PhotoItem implementation
- Test ApplePhotosProvider loading logic
- Mock PHPhotoLibrary for testing

### 2. Integration Tests
- Test permission flows
- Test with various library sizes
- Test album navigation

### 3. Manual Testing
- Test with real Photos libraries
- Test permission denial scenarios
- Test performance with large libraries (10k+ photos)

## Future Enhancements

1. **Write Access** (Phase 5)
   - Add photos to Photos Library
   - Create/modify albums
   - Edit photo metadata

2. **iCloud Integration**
   - Handle iCloud Photo Library assets
   - Download originals on demand
   - Show iCloud status

3. **Advanced Features**
   - Face recognition integration
   - Memories and moments
   - Shared albums support

## Dependencies

- PhotoKit.framework (Photos)
- Existing Photolala infrastructure:
  - PhotoProvider protocol
  - PhotoItem protocol
  - UnifiedPhotoCollectionViewController
  - PhotoManager for caching

## Success Criteria

1. Users can browse their Photos Library within Photolala
2. Performance is acceptable for libraries with 10k+ photos
3. Seamless integration with existing browser features
4. Proper handling of permissions and privacy
5. Platform-appropriate UI/UX

## Next Steps

1. Create ApplePhotosProvider class
2. Create PhotoApple struct
3. Add PhotoKit framework to project
4. Implement basic photo loading
5. Create permission request flow