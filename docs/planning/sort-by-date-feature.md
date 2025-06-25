# Sort by Date Feature Design

Created: June 14, 2025

## Overview

Add the ability to sort photos by date taken (EXIF metadata) in addition to the current filename-based sorting. This feature will help users organize and browse their photo collections chronologically.

## Requirements

1. Extract date taken from photo EXIF metadata
2. Provide UI controls to switch between sort modes
3. Support ascending/descending order
4. Handle photos without date metadata gracefully
5. Maintain performance with large collections

## Key Benefits of PhotoManager-based Approach

1. **Single Load Operation**: When generating a thumbnail, we already have the full image data - extracting metadata at the same time is efficient
2. **Persistent Cache**: Metadata is stored alongside thumbnails, available even after app restart
3. **No Redundant Reads**: Once cached, metadata is available without reloading the full image
4. **Consistent Architecture**: Follows the same pattern as thumbnail management
5. **Future-Proof**: Easy to add more metadata fields without changing the API

## Technical Approach

### 1. Metadata Management Architecture

**Key Design Decision**: PhotoManager will handle all metadata extraction and caching, similar to thumbnail management. This provides:
- Single source of truth for photo data
- Efficient caching alongside thumbnails
- No need to reload full images for metadata
- Consistent async/await API

### 2. Cache Structure Update

Rename `~/Library/Caches/Photolala/thumbnails/` to `~/Library/Caches/Photolala/cache/`

```
cache/
├── md5#abc123.jpg          # Thumbnail image
├── md5#abc123.plist        # Metadata (EXIF, dimensions, etc.)
└── ...
```

**Migration Strategy**:
- On first run, check if `thumbnails/` exists and rename to `cache/`
- Existing `.jpg` files continue to work
- Missing `.plist` files are created on demand when metadata is requested
- No need to regenerate existing thumbnails

### 3. PhotoReference Model Enhancement

```swift
class PhotoReference {
    // Existing properties (unchanged)
    let directoryPath: NSString
    let filename: String
    @Published var thumbnail: XImage?
    @Published var isLoadingThumbnail: Bool = false
    
    // New properties
    @Published var metadata: PhotoMetadata?
    @Published var isLoadingMetadata: Bool = false
    
    // Methods delegate to PhotoManager
    func loadMetadata() async throws -> PhotoMetadata? {
        guard metadata == nil else { return metadata }
        isLoadingMetadata = true
        defer { isLoadingMetadata = false }
        
        metadata = try await PhotoManager.shared.metadata(for: self)
        return metadata
    }
}
```

### 4. PhotoMetadata Structure

```swift
class PhotoMetadata: NSObject, Codable {
    let dateTaken: Date?
    let fileModificationDate: Date
    let fileSize: Int64
    let pixelWidth: Int?
    let pixelHeight: Int?
    let cameraMake: String?
    let cameraModel: String?
    let orientation: Int?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
    
    // Computed properties
    var displayDate: Date {
        dateTaken ?? fileModificationDate
    }
    
    init(dateTaken: Date? = nil,
         fileModificationDate: Date,
         fileSize: Int64,
         pixelWidth: Int? = nil,
         pixelHeight: Int? = nil,
         cameraMake: String? = nil,
         cameraModel: String? = nil,
         orientation: Int? = nil,
         gpsLatitude: Double? = nil,
         gpsLongitude: Double? = nil) {
        self.dateTaken = dateTaken
        self.fileModificationDate = fileModificationDate
        self.fileSize = fileSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.orientation = orientation
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
        super.init()
    }
    
    // Codable requirements
    enum CodingKeys: String, CodingKey {
        case dateTaken, fileModificationDate, fileSize
        case pixelWidth, pixelHeight, cameraMake, cameraModel
        case orientation, gpsLatitude, gpsLongitude
    }
}
```

### 5. Sort Options

```swift
enum PhotoSortOption: String, CaseIterable {
    case filename = "Name"
    case dateTakenAscending = "Date (Oldest First)"
    case dateTakenDescending = "Date (Newest First)"
    
    var systemImage: String {
        switch self {
        case .filename: return "textformat"
        case .dateTakenAscending: return "calendar.badge.clock"
        case .dateTakenDescending: return "calendar.badge.clock"
        }
    }
}
```

