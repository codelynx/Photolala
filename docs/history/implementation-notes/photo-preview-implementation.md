# Photo Preview Implementation Plan

**Note**: This was the original implementation plan. See "Implementation Notes" section at the end for what was actually implemented.

## Overview

This document outlines the implementation plan for the photo preview/detail view feature in Photolala. The preview allows users to view photos at full resolution with navigation, zoom, and pan capabilities.

## Requirements

### Core Features
1. **Full Image Display**
   - Load and display full-resolution images
   - Maintain aspect ratio
   - Center image in view
   - Handle various image formats

2. **Navigation**
   - Navigate between photos using:
     - Arrow keys (left/right)
     - Swipe gestures (iOS)
     - Previous/Next buttons
   - If selection exists: navigate only selected photos
   - If no selection: navigate all photos in folder

3. **Zoom and Pan**
   - Pinch to zoom (iOS)
   - Scroll wheel zoom (macOS)
   - Double-tap/click to zoom in/out
   - Pan when zoomed in
   - Reset zoom button

4. **User Interface**
   - Overlay controls (auto-hide after 3 seconds)
   - Close button (X) or Escape key
   - Navigation arrows
   - Zoom controls
   - Current photo indicator (e.g., "3 of 10")

## Technical Design

### Architecture

```
PhotoBrowserView (existing)
    ├── PhotoCollectionView
    └── PhotoPreviewView (new) - presented modally
            ├── ImageViewer (platform-specific)
            ├── OverlayControls
            └── NavigationHandler
```

### Components

#### 1. PhotoPreviewView (SwiftUI)
```swift
struct PhotoPreviewView: View {
    let photos: [PhotoReference]
    let initialIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    @State private var zoomScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var showControls = true
    
    var body: some View {
        // Main view implementation
    }
}
```

#### 2. Platform-Specific Image Display

**macOS**: Use NSImageView with NSScrollView
```swift
struct MacImageViewer: NSViewRepresentable {
    let photo: PhotoReference
    @Binding var zoomScale: CGFloat
    // Implementation using NSImageView
}
```

**iOS**: Use UIScrollView with UIImageView
```swift
struct iOSImageViewer: UIViewRepresentable {
    let photo: PhotoReference
    @Binding var zoomScale: CGFloat
    // Implementation using UIScrollView
}
```

#### 3. Navigation Logic
```swift
extension PhotoPreviewView {
    func navigateToPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
            resetZoom()
        }
    }
    
    func navigateToNext() {
        if currentIndex < photos.count - 1 {
            currentIndex += 1
            resetZoom()
        }
    }
}
```

### Integration Points

1. **Opening Preview**
   - Double-click/tap in PhotoCollectionViewController
   - Pass selected photos or all photos
   - Track initial index

2. **State Management**
   - Preview is presented as sheet/fullScreenCover
   - Parent view maintains presentation state
   - No modifications to photo data

3. **Memory Management**
   - Load only current image at full resolution
   - Keep adjacent images in cache for smooth navigation
   - Release images when not visible

## Implementation Steps

### Phase 1: Basic Preview Window
1. Create PhotoPreviewView with basic image display
2. Add close functionality (button and Escape key)
3. Present as modal from collection view
4. Load and display single image

### Phase 2: Navigation
1. Add previous/next functionality
2. Implement keyboard shortcuts (arrows)
3. Add swipe gestures for iOS
4. Show current position indicator

### Phase 3: Zoom and Pan
1. Implement pinch zoom (iOS)
2. Add scroll wheel zoom (macOS)
3. Implement pan when zoomed
4. Add zoom reset functionality

### Phase 4: Polish
1. Auto-hide controls with timer
2. Smooth transitions between images
3. Loading indicators for large images
4. Error handling for failed loads

## Platform Considerations

### macOS
- Window-based presentation (new window or sheet)
- Menu bar integration (View menu items)
- Trackpad gestures
- Mission Control compatibility

### iOS/iPadOS
- Full screen presentation
- Safe area handling
- Gesture recognizers
- Device rotation support

## Performance Considerations

1. **Image Loading**
   - Use PhotoManager for cached images when available
   - Load full resolution on demand
   - Preload adjacent images

2. **Memory Usage**
   - Limit cache to 3-5 images
   - Downscale extremely large images for display
   - Release memory on background

3. **Smooth Navigation**
   - Animate transitions
   - Load images asynchronously
   - Show progress for slow loads

## Keyboard Shortcuts

### macOS
- `Escape` - Close preview
- `←/→` - Navigate photos
- `Space` - Play/pause slideshow (future)
- `⌘+` / `⌘-` - Zoom in/out
- `⌘0` - Reset zoom

### iOS
- Swipe left/right - Navigate
- Pinch - Zoom
- Double-tap - Toggle zoom
- Tap - Show/hide controls

## Future Enhancements

1. **Slideshow Mode**
   - Auto-advance with timer
   - Transition effects
   - Music support

2. **Metadata Display**
   - EXIF information panel
   - Histogram
   - File details

3. **Editing Operations**
   - Rotate
   - Basic adjustments
   - Crop

4. **Sharing**
   - Share sheet integration
   - Export options
   - Print support

## Success Criteria

1. Preview opens within 0.5 seconds
2. Navigation between photos is smooth (<100ms)
3. Zoom and pan are responsive
4. Memory usage stays reasonable
5. All keyboard shortcuts work
6. No crashes with large images

## Testing Scenarios

1. Open preview with single photo
2. Navigate through 100+ photos
3. Zoom very large images (>50MP)
4. Rapid navigation (arrow key spam)
5. Device rotation during preview (iOS)
6. Memory pressure scenarios
7. Various image formats (JPEG, HEIC, RAW)

## Implementation Notes (June 14, 2025)

### What Was Actually Implemented

1. **Pure SwiftUI Approach**
   - Originally planned NSViewRepresentable/UIViewRepresentable for image display
   - Implemented pure SwiftUI with Image view instead
   - Used MagnificationGesture and DragGesture for zoom/pan
   - Simpler and more maintainable than platform-specific views

2. **Navigation Architecture Changes**
   - macOS: Uses NavigationStack with .navigationDestination(for:) as planned
   - iOS: Changed to .navigationDestination(item:) with @State to fix navigation within parent NavigationStack
   - Added platform-specific Image initialization helper method

3. **Selection Preview Feature**
   - Added eye icon button in toolbar for previewing selected photos
   - Not in original plan but addresses selection mode limitation
   - Consistent behavior across platforms

4. **Technical Fixes**
   - Fixed black screen issue on macOS (image loaded but didn't display)
   - Fixed iOS navigation not working (was trying to use own NavigationStack)
   - Made PhotoPreviewView fully cross-platform with conditional compilation

### Current Status
All core features from the plan have been implemented successfully, with some architectural improvements made during implementation.