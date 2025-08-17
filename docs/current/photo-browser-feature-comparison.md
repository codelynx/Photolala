# Photo Browser Feature Comparison

This document provides a comprehensive comparison of photo browser features across platforms (macOS, iOS, Android) and photo sources (Local Files, Apple Photos Library, Cloud/S3).

## Platform & Source Matrix

| Platform | Local Files | Apple Photos Library | Cloud (S3) |
|----------|------------|---------------------|------------|
| **macOS** | ✅ Full support | ✅ Full support | ✅ Full support |
| **iOS** | ✅ Full support | ✅ Full support | ✅ Full support |
| **Android** | ✅ Full support | ❌ Not available | ✅ Full support |

## Core Browser Features

### Photo Grid Display

| Feature | macOS Local | iOS Local | Android Local | macOS APL | iOS APL | macOS Cloud | iOS Cloud | Android Cloud |
|---------|------------|-----------|---------------|-----------|---------|-------------|-----------|---------------|
| **Grid View** | ✅ Native NSCollectionView | ✅ Native UICollectionView | ✅ LazyVerticalGrid | ✅ Native NSCollectionView | ✅ Native UICollectionView | ✅ Native NSCollectionView | ✅ Native UICollectionView | ✅ LazyVerticalGrid |
| **Thumbnail Sizes** | ✅ S/M/L/XL | ✅ S/M/L/XL | ✅ S/M/L | ✅ S/M/L/XL | ✅ S/M/L/XL | ✅ S/M/L/XL | ✅ S/M/L/XL | ✅ Fixed |
| **Lazy Loading** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Cell Recycling** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Smooth Scrolling** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Pull to Refresh** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

### Selection & Multi-Select

| Feature | macOS Local | iOS Local | Android Local | macOS APL | iOS APL | macOS Cloud | iOS Cloud | Android Cloud |
|---------|------------|-----------|---------------|-----------|---------|-------------|-----------|---------------|
| **Single Selection** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Multi-Selection** | ✅ Shift+Click, Cmd+Click | ✅ Long press | ✅ Long press | ✅ Shift+Click, Cmd+Click | ✅ Long press | ✅ Shift+Click, Cmd+Click | ✅ Long press | ✅ Long press |
| **Select All** | ✅ Cmd+A | ✅ Menu | ✅ Menu | ✅ Cmd+A | ✅ Menu | ✅ Cmd+A | ✅ Menu | ✅ Menu |
| **Clear Selection** | ✅ Esc | ✅ Menu | ✅ Menu | ✅ Esc | ✅ Menu | ✅ Esc | ✅ Menu | ✅ Menu |
| **Selection Count** | ✅ Status bar | ✅ Toolbar | ✅ Toolbar | ✅ Status bar | ✅ Toolbar | ✅ Status bar | ✅ Toolbar | ✅ Toolbar |

### Photo Preview/Viewer

| Feature | macOS Local | iOS Local | Android Local | macOS APL | iOS APL | macOS Cloud | iOS Cloud | Android Cloud |
|---------|------------|-----------|---------------|-----------|---------|-------------|-----------|---------------|
| **Full Screen Preview** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Zoom (Pinch/Scroll)** | ✅ 1x-10x | ✅ 1x-5x | ✅ 1x-5x | ✅ 1x-10x | ✅ 1x-5x | ✅ 1x-10x | ✅ 1x-5x | ⚠️ Basic |
| **Pan When Zoomed** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Double Tap Zoom** | ✅ 2x | ✅ 2x | ✅ 2x | ✅ 2x | ✅ 2x | ✅ 2x | ✅ 2x | ✅ 2x |
| **Swipe Navigation** | ✅ Arrow keys | ✅ | ✅ | ✅ Arrow keys | ✅ | ✅ Arrow keys | ✅ | ✅ |
| **Thumbnail Strip** | ✅ Native collection | ✅ Native collection | ✅ LazyRow | ✅ Native collection | ✅ Native collection | ✅ Native collection | ✅ Native collection | ❌ Not impl |
| **Auto-Hide Controls** | ✅ 6 sec | ✅ 6 sec | ❌ | ✅ 6 sec | ✅ 6 sec | ✅ 6 sec | ✅ 6 sec | ❌ |
| **Metadata Display** | ✅ HUD overlay | ✅ HUD overlay | ✅ Bottom sheet | ✅ HUD overlay | ✅ HUD overlay | ✅ HUD overlay | ✅ HUD overlay | ❌ |
| **Preview Mode** | ✅ All/Selected | ✅ All/Selected | ❌ All only | ✅ All/Selected | ✅ All/Selected | ✅ All/Selected | ✅ All/Selected | ❌ |

### Navigation & Organization

