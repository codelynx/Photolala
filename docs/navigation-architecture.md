# Navigation and Window Architecture

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
- **NavigationStack**: Single stack for entire app
- **Push/Pop Navigation**: Standard iOS navigation patterns
- **Touch Interaction**: Tap to navigate (vs double-click on macOS)

### Folder Selection
- Document picker for folder selection
- Security-scoped bookmarks for persistent access
- Recent folders list (future enhancement)

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
App Launch → DefaultPhotoBrowserView → Pictures Folder (or empty state)
     ↓
File → Open Folder (⌘O) → NSOpenPanel → Navigate to selected folder
     ↓
Double-click folder → Push to NavigationStack
     ↓
Double-click photo → Push PhotoDetailView
```

### iOS
```
App Launch → WelcomeView → Select Folder → Document Picker
     ↓
NavigationStack → PhotoNavigationView → PhotoCollectionView
     ↓
Tap folder → Push to NavigationStack
     ↓
Tap photo → Push PhotoDetailView
```

## Key Design Decisions

1. **No Welcome on macOS**: Professional apps should open ready to work
2. **Menu-Driven Operations**: Standard macOS pattern for file operations
3. **NavigationStack Everywhere**: Consistent navigation model across platforms
4. **Native Collection Views**: Better performance for large photo collections
5. **Window Per Folder**: Allows comparing multiple folders side-by-side

## Future Enhancements

- Sidebar navigation for folder tree
- Tabs within windows for multiple folders
- Breadcrumb navigation bar
- Quick folder switching
- Recent folders in File menu
- Folder bookmarks/favorites