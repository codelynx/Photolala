# PhotoManager and Thumbnail System Design

## Overview

The PhotoManager is responsible for generating, caching, and serving thumbnails for photos. It provides a simple API for thumbnail generation and retrieval with disk caching, ensuring efficient photo browsing across large collections.

## Goals

1. **Simplicity**: Easy-to-use API with minimal complexity
2. **Performance**: Fast thumbnail loading with multi-level caching
3. **Cross-Platform**: Works seamlessly on macOS and iOS
4. **Memory Efficiency**: Uses NSCache for automatic memory management
5. **Disk Persistence**: Caches thumbnails to disk for quick subsequent loads

## Architecture

### Core Components

```swift
// Main photo manager
class PhotoManager {
    static let shared = PhotoManager()
    
    // Storage paths
    private let photolalaStoragePath: NSString
    private let thumbnailStoragePath: NSString
    
    // Caching
    private let imageCache = NSCache<NSString, XImage>()
    private let thumbnailCache = NSCache<NSString, XThumbnail>()
    private let queue = DispatchQueue(label: "com.photolala.PhotoManager", attributes: .concurrent)
}
```

### Key Types

```swift
// Photo identifier types
enum Identifier {
    case md5(Insecure.MD5Digest) // universal photo identifier (size removed)
    case applePhotoLibrary(String) // unique device wide
    
    var string: String { /* implementation */ }
    init?(string: String) { /* implementation */ }
}

// Platform-agnostic image type (defined in XPlatform)
#if os(macOS)
typealias XImage = NSImage
#else
typealias XImage = UIImage
#endif
```

## Thumbnail Size Strategy

- Shorter side (width or height) is set to 256 pixels
- Aspect ratio is preserved with a maximum of 512 pixels for the longer side
- If the longer side exceeds 512 pixels after scaling, it's cropped to fit


## API Design

### Primary Interface

```swift
extension PhotoManager {
    /// Load thumbnail for a photo representation (async)
    /// - Parameter photoRep: The photo representation
    /// - Returns: The thumbnail image
    /// - Throws: Error if thumbnail loading fails
    func thumbnail(for photoRep: PhotoRepresentation) async throws -> XThumbnail?
    
    /// Load full image for a photo representation (async)
    /// - Parameter photo: The photo representation
    /// - Returns: The full image
    /// - Throws: Error if image loading fails
    func loadImage(for photo: PhotoRepresentation) async throws -> XImage?
    
    /// Generate a thumbnail from raw image data
    /// - Parameter data: The raw image data
    /// - Returns: The generated thumbnail image
    /// - Throws: Error if thumbnail generation fails
    func prepareThumbnail(from data: Data) throws -> XThumbnail?
    
    /// Check if thumbnail exists on disk
    /// - Parameter identifier: The photo identifier
    /// - Returns: true if thumbnail exists
    func hasThumbnail(for identifier: Identifier) -> Bool
}
```

## Implementation Strategy

### 1. Cache Key Generation

```swift
// Photo identifier is globally unique (MD5-based or Apple Photo Library ID)
let cacheKey = identifier.string + ".jpg"
```

### 2. Memory Cache

✅ **Implemented with dual cache system:**
- `imageCache`: Caches full images by file path
- `thumbnailCache`: Caches thumbnails by content identifier
- Uses `NSCache` for automatic memory management
- Thread-safe with concurrent dispatch queue

### 3. Disk Cache

Thumbnails are persisted to disk for fast subsequent loads.

**Location**: `~/Library/Caches/Photolala/thumbnails/`

The cache directory structure is created automatically on first use.

### 4. Thumbnail Generation

Implemented platform-specific thumbnail generation:
- **macOS**: Uses NSImage resizing with lockFocus/unlockFocus
- **iOS**: Uses UIGraphicsBeginImageContext for resizing

The process:
1. Load the image from raw data
2. Calculate MD5 hash for unique identification
3. Scale so the shorter side becomes 256 pixels
4. Crop the longer side to maximum 512 pixels
5. Save as JPEG to disk cache

### 5. Request Coalescing

*Note: Deferred for initial implementation to maintain simplicity*

Future enhancement to prevent duplicate work:
- Coalesce multiple requests for the same thumbnail
- Generate once, notify all requesters
- Reduce redundant processing

### 6. Priority Queue Management

*Note: Deferred for initial implementation*

Future enhancement for better responsiveness during scrolling and user interaction.

## Current Implementation Status

### What's Implemented

