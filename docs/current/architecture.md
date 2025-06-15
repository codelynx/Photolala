# Photolala Architecture

Last Updated: June 14, 2025

## Overview

Photolala is a cross-platform photo browser application built with SwiftUI, supporting macOS, iOS, and tvOS. It follows a window-per-folder architecture on macOS and uses native collection views for optimal performance with large photo collections.

## Core Architecture Principles

1. **Platform-Native UI**: Uses NSCollectionView (macOS) and UICollectionView (iOS) wrapped in SwiftUI
2. **Efficient Memory Management**: Lightweight PhotoReference model with lazy thumbnail loading
3. **Window-Per-Folder** (macOS): Each folder opens in its own window, allowing side-by-side comparison
4. **Reactive Updates**: @Observable models for automatic UI updates

## Component Architecture

### Models

#### PhotoReference
- Lightweight file representation
- Properties: `directoryPath` (NSString), `filename` (String)
- Computed: `fileURL`, `filePath`
- Observable with thumbnail caching

#### ThumbnailDisplaySettings
- Per-window display preferences
- Display modes: Scale to Fit / Scale to Fill
- Size options: Small (64px), Medium (128px), Large (256px)

#### Selection System
- Uses native collection view selection
- No custom SelectionManager
- State maintained by UICollectionView/NSCollectionView
- Selection changes communicated via callbacks

### Services

#### PhotoManager (Singleton)
- Dual caching: memory (NSCache) + disk
- Thumbnail generation with proper scaling
- Content-based identification (MD5)
- Thread-safe with QoS .userInitiated

#### DirectoryScanner
- Scans directories for supported image formats
- Creates PhotoReference objects
- Filters: jpg, jpeg, png, heic, heif, tiff, bmp, gif, webp

### Views

#### PhotoBrowserView
- Main container with toolbar
- Platform-specific navigation:
  - macOS: Own NavigationStack
  - iOS: Uses parent NavigationStack
- Manages settings and selection state

#### PhotoCollectionViewController
- NSViewController/UIViewController subclass
- Hosts native collection views
- Handles platform-specific interactions:
  - macOS: Double-click navigation
  - iOS: Tap navigation, selection mode

#### PhotoPreviewView
- Pure SwiftUI implementation
- Full image display with zoom/pan
- MagnificationGesture + DragGesture
- Cross-platform image handling

## Navigation Architecture

### macOS
```
App Launch → No default window
    ↓
File → Open Folder (⌘O) → NSOpenPanel
    ↓
New Window with NavigationStack → PhotoBrowserView
    ↓
Double-click folder → Push new PhotoBrowserView
    ↓
Double-click photo → Push PhotoPreviewView
```

### iOS
```
App Launch → Root NavigationStack → WelcomeView
    ↓
Select Folder → Document Picker
    ↓
Auto-navigate → PhotoBrowserView
    ↓
Tap folder → Push new PhotoBrowserView
    ↓
Tap photo → Push PhotoPreviewView
```

## Data Flow

1. **Directory Scanning**: DirectoryScanner → [PhotoReference]
2. **Thumbnail Loading**: PhotoReference → PhotoManager → Cached Thumbnail
3. **Selection**: User Interaction → SelectionManager → UI Updates
4. **Navigation**: Selection/Tap → NavigationStack → New View

## Platform Differences

### macOS
- Multiple windows support
- Menu-driven operations
- Keyboard navigation focus
- Double-click interactions
- NSCollectionView with built-in selection

### iOS/iPadOS
- Single window with NavigationStack
- Touch interactions
- Selection mode with toolbar
- Swipe gestures
- UICollectionView with custom selection UI

## Performance Optimizations

1. **Lazy Loading**: Thumbnails generated on-demand
2. **Dual Caching**: Memory cache + disk cache
3. **Content-Based Keys**: Prevents duplicate processing
4. **Proper Sizing**: Thumbnails scaled appropriately
5. **Native Collection Views**: Better performance than SwiftUI Grid

## Thread Safety

- PhotoManager uses serial DispatchQueue
- Main actor for UI updates
- Async/await for image operations
- No priority inversions (fixed in implementation)