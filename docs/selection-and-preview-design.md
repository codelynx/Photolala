# Selection and Preview Design

## Overview

This document outlines the design for photo selection and preview functionality in Photolala. The goal is to provide an intuitive selection system with smooth preview capabilities across all platforms.

## Purpose

### Why Selection?
Selection is essential for enabling users to perform batch operations on multiple photos:
- **Organizing**: Starring, flagging, and labeling photos for better organization
- **Metadata Operations**: Adding tags, ratings, or other metadata to multiple photos
- **File Operations**: Copy, move, or delete selected photos
- **Export/Share**: Print or share multiple photos at once
- **Future Features**: Detect faces or objects and select matching photos

### Why Preview?
Preview functionality allows users to:
- **Quick Inspection**: View photos at full resolution without leaving the browser
- **Detail Checking**: Verify focus, exposure, and composition
- **Comparison**: Navigate between selected photos for comparison
- **Metadata Review**: Check EXIF data and other photo information

## Requirements

### Selection Features
1. **Single Selection**
   - Click/tap to select a photo
   - Visual feedback (highlight, border, or overlay)
   - Deselect by clicking empty space

2. **Multiple Selection**
   - Command+click (macOS) / Long press (iOS) for individual selection
   - Shift+click for range selection
   - Drag selection (rubber band) on macOS
   - Select All (Cmd+A) / Deselect All

3. **Keyboard Navigation**
   - Arrow keys to move selection
   - Shift+Arrow for extending selection
   - Space to add/remove from selection

4. **Visual Feedback**
   - Selected state indicator (blue border/overlay)
   - Focus ring for keyboard navigation
   - Selection count in status bar/toolbar

### Preview Features
1. **Quick Preview**
   - Spacebar for Quick Look (macOS)
   - Single tap on selected item (iOS)
   - Escape to close preview

2. **Full Preview Window**
   - Double-click to open
   - Swipe/arrow keys to navigate
   - Pinch to zoom
   - Metadata display toggle

3. **Slideshow Mode**
   - Play/pause controls
   - Adjustable speed
   - Loop option

## Technical Design

### Selection State Management

```swift
@Observable
class SelectionManager {
    var selectedItems: Set<PhotoRepresentation> = []  // Note: Consider renaming PhotoRepresentation to PhotoReference
    var lastSelectedItem: PhotoRepresentation?
    var focusedItem: PhotoRepresentation?

    func select(_ item: PhotoRepresentation) {
        selectedItems.insert(item)
        lastSelectedItem = item
    }

    func deselect(_ item: PhotoRepresentation) {
        selectedItems.remove(item)
    }

    func toggleSelection(_ item: PhotoRepresentation) {
        if selectedItems.contains(item) {
            deselect(item)
        } else {
            select(item)
        }
    }

    func selectRange(from: PhotoRepresentation, to: PhotoRepresentation, in items: [PhotoRepresentation]) {
        // Implement range selection logic
    }

    func clearSelection() {
        selectedItems.removeAll()
        lastSelectedItem = nil
    }
}
```

### Collection View Integration

#### macOS (NSCollectionView)
```swift
extension PhotoCollectionViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        // Handle selection
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        // Handle deselection
    }
}
```

#### iOS (UICollectionView)
```swift
extension PhotoCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        // Handle selection logic
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Handle selection
    }
}
```

### Preview Implementation

#### Quick Look (macOS)
```swift
import QuickLookUI

class PreviewManager: QLPreviewControllerDataSource {
    var items: [PhotoRepresentation] = []
    var currentIndex: Int = 0

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return items.count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return items[index].fileURL as QLPreviewItem
    }
}
```

#### Custom Preview View
```swift
struct PhotoPreviewView: View {
    let photo: PhotoRepresentation
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    var body: some View {
        // Preview implementation
    }
}
```

## Interaction Design

### Selection Interactions
- **Single Selection**: Click/tap a thumbnail to select it
- **Multiple Selection**: Cmd+click (macOS) or long press (iOS) to add/remove from selection
- **Range Selection**: Shift+click to select all items between last selected and clicked item
- **Select All**: Cmd+A to select all visible items

### Preview Interactions
- **Double-tap on thumbnail**: Opens full image view
  - If there's an active selection: Previous/Next navigation moves between selected photos only
  - If no selection: Previous/Next navigation moves through all photos in the current folder