### 6. UI Design

#### Toolbar Controls
- Add sort picker to PhotoBrowserView toolbar
- Position: After display options, before spacer
- macOS: Segmented control or dropdown
- iOS: Menu picker

#### Visual Design
```
[📁 Folder Name]  [Display: ▦] [Size: M] [Sort: Date ↓] ... [Select]
```

### 7. PhotoManager Enhancement

```swift
extension PhotoManager {
    // Add metadata cache
    private let metadataCache = NSCache<NSString, PhotoMetadata>()
    
    // Cache directory type enum
    enum CacheType {
        case thumbnail
        case metadata
        
        var fileExtension: String {
            switch self {
            case .thumbnail: return "jpg"
            case .metadata: return "plist"
            }
        }
    }
    
    // Helper to get cache URLs
    private func cacheURL(for identifier: Identifier, type: CacheType) -> URL {
        let fileName = identifier.string + "." + type.fileExtension
        return cacheDirectoryURL.appendingPathComponent(fileName)
    }
    
    // EXIF date parser
    private func parseEXIFDate(_ dateString: String) -> Date? {
        // EXIF date format: "yyyy:MM:dd HH:mm:ss"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.date(from: dateString)
    }
    
    // Enhanced thumbnail generation that also extracts metadata
    private func generateThumbnailAndMetadata(for photo: PhotoReference) async throws -> (XThumbnail, PhotoMetadata) {
        let imageData = try Data(contentsOf: photo.fileURL)
        let identifier = Identifier.md5(md5Digest(of: imageData))
        
        // Extract metadata while we have the image data
        let metadata = try extractMetadata(from: imageData, fileURL: photo.fileURL)
        
        // Save metadata to disk
        let metadataURL = cacheURL(for: identifier, type: .metadata)
        let encoder = PropertyListEncoder()
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL)
        
        // Generate thumbnail (existing code)
        let thumbnail = try generateThumbnail(from: imageData)
        
        // Save thumbnail to disk
        let thumbnailURL = cacheURL(for: identifier, type: .thumbnail)
        try thumbnail.jpegData(compressionQuality: 0.8)?.write(to: thumbnailURL)
        
        return (thumbnail, metadata)
    }
    
    private func extractMetadata(from imageData: Data, fileURL: URL) throws -> PhotoMetadata {
        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileModificationDate = attributes[.modificationDate] as? Date ?? Date()
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Extract EXIF using ImageIO
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            // Return basic metadata if image properties can't be read
            return PhotoMetadata(
                dateTaken: nil,
                fileModificationDate: fileModificationDate,
                fileSize: fileSize,
                pixelWidth: nil,
                pixelHeight: nil,
                cameraMake: nil,
                cameraModel: nil,
                orientation: nil,
                gpsLatitude: nil,
                gpsLongitude: nil
            )
        }
        
        // Extract various metadata
        var dateTaken: Date?
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            dateTaken = parseEXIFDate(dateString)
        }
        
        let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
        let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
        let orientation = properties[kCGImagePropertyOrientation as String] as? Int
        
        // Camera info
        var cameraMake: String?
        var cameraModel: String?
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            cameraMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
        }
        
        // GPS info
        var gpsLatitude: Double?
        var gpsLongitude: Double?
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            gpsLatitude = gps[kCGImagePropertyGPSLatitude as String] as? Double
            gpsLongitude = gps[kCGImagePropertyGPSLongitude as String] as? Double
        }
        
        return PhotoMetadata(
            dateTaken: dateTaken,
            fileModificationDate: fileModificationDate,
            fileSize: fileSize,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            cameraMake: cameraMake,
            cameraModel: cameraModel,
            orientation: orientation,
            gpsLatitude: gpsLatitude,
            gpsLongitude: gpsLongitude
        )
    }
    
    // Public API
    func metadata(for photo: PhotoReference) async throws -> PhotoMetadata? {
        // Check memory cache first
        if let cached = metadataCache.object(forKey: photo.filePath as NSString) {
            return cached
        }
        
        // Check disk cache
        // Note: This currently loads full image data for MD5, which is inefficient
        // TODO: Phase 2 optimization - use file attributes for cache key
        let imageData = try Data(contentsOf: photo.fileURL)
        let identifier = Identifier.md5(md5Digest(of: imageData))
        let metadataURL = cacheURL(for: identifier, type: .metadata)
        
        if FileManager.default.fileExists(atPath: metadataURL.path) {
            let data = try Data(contentsOf: metadataURL)
            let metadata = try PropertyListDecoder().decode(PhotoMetadata.self, from: data)
            metadataCache.setObject(metadata as NSObject, forKey: photo.filePath as NSString)
            return metadata
        }
        
        // Generate thumbnail and metadata together
        let (thumbnail, metadata) = try await generateThumbnailAndMetadata(for: photo)
        
        // Cache both
        thumbnailCache.setObject(thumbnail, forKey: identifier.string as NSString)
        metadataCache.setObject(metadata as NSObject, forKey: photo.filePath as NSString)
        
        return metadata
    }
}
```

