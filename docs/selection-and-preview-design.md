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

### Keyboard Navigation Behavior
**Focus vs Selection**: These are separate concepts
- **Focus**: The current keyboard navigation position (shown with focus ring)
- **Selection**: The items marked as selected (shown with blue border)

**Arrow Keys (without modifiers)**:
- Move focus to adjacent item
- Clear current selection
- Select the newly focused item
- This provides single-selection navigation

**Shift+Arrow Keys**:
- Move focus to adjacent item
- Extend selection from anchor point to new focus
- Maintains all existing selections in the range

**Cmd+Arrow Keys** (macOS):
- Move focus without changing selection
- Allows navigating to a different item before using Space to toggle

**Space Key**:
- Toggle selection of focused item
- Maintains all other selections

**Example Flow**:
1. Click item #1 → Item #1 selected and focused
2. Press Right Arrow → Item #1 deselected, Item #2 selected and focused
3. Press Cmd+Right → Item #2 remains selected, focus moves to #3
4. Press Space → Item #2 and #3 are now selected
5. Press Shift+Right → Items #2, #3, and #4 are selected

### Keyboard Navigation Design Considerations

**Current Issue**: The behavior is confusing when mixing arrow navigation with selection
- Arrow keys are adding to selection instead of replacing
- No clear distinction between focus and selection
- Behavior doesn't match standard file browsers (Finder, Windows Explorer)

**Proposed Standard Behavior** (matching Finder/Explorer):

1. **Arrow Keys Only** (no modifiers):
   - Always moves to single selection mode
   - Clears any existing selection
   - Selects only the target item
   - Updates both focus and selection to the same item

2. **Shift+Arrow Keys**:
   - Extends selection from an "anchor" point
   - Anchor is the last item selected without Shift
   - All items between anchor and current position are selected
   - Focus moves to the new position

3. **Cmd+Arrow Keys** (macOS) / Ctrl+Arrow Keys (Windows):
   - Moves focus WITHOUT changing selection
   - Allows positioning before using Space to toggle selection
   - Focus indicator (dotted outline) separate from selection (blue border)

4. **Space Key**:
   - Toggles selection of the focused item
   - Does NOT clear other selections
   - Sets the anchor point for future Shift selections

**Visual Indicators**:
- **Selection**: Blue border (3px) and light blue background
- **Focus**: Dotted outline (can be on selected or unselected items)
- **Focus+Selected**: Both blue border and dotted outline

**Edge Cases**:
1. **No initial selection**: First arrow key selects item at position 0
2. **Focus outside view**: Auto-scroll to keep focused item visible
3. **Shift selection across gaps**: Include all items in range, even if some were previously unselected
4. **Lost focus**: When clicking empty space, clear selection but keep last focus position

### Behavior Comparison Table

| Action | Current Behavior | Proposed Behavior |
|--------|-----------------|-------------------|
| Arrow key | Adds to selection | Replaces selection with single item |
| Click item | Toggles selection | Replaces selection with single item |
| Cmd+Click | N/A | Toggles item in selection |
| Shift+Click | N/A | Selects range from anchor |
| Space key | Toggles selection | Toggles focused item only |
| Click empty space | Clears selection | Clears selection |

### Implementation Notes

1. **Anchor Point Management**:
   - Set when: Single click, arrow key without modifiers, Space key
   - Used for: Shift+click and Shift+arrow operations
   - Persists until new anchor is set

2. **Focus Ring Implementation**:
   - Separate visual layer from selection
   - Always visible when using keyboard navigation
   - Hidden when using mouse (until Tab key pressed)

3. **Platform Differences**:
   - macOS: Cmd key for focus-only movement
   - iOS: Selection mode with different interaction model
   - No keyboard navigation on iOS (touch only)

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

## iOS Selection Mode Design

### Two Distinct Modes

#### Normal Mode (Default)
- **Single tap**: Navigate to photo preview or open folder
- **Long press**: Show context menu (future feature)
- **No selection UI visible**
- Focus on browsing and viewing

#### Selection Mode
**Entering Selection Mode:**
- Tap "Select" button in navigation bar (top-right)
- Long press on any thumbnail (future enhancement)

**UI Changes in Selection Mode:**
1. **Navigation Bar**:
   - "Cancel" button (left) - exits mode, clears selection
   - Title: "Select Items" → "3 Selected" (dynamic)
   - "Select All" button (right) - toggles all selection

2. **Thumbnails**:
   - Circular checkbox overlay (top-right corner of each thumb)
   - Empty circle (unselected) → Filled blue circle with checkmark (selected)
   - Selected items get subtle blue tint overlay (20% opacity)
   - Smooth scale animation on selection change

3. **Bottom Toolbar** (appears with slide-up animation):
   - Share button (action sheet with selected items)
   - Delete button (with confirmation)
   - More (...) button for future actions (Copy, Move, etc.)
   - Disabled state when no selection

