# Thumbnail System

Last Updated: June 14, 2025

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
- **Cross-Platform**: Works on macOS, iOS, and tvOS

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

### Memory Cache (NSCache)
- Automatic memory pressure handling
- Separate caches for thumbnails and full images
- Keys: Path for full images, MD5 for thumbnails

### Disk Cache
- Location: `~/Library/Caches/Photolala/thumbnails/`
- Filename: `{md5}.thumbnail`
- Persistent across app launches
- No automatic cleanup (yet)

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

## Performance Optimizations

1. **Lazy Generation**: Thumbnails created on first request
2. **Async Loading**: Non-blocking thumbnail generation
3. **Priority Queue**: UI requests prioritized (QoS .userInitiated)
4. **Reuse**: Content-based keys prevent regeneration

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
4. Background pre-generation
5. Intelligent prefetching