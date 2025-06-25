# Popover-based Context Menu Design

Date: June 19, 2025

## Overview

This document explores replacing traditional context menus with rich popover-based interactions for photo items in Photolala.

## Current Implementation

- Traditional NSMenu on right-click (macOS)
- Text-based menu items with SF Symbol icons
- Immediate action execution via async closures
- Built using PhotoItem's `contextMenuItems()` method

## Proposed Popover Approach

### Motivation

1. **Richer User Interface**
   - Display photo thumbnail preview
   - Show detailed metadata (size, dimensions, dates)
   - Support for progress indicators during operations
   - Custom layouts with visual hierarchy

2. **Modern User Experience**
   - Aligns with current macOS/iOS design patterns
   - More touch-friendly for iPad users
   - Visual feedback for actions
   - Space for explanatory text

3. **Enhanced Functionality**
   - Can include toggles, sliders, or other controls
   - Group related actions visually
   - Show real-time status updates
   - Progressive disclosure of information

## Design Mockup

```
┌─────────────────────────────┐
│ [Photo Thumbnail Preview]    │
│                             │
│ sunset-photo.jpg            │
│ 2.4 MB • 3024×4032 • JPEG  │
│ June 19, 2025 at 3:45 PM   │
│ ─────────────────────────   │
│ 📁 Show in Finder           │
│ 📋 Copy                     │
│ 🏷️ Add Tags...             │
│ ─────────────────────────   │
│ ☁️ Backup to Cloud          │
│ 🗄️ Archive (Deep Storage)   │
│ ⬇️ Restore from Archive     │
│    Expires in 24 hours      │
│ ─────────────────────────   │
│ ℹ️ More Info                │
│ 🗑️ Move to Trash           │
└─────────────────────────────┘
```

## Technical Implementation

### Trigger Mechanisms

1. **macOS**
   - Right-click → Show popover at cursor position
   - Control-click → Same as right-click
   - Click on cell's "•••" button → Show below button

2. **iOS/iPadOS**
   - Long press → Show popover with haptic feedback
   - Tap on cell's "•••" button → Show popover
   - 3D Touch (if available) → Peek and pop style

### Architecture

#### View Structure
```swift
struct PhotoPopoverView: View {
    let photo: any PhotoItem
    @State private var isPerformingAction = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with thumbnail and info
            PhotoPopoverHeader(photo: photo)
            
            Divider()
            
            // Action sections
            VStack(spacing: 12) {
                FileActionsSection(photo: photo)
                CloudActionsSection(photo: photo)
                DangerousActionsSection(photo: photo)
            }
            .padding()
        }
        .frame(width: 280)
    }
}
```

#### Platform Implementation

**macOS**
```swift
let popover = NSPopover()
popover.contentViewController = NSHostingController(
    rootView: PhotoPopoverView(photo: photo)
)
popover.behavior = .transient
popover.show(relativeTo: rect, of: view, preferredEdge: .maxY)
```

**iOS**
```swift
let hostingController = UIHostingController(
    rootView: PhotoPopoverView(photo: photo)
)
hostingController.modalPresentationStyle = .popover
hostingController.popoverPresentationController?.sourceView = cell
present(hostingController, animated: true)
```

### Features by Photo Type

#### Local Photos (PhotoFile)
- Show in Finder/Files
- Copy/Move operations
- Quick Look preview
- Add to backup queue
- File system operations

#### Cloud Photos (PhotoS3)
- Download options (original/optimized)
- Archive management
- Restore status and progress
- Share temporary link
- Storage class transitions

## Interaction Design

### Visual Feedback
1. **Hover States**: Highlight on mouse over (macOS)
2. **Press States**: Visual depression on tap
3. **Loading States**: Progress indicators for async operations
4. **Success/Error States**: Brief confirmation before dismiss

### Popover Behavior
1. **Dismissal**
   - Click/tap outside popover
   - ESC key (macOS)
   - Swipe down (iOS)
   - After successful action (configurable)

2. **Position Management**
   - Smart positioning to avoid screen edges
   - Arrow points to source cell
   - Maintains position during content updates

3. **Animation**
   - Smooth fade-in with slight scale
   - Spring physics for natural feel
   - Coordinated with cell highlighting

## Benefits Over Traditional Menus

1. **Information Density**: Show more context without clicking
2. **Visual Hierarchy**: Better organization of actions
3. **Progress Tracking**: Real-time feedback for long operations
4. **Discoverability**: Icons and descriptions improve clarity
5. **Touch Optimization**: Larger tap targets for mobile
6. **Extensibility**: Easy to add new sections/actions

## Implementation Phases

### Phase 1: Basic Popover
- Replace context menu with simple popover
- Port existing actions
- Basic styling and animations

### Phase 2: Enhanced UI
- Add thumbnail preview
- Include metadata display
- Implement progress indicators
- Add hover/press states

