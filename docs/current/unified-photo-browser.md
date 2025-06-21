# Unified Photo Browser Architecture

## Overview

The unified photo browser architecture provides a consistent interface for browsing photos from different sources (local files, S3, etc.) using a protocol-oriented design with dependency injection.

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
  - `LocalPhotoProvider` - Loads photos from local directories
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
let photoProvider = LocalPhotoProvider(directoryPath: "/path/to/photos")

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

## Implementation Status

### ✅ Completed
- PhotoItem protocol implementation
- PhotoProvider implementations (Local, S3)
- UnifiedPhotoCollectionViewController
- UnifiedPhotoCell with thumbnail loading
- Migration of PhotoBrowserView
- Migration of S3PhotoBrowserView
- Thumbnail sizing with S/M/L options
- Basic header support for grouping

### 🚧 In Progress
- Header view registration and display
- Context menu implementation
- Prefetching support

### 📋 TODO
- Archive badge display
- Enhanced selection handling
- Keyboard navigation
- Performance optimizations for very large collections

## Future Enhancements

1. Virtual scrolling for improved performance with large collections
2. Prefetching and caching improvements
3. More sophisticated selection management
4. Enhanced context menu customization