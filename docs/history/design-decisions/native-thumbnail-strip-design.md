# Native Thumbnail Strip Implementation Design

## Overview

Replace the current SwiftUI LazyHStack-based thumbnail strip in PhotoPreviewView with native NSCollectionView (macOS) / UICollectionView (iOS) implementation for better performance with large photo collections.

## Goals

1. **Maintain Current Design**: Keep the exact same visual appearance and interactions
2. **Improve Performance**: Use cell recycling for efficient memory usage with thousands of photos
3. **Smooth Scrolling**: Implement prefetching for seamless experience
4. **Cross-Platform**: Work identically on macOS and iOS

## Current Design to Preserve

### Visual Appearance
- **Container**: Black background with 0.8 opacity
- **Height**: 84px total (60px thumbnails + 24px padding)
- **Spacing**: 8px between thumbnails
- **Padding**: 16px horizontal, 12px vertical
- **Thumbnail Size**: 60x60 pixels
- **Corner Radius**: 4px on thumbnails
- **Selection Indicator**: 
  - White border (3px when selected, 1px when not)
  - Scale effect (1.1x when selected)
  - Smooth animation (0.2s ease-in-out)

### Interactions
- **Tap**: Select thumbnail and update current photo
- **Auto-scroll**: Center selected thumbnail when it changes
- **Loading**: Show gray placeholder with progress indicator
- **Caching**: Use already-loaded thumbnails from PhotoReference

## Implementation Plan

### 1. Create ThumbnailStripView (NSViewRepresentable/UIViewRepresentable)

```swift
struct ThumbnailStripView: XViewRepresentable {
    let photos: [PhotoReference]
    @Binding var currentIndex: Int
    let thumbnailSize: CGSize
    let onTimerExtend: (() -> Void)?
}
```

### 2. Collection View Setup

#### Layout Configuration
- Horizontal flow layout
- Item size: 60x60
- Section insets: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
- Minimum spacing: 8px
- Scroll direction: .horizontal

#### Cell Design (ThumbnailStripCell)
- Reusable cell with:
  - Image view for thumbnail
  - Loading indicator
  - Selection border layer
  - Corner radius mask
- Async thumbnail loading with cancellation
- Reuse preparation

### 3. Coordinator Pattern

```swift
class Coordinator: NSObject {
    // Handle collection view delegate/datasource
    // Manage selection state
    // Handle tap gestures
    // Coordinate with SwiftUI binding
}
```

### 4. Performance Features

- **Cell Recycling**: Only ~10-20 cells in memory regardless of collection size
- **Prefetching**: Load thumbnails for cells about to become visible
- **Cancellation**: Cancel loads for cells that scroll off-screen
- **Cache Integration**: Use PhotoManager's existing thumbnail cache
- **Smart Scrolling**: Batch updates when programmatically scrolling

### 5. Platform Differences

#### macOS (NSCollectionView)
- Use NSCollectionViewItem for cells
- Handle selection through delegate methods
- Custom background view for container styling

#### iOS (UICollectionView)
- Use UICollectionViewCell
- Handle selection through delegate methods
- Background color on collection view itself

## Migration Strategy

1. **Create New Component**: Build ThumbnailStripView alongside existing
2. **Feature Flag**: Add toggle to switch between implementations
3. **Test & Compare**: Ensure identical appearance and behavior
4. **Performance Testing**: Verify improvements with large collections
5. **Remove Old Code**: Once verified, remove LazyHStack implementation

## Success Criteria

- ✅ Identical visual appearance to current design
- ✅ Same interactions and animations
- ✅ Handles 10,000+ photos without performance degradation
- ✅ Memory usage stays constant regardless of collection size
- ✅ Smooth 60fps scrolling
- ✅ No regression in functionality

## Code Structure

```
photolala/Views/
├── PhotoPreviewView.swift (updated to use new component)
├── ThumbnailStrip/
│   ├── ThumbnailStripView.swift (main wrapper)
│   ├── ThumbnailStripViewController.swift (native controller)
│   ├── ThumbnailStripCell.swift (reusable cell)
│   └── ThumbnailStripCoordinator.swift (SwiftUI bridge)
```

## Notes

- Keep the existing ThumbnailStrip SwiftUI view during development
- Add debug logging to compare performance metrics
- Consider adding haptic feedback on selection (iOS)
- Ensure VoiceOver accessibility is maintained