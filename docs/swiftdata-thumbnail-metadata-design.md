# SwiftData for Thumbnail Metadata Design

## Overview

While PhotoRepresentation remains a simple struct (no database), we'll use SwiftData to store thumbnail metadata for performance and rich querying capabilities.

## Architecture

```
PhotoRepresentation (Struct)          ThumbnailMetadata (@Model)
├── filePath                         ├── universalPhotoID (unique)
├── fileSize                         ├── fileSize
├── createdDate                      ├── imageWidth
├── modifiedDate                     ├── imageHeight
└── photoIdentifier?                 ├── originalCreatedDate
                                    ├── isFavorite
                                    ├── rating (1-5)
                                    └── tags: [String]
```

## ThumbnailMetadata Model

```swift
import SwiftData
import Foundation

@Model
final class ThumbnailMetadata {
    // Primary identification
    @Attribute(.unique) var universalPhotoID: UniversalPhotoIdentifier
    
    // File information
    var fileSize: Int64
    
    // Image metadata
    var imageWidth: Int
    var imageHeight: Int
    var originalCreatedDate: Date?
    
    // User metadata
    var isFavorite: Bool = false
    var rating: Int = 0  // 0-5 stars
    var tags: [String] = []
    
    // Thumbnail location (computed)
    var thumbnailPath: String {
        // ~/Library/Caches/Photolala/Thumbnails/md5/md5~{md5}~{size}.jpg
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let contentID = universalPhotoID.string
        let prefix = String(contentID.prefix(2))
        return cacheDir
            .appendingPathComponent("Photolala/Thumbnails/\(prefix)/\(contentID).jpg")
            .path
    }
    
    init(
        upi: UniversalPhotoIdentifier,
        fileSize: Int64,
        imageWidth: Int,
        imageHeight: Int,
        originalCreatedDate: Date? = nil
    ) {
        self.universalPhotoID = upi
        self.fileSize = fileSize
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.originalCreatedDate = originalCreatedDate
    }
}
```

## Integration with PhotoRepresentation

```swift
extension PhotoRepresentation {
    /// Get or create thumbnail metadata
    func thumbnailMetadata(in context: ModelContext) async -> ThumbnailMetadata? {
        guard let identifier = photoIdentifier else { return nil }
        
        let upi = UniversalPhotoIdentifier(
            contentHash: identifier.contentHash,
            fileSize: identifier.fileSize
        )
        
        // Try to fetch existing
        let descriptor = FetchDescriptor<ThumbnailMetadata>(
            predicate: #Predicate { $0.universalPhotoID == upi }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        // Create new if we have dimensions
        guard let width = imageWidth, let height = imageHeight else { return nil }
        
        let metadata = ThumbnailMetadata(
            upi: upi,
            fileSize: fileSize,
            imageWidth: width,
            imageHeight: height,
            originalCreatedDate: createdDate
        )
        
        context.insert(metadata)
        try? context.save()
        
        return metadata
    }
}
```

## ThumbnailService Integration

```swift
actor ThumbnailService {
    private let modelContainer: ModelContainer
    
    init() {
        let schema = Schema([ThumbnailMetadata.self])
        let config = ModelConfiguration(schema: schema)
        self.modelContainer = try! ModelContainer(for: schema, configurations: [config])
    }
    
    func thumbnail(for photo: PhotoRepresentation) async -> XImage? {
        // 1. Check if thumbnail exists on disk using contentID
        guard let identifier = photo.photoIdentifier else { return nil }
        
        let contentID = identifier.string
        let thumbnailURL = getThumbnailURL(for: contentID)
        if let cached = loadFromDisk(at: thumbnailURL) {
            // Update access stats in background
            Task {
                await updateAccessStats(for: identifier)
            }
            return cached
        }
        
        // 2. Generate thumbnail
        guard let thumbnail = try? await generateThumbnail(for: photo) else { return nil }
        
        // 3. Save to disk
        saveToDisk(thumbnail, at: thumbnailURL)
        
        // 4. Store metadata
        await storeMetadata(for: photo, thumbnail: thumbnail)
        
        return thumbnail
    }
    
    private func storeMetadata(for photo: PhotoRepresentation, thumbnail: XImage) async {
        let context = modelContainer.mainContext
        
        guard let identifier = photo.photoIdentifier else { return }
        
        let upi = UniversalPhotoIdentifier(
            contentHash: identifier.contentHash,
            fileSize: identifier.fileSize
        )
        
        let metadata = ThumbnailMetadata(
            upi: upi,
            fileSize: photo.fileSize,
            imageWidth: Int(thumbnail.size.width),
            imageHeight: Int(thumbnail.size.height),
            originalCreatedDate: photo.createdDate
        )
        
        context.insert(metadata)
        try? context.save()
    }
}
```

## Query Examples

```swift
// Find all favorited photos
let favorites = try context.fetch(
    FetchDescriptor<ThumbnailMetadata>(
        predicate: #Predicate { $0.isFavorite == true },
        sortBy: [SortDescriptor(\.originalCreatedDate, order: .reverse)]
    )
)

// Find highly rated photos
let highRated = try context.fetch(
    FetchDescriptor<ThumbnailMetadata>(
        predicate: #Predicate { $0.rating >= 4 }
    )
)

// Search by tags
let tagged = try context.fetch(
    FetchDescriptor<ThumbnailMetadata>(
        predicate: #Predicate { metadata in
            metadata.tags.contains("vacation")
        }
    )
)

// Find photos by size range
let largePhotos = try context.fetch(
    FetchDescriptor<ThumbnailMetadata>(
        predicate: #Predicate { metadata in
            metadata.fileSize > 10_000_000 // > 10MB
        }
    )
)
```

## Benefits of This Hybrid Approach

1. **PhotoRepresentation stays simple** - Just a struct for current files
2. **Rich metadata for thumbnails** - Tags, ratings, favorites
3. **Fast queries** - Find photos by metadata without scanning
4. **Persistent user data** - Ratings/tags survive file moves
5. **Performance** - Quick lookup by content ID
6. **Migration-friendly** - Can add fields to ThumbnailMetadata easily

## Implementation Plan

### Phase 1: Basic Integration
1. Add ThumbnailMetadata model
2. Update ThumbnailService to store metadata
3. Add ModelContainer to app (just for thumbnails)

### Phase 2: User Features
1. Add favorite toggle UI
2. Add rating UI (1-5 stars)
3. Add tag management

### Phase 3: Search & Filter
1. Query by favorites
2. Filter by rating
3. Search by tags
4. Sort options

## Key Points

- **SwiftData only for app data**, not file representation
- **UniversalPhotoIdentifier as primary key** - Content-based, survives file moves
- **No file paths stored** - Clean separation of concerns
- **Computed thumbnail path** - Based on content ID from UniversalPhotoIdentifier
- **Background metadata updates** - Don't block UI
- **Minimal stored data** - Only what's needed for rich queries

This gives us the best of both worlds: simple file browsing with rich metadata capabilities!