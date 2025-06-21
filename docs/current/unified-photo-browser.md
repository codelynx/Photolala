# Unified Photo Browser Architecture

Last Updated: June 21, 2025 (Added Apple Photos scale fix details)

## Overview

The unified photo browser architecture provides a consistent interface for browsing photos from different sources (local files, S3, Apple Photos Library) using a protocol-oriented design with dependency injection.

## Key Components

### 1. PhotoItem Protocol
- **Purpose**: Common interface for all photo types
- **Location**: `Models/PhotoItem.swift`
- **Key Methods**:
  - `loadThumbnail()` - Asynchronously loads thumbnail image
  - `loadImageData()` - Loads full image data
  - `contextMenuItems()` - Provides source-specific context menu items

### 2. PhotoProvider Protocol
- **Purpose**: Abstracts photo source management
- **Location**: `Services/PhotoProvider.swift`
- **Implementations**:
  - `BasePhotoProvider` - Common functionality with @MainActor for thread safety
  - `DirectoryPhotoProvider` - Loads photos from local directories with progressive loading
  - `S3PhotoProvider` - Loads photos from S3 with catalog support
  - `ApplePhotosProvider` - Loads photos from Apple Photos Library via PhotoKit

### 3. UnifiedPhotoCollectionViewController
- **Purpose**: Platform-agnostic collection view controller
- **Location**: `Views/UnifiedPhotoCollectionViewController.swift`
- **Features**:
  - Works with any PhotoProvider
  - Handles selection, context menus, and delegate callbacks
  - Uses diffable data sources for smooth updates
  - Platform-specific implementations for macOS/iOS

### 4. UnifiedPhotoCell
- **Purpose**: Collection view cell for displaying any PhotoItem
- **Location**: `Views/UnifiedPhotoCell.swift`
- **Features**:
  - Asynchronous thumbnail loading with progress indicator
  - Archive badge support
  - Selection state visualization
  - Platform-specific implementations (NSCollectionViewItem/UICollectionViewCell)

### 5. UnifiedPhotoCollectionViewRepresentable
- **Purpose**: SwiftUI bridge to UnifiedPhotoCollectionViewController
- **Location**: `Views/UnifiedPhotoCollectionViewRepresentable.swift`
- **Usage**: Used by both PhotoBrowserView and S3PhotoBrowserView

## Architecture Benefits

1. **Code Reuse**: Single UI implementation for multiple photo sources
2. **Extensibility**: Easy to add new photo sources by implementing PhotoProvider
3. **Consistency**: Uniform behavior across different photo types
4. **Maintainability**: Changes to photo browsing UI only need to be made once
5. **Type Safety**: Protocol-oriented design with proper abstractions

## Usage Example

```swift
// For local photos
let photoProvider = DirectoryPhotoProvider(directoryPath: "/path/to/photos")

// For S3 photos
let photoProvider = S3PhotoProvider(userId: "user123")

// For Apple Photos Library
let photoProvider = ApplePhotosProvider()

// All use the same UI component
UnifiedPhotoCollectionViewRepresentable(
    photoProvider: photoProvider,
    settings: thumbnailSettings,
    onSelectPhoto: { photo, allPhotos in
        // Handle selection
    },
    onSelectionChanged: { selectedPhotos in
        // Handle selection changes
    }
)
```

## Platform Considerations

- **macOS**: Uses NSCollectionView with NSCollectionViewItem
- **iOS**: Uses UICollectionView with UICollectionViewCell
- **Cross-platform**: XPlatform utilities provide consistent APIs

## Apple Photos Integration

The Apple Photos integration demonstrates the flexibility of the unified architecture:

### PhotoApple Implementation
- Wraps PHAsset from PhotoKit framework
- Implements PhotoItem protocol seamlessly
- Uses PHCachingImageManager for efficient thumbnails
- Provides Photos metadata through common interface

### ApplePhotosProvider Features
- Authorization handling with clear user communication
- Album browsing (smart albums and user collections)
- Automatic loading state management
- Thread-safe with @MainActor

### User Access Points
- **macOS**: Window → Apple Photos Library (⌘⌥L)
- **iOS**: "Photos Library" button on welcome screen
- Opens in new window (macOS) or pushes navigation (iOS)

## Implementation Status

### ✅ Completed
- PhotoItem protocol implementation
- PhotoProvider implementations (Local, S3, Apple Photos)
- UnifiedPhotoCollectionViewController
- UnifiedPhotoCell with thumbnail loading
- Migration of PhotoBrowserView
- Migration of S3PhotoBrowserView
- Apple Photos Library integration
- Thumbnail sizing with S/M/L options
- Basic header support for grouping
- Album browsing for Apple Photos
- Authorization handling for PhotoKit
- Scale to fit/fill display modes working across all browsers
- Proper constraint management for square thumbnails
- Dynamic cell resizing when changing thumbnail sizes

### 🚧 In Progress
- Header view registration and display
- Context menu implementation
- Prefetching support

### 📋 TODO
- Archive badge display
- Enhanced selection handling
- Keyboard navigation
- Performance optimizations for very large collections
- Search integration for Apple Photos
- Live Photos support

## Technical Details

### Display Mode Implementation
The unified browser supports two display modes:
- **Scale to Fit**: Shows entire image with letterboxing/pillarboxing as needed
- **Scale to Fill**: Crops image to fill the entire cell (default)

Key components:
- `ScalableImageView`: Custom NSImageView that implements proper scaling on macOS
- `ThumbnailDisplaySettings`: Observable settings object with display mode
- Settings are passed as @Binding for two-way updates
- `updateDisplayModeOnly()` method for efficient display updates without reloading

### Constraint Management
Cells use centered image views with fixed size constraints to avoid conflicts:
- Image view uses centerX instead of leading/trailing constraints
- Cell view has `masksToBounds = true` for proper clipping
- ScalableImageView always clips to bounds regardless of mode
- Layout updates trigger full cell reconfiguration for size changes

## Future Enhancements

1. Virtual scrolling for improved performance with large collections
2. Prefetching and caching improvements
3. More sophisticated selection management
4. Enhanced context menu customization