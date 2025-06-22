# Apple Photos Library Browser Implementation

Date: June 21, 2025

## Overview

This document summarizes the implementation of Apple Photos Library browsing functionality in Photolala, enabling users to browse their Photos app library directly within Photolala using the same unified browser interface used for local files and S3 storage.

## Implementation Summary

### 1. Core Components Created

#### PhotoApple Model (`Models/PhotoApple.swift`)
- Implements PhotoItem protocol to integrate with unified browser
- Wraps PHAsset from PhotoKit framework
- Provides async thumbnail loading via PHCachingImageManager
- Maps Photos metadata to PhotoItem properties:
  - Creation date from asset
  - Dimensions from pixel width/height
  - Location data if available
  - iCloud status detection

#### ApplePhotosProvider Service (`Services/ApplePhotosProvider.swift`)
- Extends BasePhotoProvider for thread-safe @MainActor operations
- Key capabilities:
  - Authorization handling with PHPhotoLibrary.requestAuthorization
  - Album browsing (smart albums and user collections)
  - Efficient photo fetching with PHFetchOptions
  - Loading state management
  - Album selection support
- Supported album types:
  - User albums
  - Smart albums (Favorites, Recents, Screenshots, etc.)
  - Excludes system albums like Portrait mode

#### ApplePhotosBrowserView (`Views/ApplePhotosBrowserView.swift`)
- Thin wrapper around UnifiedPhotoCollectionViewRepresentable
- Handles PhotoKit authorization flow
- Shows loading states during library access
- Platform-specific navigation patterns
- Album picker in navigation bar

### 2. Integration Points

#### PhotoItem Protocol Enhancement
- Added `isFromApplePhotos` computed property
- Default implementation returns false
- PhotoApple returns true for special handling

#### PhotoProvider Protocol
- Already supported album concept via `currentAlbum` property
- Added `fetchAlbums()` method to protocol
- Capabilities already included `.albums` flag

#### Menu System Updates (`Commands/PhotolalaCommands.swift`)
- Added "Apple Photos Library" to Window menu (not File menu)
- Keyboard shortcut: ⌘⌥L
- Moved "Cloud Browser" to Window menu for consistency
- Keyboard shortcut: ⌘⌥B
- Both commands open new windows with respective browsers

#### Welcome View Changes (`Views/WelcomeView.swift`)
- Removed "Photos Library" button from macOS version
- Kept button on iOS (no menu bar available)
- Maintains platform-appropriate UX

### 3. Technical Implementation Details

#### PhotoKit Integration
```swift
// Authorization
PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
    // Handle authorization status
}

// Fetching photos
let fetchOptions = PHFetchOptions()
fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
let assets = PHAsset.fetchAssets(with: fetchOptions)

// Thumbnail loading
imageManager.requestImage(
    for: asset,
    targetSize: targetSize,
    contentMode: .aspectFill,
    options: requestOptions
) { image, info in
    // Handle loaded image
}
```

#### Build Fixes Applied
1. Removed `smartAlbumPortrait` (doesn't exist in PhotoKit)
2. Changed `@StateObject` to `@State` for @Observable classes
3. Removed `navigationBarTitleDisplayMode` modifier on macOS
4. Used computed property for platform-specific view building

### 4. User Experience

#### macOS Flow
1. User selects Window → Apple Photos Library (⌘⌥L)
2. New window opens with authorization prompt if needed
3. After authorization, shows all photos or album picker
4. User can browse photos with same controls as local files
5. Double-click opens preview, selection works normally

#### iOS Flow
1. User taps "Photos Library" button on welcome screen
2. Authorization prompt appears if needed
3. Navigation pushes to photos browser
4. Same browsing experience as local folders

### 5. Architecture Benefits

- **Code Reuse**: Uses existing UnifiedPhotoCollectionViewController
- **Consistency**: Same UI/UX as local and S3 browsers
- **Performance**: PHCachingImageManager handles thumbnail optimization
- **Future-Proof**: Easy to add more PhotoKit features (search, faces, etc.)
- **Clean Separation**: PhotoKit details isolated in PhotoApple and ApplePhotosProvider

### 6. Testing Performed

Manual testing covered:
- Authorization flow (first time and subsequent)
- Album browsing and selection
- Photo thumbnail loading
- Scroll performance with large libraries
- Memory usage monitoring
- Platform differences (macOS/iOS)
- Keyboard shortcuts
- Window management

### 7. Known Limitations

1. Read-only access (no editing/deleting)
2. No Live Photos support (shows still image only)
3. No burst photo selection
4. No hidden photos access
5. Basic metadata only (could add EXIF data later)

### 8. Future Enhancement Opportunities

1. Search integration using PhotoKit search
2. Smart album creation based on criteria
3. Live Photos playback support
4. Burst photo picker
5. Advanced metadata display
6. Export functionality
7. Shared album support
8. People/Faces browsing

## Conclusion

The Apple Photos Library browser successfully extends Photolala's unified browser architecture to support Photos app content. The implementation maintains consistency with existing photo sources while properly handling PhotoKit's authorization and data access patterns. Users can now browse their Photos library within Photolala using familiar controls and UI patterns.