### Phase 3: Advanced Features
- Action grouping and sections
- Conditional actions based on state
- Keyboard shortcuts in popover
- Multi-selection support

## Alternative Approaches

### Hybrid Model
- Keep quick context menu for power users (right-click)
- Add popover for rich interaction (option-click or button)
- Best of both worlds approach

### Progressive Disclosure
- Compact popover initially
- "More" button reveals additional options
- Remember user's preference

## Considerations

### Performance
- Lazy load popover content
- Reuse popover instances
- Preload thumbnails in background

### Accessibility
- Full keyboard navigation
- VoiceOver support
- High contrast mode
- Respect reduced motion preferences

### Edge Cases
- Multiple selection handling
- Popover near screen edges
- Scroll view interaction
- Window resizing behavior

## Future Enhancements

1. **Custom Actions**: User-defined shortcuts
2. **Batch Operations**: Apply to multiple items
3. **Preview Extensions**: Quick Look integration
4. **Sharing**: Direct share to apps/services
5. **Automation**: Shortcuts app actions

## Decision Points

1. Should popover be modal or allow background interaction?
2. How to handle multiple popovers?
3. Which actions should dismiss vs update popover?
4. Should we maintain context menu as fallback?
5. Custom vs system popover appearance?

## Selection State Integration

### Challenge
How do popover context menus coexist with the collection view's selection state?

### Current Selection Behavior
- **Click/Tap**: Selects/deselects item
- **Cmd/Ctrl+Click**: Multi-select toggle  
- **Shift+Click**: Range select
- **Right-click**: Shows context menu (currently selects item if not selected)

### Recommended Approach: Smart Context Detection

#### Interaction Rules
1. **Right-click on unselected photo**
   - Select the photo first
   - Show single-photo popover

2. **Right-click on selected photo (alone)**
   - Keep selection
   - Show single-photo popover

3. **Right-click on selected photo (multiple selected)**
   - Keep all selections
   - Show bulk-action popover for all selected photos

4. **Right-click with mixed selection**
   - Option to include clicked photo in bulk action

#### Implementation
```swift
enum PopoverContext {
    case singlePhoto(PhotoItem)
    case multiplePhotos([PhotoItem])
    case mixedSelection([PhotoItem], clicked: PhotoItem)
}

func handleContextualClick(at photo: PhotoItem) {
    let context: PopoverContext
    
    if selectedPhotos.isEmpty {
        // Nothing selected - select clicked photo
        select(photo)
        context = .singlePhoto(photo)
    } else if selectedPhotos.contains(photo) {
        // Clicked on selected photo
        if selectedPhotos.count == 1 {
            context = .singlePhoto(photo)
        } else {
            context = .multiplePhotos(Array(selectedPhotos))
        }
    } else {
        // Clicked on unselected photo while others selected
        context = .mixedSelection(Array(selectedPhotos), clicked: photo)
    }
    
    showPopover(for: context)
}
```

### Visual Adaptations

#### Single Selection Popover
```
┌─────────────────────────────┐
│ [Photo Thumbnail]           │
│ sunset.jpg                  │
│ ─────────────────────────   │
│ 📁 Show in Finder           │
│ ☐ Add to Selection         │ ← Shows if others selected
└─────────────────────────────┘
```

#### Multi-Selection Popover  
```
┌─────────────────────────────┐
│ [Grid of 4 thumbnails]      │
│ 4 photos selected           │
│ Total size: 9.6 MB          │
│ ─────────────────────────   │
│ 📁 Show All in Finder       │
│ ☁️ Backup All               │
│ 🏷️ Tag All...              │
│ ─────────────────────────   │
│ ☐ Include clicked.jpg       │ ← If right-clicked unselected
└─────────────────────────────┘
```

### Design Principles

1. **Selection Preservation**
   - Never clear existing selection when showing popover
   - Exception: Right-clicking unselected item selects it

2. **Clear Visual Feedback**
   - Maintain selection highlighting under popover
   - Show selection count in popover header
   - Indicate whether actions apply to one or many

3. **Consistent Keyboard Behavior**
   - ESC dismisses popover only (preserves selection)
   - Selection shortcuts (Cmd+A) work normally
   - Arrow keys navigate grid, not popover

4. **Touch-Friendly Interaction**
   - Long-press shows popover without selection change
   - Selection mode toggle available in toolbar
   - Clear tap targets for all actions

### Alternative Approaches Considered

1. **Explicit Trigger Separation**: Dedicated "•••" button for popover
2. **Modal State Switch**: Toggle between selection and action modes
3. **Hover Actions**: Show actions on hover (desktop only)

The smart context detection approach was chosen for its familiarity and efficiency.

## Adaptive Content for Photo Types

