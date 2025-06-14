# Navigation and Window Architecture

Last Updated: June 14, 2025

## Overview

Photolala uses platform-appropriate navigation patterns, with a focus on macOS conventions for desktop usage and iOS patterns for mobile devices.

## macOS Navigation

### Window Management
- **No Welcome Screen**: App opens directly to a functional photo browser
- **Default Folder**: Opens Pictures folder on launch (if available)
- **Menu-Driven**: File → Open Folder... (⌘O) for folder selection
- **Multi-Window Support**: Each folder can open in its own window
- **Window Per Folder**: Maintains Adobe Bridge-like workflow

### Navigation Within Windows
- **NavigationStack**: Each window has its own navigation stack
- **Push Navigation**: Double-click folders to navigate deeper
- **Back Button**: Navigate up the folder hierarchy
- **Toolbar Actions**:
  - "Open in New Window" - Opens current folder in new window
  - "Select Folder..." - Navigate to different folder in same window

### Implementation Details

#### PhotolalaCommands
```swift
struct PhotolalaCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Folder...") {
                openFolder()
            }
            .keyboardShortcut("O", modifiers: .command)
        }
    }
}
```

#### DefaultPhotoBrowserView
- Shows current folder content or empty state
- Handles initial folder selection
- Opens Pictures folder by default
- Provides "No Folder Selected" state with ⌘O hint

#### Window Groups
1. **Main Window**: `WindowGroup("Photolala")` - Default window on launch
2. **Folder Windows**: `WindowGroup("Photo Browser", for: URL.self)` - Additional folder windows

## iOS/iPadOS Navigation

### Single Window Approach
- **Welcome Screen**: Initial folder selection interface
- **NavigationStack**: Single stack for entire app at root level
- **Push/Pop Navigation**: Standard iOS navigation patterns
- **Touch Interaction**: Tap to navigate (vs double-click on macOS)

### Folder Selection
- Document picker for folder selection
- Security-scoped bookmarks for persistent access
- Recent folders list (future enhancement)

### Photo Preview Navigation (Updated June 14, 2025)
- **Navigation Fix**: PhotoBrowserView uses `.navigationDestination(item:)` instead of its own NavigationStack
- **State Management**: `@State private var selectedPhotoNavigation: PreviewNavigation?`
- **Seamless Integration**: Works within parent NavigationStack from app root

## Cross-Platform Components

### PhotoNavigationView
- Wraps PhotoCollectionView with NavigationStack
- Handles navigation destinations:
  - Folder navigation (push new collection view)
  - Photo detail view (full-screen photo viewer)
- Platform-specific toolbar items

### PhotoCollectionViewController
- Native collection views (NSCollectionView/UICollectionView)
- Hosted in SwiftUI via representable protocols
- Callbacks for navigation:
  - `onSelectPhoto`: Navigate to photo detail
  - `onSelectFolder`: Navigate to subfolder

## Navigation Flow

### macOS
```
App Launch → No default window (as of June 2025)
     ↓
File → Open Folder (⌘O) → NSOpenPanel → Open new window with folder
     ↓
Each window has NavigationStack → PhotoBrowserView
     ↓
Double-click folder → Push to NavigationStack
     ↓
Double-click photo → Push PhotoPreviewView
     ↓
Selection mode: Select photos → Eye button → Preview selected photos
```

### iOS
```
App Launch → NavigationStack (root) → WelcomeView
     ↓
Select Folder → Document Picker → Auto-navigate to PhotoBrowserView
     ↓
PhotoBrowserView (within parent NavigationStack)
     ↓
Tap folder → Push new PhotoBrowserView
     ↓
Tap photo → Set selectedPhotoNavigation → Push PhotoPreviewView
     ↓
Selection mode: Select photos → Eye button → Preview selected photos
```

## Selection Preview Feature (Added June 14, 2025)

### Overview
- **Eye Button**: Appears in toolbar when photos are selected
- **Consistent Behavior**: Works identically on macOS and iOS
- **Smart Preview**: Shows only selected photos when selection exists

### Implementation
- **PhotoBrowserView**: Added `previewSelectedPhotos()` method
- **Sorting**: Selected photos shown in alphabetical order by filename
- **UI Integration**: Eye icon with "Preview" label in toolbar
- **Platform Help**: macOS shows "Preview selected photos" tooltip

## Key Design Decisions

1. **No Welcome on macOS**: Professional apps should open ready to work
2. **Menu-Driven Operations**: Standard macOS pattern for file operations
3. **NavigationStack Architecture**: 
   - macOS: Each window has its own NavigationStack
   - iOS: Single root NavigationStack, views use `.navigationDestination(item:)`
4. **Native Collection Views**: Better performance for large photo collections
5. **Window Per Folder**: Allows comparing multiple folders side-by-side
6. **Selection Preview**: Separate action for previewing selected photos

## Future Enhancements

- Sidebar navigation for folder tree
- Tabs within windows for multiple folders
- Breadcrumb navigation bar
- Quick folder switching
- Recent folders in File menu
- Folder bookmarks/favorites