| Feature | macOS Local | iOS Local | Android Local | macOS APL | iOS APL | macOS Cloud | iOS Cloud | Android Cloud |
|---------|------------|-----------|---------------|-----------|---------|-------------|-----------|---------------|
| **Folder Navigation** | ✅ NavigationStack | ✅ NavigationStack | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Breadcrumbs** | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| **Albums** | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Search** | ✅ Filename | ✅ Filename | ✅ Filename | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Sort Options** | ✅ Name/Date/Size | ✅ Name/Date/Size | ✅ Name/Date | ✅ Date | ✅ Date | ✅ Name/Date | ✅ Name/Date | ✅ Name/Date |
| **Group by Date** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |

### Backup & Cloud Features

| Feature | macOS Local | iOS Local | Android Local | macOS APL | iOS APL | macOS Cloud | iOS Cloud | Android Cloud |
|---------|------------|-----------|---------------|-----------|---------|-------------|-----------|---------------|
| **Star for Backup** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Backup Queue** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Auto Backup Timer** | ✅ 1 min | ✅ 1 min | ✅ 1 min | ✅ 1 min | ✅ 1 min | ❌ | ❌ | ❌ |
| **Archive Status** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ Display | ✅ Display | ✅ Display |
| **Retrieval** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ Basic |
| **Download** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ |

### Bookmarks & Tags

| Feature | macOS Local | iOS Local | Android Local | macOS APL | iOS APL | macOS Cloud | iOS Cloud | Android Cloud |
|---------|------------|-----------|---------------|-----------|---------|-------------|-----------|---------------|
| **Emoji Bookmarks** | ✅ 12 types | ✅ 12 types | ✅ 12 types | ✅ 12 types | ✅ 12 types | ❌ | ❌ | ❌ |
| **Color Flags** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **Tag Dialog** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| **MD5 Identification** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |

### Platform-Specific Features

| Feature | macOS | iOS | Android |
|---------|-------|-----|---------|
| **Multi-Window** | ✅ Each folder/source in separate window | ❌ Single window | ❌ Single activity |
| **Menu Bar** | ✅ Full menu system | ❌ | ❌ |
| **Keyboard Shortcuts** | ✅ Extensive (Space, arrows, F, T, I, etc.) | ⚠️ Limited (external keyboard) | ❌ |
| **Inspector Panel** | ✅ Native inspector | ✅ Sheet-based | ❌ |
| **Drag & Drop** | ✅ | ❌ | ❌ |
| **Context Menus** | ✅ Right-click | ✅ Long press | ✅ Long press |
| **Welcome Screen** | ❌ Opens directly | ✅ | ✅ |
| **Account Settings** | ✅ | ✅ | ✅ |

## Implementation Technologies

### Apple Platforms (iOS/macOS)
- **UI Framework**: SwiftUI with UIKit/AppKit bridges
- **Collection Views**: Native NSCollectionView (macOS) / UICollectionView (iOS)
- **Navigation**: NavigationStack
- **Image Loading**: PhotoManagerV2 with caching
- **Gestures**: MagnificationGesture, DragGesture, TapGesture
- **Data Providers**: DirectoryPhotoProvider, ApplePhotosProvider, CloudPhotoProvider

### Android
- **UI Framework**: Jetpack Compose
- **Collection Views**: LazyVerticalGrid, LazyRow
- **Navigation**: Jetpack Navigation
- **Image Loading**: Coil with caching
- **Gestures**: Modifier.zoomable, detectTransformGestures
- **Data Providers**: MediaStore, S3 client

## Recent Improvements (From Previous Session)

1. **Preview Mode Fix**: Space key now respects selection (shows selected photos only when selection exists)
2. **Control Timer**: Increased from 3 to 6 seconds for better UX
3. **Thumbnail Strip Optimization**: Removed SwiftUI LazyHStack fallback, using only native collection views
4. **Gesture Conflict Resolution**: Fixed thumbnail tap responsiveness by proper gesture layering
5. **Android Thumbnail Strip**: Implemented LazyRow-based thumbnail strip for feature parity

## Known Limitations

### Android
- No Apple Photos Library support (platform limitation)
- Thumbnail strip in preview not yet implemented
- No keyboard shortcuts
- Basic zoom implementation compared to iOS/macOS
- No inspector panel

### iOS
- No multi-window support
- Limited keyboard shortcuts (external keyboard only)
- No drag & drop

### All Platforms
- Cloud photos are read-only (no local editing)
- Archive retrieval requires manual action
- No video playback in preview (photos only)

## Recommendations for Future Development

1. **Android Parity**: 
   - Implement thumbnail strip in PhotoViewerScreen
   - Add selection-based preview mode
   - Improve zoom/pan gestures to match iOS quality

2. **Cross-Platform**:
   - Unified gesture handling library
   - Consistent metadata display format
   - Shared animation timings and behaviors

3. **Performance**:
   - Optimize thumbnail generation for large collections
   - Implement smarter prefetching strategies
   - Consider virtual scrolling for very large grids