# Thumbnail System

Last Updated: June 25, 2025

## Overview

Photolala implements a sophisticated thumbnail system with dual caching (memory + disk), content-based identification, and proper image scaling.

## PhotoManager Architecture

### Singleton Pattern
```swift
class PhotoManager {
    static let shared = PhotoManager()
    private let imageCache = NSCache<NSString, XImage>()
    private let thumbnailCache = NSCache<NSString, XImage>()
}
```

### Key Features
- **Dual Caching**: Separate caches for full images and thumbnails
- **Content-Based Keys**: MD5 digest prevents duplicate processing
- **Thread Safety**: Serial DispatchQueue with QoS .userInitiated
- **Cross-Platform**: Works on macOS and iOS

## Thumbnail Generation

### Sizing Algorithm
1. Calculate scale to fit 256px on shorter side
2. Scale image maintaining aspect ratio
3. Crop longer side to max 512px if needed
4. Final size: 256px on short side, max 512px on long side

### Platform Implementation

#### macOS
```swift
// Uses NSBitmapImageRep for thread safety
let bitmap = NSBitmapImageRep(...)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
scaledImage.draw(in: targetRect)
```

#### iOS
```swift
// Manual EXIF orientation handling
UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
image.draw(in: targetRect)
let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
```

## Caching Strategy

### Three-Tier Cache System (June 25, 2025)

Photolala now uses a three-tier caching system for optimal performance:

1. **Memory Cache (NSCache)**
   - Automatic memory pressure handling
   - Separate caches for thumbnails and full images
   - Keys: Path for full images, path for thumbnails
   - Fastest access, cleared on memory pressure

2. **Metadata Cache (ThumbnailMetadataCache)**
   - Persistent JSON storage: `~/Library/Application Support/Photolala/thumbnail-metadata.json`
   - Maps file paths to MD5 hashes
   - Validates using file size and modification date
   - Prevents redundant MD5 computation
   - Auto-cleanup of entries older than 30 days

3. **Disk Cache**
   - Location: `~/Library/Caches/Photolala/thumbnails/`
   - Filename: `{md5}.thumbnail`
   - Persistent across app launches
   - Content-based deduplication via MD5

### Cache Flow
When loading a thumbnail:
1. Check memory cache by file path → Hit: Return immediately
2. Check metadata cache for MD5 → Hit: Skip to step 4
3. Compute MD5 from file data (cache miss only)
4. Check disk cache by MD5 → Hit: Load and return
5. Generate thumbnail (full miss only)

This optimization provides ~10x performance improvement when reopening directories.

## Display Settings Integration

### ThumbnailOption Enum
```swift
enum ThumbnailOption {
    case small    // 64px
    case medium   // 128px (default)
    case large    // 256px
}
```

### Layout Properties
Each option includes:
- `size`: Cell size in points
- `spacing`: Inter-item spacing
- `cornerRadius`: Cell corner radius
- `sectionInset`: Collection view insets

### Item Info Bar
- `showItemInfo`: Boolean to show/hide filename below thumbnails
- Adds 24px to cell height when enabled
- Displays truncated filename with secondary label color
- Toggleable via toolbar button

### Scale Mode Support (Added July 2, 2025)

Scale mode determines how thumbnails are displayed within their cells:

#### iOS/macOS Implementation
- Toggle in unified gear menu (iOS) or toolbar (macOS)
- Two modes: `scaleToFit` and `scaleToFill`
- Uses system icons: `aspectratio` (fit) and `aspectratio.fill` (fill)
- Applied via `contentMode` on iOS, `imageScaling` on macOS
- Settings persist in `ThumbnailDisplaySettings`

#### Android Implementation
- Radio button selection in grid options menu
- Uses Compose's `ContentScale.Fit` or `ContentScale.Crop`
- Persisted in `PreferencesManager`
- Follows Material Design patterns

#### User Experience
- **Scale to Fit**: Shows entire photo, may have letterboxing
- **Scale to Fill**: Crops to fill cell (default on both platforms)
- Instant visual feedback when toggling
- Works within 256px thumbnail generation constraints

### Android Info Bar (Added July 2, 2025)
Platform parity implementation for Android:
- Shows file size (formatted as B/KB/MB/GB)
- Tag flags display on left side
- Column layout with dynamic aspect ratio adjustment
- When hidden, flags overlay on image bottom-left
- 24dp height matching iOS/macOS 24pt

## Apple Photos Thumbnail Handling

Photolala uses a dual-path approach for Apple Photos thumbnails:

1. **Browsing Mode** (Fast Path)
   - Uses Photos framework's requestImage API
   - 512x512 thumbnails for responsive display
   - Cached by Apple Photo ID
   - No original data loading required

2. **Backup Mode** (Comprehensive Path)
   - Loads original photo data
   - Generates proper 256x256-512x512 thumbnails
   - Extracts full metadata simultaneously
   - Cached by MD5 hash for consistency

## Performance Optimizations

1. **Lazy Generation**: Thumbnails created on first request
2. **Async Loading**: Non-blocking thumbnail generation
3. **Priority Queue**: UI requests prioritized (QoS .userInitiated)
4. **Reuse**: Content-based keys prevent regeneration
5. **Dual-Path Caching**: Optimized paths for different use cases

## Usage in Collection Views

### Loading Pattern
```swift
Task { @MainActor in
    if let thumbnail = try await PhotoManager.shared.thumbnail(for: photo) {
        self.imageView?.image = thumbnail
    }
}
```

### Cell Lifecycle
1. Cell appears → Request thumbnail
2. Cache hit → Immediate display
3. Cache miss → Generate async
4. Cell reuse → Cancel pending requests

## Known Limitations

1. No disk cache size limit
2. No cache expiration
3. No progressive loading for very large images
4. iOS requires manual orientation handling

## Future Enhancements

1. Cache size management
2. LRU eviction policy
3. Progressive JPEG loading

## Recent Improvements (June 19, 2025)

### Placeholder Display
- Added separate placeholder image view (50% size of cell)
- Uses subtle tertiaryLabelColor for better visual hierarchy
- Placeholder properly hides when thumbnail loads
- Shows error icon for failed loads

### Concurrent Loading Fix
- Fixed issue where thumbnails wouldn't load on initial display
- Added proper Task tracking in PhotoFile.loadPhotoData()
- Concurrent requests now wait for existing loading operation
- Eliminates "No thumbnail available" messages on first view

### Implementation Details
```swift
// PhotoFile concurrent loading support
private var loadingTask: Task<Void, Error>?

func loadPhotoData() async throws {
    if let existingTask = loadingTask {
        try await existingTask.value
        return
    }
    // ... create and track new loading task
}
```

### Cell Updates
- UnifiedPhotoCell now has dedicated placeholderImageView
- Proper show/hide logic based on thumbnail availability
- Consistent behavior across macOS and iOS platforms