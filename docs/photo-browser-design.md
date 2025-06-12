# Photo Browser Feature Design

## Overview

Photolala is a cross-platform photo browser application similar to Adobe Bridge that allows users to browse and view their photo collections efficiently across Apple platforms. It uses a window-per-folder architecture where each window displays photos from a single directory.

## Platform Support

### Target Platforms
- **macOS 14.0+**: Full-featured desktop experience with keyboard shortcuts and multi-window support
- **iOS 18.5+**: Touch-optimized interface for iPhone and iPad

### Platform-Specific Features

#### macOS
- Multiple windows (one per folder)
- Keyboard shortcuts for navigation
- Right-click context menus  
- Drag and drop folder to open
- No window persistence (fresh start each time)
- Welcome screen with "Select Folder" button

#### iOS/iPadOS
- Welcome screen with folder selection
- iPad: Multiple scenes for browsing different folders
- Touch gestures (pinch to zoom, swipe to navigate) (LATER)
- Photos Library integration

## Core Architecture

### Database-Free Design
- **No SwiftData/CoreData** - Simple file-based approach
- **PhotoRepresentation** struct instead of @Model class
- **SimplePhotoScanner** for directory scanning
- **File system as source of truth**

### Key Models

```swift
// Lightweight metadata representation
struct PhotoRepresentation: Identifiable, Hashable {
    let filePath: String              // Single source of truth
    let fileSize: Int64
    let createdDate: Date
    let modifiedDate: Date
    
    var photoIdentifier: PhotoIdentifier?  // Content-based ID
    var imageHeader: Data?            // First 64KB for metadata
    var imageWidth: Int?
    var imageHeight: Int?
    
    // Computed properties
    var id: String { filePath }
    var fileName: String { /* from filePath */ }
    var directoryPath: String { /* from filePath */ }
    var cacheKey: String { /* from photoIdentifier */ }
}

// Content-based identification
enum PhotoIdentifier {
    case contentHash(md5: String, byteSize: Int64)
    case photoLibrary(assetId: String)
    
    var string: String { /* "md5~hash~size" format */ }
}
```

## Core Features

### 1. Directory Scanning
- **SimplePhotoScanner** for fast file discovery
- Scan single directory (no recursion by default)
- Support common formats: JPEG, PNG, HEIF, HEIC, TIFF, GIF, WebP
- Network drive support (with loading indicators)
- `.photolala` footprint files for instant loading

### 2. Thumbnail System
- **Content-based caching**: `~/Library/Caches/Photolala/Thumbnails/`
- **Cache key**: Based on file content (MD5 hash + size)
- **Size**: 256px on longest edge, maintaining aspect ratio
- **Format**: JPEG with 0.8 quality
- **Single loading path**: NativePhotoGrid → ThumbnailService
- **Passive display**: ThumbnailView just shows cached thumbnails

### 3. User Interface
- **NativePhotoGrid**: Native collection view for performance
- **Adjustable grid size**: 2-10 columns
- **Scale modes**: Fill or Fit
- **Selection support**: Single and multi-select
- **LoadingManager**: Priority-based thumbnail loading
- **PhotoDetailView**: Full-screen viewing with zoom

### 4. Performance Optimizations
- **Lazy loading**: Only load visible thumbnails
- **Priority system**: Visible > Prefetch > Background
- **Memory efficient**: Thumbnails released when scrolled away
- **Native collection views**: Handle 100K+ photos
- **Footprint files**: Instant directory loading

## Loading Strategy

1. **Check `.photolala` footprint file**
   - CSV format: `filename,size,modified,headerMD5,width,height`
   - Provides instant photo list without scanning

2. **Quick scan for UI responsiveness**
   - Create PhotoRepresentation with basic file info
   - Display grid immediately
   - Load thumbnails on demand

3. **Progressive enhancement**
   - Calculate content identifiers in background
   - Generate missing thumbnails as needed
   - Update `.photolala` file for next time

4. **Thumbnail loading flow**
   ```
   Cell appears → Check disk cache → Display if found
                                  → Generate if missing
   ```