- **Navigation in Preview**: 
  - Arrow keys (macOS) or swipe gestures (iOS) to navigate
  - Previous/Next buttons in the UI
  - Same behavior on both macOS and iOS
- **Exit Preview**: Escape key or tap close button

## User Interactions

### Selection Gestures
- **Single Click**: Select/deselect item
- **Cmd+Click**: Add/remove from selection
- **Shift+Click**: Select range
- **Drag**: Rubber band selection (macOS)
- **Long Press**: Enter selection mode (iOS)

### Preview Gestures
- **Double Click**: Open full preview
- **Spacebar**: Quick Look (macOS)
- **Swipe**: Navigate between photos
- **Pinch**: Zoom in/out
- **Double Tap**: Zoom to fit/fill

## Visual Design

### Selection Indicators
- Blue border (3px) for selected items
- Semi-transparent overlay for better visibility
- Checkbox overlay option for multi-select mode
- Focus ring for keyboard navigation

### Preview UI
- Full-screen or windowed mode
- Overlay controls (auto-hide)
- Bottom toolbar with metadata
- Navigation arrows on hover

## Platform Considerations

### macOS
- Native Quick Look integration
- Multiple windows support
- Keyboard shortcuts
- Context menus

### iOS/iPadOS
- Touch-optimized selection
- Gesture-based navigation
- Share sheet integration
- Adaptive UI for different sizes

## Implementation Phases

### Phase 1: Basic Selection Infrastructure
**Goal**: Establish foundation for selection system
- Create SelectionManager class (per-window)
- Integrate with PhotoBrowserView
- Single-click selection with visual feedback (blue border)
- Clear selection on empty space click
- Basic keyboard navigation (arrow keys)

### Phase 2: Multi-Selection Support
**Goal**: Enable selecting multiple photos
- Cmd+click (macOS) / Long press (iOS) for toggle selection
- Shift+click for range selection
- Select All (Cmd+A) / Deselect All
- Selection count display in toolbar/status area
- Update collection view delegate methods

### Phase 3: Full Image Preview
**Goal**: Basic preview functionality
- Double-tap to open full image view
- Create PhotoPreviewView
- Navigation based on selection state:
  - With selection: navigate between selected photos
  - Without selection: navigate through all photos
- Basic gestures: swipe/arrow keys for navigation
- Escape/close button to exit

### Phase 4: Enhanced Preview Features
**Goal**: Polish preview experience
- Smooth transition animations
- Pinch to zoom / double-tap zoom
- Pan when zoomed
- Quick Look integration (macOS Spacebar)
- Metadata overlay (EXIF info)

### Phase 5: Selection Operations
**Goal**: Make selection useful
- Context menu for selected items
- Batch operations framework
- Basic operations: Copy, Move, Delete
- Preparation for future: Star, Flag, Label

### Phase 6: Advanced Features (Future)
**Goal**: Power user features
- Drag selection (rubber band) on macOS
- Slideshow mode for selected photos
- Export/Share selected photos
- Print support
- Face/object detection and selection

## Open Questions

1. Should we support drag-and-drop of selected items?
2. How should selection persist when navigating folders?
3. Should we add a selection mode toggle for iOS?
4. What metadata should be displayed in preview?
5. Should preview support editing operations?
6. Should we rename PhotoRepresentation to PhotoReference throughout the codebase?
   - This would better reflect that it's a reference to a photo file rather than the photo data itself
   - Impact would be significant as it affects many files and APIs

## Additional Concerns

### Performance
- **Large Selections**: How to handle performance when selecting thousands of photos?
- **Memory Management**: Preview of large RAW files or high-resolution images
- **Thumbnail Loading**: Should selection state affect thumbnail loading priority?

### UI/UX Consistency
- **Selection Persistence**: Should selection clear when changing folders or persist for operations across folders?
- **Visual Feedback**: How prominent should selection indicators be? Current design suggests 3px blue border
- **Context Menus**: What operations should be available via right-click on selection?

### Technical Implementation
- **Collection View Integration**: NSCollectionView (macOS) and UICollectionView (iOS) have different selection APIs
- **State Management**: SelectionManager should be per-window (each window maintains its own selection)
- **Preview Transition**: Smooth animation from thumbnail to full preview

### Edge Cases
- **Deleted Files**: What happens if selected files are deleted externally?
- **Mixed Media**: How to handle selection containing both photos and videos?
- **Keyboard Shortcuts**: Potential conflicts with system shortcuts
