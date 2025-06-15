# macOS Context Menu Design

## Overview

This document outlines the design for implementing context menus in Photolala's photo browser on macOS. The context menu will provide quick access to photo details, metadata, and file operations without navigating away from the grid view.

## Problem Statement

### Current Limitations
1. **Small thumbnail trade-off**: In Small (64px) mode, users can see many photos at once but details are hard to discern
2. **No quick metadata access**: Users must open preview to see photo metadata
3. **Limited file operations**: No quick way to reveal photos in Finder or use Quick Look
4. **Size constraints**: Large mode (256px) is the maximum without sacrificing quality

### User Needs
- Quick preview of photo details without leaving grid view
- Access to metadata for decision making (date, camera, size)
- Non-destructive file operations (reveal in Finder, open with other apps)
- Larger preview when needed, especially in Small mode

### Design Philosophy
Photolala is a **browsing tool**, not a file manager. The context menu should:
- Provide quick access to photo information
- Enable opening photos in other applications for editing
- Avoid any destructive operations (delete, move, rename)
- Keep the interface clean and focused

## Proposed Solution

### Context Menu Trigger
- **Right-click** on any photo in the collection view
- **Control-click** as alternative
- Menu appears at cursor position

### Menu Structure

```
┌─────────────────────────────────┐
│ [Photo Preview - 512x512px]     │
│                                 │
│ DSC_1234.jpg                   │
│ 4032 × 3024 • 5.2 MB          │
│ June 15, 2025 at 2:34 PM      │
│ Canon EOS R5                   │
├─────────────────────────────────┤
│ Open                       ⏎   │
│ Quick Look            Space   │
│ Open With...              ▶   │
├─────────────────────────────────┤
│ Reveal in Finder          ⌘R  │
│ Get Info                  ⌘I  │
└─────────────────────────────────┘
```

### Context Menu Components

#### 1. Photo Preview Section (Top)
- **Size**: 512x512 pixels (2x Large mode)
- **Quality**: Uses existing thumbnail if available, generates if needed
- **Display**: 
  - Centered in menu width
  - Always uses Scale to Fit (shows entire image)
  - Transparent background with 1px border
  - 4px rounded corners
- **Loading**: Show spinner if thumbnail not ready

#### 2. Metadata Section
- **Filename**: Bold, truncated with ellipsis if too long
- **Dimensions & Size**: "width × height • file size"
- **Date**: Formatted date/time (respects system locale)
- **Camera**: Make and model if available
- **Loading**: "Loading metadata..." if not yet fetched

#### 3. Action Items
- **Open**: Navigate to PhotoPreviewView (same as double-click)
- **Quick Look**: System Quick Look preview (spacebar)
- **Open With**: System menu for external apps
- **Reveal in Finder**: Show file location
- **Get Info**: System file info panel

No destructive operations - Photolala is purely for browsing

## Implementation Details

### NSMenu Custom View

```swift
// Custom view for preview + metadata section
class PhotoContextMenuHeaderView: NSView {
    let imageView: ScalableImageView
    let filenameLabel: NSTextField
    let dimensionsLabel: NSTextField
    let dateLabel: NSTextField
    let cameraLabel: NSTextField
    let loadingSpinner: NSProgressIndicator
    
    func configure(with photo: PhotoReference) {
        // Load thumbnail at 512px
        // Display existing metadata
        // Fetch full metadata if needed
    }
}
```

### Integration Points

1. **PhotoCollectionViewController**
   - Add `menu` property to NSCollectionView
   - Implement `menuForEvent:` or use `NSCollectionViewDelegate`
   - Track right-clicked item

2. **Metadata Loading**
   - Use existing PhotoManager for thumbnail
   - Load metadata asynchronously if not cached
   - Update menu view when data arrives

3. **Menu Actions**
   - Open: Navigate to PhotoPreviewView
   - Quick Look: Use QLPreviewPanel
   - Open With: System open with menu
   - Reveal in Finder: NSWorkspace.shared.selectFile
   - Get Info: NSWorkspace.shared.showFileInfo

### Performance Considerations

1. **Lazy Loading**
   - Don't generate 512px thumbnail until menu requested
   - Cache generated thumbnails
   - Show placeholder while loading

2. **Metadata**
   - Use cached metadata when available
   - Load asynchronously to avoid blocking
   - Show partial data immediately

3. **Menu Reuse**
   - Create menu once, update content
   - Avoid recreating views

## Platform Considerations

### macOS Specific
- Uses NSMenu with custom NSMenuItem views
- Integrates with system services (Quick Look, Finder)
- Follows macOS HIG for context menus

### Not for iOS/iPadOS
- iOS uses different interaction pattern (long press)
- Would require UIContextMenuConfiguration
- Different preview style (blurred background)

## Visual Design

### Spacing
- 16px padding around preview image
- 8px between metadata lines
- Standard menu item heights for actions

### Typography
- Filename: System font, medium, 13pt
- Metadata: System font, regular, 11pt, secondary color
- Menu items: Standard system menu font

### Colors
- Background: Standard menu background
- Text: Label colors (primary/secondary)
- Dividers: Standard separator color