**Interactions in Selection Mode:**
- **Tap thumbnail**: Toggle selection with haptic feedback
- **Tap "Select All"**: Select/deselect all items
- **Tap "Cancel"**: Exit mode without action
- **Tap toolbar action**: Perform on selected items
- **No navigation**: Prevents accidental navigation

**Visual Specifications:**
- Checkbox: 24pt diameter, 8pt from edges
- Selection overlay: systemBlue at 20% opacity
- Toolbar height: 44pt + safe area
- Animation duration: 0.3s with ease-in-out

**Implementation Notes:**
- Use UICollectionView's built-in allowsMultipleSelectionDuringEditing
- Toolbar uses UIToolbar with standard items
- Checkbox can be UIImageView with SF Symbols
- Track mode state in view controller

## Implementation Status

### Phase 1: Basic Selection Infrastructure ✅ COMPLETED
**What was implemented:**
- Created SelectionManager class (per-window) with selection state tracking
- Integrated with PhotoBrowserView as @State property
- Visual feedback: 3px blue border + light blue background for selected items
- Focus ring support (2px border) for keyboard navigation
- Basic selection/deselection through collection view delegates

**Implementation approach changed:**
- Instead of custom keyboard/mouse handling, we use NSCollectionView's built-in selection
- SelectionManager syncs with collection view's selection state
- Simpler but less customizable approach

### Phase 2: Multi-Selection Support ✅ COMPLETED
**macOS (via NSCollectionView):**
- Single click selection
- Cmd+click for toggle selection (macOS native)
- Shift+click for range selection (macOS native)
- Arrow key navigation (macOS native)
- Shift+arrow for extending selection (macOS native)

**iOS Selection Mode - COMPLETED:**
- Implemented proper iOS selection mode pattern
- "Select" button in navigation bar (SwiftUI toolbar)
- Enter/exit selection mode with UI changes
- Cancel and Select All buttons in navigation bar
- Checkbox overlays on thumbnails (circle/checkmark.circle.fill)
- Bottom toolbar with Share and Delete actions
- Selection count display in navigation title
- Proper touch interactions (tap to toggle selection)
- Visual feedback with blue checkmarks and tinted overlay

### Phase 3: Full Image Preview ❌ NOT STARTED
- Double-click currently navigates folders, not preview
- No PhotoPreviewView implemented
- No preview navigation

### Phase 4: Enhanced Preview Features ❌ NOT STARTED
### Phase 5: Selection Operations ❌ NOT STARTED
### Phase 6: Advanced Features ❌ NOT STARTED

## Current Implementation Details

### Architecture Simplification
We chose to use NSCollectionView's built-in selection mechanism rather than implementing custom keyboard/mouse handling. This provides:

**Benefits:**
- Standard macOS selection behavior
- Less code to maintain
- Automatic keyboard navigation
- Platform-consistent behavior

**Trade-offs:**
- Less control over selection behavior
- Some custom behaviors not possible
- Must work within NSCollectionView's constraints

### Key Components

1. **SelectionManager** (`Models/SelectionManager.swift`)
   - Maintains `selectedItems` set
   - Tracks `anchorItem` and `focusedItem` (though not fully utilized)
   - Provides methods for selection manipulation

2. **PhotoCollectionViewController** 
   - Implements `didSelectItemsAt` and `didDeselectItemsAt`
   - Syncs collection view selection with SelectionManager
   - Updates visual state of items

3. **Visual Feedback**
   - Selected: 3px blue border + light blue background
   - Focus: 2px system focus color border
   - Implemented in `updateSelectionState()` method

### Implementation Architecture Changes

**iOS Selection Mode Integration:**
The iOS selection mode required a different approach than originally planned due to SwiftUI/UIKit integration:

1. **Select Button Location**: 
   - Placed in SwiftUI's PhotoBrowserView toolbar rather than UIViewController's navigationItem
   - This ensures proper integration with SwiftUI navigation

2. **State Communication**:
   - Added bidirectional binding between SwiftUI and UIKit:
     - `@Binding var isSelectionModeActive: Bool` - tracks selection mode state
     - `@Binding var photosCount: Int` - controls when to show Select button
   - Callbacks from UIViewController to SwiftUI:
     - `onPhotosLoaded: ((Int) -> Void)?` - notifies when photos are loaded
     - `onSelectionModeChanged: ((Bool) -> Void)?` - syncs selection mode state

3. **Visual Implementation**:
   - Checkbox overlay added to PhotoCollectionViewCell
   - Uses SF Symbols (circle/checkmark.circle.fill)
   - 24pt checkbox in top-right corner
   - Blue tint for selected state

### Next Steps
To continue development:
1. Implement double-click preview (Phase 3)
2. Create context menu for selected items
3. Implement actual batch operations (currently shows placeholder alerts)
4. Add drag-and-drop support for selected items
5. Implement keyboard shortcuts for selection operations

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
