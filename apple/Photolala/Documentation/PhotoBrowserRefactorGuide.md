# Photo Browser Architecture Refactor Guide

## Overview
We've refactored the photo browser to follow cleaner separation of concerns:
- **PhotoBrowserView**: Pure rendering view (no source management)
- **PhotoBrowserHostView**: Manages source switching and environment updates
- **PhotoSourceFactory**: Handles async source creation with platform awareness

## Migration Steps

### 1. Replace PhotoBrowserView with PhotoBrowserHostView

**Before:**
```swift
// In HomeView, PhotoWindowManager, etc.
PhotoBrowserView(
    environment: environment,
    title: "Photos",
    onSourceChange: { newSource in ... }
)
```

**After:**
```swift
PhotoBrowserHostView(
    initialEnvironment: environment,
    title: "Photos",
    factory: DefaultPhotoSourceFactory.shared,
    onSourceChange: { newSource in ... }
)
```

### 2. For Simple Display (No Source Switching)

If you just need to display photos without source switching:

```swift
PhotoBrowserView(
    environment: environment,
    title: "Photos",
    onItemTapped: { item in ... }
)
```

### 3. Update Window Creation (macOS)

**In PhotoWindowManager:**
```swift
func openCloudPhotosWindow(environment: PhotoBrowserEnvironment) {
    let contentView = NavigationStack {
        PhotoBrowserHostView(
            initialEnvironment: environment,
            title: "Cloud Photos"
        )
        .navigationTitle("Cloud Photos")
        .navigationSubtitle("Photolala Cloud")
    }
    // ... rest of window creation
}
```

### 4. Update Navigation Destinations (iOS)

**In HomeView navigation destinations:**
```swift
case .localFolder(let url, let scopeStarted):
    let source = LocalPhotoSource(directoryURL: url, requiresSecurityScope: true)
    let environment = PhotoBrowserEnvironment(source: source)
    PhotoBrowserHostView(
        initialEnvironment: environment,
        title: url.lastPathComponent
    )

case .cloudPhotos:
    CloudPhotosLoaderView() // This internally uses PhotoBrowserHostView
```

## Key Benefits

1. **Clean Separation**: Views don't manage their own data sources
2. **Platform Awareness**: Factory handles iOS vs macOS differences
3. **State Consistency**: Host ensures UI and source stay in sync
4. **Error Recovery**: Proper rollback on source creation failures
5. **Testability**: Pure views are easier to test and preview

## Factory Pattern Usage

The `PhotoSourceFactory` provides platform-aware source creation:

```swift
let factory = DefaultPhotoSourceFactory.shared

// Create local source (handles iOS sandbox)
let localSource = await factory.makeLocalSource(url: nil)

// Create cloud source (throws on failure)
let cloudSource = try await factory.makeCloudSource()

// Create Apple Photos source
let appleSource = factory.makeApplePhotosSource()
```

## Source Switching Flow

1. User selects new source in UI
2. Host captures current state (for rollback)
3. Factory creates new source asynchronously
4. On success: Update environment, notify callbacks
5. On failure: Restore previous state, show error

## Platform-Specific Behavior

### macOS
- Can create local source with Pictures directory fallback
- Windows can be opened at any time

### iOS
- Requires security-scoped bookmarks for folders
- Shows error if no folder previously selected
- Navigation-based instead of window-based

## Testing

The refactored architecture makes testing easier:

```swift
// Test view with mock source
let mockSource = MockPhotoSource()
let env = PhotoBrowserEnvironment(source: mockSource)
let view = PhotoBrowserView(environment: env)

// Test factory with different scenarios
let factory = TestPhotoSourceFactory()
let source = await factory.makeLocalSource(url: testURL)
```