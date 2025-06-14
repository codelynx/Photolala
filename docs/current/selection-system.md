# Selection System

Last Updated: June 14, 2025

## Overview

Photolala implements a per-window selection system that integrates with native collection views and provides consistent behavior across platforms.

## SelectionManager

### Architecture
```swift
@Observable
class SelectionManager {
    private(set) var selectedItems: Set<PhotoReference> = []
    private(set) var anchorItem: PhotoReference?
    private(set) var focusedItem: PhotoReference?
}
```

### Key Features
- **Per-Window State**: Each window has its own SelectionManager
- **Set-Based Storage**: Efficient membership testing
- **Observable**: Automatic UI updates
- **Platform Integration**: Syncs with native collection view selection

## Platform-Specific Behavior

### macOS
- **Native Integration**: Uses NSCollectionView's built-in selection
- **Keyboard Support**: 
  - Arrow keys for navigation
  - Shift+Arrow for range selection
  - Cmd+Click for toggle selection
- **Visual Feedback**:
  - Selected: 3px blue border + light blue background
  - Focus: 2px system focus color border

### iOS
- **Selection Mode**: Explicit mode with UI changes
- **Visual Feedback**:
  - Selected: 4px blue border + 15% blue tint
  - Normal mode: 1px separator color border
- **Toolbar Integration**:
  - "Select" button to enter mode
  - "Cancel" and "Select All" in selection mode
  - Bottom toolbar with actions

## Selection Mode Flow (iOS)

### Enter Selection Mode
1. User taps "Select" button
2. Navigation bar updates with Cancel/Select All
3. Bottom toolbar appears with actions
4. Collection view enables multi-selection
5. Cells show selection UI

### Exit Selection Mode
1. User taps "Cancel" or completes action
2. Selection cleared
3. UI returns to normal state
4. Navigation bar restored
5. Bottom toolbar hidden

## Preview Integration

### Selection-Aware Preview
```swift
if !selectionManager.selectedItems.isEmpty {
    photosToShow = allPhotos.filter { selectionManager.selectedItems.contains($0) }
} else {
    photosToShow = allPhotos
}
```

### Eye Button
- Appears when selection exists
- Shows only selected photos
- Maintains selection after preview
- Consistent across platforms

## Implementation Details

### Collection View Sync
```swift
// macOS - NSCollectionView delegate
func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
    for indexPath in indexPaths {
        let photo = photos[indexPath.item]
        selectionManager.addToSelection(photo)
    }
}
```

### Selection Operations
- **Add**: `addToSelection(_ item: PhotoReference)`
- **Remove**: `removeFromSelection(_ item: PhotoReference)`
- **Toggle**: `toggleSelection(_ item: PhotoReference)`
- **Clear**: `clearSelection()`
- **Select All**: Iterate through all photos

## Visual Design

### Selection Indicators
1. **Border**: Primary selection indicator
2. **Background**: Secondary visual feedback
3. **Checkbox** (iOS): Overlay in selection mode
4. **Focus Ring** (macOS): Keyboard navigation

### Color Scheme
- Selection: System blue
- Background tint: 15% opacity
- Focus: System focus color
- Border width: Platform-specific

## Trade-offs

### Original Design vs. Implementation
- **Planned**: Custom selection handling
- **Implemented**: Native collection view selection
- **Benefits**: 
  - Platform consistency
  - Less code to maintain
  - Built-in keyboard support
- **Limitations**:
  - Less control over behavior
  - Some edge cases differ from design

## Future Enhancements

1. Drag selection (rubber band)
2. Selection persistence
3. Smart selection (by date, type)
4. Selection actions menu
5. Quick Look for selection