# Native Thumbnail Strip Implementation

## Overview

The native thumbnail strip is a performance-optimized implementation that replaces the SwiftUI LazyHStack approach with platform-native collection views (NSCollectionView on macOS, UICollectionView on iOS). This provides efficient cell recycling and smooth scrolling even with thousands of photos.

## Architecture

### Component Structure

```
ThumbnailStripView (SwiftUI)
    └── ThumbnailStripViewController (Native)
            └── Collection View
                    └── ThumbnailStripCell (Reusable cells)
```

### Key Classes

1. **ThumbnailStripView**: SwiftUI wrapper implementing `XViewControllerRepresentable`
   - Manages the binding between SwiftUI state and native view controller
   - Handles coordinator pattern for selection updates

2. **ThumbnailStripViewController**: Native view controller
   - Manages collection view lifecycle
   - Handles selection state and scrolling
   - Implements data source and delegate methods

3. **ThumbnailStripCell**: Reusable collection view cell
   - Efficient thumbnail loading with cancellation
   - Visual selection state management
   - Platform-specific appearance customization

## Visual Design

### Cell Appearance
- **Size**: 60x60 pixels (configurable)
- **Corner Radius**: 4 pixels
- **Image Inset**: 2 pixels (to show border)
- **Background**: Gray placeholder while loading

### Selection State
- **Regular State**:
  - Border Width: 0px (macOS) / 1px (iOS)
  - Border Color: Clear (macOS) / White (iOS)
  - Scale: 1.0x

- **Selected State**:
  - Border Width: 3px
  - Border Color: System Blue
  - Scale: 1.05x (with animation)

### Layout
- **Item Spacing**: 8 pixels
- **Section Insets**: 16 pixels (left/right)
- **Container Padding**: 12 pixels (top/bottom)
- **Total Height**: 84 pixels (60 + 24 for padding)

## Performance Features

1. **Cell Recycling**: Only ~10-20 cells in memory at once
2. **Prefetching**: Preloads upcoming thumbnails (iOS)
3. **Task Cancellation**: Cancels thumbnail loads for recycled cells
4. **Concurrent Loading**: Limits to 4 simultaneous thumbnail loads

## Configuration

### Feature Flag
```swift
private let useNativeThumbnailStrip = true // In PhotoPreviewView
```

### Customization Points
All visual constants are defined at the top of ThumbnailStripCell:
```swift
// Border styling
private let regularBorderWidth: CGFloat = 0
private let selectedBorderWidth: CGFloat = 3
private let regularBorderColor = NSColor.clear.cgColor
private let selectedBorderColor = NSColor.systemBlue.cgColor
```

## Usage

The thumbnail strip is automatically shown in PhotoPreviewView when pressing 't':
```swift
ThumbnailStripView(
    photos: photos,
    currentIndex: $currentIndex,
    thumbnailSize: CGSize(width: 60, height: 60),
    onTimerExtend: extendControlsTimer
)
.frame(height: 84)
```

## Implementation Notes

- Selection is handled through collection view delegate methods
- Initial selection is set in `viewDidAppear` to ensure proper display
- Image scaling uses `.scaleAxesIndependently` for consistent fill
- Z-position layering ensures borders are always visible
- Supports keyboard navigation through PhotoPreviewView