## Implementation Plan

### Phase 1: PhotoManager & Metadata Infrastructure (1-2 days)
1. ✅ Create this design document
2. Update cache directory structure (thumbnails → cache)
   - Migration: Check for existing thumbnails directory and rename
   - Update thumbnailStoragePath to cacheDirectoryPath
3. Create PhotoMetadata class (NSObject for NSCache compatibility)
4. Update PhotoManager to extract metadata during thumbnail generation
   - Modify existing thumbnail generation to also extract metadata
   - Update existing thumbnail method to check for cached metadata
5. Add metadata caching (memory and disk)
6. Update PhotoReference with metadata property
7. Test metadata extraction with various photo formats

### Implementation Notes:
- **Backward Compatibility**: Existing thumbnails will still work, metadata will be generated on next access
- **GPS Coordinates**: Need to handle GPS ref (N/S, E/W) and convert to signed decimal
- **Date Parsing**: EXIF dates are in "yyyy:MM:dd HH:mm:ss" format, not ISO8601
- **Thread Safety**: PhotoManager already uses concurrent queue, maintain same pattern

### Phase 2: Sorting Implementation (1 day)
1. Add PhotoSortOption enum
2. Implement sorting logic in PhotoBrowserView
3. Add sort state to ThumbnailDisplaySettings
4. Handle photos without dates gracefully

### Phase 3: UI Integration (1 day)
1. Add sort picker to toolbar
2. Platform-specific UI (segmented control vs menu)
3. Visual indicators for current sort
4. Keyboard shortcuts (optional)

### Phase 4: Performance & Polish (1 day)
1. Optimize batch metadata loading
2. Progress indication for initial scan
3. Handle edge cases (corrupted EXIF, etc.)
4. Update cache statistics to include metadata

## User Experience

### Loading States
- Initial view shows photos sorted by name (instant)
- When switching to date sort:
  - Show loading indicator if needed
  - Extract dates progressively
  - Update view as dates become available

### Missing Dates
- Photos without EXIF date use file modification date
- Group or mark photos without dates
- Consider adding visual indicator

### Sort Persistence
- Remember sort preference per folder
- Store in UserDefaults or window state

## Testing Considerations

1. **Test Data Needed**:
   - Photos with EXIF dates
   - Photos without EXIF dates
   - RAW files with metadata
   - Screenshots without camera data
   - Very old photos with unusual date formats

2. **Performance Testing**:
   - Folders with 1000+ photos
   - Mixed file types
   - Network/external drives

3. **Edge Cases**:
   - Corrupted EXIF data
   - Future dates
   - Time zone handling

## Future Enhancements

1. **Additional Sort Options**:
   - File size
   - Image dimensions
   - Camera model
   - Location (if GPS data exists)

2. **Grouping**:
   - Group by date (day/month/year)
   - Group by event (smart clustering)

3. **Filter Integration**:
   - Combine sort with date range filters
   - Quick jump to specific dates

## Success Criteria

1. Photos can be sorted by date taken
2. Performance remains acceptable (<1s for 1000 photos)
3. UI clearly indicates current sort mode
4. Missing dates handled gracefully
5. Sort preference persists appropriately