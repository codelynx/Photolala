# Metadata System

**Last Updated**: June 23, 2025
**Status**: Implemented

## Overview

Photolala's metadata system provides comprehensive photo metadata extraction, caching, and display across all photo sources (local files, Apple Photos Library, and S3 cloud storage). The system uses a two-path approach for optimal performance and data consistency.

## Architecture

### Two-Path Metadata Storage

1. **Primary Path: SwiftData Catalog**
   - Used for starred/cataloged photos
   - Stored in `CatalogPhotoEntry` with extended EXIF fields
   - Provides fast access for frequently accessed photos
   - Includes backup status and extended metadata

2. **Fallback Path: Cache Directory**
   - Plist files stored in `~/Library/Caches/Photolala/cache/`
   - Named using MD5 hash: `{md5}.plist`
   - Binary property list format for efficiency
   - Used for non-cataloged photos

### Apple Photos Dual-Path System

Apple Photos Library uses a special dual-path caching approach to balance responsive browsing with consistent backup handling:

1. **Browsing Path (Fast)**
   - Uses Apple Photo ID as cache key
   - No original data loading required
   - Basic metadata from PHAsset properties
   - 512x512 thumbnails from Photos framework
   - Instant display for responsive UX

2. **Backup Path (Comprehensive)**
   - Uses MD5 hash as cache key
   - Loads original photo data once
   - Extracts full EXIF metadata
   - Generates proper thumbnails (256x256-512x512)
   - Consistent with local file handling

The system maintains a persistent photo ID → MD5 mapping to avoid recomputing hashes.

### Metadata Extraction

Metadata is extracted during thumbnail generation for efficiency:

```swift
// PhotoProcessor reads file once for all operations
let processedData = try await PhotoProcessor.processPhoto(photo)
// Returns: thumbnail, MD5 hash, and metadata
```

### Extracted Fields

#### Basic Metadata (PhotoMetadata)
- `dateTaken` - EXIF DateTimeOriginal
- `fileModificationDate` - File system date
- `fileSize` - Size in bytes
- `pixelWidth/pixelHeight` - Image dimensions
- `cameraMake/cameraModel` - Camera information
- `orientation` - EXIF orientation flag
- `gpsLatitude/gpsLongitude` - GPS coordinates
- `applePhotoID` - Apple Photos Library identifier

#### Extended Metadata (CatalogPhotoEntry only)
- `aperture` - f-stop value
- `shutterSpeed` - Exposure time
- `iso` - ISO speed rating
- `focalLength` - Lens focal length

## Implementation Details

### UnifiedMetadataLoader

Central service for metadata retrieval:

```swift
@MainActor
class UnifiedMetadataLoader {
    // Check SwiftData first, then cache
    func loadMetadata(for photo: any PhotoItem) async -> PhotoMetadata?
    
    // Load extended EXIF data
    func loadExtendedMetadata(for photo: any PhotoItem, baseMetadata: PhotoMetadata) async -> ExtendedPhotoMetadata
}
```

### ApplePhotosMetadataCache

Manages the dual-path caching for Apple Photos:

```swift
@MainActor
class ApplePhotosMetadataCache {
    // Fast path for browsing
    func getMetadataForBrowsing(_ photo: PhotoApple) async -> PhotoMetadata
    
    // Comprehensive path for backup
    func getMetadataForBackup(_ photo: PhotoApple) async throws -> (md5: String, metadata: PhotoMetadata)
    
    // Check if photo has been processed
    func isProcessed(_ photoID: String) -> Bool
}
```

### Caching Strategy

1. **Memory Cache**: NSCache with file path as key
2. **Disk Cache**: Plist files with MD5 hash as filename
3. **SwiftData**: Persistent storage for cataloged photos

### Photo Type Support

#### PhotoFile (Local Files)
- Full metadata extraction from image files
- Cached in both memory and disk
- MD5 hash computed for deduplication

#### PhotoApple (Apple Photos)
- **Browsing Mode**: Basic metadata from PHAsset properties
- **Backup Mode**: Full EXIF extraction from original data
- File size loaded asynchronously on demand
- Dual-path caching with ApplePhotosMetadataCache
- Persistent photo ID → MD5 mapping

#### PhotoS3 (Cloud Storage)
- Metadata from catalog entries
- No additional extraction needed
- Already stored in cloud catalog

## Inspector Integration

The metadata is displayed in the InspectorView's MetadataSection:

```swift
struct MetadataSection: View {
    // Displays:
    // - Camera make/model
    // - Date taken
    // - GPS coordinates
    // - EXIF settings (aperture, shutter speed, ISO, focal length)
    // - Orientation info
}
```

## Performance Considerations

1. **Unified Processing**: Single file read for thumbnail + metadata + MD5
2. **Lazy Loading**: Metadata loaded on demand
3. **Efficient Caching**: Two-tier caching reduces repeated extractions
4. **Background Processing**: Catalog generation happens in background

## Future Enhancements

1. **Additional Fields**: White balance, flash info, copyright
2. **Metadata Editing**: Allow users to modify certain fields
3. **Export Options**: Include metadata in exported photos
4. **Background Processing**: Pre-process frequently accessed Apple Photos
5. **Conflict Resolution**: Handle metadata conflicts between sources

## Related Documentation

- [Thumbnail System](thumbnail-system.md) - Thumbnail generation and caching
- [Architecture](architecture.md) - Overall system architecture
- [Apple Photos Metadata Extraction](../planning/apple-photos-metadata-extraction.md) - Future plans