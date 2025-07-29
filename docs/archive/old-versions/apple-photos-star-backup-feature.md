# Apple Photos Library Star & Backup Feature

**Date**: 2025-06-21
**Status**: Planning
**Feature**: Star and backup Apple Photos to S3 with full metadata preservation

## Overview

Enable users to star photos from Apple Photos Library, which triggers:
1. Extract original photo data from Photos Library
2. Extract and preserve EXIF metadata
3. Compute MD5 hash for deduplication
4. Generate standardized thumbnail (optional)
5. Upload to S3 with metadata preservation

This creates a backup of Apple Photos in S3 that matches the format and structure of directory-based photo backups.

## Architecture Design

### Data Flow

```
User Stars Photo in APL
    ↓
PhotoApple.star()
    ↓
Extract Original Data ← PHImageManager.requestImageData
    ↓
Process Photo Data
    ├── Extract EXIF Metadata
    ├── Compute MD5 Hash
    └── Generate Thumbnail (optional)
    ↓
Create Temporary PhotoFile
    ↓
BackupQueueManager.addToQueue()
    ↓
S3BackupService.uploadPhoto()
    ↓
Update UI State
```

## Detailed Implementation Plan

### Phase 1: Extract Original Photo Data

```swift
extension PhotoApple {
    func extractOriginalData() async throws -> (data: Data, metadata: PhotoMetadata) {
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .original  // Important: Get original, not edited
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true // Allow iCloud download
            options.progressHandler = { progress, _, _, _ in
                // Update UI with download progress
                Task { @MainActor in
                    self.downloadProgress = progress
                }
            }
            
            imageManager.requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, dataUTI, orientation, info in
                guard let data = data else {
                    continuation.resume(throwing: ApplePhotosError.dataExtractionFailed)
                    return
                }
                
                // Extract metadata from image data
                let metadata = self.extractMetadata(from: data)
                continuation.resume(returning: (data, metadata))
            }
        }
    }
    
    private func extractMetadata(from data: Data) -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return PhotoMetadata()
        }
        
        // Extract comprehensive metadata
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        
        return PhotoMetadata(
            dateTaken: asset.creationDate,
            fileModificationDate: asset.modificationDate ?? Date(),
            fileSize: Int64(data.count),
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            cameraMake: tiff?[kCGImagePropertyTIFFMake as String] as? String,
            cameraModel: tiff?[kCGImagePropertyTIFFModel as String] as? String,
            gpsLatitude: gps?[kCGImagePropertyGPSLatitude as String] as? Double,
            gpsLongitude: gps?[kCGImagePropertyGPSLongitude as String] as? Double
            // ... other EXIF fields
        )
    }
}
```

### Phase 2: Process and Prepare for S3

```swift
extension PhotoApple {
    func prepareForBackup() async throws -> BackupPackage {
        // Step 1: Get original data and metadata
        let (data, metadata) = try await extractOriginalData()
        
        // Step 2: Compute MD5 (critical for deduplication)
        let md5 = Insecure.MD5.hash(data: data)
        let md5String = md5.map { String(format: "%02x", $0) }.joined()
        
        // Step 3: Determine file extension from UTI
        let fileExtension = determineFileExtension() ?? "jpg"
        
        // Step 4: Generate S3 key
        // Format: photos/2024/06/md5hash.jpg
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM"
        let datePath = dateFormatter.string(from: metadata.dateTaken ?? Date())
        let s3Key = "photos/\(datePath)/\(md5String).\(fileExtension)"
        
        // Step 5: Generate thumbnail (using existing PhotoProcessor logic)
        let thumbnail = try await generateStandardThumbnail(from: data)
        
        return BackupPackage(
            originalData: data,
            thumbnailData: thumbnail.jpegData,
            metadata: metadata,
            md5: md5String,
            s3Key: s3Key,
            originalFilename: self.filename
        )
    }
    
    private func determineFileExtension() -> String? {
        // Get from PHAssetResource
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first(where: { $0.type == .photo }) {
            let filename = resource.originalFilename
            return (filename as NSString).pathExtension.lowercased()
        }
        
        // Fallback based on asset media subtype
        if asset.mediaSubtypes.contains(.photoLive) {
            return "heic"
        }
        
        return nil
    }
}
```

### Phase 3: Integration with BackupQueueManager

```swift
extension BackupQueueManager {
    func addApplePhoto(_ photo: PhotoApple) async throws {
        // Show progress UI
        await MainActor.run {
            self.showBackupProgress(for: photo)
        }
        
        do {
            // Extract and process photo
            let package = try await photo.prepareForBackup()
            
            // Check if already exists in S3
            if await s3Service.objectExists(key: package.s3Key) {
                // Photo already backed up (same MD5)
                await MainActor.run {
                    self.backupStatus[package.md5] = .uploaded
                    self.hideBackupProgress(for: photo)
                }
                return
            }
            
            // Create backup entry
            let backupItem = PhotoBackupItem(
                id: photo.id,
                md5: package.md5,
                s3Key: package.s3Key,
                originalData: package.originalData,
                thumbnailData: package.thumbnailData,
                metadata: package.metadata,
                source: .applePhotos(assetId: photo.asset.localIdentifier)
            )
            
            // Add to queue
            self.addToQueue(backupItem)
            
            // Start upload if not already running
            self.processQueue()
            
        } catch {
            await MainActor.run {
                self.backupStatus[photo.id] = .failed(error)
                self.hideBackupProgress(for: photo)
            }
            throw error
        }
    }
}
```

