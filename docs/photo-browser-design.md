# Photo Browser Feature Design

## Overview

A photo browser application similar to Adobe Bridge that allows users to browse and view their photo collections efficiently across Apple platforms.

## Platform Support

### Target Platforms
- **macOS**: Full-featured desktop experience with keyboard shortcuts and multi-window support
- **iOS**: Touch-optimized interface for iPhone and iPad
- **tvOS**: Big screen browsing with remote control navigation
- **visionOS** (future consideration): To be designed separately due to unique spatial computing requirements

### Platform-Specific Considerations

#### macOS
- Drag and drop support
- Multiple windows for comparing photos
- Keyboard shortcuts for navigation
- Right-click context menus
- Integration with Finder

#### iOS/iPadOS
- Touch gestures (pinch to zoom, swipe to navigate)
- Split-screen support on iPad
- Share sheet integration
- Photos app extension support
- iCloud Photo Library awareness

#### tvOS
- Focus-based navigation
- Remote control gestures
- Slideshow mode optimized for TV viewing
- Limited file system access (streaming from other devices)

## Core Features

### 1. Directory Selection and Scanning
- User selects a root directory to browse (platform-dependent):
  - **macOS**: Full file system access via NSOpenPanel
  - **iOS**: Document browser or Photos library access
  - **tvOS**: Browse shared folders from paired devices or network shares
- System recursively scans for all image files (JPEG, PNG, HEIF, RAW formats)
- Support for common photo formats used by cameras and phones

### 2. View Modes
- **Directory View**: Maintains folder hierarchy, showing photos organized by their directory structure
- **Flat View**: Shows all photos in one continuous grid, ignoring directory structure
- Toggle between views with a simple UI control

### 3. Thumbnail Management
- Generate thumbnails for fast browsing of large photo collections
- Cache thumbnails for performance

#### Storage Options to Consider:
1. **File System Cache**
   - Store thumbnails in a hidden directory (e.g., `~/Library/Caches/Photolala/`)
   - Pros: Simple, direct file access
   - Cons: Manual cache management needed

2. **SwiftData/Core Data**
   - Store thumbnails as binary data with metadata
   - Pros: Integrated querying, automatic memory management
   - Cons: Database size concerns with many images

3. **Hybrid Approach**
   - Store thumbnail file paths and metadata in SwiftData
   - Store actual thumbnail images in file system
   - Pros: Best of both worlds
   - Cons: More complex implementation

### 4. User Interface
- Grid layout similar to Photos.app
- Adjustable thumbnail sizes
- Smooth scrolling with lazy loading
- Quick preview on selection
- Full-screen view mode

### 5. Performance Considerations
- Asynchronous image loading and thumbnail generation
- Progressive loading for large directories
- Memory-efficient handling of large collections
- Background thumbnail generation

## Technical Architecture

### Shared Codebase Strategy
- Use SwiftUI for maximum code sharing across platforms
- Platform-specific UI adaptations using conditional compilation
- Shared data models and business logic
- Platform-specific features isolated in separate modules

### Data Model
```
Photo
- id: UUID
- filePath: String
- fileName: String
- directoryPath: String
- dateCreated: Date
- dateModified: Date
- fileSize: Int64
- imageWidth: Int?
- imageHeight: Int?
- thumbnailPath: String?
- isFavorite: Bool
- tags: [String]

Directory
- path: String
- name: String
- photoCount: Int
- lastScanned: Date
```

### Key Components
1. **PhotoScanner**: Discovers and indexes photos
2. **ThumbnailGenerator**: Creates and caches thumbnails
3. **PhotoGridView**: Main browsing interface
4. **PhotoDetailView**: Full-screen photo viewer
5. **DirectoryTreeView**: Hierarchical folder browser

## Future Enhancements
- Photo organization tools (move, copy, rename)
- Tagging and categorization
- Search functionality
- EXIF data viewing
- Basic editing capabilities
- Export and sharing options

## Questions for Discussion
1. Should we prioritize SwiftData or file system for thumbnail storage?
2. What should be the default thumbnail size(s) for each platform?
3. Should we support RAW formats initially or add later?
4. How should we handle duplicate photos?
5. What metadata should we extract and display?
6. Should thumbnails be generated on-demand or pre-generated?
7. How to handle photo access on iOS/tvOS with limited file system access?
8. Should we support iCloud Photos integration on iOS/macOS?
9. What navigation patterns work best for tvOS remote control?
10. Should we build platform-specific features first or focus on shared functionality?

## Next Steps
1. Finalize storage approach for thumbnails
2. Define specific image formats to support
3. Create UI mockups
4. Set up project structure with appropriate targets