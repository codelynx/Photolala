# Navigation Flow

Last Updated: June 14, 2025

## Overview

Photolala uses platform-appropriate navigation patterns with NavigationStack on both platforms, but with different architectural approaches.

## macOS Navigation

### Window Management
- **No Default Window**: App launches without a window
- **Menu-Driven**: File → Open Folder... (⌘O)
- **Window-Per-Folder**: Each folder opens in a new window
- **Multi-Window Support**: Compare folders side-by-side

### Navigation Stack
Each window has its own NavigationStack:
```swift
NavigationStack(path: $navigationPath) {
    PhotoBrowserView()
        .navigationDestination(for: PreviewNavigation.self) { 
            PhotoPreviewView()
        }
}
```

### User Interactions
- **Double-click folder**: Push new PhotoBrowserView
- **Double-click photo**: Push PhotoPreviewView
- **Selection + Eye button**: Preview selected photos
- **Keyboard**: Arrow keys for navigation
- **Escape**: Close preview

## iOS Navigation

### Single NavigationStack Architecture
Root-level NavigationStack in App:
```swift
WindowGroup {
    NavigationStack {
        WelcomeView()
    }
}
```

### Navigation Implementation
PhotoBrowserView uses `.navigationDestination(item:)`:
```swift
.navigationDestination(item: $selectedPhotoNavigation) { navigation in
    PhotoPreviewView(photos: navigation.photos, initialIndex: navigation.initialIndex)
}
```

### User Interactions
- **Tap folder**: Push new PhotoBrowserView
- **Tap photo**: Set selectedPhotoNavigation state
- **Selection mode**: Tap to select, eye button to preview
- **Swipe**: Navigate between photos in preview
- **Pinch**: Zoom in preview

## Selection Preview Feature

### Behavior
- **Normal Mode**: Direct navigation to photo
- **Selection Mode**: 
  - Tap/click selects photos
  - Eye button previews selection
  - Photos shown in alphabetical order

### Implementation
```swift
private func previewSelectedPhotos() {
    let selectedPhotos = selectionManager.selectedItems.sorted { 
        $0.filename < $1.filename 
    }
    let navigation = PreviewNavigation(photos: selectedPhotos, initialIndex: 0)
    
    #if os(macOS)
    navigationPath.append(navigation)
    #else
    selectedPhotoNavigation = navigation
    #endif
}
```

## Key Design Decisions

1. **Platform-Specific Navigation**: 
   - macOS: Window owns NavigationStack
   - iOS: App owns NavigationStack
   
2. **State Management**:
   - macOS: NavigationPath for push/pop
   - iOS: Optional state for presentation
   
3. **Selection Integration**: Same preview mechanism for both individual and selected photos

## Navigation Data Model

```swift
struct PreviewNavigation: Hashable {
    let photos: [PhotoReference]
    let initialIndex: Int
}
```