# Metadata Backup System

## Overview

The metadata backup system automatically backs up photo metadata alongside photos in S3, enabling features like searching backed-up photos, preserving EXIF data, and displaying photo information without downloading the full image. Metadata is stored as binary plist files in S3 Standard storage class for quick access.

## Architecture

### Storage Structure

```
s3://photolala-backup/
├── users/
│   └── {userId}/
│       ├── photos/
│       │   └── {md5}.dat         # Photo data (Deep Archive)
│       ├── thumbs/
│       │   └── {md5}.dat         # Thumbnail (Standard)
│       └── metadata/
│           └── {md5}.plist       # Metadata (Standard)
```

### Metadata Model

The system uses the existing `PhotoMetadata` class which is `Codable`:

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
}
```

## Implementation

### Upload Flow

1. **Photo Upload**: When a photo is uploaded, its MD5 hash is calculated
2. **Thumbnail Generation**: A thumbnail is generated and uploaded
3. **Metadata Extraction**: PhotoManager extracts metadata from the photo
4. **Metadata Upload**: Metadata is serialized to plist and uploaded to S3

```swift
// In S3BackupManager.uploadPhoto()
let md5 = try await s3Service.uploadPhoto(data: data, userId: userId)

if let thumbnail = try? await PhotoManager.shared.thumbnail(for: photoRef) {
    if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
        try await s3Service.uploadThumbnail(data: thumbnailData, md5: md5, userId: userId)
    }
}

if let metadata = try? await PhotoManager.shared.metadata(for: photoRef) {
    try await s3Service.uploadMetadata(metadata, md5: md5, userId: userId)
}
```

### Metadata Storage

- **Format**: Property List (plist) with binary encoding
- **Storage Class**: S3 Standard (not archived)
- **Size**: Typically 200-400 bytes per photo
- **Cost**: Free bonus storage (doesn't count against quota)

### Retrieval

Two methods for retrieving metadata:

1. **Individual**: `downloadMetadata(md5:userId:)` - For single photo
2. **Bulk**: `listUserMetadata(userId:)` - For all photos
3. **Combined**: `listUserPhotosWithMetadata(userId:)` - Photos with metadata

The bulk method uses parallel downloads for efficiency:

```swift
await withTaskGroup(of: (String, PhotoMetadata?).self) { group in
    for object in response.contents ?? [] {
        group.addTask {
            let metadata = try? await self.downloadMetadata(md5: md5, userId: userId)
            return (md5, metadata)
        }
    }
}
```

## Benefits

1. **Search Capability**: Search backed-up photos by camera, date, location
2. **Preview Information**: Show photo details without downloading
3. **EXIF Preservation**: Preserve all metadata even if original is lost
4. **Performance**: Quick access to photo information
5. **Cost Efficient**: Metadata stays in Standard storage (minimal cost)
6. **Native Format**: Binary plist is native to Apple platforms, compact and fast

## Future Enhancements

1. **Search API**: Build search functionality for metadata
   - Search by date range
   - Search by camera model
   - Search by location

2. **Metadata Enrichment**: Add computed metadata
   - Face detection results
   - Object detection tags
   - Color analysis

3. **Batch Operations**: Optimize for large uploads
   - Queue metadata uploads
   - Retry failed uploads
   - Progress tracking

4. **Privacy Features**: 
   - Option to strip GPS data
   - Selective metadata backup
   - Encryption for sensitive data

## API Reference

### S3BackupService Methods

```swift
// Upload metadata for a photo
func uploadMetadata(_ metadata: PhotoMetadata, md5: String, userId: String) async throws

// Download metadata for a single photo
func downloadMetadata(md5: String, userId: String) async throws -> PhotoMetadata?

// List all metadata for a user
func listUserMetadata(userId: String) async throws -> [String: PhotoMetadata]

// List photos with their metadata
func listUserPhotosWithMetadata(userId: String) async throws -> [PhotoEntry]
```

### PhotoEntry Extension

```swift
struct PhotoEntry {
    let md5: String
    let size: Int64
    let lastModified: Date
    let storageClass: String
    var metadata: PhotoMetadata?  // Now includes metadata
}
```

## Testing

The S3BackupTestView has been updated to display metadata:
- Shows photo dimensions if available
- Shows camera information if available
- Uses blue color to distinguish metadata from file info

## Cost Analysis

- **Storage**: ~300 bytes average per photo (binary plist)
- **Price**: $0.023 per GB per month (Standard)
- **Example**: 10,000 photos = 3 MB = $0.00007/month
- **Conclusion**: Negligible cost for significant value

## Related Documentation

- [S3 Backup Service Design](../../services/s3-backup/design/s3-backup-service-design.md)
- [Archive Retrieval System](./archive-retrieval-system.md)
- [Photo Metadata Model](../history/implementation-notes/photo-grouping-phase1-implementation.md)