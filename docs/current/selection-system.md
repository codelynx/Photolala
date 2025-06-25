# Selection System

Last Updated: June 15, 2025

## Overview

Photolala uses native platform selection mechanisms exclusively, leveraging UICollectionView and NSCollectionView's built-in selection capabilities for consistent platform behavior.

## Architecture

### System-Native Selection
- **No custom SelectionManager**: Direct use of collection view selection APIs
- **Platform consistency**: Follows iOS/macOS selection conventions
- **State management**: Selection state maintained by collection views
- **Callbacks**: `onSelectionChanged` provides selected photos array

## Platform-Specific Behavior

### macOS
- **Native Integration**: NSCollectionView with `allowsMultipleSelection`
- **Selection Storage**: `selectionIndexPaths` property
- **Keyboard Support**: 
  - Arrow keys for navigation
  - Shift+Arrow for range selection
  - Cmd+Click for toggle selection
- **Visual Feedback**:
  - Selected: 3px blue border + light blue background
  - Focus: 2px system focus color border

### iOS
- **Native Integration**: UICollectionView with `allowsMultipleSelection`
- **Selection Storage**: `indexPathsForSelectedItems` property
- **Touch Interactions**:
  - Single tap to select/deselect
  - Double tap to preview photo
- **Visual Feedback**:
  - Selected: 4px blue border + 15% blue tint
  - Unselected: 1px separator color border

## Implementation Details

### PhotoCollectionViewController

#### Selection Preservation
The collection view preserves selection state during:
- **Data Reloads**: Selection is saved before reload and restored after
- **Layout Updates**: Uses `invalidateLayout()` instead of `reloadData()` to maintain selection
- **Cell Reuse**: Cells sync their `isSelected` property when dequeued

```swift
func reloadData() {
    // Preserve selection when reloading
    let selectedPaths = collectionView.indexPathsForSelectedItems ?? []
    collectionView.reloadData()
    
    // Restore selection
    for indexPath in selectedPaths {
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }
}
```

#### iOS Selection Handling
```swift
func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    // System has already selected the item
    // Notify of selection change
    onSelectionChanged?(selectedPhotos)
}

func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
    // System has already deselected the item
    // Notify of selection change
    onSelectionChanged?(selectedPhotos)
}
```

#### macOS Selection Handling
```swift
func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
    onSelectionChanged?(selectedPhotos)
}

func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
    onSelectionChanged?(selectedPhotos)
}
```

### Cell Configuration

#### Syncing Selection During Cell Reuse
When cells are reused during scrolling, their selection state must be synchronized:

```swift
func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath)
    // ... configure cell ...
    
    // Sync selection state when cells are reused
    let selectedPaths = collectionView.indexPathsForSelectedItems ?? []
    let shouldBeSelected = selectedPaths.contains(indexPath)
    if shouldBeSelected != cell.isSelected {
        cell.isSelected = shouldBeSelected
    }
    
    return cell
}
```

### Cell Selection State

#### PhotoCollectionViewCell
```swift
override var isSelected: Bool {
    didSet {
        updateSelectionState()
    }
}

private func updateSelectionState() {
    #if os(macOS)
    // macOS: Border-based selection
    layer?.borderWidth = isSelected ? 3 : 0
    layer?.borderColor = isSelected ? NSColor.controlAccentColor.cgColor : nil
    layer?.backgroundColor = isSelected ? 
        NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor : 
        NSColor.clear.cgColor
    #else
    // iOS: Border + tint selection
    layer.borderWidth = isSelected ? 4 : 1
    layer.borderColor = isSelected ? 
        UIColor.systemBlue.cgColor : 
        UIColor.separator.cgColor
    contentView.backgroundColor = isSelected ? 
        UIColor.systemBlue.withAlphaComponent(0.15) : 
        .clear
    #endif
}
```

## Selection Operations

All selection operations are performed through collection view APIs:

- **Select**: `collectionView.selectItem(at:animated:scrollPosition:)`
- **Deselect**: `collectionView.deselectItem(at:animated:)`
- **Clear**: Iterate through selected items and deselect
- **Select All**: Iterate through all items and select
- **Get Selection**: 
  - iOS: `collectionView.indexPathsForSelectedItems`
  - macOS: `collectionView.selectionIndexPaths`

## Preview Integration

### Selection-Aware Preview
```swift
private func handlePhotoSelection(_ photo: PhotoReference, _ allPhotos: [PhotoReference]) {
    let photosToShow: [PhotoReference]
    let initialIndex: Int
    
    if !selectedPhotos.isEmpty {
        // Show only selected photos
        photosToShow = allPhotos.filter { selectedPhotos.contains($0) }
        initialIndex = photosToShow.firstIndex(of: photo) ?? 0
    } else {
        // Show all photos
        photosToShow = allPhotos
        initialIndex = allPhotos.firstIndex(of: photo) ?? 0
    }
}
```

### Eye Button
- Appears when selection exists
- Shows only selected photos in order
- Maintains selection after preview

## Benefits of System-Native Approach

1. **Platform Consistency**: Follows iOS/macOS HIG
2. **Reduced Complexity**: No custom state management
3. **Built-in Features**: Keyboard navigation, accessibility
4. **Performance**: Optimized platform implementations
5. **Future-Proof**: Automatically gets platform updates

## Trade-offs

### Advantages
- Less code to maintain
- Consistent with platform behavior
- Free keyboard/accessibility support
- Simpler state management

### Limitations
- Less control over selection behavior
- Platform differences must be accepted
- Custom selection features harder to implement