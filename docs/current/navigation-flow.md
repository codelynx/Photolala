# Navigation Flow

Last Updated: July 3, 2025

## Overview

Photolala uses platform-appropriate navigation patterns - NavigationStack on Apple platforms and Jetpack Navigation on Android, each with platform-specific architectural approaches.

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

### Authentication (macOS)
- **Menu Access**: 
  - Photolala → Sign In... (when signed out)
  - Photolala → Sign Out [Username] (when signed in)
- **Toolbar Access**: Sign In button in folder browser windows
- **Window-based**: Authentication opens in dedicated window (600x700)
- **Cloud Settings**: Photolala → Cloud Backup Settings...
- **Native UI**: Uses macOS button styles (.borderedProminent, .bordered)

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

### Authentication (iOS)
- **Welcome View**: "Sign In to Enable Backup" button
- **Sheet Presentation**: Full-screen authentication sheet
- **Sign Out**: Available in both WelcomeView and AuthenticationChoiceView
- **Custom UI**: iOS-style buttons with colored backgrounds
- **Persistence**: Sign-in state maintained across app launches

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

## Android Navigation

### Jetpack Navigation Architecture
Single NavHost with composable destinations:
```kotlin
NavHost(
    navController = navController,
    startDestination = PhotolalaRoute.Welcome.route
) {
    composable(PhotolalaRoute.Welcome.route) { /* ... */ }
    composable(PhotolalaRoute.PhotoGrid.route) { /* ... */ }
    composable(PhotolalaRoute.PhotoViewer.route) { /* ... */ }
    composable(PhotolalaRoute.SignIn.route) { /* ... */ }
    composable(PhotolalaRoute.CreateAccount.route) { /* ... */ }
}
```

### Navigation Routes
```kotlin
sealed class PhotolalaRoute(val route: String) {
    object Welcome : PhotolalaRoute("welcome")
    object PhotoGrid : PhotolalaRoute("photo_grid")
    object PhotoViewer : PhotolalaRoute("photo_viewer/{photoIndex}")
    object SignIn : PhotolalaRoute("sign_in")
    object CreateAccount : PhotolalaRoute("create_account")
}
```

### User Interactions
- **Tap "Browse Photos"**: Navigate to PhotoGrid
- **Tap photo**: Navigate to PhotoViewer with index
- **Back gesture/button**: Pop back stack
- **Authentication**: Navigate to SignIn or CreateAccount

### Authentication (Android)
- **Welcome Screen**: 
  - "Sign In" button for existing users
  - "Create Account" button for new users
  - SignedInCard showing user status when authenticated
- **Full-Screen Navigation**: Authentication screens use navigation routes
- **Material3 UI**: Follows Material Design guidelines
- **Success/Cancel**: Pop back to previous screen
- **Secure Storage**: Android Keystore for credential encryption