## Keyboard Support

- **Escape**: Dismiss menu
- **Arrow keys**: Navigate menu items
- **Return**: Activate selected item
- Standard shortcuts for actions

## Edge Cases

1. **Missing Metadata**
   - Show only available information
   - Don't show empty lines

2. **Loading Failures**
   - Show error message in preview area
   - Disable relevant menu items

3. **Multiple Selection**
   - Show count in header: "3 photos selected"
   - Only show menu items that make sense for multiple files
   - No preview for multiple items
   - Quick Look can handle multiple items

4. **Small Window**
   - Ensure menu doesn't exceed window bounds
   - Position adjustment if needed

## Future Enhancements

1. **Extended Metadata**
   - EXIF details submenu
   - GPS location with map
   - Histogram

2. **Read-Only Features**
   - Copy image info to clipboard
   - Export metadata as text
   - Show color profile information

3. **Integration**
   - Quick Look plugins support
   - Custom preview renderers
   - Metadata extensions

## Testing Strategy

1. **Functional Tests**
   - Right-click on various photos
   - Verify all actions work
   - Test with missing metadata

2. **Performance Tests**
   - Large folders (1000+ photos)
   - Rapid context menu opening
   - Memory usage monitoring

3. **UI Tests**
   - Different thumbnail sizes
   - Various image aspect ratios
   - Dark/light mode

## Success Criteria

1. Menu appears within 100ms of right-click
2. Preview image loads within 200ms (if cached)
3. All actions complete successfully
4. No memory leaks with repeated use
5. Smooth scrolling maintained in grid

## Implementation Priority

1. **Phase 1**: Basic menu with preview and metadata
2. **Phase 2**: File operations (Open, Reveal, Copy)
3. **Phase 3**: Quick Look and sharing
4. **Phase 4**: Advanced features (if needed)

## Questions to Resolve

1. Should we show RAW file badges/indicators?
2. How to handle encrypted/protected files?
3. Should menu stay open after some actions?
4. Custom preview size preference?
5. Should we add "Copy Image" for copying to clipboard?
6. ~~How to indicate when metadata is still loading?~~ → Shows "Loading..." text

## Implementation Status ✅

### Completed Features

1. **Context Menu Infrastructure**
   - Custom `ClickedCollectionView` to track right-clicked items
   - NSMenuDelegate implementation for dynamic menu building
   - Proper handling of Control+click as right-click

2. **PhotoContextMenuHeaderView**
   - 512x512px preview area with transparent background
   - 1px separator color border (consistent with thumbnails)
   - ScalableImageView with `.scaleToFit` for proper aspect ratio
   - Dynamic height using `intrinsicContentSize`
   - Async thumbnail loading with spinner feedback

3. **Metadata Display**
   - Filename (bold, 13pt)
   - Dimensions & file size (11pt, secondary color)
   - File modification date (formatted)
   - Camera info when available
   - "Loading..." placeholder for async data

4. **Menu Actions**
   - Open (navigates to PhotoPreviewView)
   - Quick Look with full QLPreviewPanel integration
   - Open With submenu (dynamic app list)
   - Reveal in Finder (single/multiple files)
   - Get Info (using AppleScript)

5. **Visual Refinements**
   - Transparent background instead of gray fill
   - Thin border matching thumbnail style
   - 4px rounded corners
   - Proper constraint handling without conflicts

### Implementation Details

1. **Event Handling**
   ```swift
   // ClickedCollectionView tracks right-clicked item
   override func menu(for event: NSEvent) -> NSMenu? {
       clickedIndexPath = indexPathForItem(at: point)
       // Auto-select if not already selected
   }
   ```

2. **Dynamic Sizing**
   ```swift
   override var intrinsicContentSize: NSSize {
       let width: CGFloat = 544
       var height: CGFloat = 16 + 512 + 16 + metadataHeight + 16
       return NSSize(width: width, height: height)
   }
   ```

3. **Quick Look Integration**
   - Implements QLPreviewPanelDataSource & Delegate
   - Proper animation from thumbnail position
   - Supports multiple photo selection

### Lessons Learned

1. **NSMenuItem with custom views needs careful setup**
   - Must disable `translatesAutoresizingMaskIntoConstraints`
   - Use `intrinsicContentSize` instead of fixed frames
   - Call `invalidateIntrinsicContentSize()` when content changes

2. **Control+click handling**
   - PhotoCollectionViewItem passes Control+click to rightMouseDown
   - Menu delegate approach cleaner than manual menu creation

3. **Visual consistency**
   - Transparent background with border looks better than solid fill
   - Matches existing thumbnail design language

### Known Issues / TODOs

1. **Debug statements** - Remove print statements in production:
   - ClickedCollectionView has debug prints
   - PhotoCollectionViewController menuNeedsUpdate has debug prints
   - PhotoCollectionViewItem mouseDown has debug prints

2. **Future enhancements**:
   - Consider caching 512px thumbnails separately
   - Add keyboard navigation within menu
   - Support for RAW file indicators
   - Copy image to clipboard functionality