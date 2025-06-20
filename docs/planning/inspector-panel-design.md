# Inspector Panel Design

Date: June 19, 2025

## Overview

This document outlines the design for an inspector panel in Photolala, providing a modern alternative to context menus for displaying photo information and actions.

## Motivation

1. **Better UX**: Inspector panels are familiar to Mac users (Finder, Photos, Xcode)
2. **Always Accessible**: No need to right-click to see information
3. **Richer Interface**: Can display more information and controls than a menu
4. **Responsive**: Updates dynamically based on selection
5. **Touch Friendly**: Works well on iPad without right-click

## Design Specifications

### Platform-Specific Behavior

#### macOS
1. **Toggle**: Show/hide via:
   - Menu: View → Show Inspector (⌘I)
   - Toolbar button
   - Programmatically based on selection

2. **Position**:
   - Right side of window (default)
   - Fixed width: 260-320 points
   - Full height of window
   - Resizable with minimum/maximum constraints

3. **Persistence**:
   - Remember show/hide state per window
   - Remember width preference

#### iPad
1. **Toggle**: Show/hide via:
   - Toolbar button (info icon)
   - Swipe from right edge
   - Long press on photo → "Show Info"

2. **Presentation**:
   - **Regular width**: Sidebar (similar to macOS)
   - **Compact width**: Modal sheet or popover
   - **Split View**: Adaptive based on available space

3. **Persistence**:
   - Remember preference per size class
   - Auto-hide in compact environments

#### iPhone
1. **Toggle**: Show/hide via:
   - Toolbar button (info icon)
   - Swipe up gesture
   - Long press on photo → "Show Info"

2. **Presentation**:
   - Full-screen modal with dismiss button
   - Or bottom sheet (half-height, expandable)
   - Swipe down to dismiss

3. **Navigation**:
   - Segmented control for sections
   - Or scrollable single view
   - Collapse less important sections

### Content Sections

#### 1. Photo Information
- Thumbnail preview (if single selection)
- Grid preview (if multiple selection, max 4 thumbnails)
- File name
- File size
- Dimensions
- Date taken/modified
- Location (if available)

#### 2. Quick Actions
- Show in Finder (macOS) / Show in Files (iOS)
- Open With... (context-aware)
- Share (native share sheet)
- Star/Unstar for backup
- Copy/Duplicate
- Rename (future)

#### 3. Metadata (Collapsible)
- EXIF data
- Camera info
- GPS coordinates
- Keywords/tags

#### 4. Backup Status (for S3 photos)
- Backup state
- Storage class
- Last modified
- Retrieval options

### Selection Behavior

1. **No Selection**: Show placeholder "Select photos to view details"
2. **Single Selection**: Show full details for selected photo
3. **Multiple Selection**: Show summary (count, total size) and common actions
4. **Mixed Selection**: Show appropriate sections for mixed local/S3 photos

### Visual Design

- Use standard system styling (sidebar on macOS, grouped list on iOS)
- Section headers with disclosure triangles (chevrons on iOS)
- Subtle separators between sections
- Native controls (buttons, labels)
- Respect system appearance (light/dark mode)
- Consistent spacing and padding across platforms
- Loading states for async operations
- Empty states for missing metadata

## Implementation Approach

### 1. Inspector View (SwiftUI)
```swift
struct InspectorView: View {
    let selection: [any PhotoItem]

    var body: some View {
        // Inspector content
    }
}
```

### 2. Integration with PhotoBrowserView
- Add inspector state to view model
- Use HSplitView for layout
- Bind selection to inspector

### 3. Menu/Keyboard Support
- Add menu item to View menu
- Implement ⌘I shortcut
- Add toolbar button

### 4. State Management
- Track inspector visibility per window/device
- Persist width in UserDefaults (macOS/iPad)
- Update on selection changes
- Handle rotation and size class changes

### 5. Adaptive Layout
```swift
struct InspectorContainer: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var body: some View {
        if sizeClass == .regular {
            // Sidebar presentation
        } else {
            // Sheet/popover presentation
        }
    }
}
```

## Benefits Over Context Menus

1. **Discoverable**: Always visible when needed
2. **Non-Modal**: Doesn't block interaction
3. **Persistent**: Information stays visible
4. **Extensible**: Easy to add new sections
5. **Accessible**: Better for keyboard/voice control

## Future Enhancements

1. **Editing**: In-place editing of metadata
2. **Batch Operations**: Apply changes to multiple photos
3. **Plugins**: Allow extensions to add custom sections
4. **Export**: Export metadata to various formats
5. **Search**: Search within metadata

## Technical Considerations

1. **Performance**: Lazy load metadata to avoid blocking UI
2. **Caching**: Cache computed values (file sizes, dimensions)
3. **Updates**: Use Combine to update when files change
4. **Layout**: Handle different window sizes gracefully
5. **Touch**: Ensure touch targets meet minimum size (44pt)
6. **Gestures**: Support standard iOS/iPadOS gestures
7. **Keyboard**: Full keyboard navigation support on iPad

## Platform-Specific Features

### iOS/iPadOS Additions
- **Share Sheet**: Native share sheet integration
- **Quick Actions**: 3D Touch/Haptic Touch menus
- **Drag & Drop**: Support for dragging photos out
- **Context Menus**: Long-press for quick actions

### macOS Additions  
- **Drag & Drop**: Drag photos to Finder
- **Services Menu**: Integrate with system services
- **AppleScript**: Scriptable inspector properties
- **Keyboard Shortcuts**: Full keyboard control

## Example Implementations

### Files.app (iOS)
- Info button in toolbar
- Modal sheet presentation
- Segmented sections

### Photos.app (iOS/macOS)
- Unified info panel
- Adaptive presentation
- Rich metadata display

### Finder (macOS)
- Get Info window
- Inspector sidebar
- Live updates

## Accessibility Considerations

1. **VoiceOver**: Full support with descriptive labels
2. **Keyboard Navigation**: Tab through all controls
3. **Dynamic Type**: Respect text size preferences
4. **Reduce Motion**: Minimize animations when enabled
5. **High Contrast**: Support increased contrast mode

## Testing Strategy

1. **Unit Tests**: Test data formatting and calculations
2. **UI Tests**: Test show/hide behavior
3. **Device Testing**: Test on all supported devices
4. **Rotation Testing**: Ensure proper adaptation
5. **Performance Testing**: Large selections, slow metadata

## Success Metrics

1. **Discoverability**: Users find and use the inspector
2. **Performance**: No lag when updating selection
3. **Adoption**: Replaces need for context menus
4. **Satisfaction**: Positive user feedback