1. **PhotoManager Class**: Singleton for managing photo operations
2. **Thumbnail Generation**: Synchronous thumbnail creation from raw data
3. **Disk Caching**: Automatic saving to ~/Library/Caches/Photolala/thumbnails/
4. **MD5-based Identification**: Universal photo identification using content hash
5. **Platform-specific Resizing**: Native image APIs for each platform

### What's Not Yet Implemented

1. ~~**Memory Cache**: No in-memory caching with NSCache~~ ✅ Implemented
2. ~~**Async API**: Currently only synchronous operations~~ ✅ Implemented
3. **Request Coalescing**: No prevention of duplicate work
4. ~~**Collection View Integration**: Views currently load full images~~ ✅ Implemented

## Usage Examples

### Current Usage Pattern

```swift
// Generate thumbnail from raw data
if let data = try? Data(contentsOf: photoURL),
   let thumbnail = try? PhotoManager.shared.thumbnail(rawData: data) {
    // Use thumbnail
    imageView.image = thumbnail
}

// Check for cached thumbnail
let identifier = PhotoManager.Identifier.md5(md5Hash, fileSize)
if let cachedThumbnail = PhotoManager.shared.thumbnail(for: identifier) {
    imageView.image = cachedThumbnail
}
```

### Current Collection View Implementation

```swift
// PhotoCollectionViewItem (macOS) / PhotoCollectionViewCell (iOS)
private func loadThumbnail() {
    guard let photoRep = photoRepresentation else { return }
    let url = photoRep.fileURL
    
    // Currently loading full images - needs update to use PhotoManager
    DispatchQueue.global(qos: .userInitiated).async {
        if let image = XImage(contentsOf: url) {
            DispatchQueue.main.async {
                self.imageView?.image = image
            }
        }
    }
}
```

### Next Steps for Integration

1. **Update Collection View Items** to use PhotoManager:
```swift
private func loadThumbnail() {
    guard let photoRep = photoRepresentation else { return }
    
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            let data = try Data(contentsOf: photoRep.fileURL)
            if let thumbnail = try PhotoManager.shared.thumbnail(rawData: data) {
                DispatchQueue.main.async {
                    self.imageView?.image = thumbnail
                }
            }
        } catch {
            // Handle error
        }
    }
}
```

2. **Add Memory Cache** to PhotoManager
3. **Implement Async/Await API** for better integration

## Performance Considerations

*Note: These optimizations will be implemented in later phases*

1. **Image Loading**: Use `CGImageSource` for efficient thumbnail generation without loading full image
2. **Threading**: All disk I/O on background queue, UI updates on main queue
3. **Memory Limits**: Configure based on device (e.g., 50MB on iPhone, 200MB on Mac)
4. **Disk Limits**: Implement LRU eviction when cache exceeds size limit
5. **Format**: Save thumbnails as JPEG with 0.8 quality for size/quality balance

## Testing Strategy

1. **Unit Tests**:
   - Cache key generation
   - Memory cache behavior
   - Disk cache operations
   - Request coalescing

2. **Integration Tests**:
   - Collection view scrolling performance
   - Memory pressure handling
   - Large directory handling (1000+ images)

3. **Performance Tests**:
   - Thumbnail generation speed
   - Cache hit rates
   - Memory usage under load

## Future Enhancements

1. **Smart Preloading**: Predict scroll direction and preload accordingly
2. **Quality Levels**: Multiple quality levels with progressive loading
3. **Format Support**: HEIC thumbnail generation optimization
4. **iCloud Photos**: Special handling for cloud-based photos
5. **Batch Operations**: Optimize for bulk thumbnail generation
6. **Export API**: Allow apps to export generated thumbnails

## Implementation Phases

### Phase 1: Core Implementation ✅
- Basic PhotoManager singleton class ✅
- Synchronous thumbnail generation ✅
- Disk caching implementation ✅
- MD5-based identification ✅
- Platform-specific image resizing ✅

### Phase 2: Collection View Integration ✅
- Update collection views to use PhotoManager ✅
- Add memory caching with NSCache ✅
- Implement proper error handling ✅
- Add loading placeholders (partial - uses PhotoRepresentation.thumbnail)

### Phase 3: Advanced Features
- Async/await API for better performance
- Request coalescing to prevent duplicate work
- Priority queue management for better UX
- Preloading system for smooth scrolling

### Phase 4: Optimization
- Use CGImageSource for efficient loading
- Memory pressure handling
- Smart eviction policies (LRU)
- HEIC optimization
- Progressive loading
