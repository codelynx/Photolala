# Thumbnail Display Options Design

## Overview

This feature allows users to customize how thumbnails are displayed in the photo browser, including:
- Toggle between "Scale to Fit" and "Scale to Fill" modes
- Adjust thumbnail cell size dynamically
- Persist user preferences across sessions

## Goals

1. **Flexibility**: Give users control over thumbnail appearance
2. **Visual Clarity**: Support different viewing preferences (see entire image vs. fill cell)
3. **Performance**: Maintain smooth scrolling with different cell sizes
4. **Consistency**: Work seamlessly across macOS and iOS
5. **Persistence**: Remember user preferences

## Design Specifications

### Display Modes

#### Scale to Fit
- Shows the entire image within the cell bounds
- Maintains aspect ratio without cropping
- May show letterboxing/pillarboxing for non-square images
- Default mode for new installations

#### Scale to Fill
- Fills the entire cell with the image
- Maintains aspect ratio but crops as needed
- Centers the image in the cell
- No empty space in cells

### Cell Size Options

#### Predefined Sizes
- **Small**: 64x64 points
- **Medium**: 128x128 points
- **Large**: 256x256 points (default)

#### macOS Additional Features
- Slider for continuous adjustment (64-512 points)
- Keyboard shortcuts for quick size changes
- Pinch-to-zoom gesture on trackpad

#### iOS/iPadOS Features
- Pinch gesture for dynamic resizing
- Preset buttons in toolbar
- Adaptive sizing based on device

## Implementation Strategy

### 1. View Model Enhancement

```swift
@Observable
class PhotoBrowserViewModel {
    // Display settings
    var thumbnailDisplayMode: ThumbnailDisplayMode = .scaleToFit
    var thumbnailSize: CGFloat = 256

    // Persistence
    @AppStorage("thumbnailDisplayMode")
    private var storedDisplayMode: String = "fit"

    @AppStorage("thumbnailSize")
    private var storedThumbnailSize: Double = 256
}

enum ThumbnailDisplayMode: String, CaseIterable {
    case scaleToFit = "fit"
    case scaleToFill = "fill"

    var localizedName: String {
        switch self {
        case .scaleToFit: return "Scale to Fit"
        case .scaleToFill: return "Scale to Fill"
        }
    }
}
```

### 2. Collection View Updates

#### Cell Configuration
```swift
// PhotoCollectionViewCell
func configure(with photo: PhotoReference, displayMode: ThumbnailDisplayMode) {
    switch displayMode {
    case .scaleToFit:
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .secondarySystemBackground
    case .scaleToFill:
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .clear
    }
}
```

#### Dynamic Layout
```swift
// Collection view flow layout
func updateLayout(cellSize: CGFloat) {
    let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
    layout?.itemSize = CGSize(width: cellSize, height: cellSize)
    layout?.invalidateLayout()
}
```

### 3. UI Controls

#### macOS Toolbar
- Segmented control for display mode
- Slider for cell size
- Menu bar items under View menu

#### iOS Toolbar
- Button to toggle display mode
- Size preset buttons or popover
- Settings accessible via long press

### 4. Gesture Support

#### macOS
```swift
// Pinch gesture recognizer
@objc func handlePinch(_ gesture: NSMagnificationGestureRecognizer) {
    let newSize = thumbnailSize * (1.0 + gesture.magnification)
    thumbnailSize = min(max(newSize, 100), 300)
    gesture.magnification = 0
}
```

#### iOS
```swift
// Pinch gesture recognizer
@objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    if gesture.state == .changed {
        let newSize = thumbnailSize * gesture.scale
        thumbnailSize = min(max(newSize, 100), 300)
        gesture.scale = 1.0
    }
}
```

## User Interface

### macOS Design

```
┌─────────────────────────────────────────┐
│ Window Toolbar                          │
│ [←] [→] ─── [Fit|Fill] ──[●]──── [⚙]   │
├─────────────────────────────────────────┤
│                                         │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐              │
│  │   │ │   │ │   │ │   │              │
│  └───┘ └───┘ └───┘ └───┘              │
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐              │
│  │   │ │   │ │   │ │   │              │
│  └───┘ └───┘ └───┘ └───┘              │
│                                         │
└─────────────────────────────────────────┘
```

### iOS Design

```
┌─────────────────────────────────────────┐
│        Navigation Bar                    │
│ [Back]    Folder Name         [Options] │
├─────────────────────────────────────────┤
│                                         │
│  ┌───┐ ┌───┐ ┌───┐                    │
│  │   │ │   │ │   │                    │
│  └───┘ └───┘ └───┘                    │
│  ┌───┐ ┌───┐ ┌───┐                    │
│  │   │ │   │ │   │                    │
│  └───┘ └───┘ └───┘                    │
│                                         │
├─────────────────────────────────────────┤
│ [S] [M] [L] [XL]      [Fit] [Fill]     │
└─────────────────────────────────────────┘
```

## Keyboard Shortcuts (macOS)

- `⌘ +` : Increase thumbnail size
- `⌘ -` : Decrease thumbnail size
- `⌘ 0` : Reset to default size
- `⌘ 1` : Small thumbnails (64px)
- `⌘ 2` : Medium thumbnails (128px)
- `⌘ 3` : Large thumbnails (256px)
- `⌘ D` : Toggle display mode

## Performance Considerations

1. **Thumbnail Regeneration**:
   - Don't regenerate thumbnails when changing display mode
   - Only adjust how existing thumbnails are displayed

2. **Layout Updates**:
   - Batch layout updates to avoid multiple reflows
   - Use animation for smooth transitions

3. **Memory Management**:
   - Adjust cache size based on cell count visible
   - Smaller cells = more visible = adjust cache accordingly

## Implementation Phases

### Phase 1: Core Functionality
1. Add display mode toggle (fit/fill)
2. Implement in collection view cells
3. Add toolbar controls
4. Persist settings with @AppStorage

### Phase 2: Dynamic Sizing
1. Add size adjustment controls
2. Implement gesture recognizers
3. Update collection view layout dynamically
4. Add keyboard shortcuts (macOS)

### Phase 3: Polish
1. Add smooth animations
2. Implement presets UI
3. Add accessibility labels
4. Performance optimization

## Testing Requirements

1. **Visual Testing**:
   - Verify fit/fill modes work correctly
   - Test with various aspect ratios
   - Ensure smooth transitions

2. **Performance Testing**:
   - Scroll performance with different sizes
   - Memory usage with many small cells
   - Layout update performance

3. **Persistence Testing**:
   - Settings persist across launches
   - Settings sync between windows (macOS)

## Future Enhancements

1. **Grid Density Options**:
   - Fixed number of columns
   - Automatic column adjustment

2. **Aspect Ratio Modes**:
   - Square cells only
   - Maintain photo aspect ratio

3. **Advanced Display Options**:
   - Show/hide photo info overlay
   - Border and spacing adjustments
   - Background color options

## Summary

This feature enhances the photo browsing experience by giving users control over how their photos are displayed. The implementation focuses on performance, cross-platform consistency, and intuitive controls while maintaining the simplicity of the current design.