## Implementation Phases

### Phase 1: Core Foundation ✅ (Completed)
- [x] Basic project structure with macOS/iOS targets
- [x] PhotoRepresentation model (no database)
- [x] SimplePhotoScanner for directory listing
- [x] Basic MainWindowView
- [x] Window-per-folder architecture
- [x] Welcome screen with folder selection

### Phase 2: Thumbnail System 🚧 (In Progress)
- [x] ThumbnailService with disk caching
- [x] Content-based cache keys (MD5 + fileSize)
- [x] Single loading path (NativePhotoGrid → ThumbnailService)
- [ ] Complete removal of SwiftData dependencies
- [ ] Fix remaining Photo → PhotoRepresentation references
- [ ] Memory cache layer for performance

### Phase 3: Grid View Polish 📋
- [ ] Smooth scrolling with 10K+ photos
- [ ] Progressive loading indicators
- [ ] Selection persistence during scroll
- [ ] Grid size adjustment (2-10 columns)
- [ ] Scale mode toggle (Fill/Fit)
- [ ] Platform-specific optimizations

### Phase 4: Footprint System 📋
- [ ] `.photolala` file format implementation
- [ ] Fast directory loading from footprint
- [ ] Background footprint updates
- [ ] Incremental scanning for changes
- [ ] Network drive optimizations

### Phase 5: Photo Detail View 📋
- [ ] Full-screen photo viewer
- [ ] Smooth transitions from grid
- [ ] Zoom and pan gestures
- [ ] Previous/Next navigation
- [ ] Basic metadata display
- [ ] Platform-specific controls

### Phase 6: Advanced Features 📋
- [ ] Multi-selection operations
- [ ] Keyboard shortcuts (macOS)
- [ ] Touch gestures (iOS)
- [ ] Search and filtering
- [ ] Sort options (name, date, size)
- [ ] Export/sharing

### Phase 7: Performance & Polish 📋
- [ ] Handle 100K+ photo directories
- [ ] Memory usage optimization
- [ ] Background task management
- [ ] Error handling and recovery
- [ ] Accessibility support
- [ ] App icon and launch screen

### Phase 8: Future Enhancements 🔮
- [ ] EXIF metadata panel
- [ ] Folder tree navigation
- [ ] Tags and ratings system
- [ ] Duplicate detection
- [ ] Basic editing tools
- [ ] iCloud sync support

## Current Implementation Status

### ✅ Completed
- PhotoRepresentation model (no database)
- SimplePhotoScanner (file-based)
- MainWindowView without SwiftData
- ThumbnailService with disk caching
- NativePhotoGrid with platform adaptations
- Window-per-folder architecture
- Photos Library integration (iOS/macOS)

### 🚧 In Progress
- No migration we have never released the service

### 📋 Future Enhancements
- EXIF metadata viewing
- Search and filtering
- Folder tree navigation
- Export/sharing features
- Tags and ratings (using .photolala files)

## Technical Decisions

### Why No Database?
- **Simplicity**: File system is the source of truth
- **Reliability**: No database corruption
- **Performance**: No ORM overhead
- **Portability**: Just files, no migration issues

### Content-Based Identification
- **Deduplication**: Same photo identified even if moved/renamed
- **Stable cache keys**: Thumbnails persist across moves
- **Format**: `"md5~{hash}~{fileSize}"`

### Window-Per-Folder
- **Simple mental model**: One window = one folder
- **Multi-tasking**: Compare folders side by side
- **No state management**: Each window is independent

## Platform Differences

### macOS
- NSCollectionView with NSViewRepresentable
- Multiple windows via WindowGroup
- File system access via NSOpenPanel

### iOS
- UICollectionView with UIViewRepresentable  
- Navigation-based UI
- Limited file access (document picker)

## Next Steps

1. Complete PhotoRepresentation migration
2. Remove remaining SwiftData code
3. Implement .photolala footprint optimization
4. Add progressive metadata loading
5. Polish platform-specific features