### Challenge
PhotoItem protocol is implemented by different types (PhotoFile, PhotoS3) with varying available properties and capabilities. The popover must gracefully handle missing data and show appropriate actions.

### Property Availability by Type

| Property | PhotoFile | PhotoS3 | Handling |
|----------|-----------|---------|----------|
| filename | ✓ Always | ✓ Always | Safe to use |
| fileSize | ✓ Always | ✓ Always | Safe to use |
| dimensions | ✓ From metadata | ✓ From catalog | Show if available |
| creationDate | ✓ File system | ✓ photoDate | Fallback to modified |
| location | ✗ Not available | ✗ Not available | Hide section |
| storageClass | ✗ N/A | ✓ Always | S3 only |
| localPath | ✓ Always | ✗ Never | File only |
| md5 | ✓ Computed | ✓ Always | Different sources |

### Adaptive UI Implementation

```swift
struct PhotoPopoverView: View {
    let photo: any PhotoItem
    
    var body: some View {
        VStack(spacing: 0) {
            // Always available
            PhotoHeader(
                title: photo.displayName,
                subtitle: formatFileSize(photo.fileSize)
            )
            
            // Conditionally show metadata
            if let dimensions = photo.dimensions {
                DimensionsRow(dimensions)
            }
            
            if let date = photo.creationDate ?? photo.modificationDate {
                DateRow(date)
            }
            
            Divider()
            
            // Type-specific sections
            if photo is PhotoFile {
                LocalFileActions(photo)
            } else if photo is PhotoS3 {
                CloudPhotoActions(photo)
            }
            
            // Common actions
            CommonActions(photo)
        }
    }
}
```

### Graceful Degradation Examples

#### Full Information (Local File with Metadata)
```
┌─────────────────────────────┐
│ [Thumbnail]                 │
│ sunset-photo.jpg            │
│ 2.4 MB • 3024×4032 • JPEG  │
│ June 19, 2025 at 3:45 PM   │
│ ─────────────────────────   │
│ 📁 Show in Finder           │
│ 📋 Copy                     │
│ ☁️ Backup to Cloud          │
└─────────────────────────────┘
```

#### Minimal Information (S3 Photo without Dimensions)
```
┌─────────────────────────────┐
│ [Thumbnail or Placeholder]  │
│ vacation-photo.heic         │
│ 3.1 MB                      │
│ Uploaded May 2025           │
│ ─────────────────────────   │
│ ⬇️ Download                 │
│ 🗄️ Deep Archive            │
│ 🔗 Share Link              │
└─────────────────────────────┘
```

#### Loading State
```
┌─────────────────────────────┐
│ [Loading Spinner]           │
│ IMG_1234.JPG                │
│ Loading details...          │
│ ─────────────────────────   │
│ ⏸️ Cancel                   │
└─────────────────────────────┘
```

### Action Availability Matrix

```swift
extension PhotoItem {
    var availableActions: [PhotoAction] {
        var actions: [PhotoAction] = []
        
        // Universal actions
        actions.append(.copyName)
        
        // Type-specific actions
        switch self {
        case let file as PhotoFile:
            actions.append(.showInFinder)
            actions.append(.quickLook)
            if !file.isArchived {
                actions.append(.backupToCloud)
            }
            
        case let s3Photo as PhotoS3:
            actions.append(.download)
            if s3Photo.storageClass != .standard {
                actions.append(.restore)
            }
            if s3Photo.canShare {
                actions.append(.shareLink)
            }
        }
        
        return actions
    }
}
```

### Progressive Enhancement Strategy

1. **Core Information** (Always Show)
   - Filename
   - File size (if available)
   - Basic actions (copy name)

2. **Enhanced Information** (When Available)
   - Dimensions
   - Creation/modification date
   - File type/format
   - Location metadata

3. **Premium Features** (Type Specific)
   - Archive status and actions
   - Download progress
   - Sharing capabilities
   - Local file operations

### Error Handling

```swift
struct PhotoPopoverContent: View {
    @State private var loadError: Error?
    
    var body: some View {
        if let error = loadError {
            ErrorView(
                message: "Unable to load photo details",
                retry: { loadPhotoDetails() }
            )
        } else {
            // Normal content
        }
    }
}
```

### Best Practices

1. **Never Assume Properties**
   - Always use optional binding
   - Provide sensible defaults
   - Hide sections rather than show empty

2. **Loading States**
   - Show immediately with available data
   - Load additional details asynchronously
   - Update UI smoothly as data arrives

3. **Type Safety**
   - Use type checking for specific features
   - Avoid force casting
   - Leverage protocol extensions

4. **User Communication**
   - Clear messaging for unavailable features
   - Explain why actions are disabled
   - Suggest alternatives when possible

## References

- Apple HIG: [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers)
- NSPopover Documentation
- UIPopoverPresentationController Documentation
- SwiftUI Popover Modifier