### Phase 4: S3 Upload with Metadata

```swift
extension S3BackupService {
    func uploadApplePhoto(_ package: BackupPackage) async throws {
        // Upload original photo
        try await uploadData(
            package.originalData,
            to: package.s3Key,
            metadata: [
                "original-filename": package.originalFilename,
                "source": "apple-photos",
                "md5": package.md5,
                "date-taken": ISO8601DateFormatter().string(from: package.metadata.dateTaken ?? Date()),
                "camera-make": package.metadata.cameraMake ?? "",
                "camera-model": package.metadata.cameraModel ?? ""
            ]
        )
        
        // Upload thumbnail
        let thumbnailKey = package.s3Key.replacingOccurrences(of: "/photos/", with: "/thumbnails/")
            .replacingOccurrences(of: ".\(package.s3Key.pathExtension)", with: ".jpg")
        
        try await uploadData(
            package.thumbnailData,
            to: thumbnailKey,
            metadata: ["source": "apple-photos-thumbnail"]
        )
        
        // Update catalog
        await updateCatalog(with: package)
    }
}
```

### Phase 5: UI Integration

```swift
// In PhotoContextMenuItem for Apple Photos
extension PhotoApple {
    func contextMenuItems() -> [PhotoContextMenuItem] {
        var items = super.contextMenuItems()
        
        // Add star option
        let backupStatus = BackupQueueManager.shared.backupStatus[self.id]
        let isStarred = backupStatus == .queued || backupStatus == .uploaded
        
        items.append(PhotoContextMenuItem(
            title: isStarred ? "Unstar" : "Star for Backup",
            systemImage: isStarred ? "star.fill" : "star",
            action: { [weak self] in
                guard let self = self else { return }
                Task {
                    if isStarred {
                        BackupQueueManager.shared.removeFromQueue(self)
                    } else {
                        try await BackupQueueManager.shared.addApplePhoto(self)
                    }
                }
            }
        ))
        
        return items
    }
}
```

## Data Structures

### BackupPackage
```swift
struct BackupPackage {
    let originalData: Data
    let thumbnailData: Data
    let metadata: PhotoMetadata
    let md5: String
    let s3Key: String
    let originalFilename: String
}
```

### PhotoBackupItem
```swift
struct PhotoBackupItem {
    let id: String
    let md5: String
    let s3Key: String
    let originalData: Data
    let thumbnailData: Data
    let metadata: PhotoMetadata
    let source: PhotoSource
    
    enum PhotoSource {
        case directory(path: String)
        case applePhotos(assetId: String)
    }
}
```

## Key Considerations

### 1. iCloud Photo Library
- Photos might be optimized (not stored locally)
- Need to handle download progress
- Consider network usage and costs
- Implement proper timeout handling

### 2. Deduplication
- MD5 hash ensures no duplicate uploads
- Same photo from different sources shares same S3 object
- Important for storage efficiency

### 3. Metadata Preservation
- Store all EXIF data in S3 object metadata
- Preserve original filename
- Track source (Apple Photos vs Directory)
- Enable future restoration

### 4. Error Handling
```swift
enum ApplePhotosBackupError: Error {
    case photoNotFound
    case iCloudDownloadFailed
    case metadataExtractionFailed
    case insufficientStorage
    case networkError
    case s3UploadFailed
}
```

### 5. Progress Reporting
- Show download progress for iCloud photos
- Show processing status
- Show upload progress
- Handle cancellation

## Performance Optimizations

### 1. Concurrent Processing
- Process multiple photos in parallel
- Limit concurrent operations (e.g., 3 at a time)
- Queue management for optimal throughput

### 2. Memory Management
- Stream large files instead of loading into memory
- Clean up temporary data after upload
- Monitor memory pressure

### 3. Caching
- Cache MD5 hashes to avoid recomputation
- Cache extraction results for same asset
- Persist backup status across sessions

## Testing Scenarios

1. **Local Photos**
   - Photos fully downloaded on device
   - Should be fast and reliable

2. **iCloud Optimized Photos**
   - Require download
   - Test progress reporting
   - Test cancellation
   - Test network failure recovery

3. **Large Photos**
   - RAW files (30-50MB)
   - 4K videos
   - Memory pressure handling

4. **Edge Cases**
   - Live Photos (HEIC + MOV)
   - Edited photos (multiple versions)
   - Photos without EXIF data
   - Corrupted photos

## Future Enhancements

1. **Batch Operations**
   - Star multiple photos at once
   - Bulk backup operations
   - Progress for batch

2. **Smart Backup**
   - Auto-backup based on criteria
   - Face recognition integration
   - Album-based backup

3. **Restore Capability**
   - Restore from S3 to Photos Library
   - Metadata preservation
   - Version management

4. **Optimization**
   - Delta sync for edited photos
   - Compression options
   - Bandwidth throttling

## Implementation Priority

1. **MVP (Phase 1)**
   - Basic star functionality
   - Original photo extraction
   - MD5 computation
   - S3 upload

2. **Enhanced (Phase 2)**
   - Full metadata extraction
   - Progress reporting
   - Error recovery
   - Deduplication

3. **Advanced (Phase 3)**
   - Batch operations
   - Smart backup rules
   - Restore functionality

## Conclusion

This feature would provide seamless backup of Apple Photos Library to S3, maintaining the same structure and metadata as directory-based photos. The key challenges are handling iCloud photos and maintaining performance with large libraries. The implementation should focus on reliability, progress feedback, and proper error handling to ensure a smooth user experience.