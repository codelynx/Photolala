# Star Status Display Strategy

**Date**: 2025-06-21
**Status**: Planning
**Feature**: Consistent star display across Apple Photos Library and Directory browsers

## Problem Statement

The same photo can exist in multiple places:
1. **Apple Photos Library** - Original source
2. **Local Directory** - Downloaded/exported copy
3. **S3 Backup** - Backed up from either source

We need to show consistent star status regardless of where the photo is being viewed.

## Key Challenges

### 1. Photo Identification
- **Directory Photos**: Have MD5 hash computed during scan
- **Apple Photos**: No MD5 until manually computed (expensive operation)
- **Same Photo Different Sources**: Need to recognize duplicates

### 2. Performance Constraints
- Can't compute MD5 for every Apple Photo on display
- Need instant star status display
- Must handle large libraries (10,000+ photos)

## Proposed Solutions

### Solution 1: Dual Tracking System

Maintain two tracking mechanisms:

```swift
class BackupQueueManager {
    // Existing MD5-based tracking for directory photos
    var backupStatus: [String: BackupStatus] = [:]  // MD5 -> Status
    
    // New: Apple Photos tracking
    var applePhotoStatus: [String: BackupStatus] = [:]  // PHAsset.localIdentifier -> Status
    
    // New: Mapping between Apple Photos and MD5
    var applePhotoToMD5: [String: String] = [:]  // localIdentifier -> MD5
}
```

#### Implementation Flow:

1. **When Viewing Apple Photos**:
```swift
extension PhotoApple {
    var backupStatus: BackupStatus {
        // First check direct Apple Photo status
        if let status = BackupQueueManager.shared.applePhotoStatus[asset.localIdentifier] {
            return status
        }
        
        // Then check if we have MD5 mapping
        if let md5 = BackupQueueManager.shared.applePhotoToMD5[asset.localIdentifier],
           let status = BackupQueueManager.shared.backupStatus[md5] {
            return status
        }
        
        return .none
    }
}
```

2. **When Starring Apple Photo**:
```swift
func starApplePhoto(_ photo: PhotoApple) async {
    // Immediate UI feedback
    applePhotoStatus[photo.asset.localIdentifier] = .queued
    
    // Background processing
    let md5 = await computeMD5(for: photo)
    
    // Update mapping
    applePhotoToMD5[photo.asset.localIdentifier] = md5
    
    // Check if already backed up via different source
    if backupStatus[md5] == .uploaded {
        applePhotoStatus[photo.asset.localIdentifier] = .uploaded
        return
    }
    
    // Proceed with backup...
}
```

3. **When Viewing Directory Photos**:
```swift
extension PhotoFile {
    var backupStatus: BackupStatus {
        guard let md5 = self.md5Hash else { return .none }
        
        // Check standard MD5-based status
        return BackupQueueManager.shared.backupStatus[md5] ?? .none
    }
}
```

### Solution 2: Lazy MD5 Computation with Caching

Store computed MD5s persistently for Apple Photos:

```swift
class ApplePhotoMD5Cache {
    private let cacheURL: URL
    private var cache: [String: MD5Info] = [:]
    
    struct MD5Info: Codable {
        let md5: String
        let fileSize: Int64
        let modificationDate: Date
        
        // Validate cache entry is still valid
        func isValid(for asset: PHAsset) -> Bool {
            // Check if photo has been edited since cache
            return asset.modificationDate == nil || 
                   asset.modificationDate! <= modificationDate
        }
    }
    
    func getMD5(for asset: PHAsset) async -> String? {
        let identifier = asset.localIdentifier
        
        // Check cache
        if let cached = cache[identifier],
           cached.isValid(for: asset) {
            return cached.md5
        }
        
        // Compute and cache
        if let md5 = await computeMD5(for: asset) {
            cache[identifier] = MD5Info(
                md5: md5,
                fileSize: asset.fileSize ?? 0,
                modificationDate: Date()
            )
            await save()
            return md5
        }
        
        return nil
    }
}
```

### Solution 3: Hybrid Approach (Recommended)

Combine both solutions for optimal performance:

```swift
class UnifiedBackupTracker {
    // Fast lookup for Apple Photos
    private var applePhotoStatus: [String: BackupStatus] = [:]
    
    // MD5-based lookup for all photos
    private var md5Status: [String: BackupStatus] = [:]
    
    // Cached MD5s for Apple Photos
    private var applePhotoMD5Cache: ApplePhotoMD5Cache
    
    // Persistence
    private let statusFileURL: URL
    
    func getStatus(for photo: any PhotoItem) -> BackupStatus {
        switch photo {
        case let applePhoto as PhotoApple:
            return getApplePhotoStatus(applePhoto)
            
        case let filePhoto as PhotoFile:
            return getFilePhotoStatus(filePhoto)
            
        default:
            return .none
        }
    }
    
    private func getApplePhotoStatus(_ photo: PhotoApple) -> BackupStatus {
        let id = photo.asset.localIdentifier
        
        // 1. Check direct status (fastest)
        if let status = applePhotoStatus[id] {
            return status
        }
        
        // 2. Check cached MD5 (fast)
        if let md5 = applePhotoMD5Cache.getCachedMD5(for: photo.asset),
           let status = md5Status[md5] {
            // Update Apple Photo status for faster future lookups
            applePhotoStatus[id] = status
            return status
        }
        
        // 3. No status found
        return .none
    }
    
    private func getFilePhotoStatus(_ photo: PhotoFile) -> BackupStatus {
        guard let md5 = photo.md5Hash else { return .none }
        return md5Status[md5] ?? .none
    }
}
```

## UI Implementation

### 1. Star Display in Collection View

```swift
// In UnifiedPhotoCell
func configure(with photo: any PhotoItem, settings: ThumbnailDisplaySettings) {
    // Existing configuration...
    
    // Update star immediately with cached status
    updateStarStatus(for: photo)
    
    // Check for updated status in background
    Task {
        let status = await BackupQueueManager.shared.getStatus(for: photo)
        await MainActor.run {
            self.updateStarDisplay(status)
        }
    }
}

private func updateStarStatus(for photo: any PhotoItem) {
    // Quick synchronous check
    let status = BackupQueueManager.shared.getCachedStatus(for: photo)
    updateStarDisplay(status)
}
```

### 2. Handling Duplicates

When the same photo exists in both APL and directory:

```swift
class DuplicateResolver {
    func resolveStatus(applePhoto: PhotoApple?, filePhoto: PhotoFile?) -> BackupStatus {
        // Priority order:
        // 1. If either is uploaded -> uploaded
        // 2. If either is queued -> queued
        // 3. If either is failed -> failed
        // 4. Otherwise -> none
        
        let statuses = [
            applePhoto?.backupStatus,
            filePhoto?.backupStatus
        ].compactMap { $0 }
        
        if statuses.contains(.uploaded) { return .uploaded }
        if statuses.contains(.queued) { return .queued }
        if statuses.contains(.failed) { return .failed }
        return .none
    }
}
```

## Performance Optimizations

### 1. Batch Status Checking
```swift
extension BackupQueueManager {
    func preloadStatuses(for photos: [any PhotoItem]) async {
        // Group by type
        let applePhotos = photos.compactMap { $0 as? PhotoApple }
        let filePhotos = photos.compactMap { $0 as? PhotoFile }
        
        // Preload Apple Photo MD5s in parallel
        await withTaskGroup(of: Void.self) { group in
            for photo in applePhotos {
                group.addTask {
                    _ = await self.applePhotoMD5Cache.getMD5(for: photo.asset)
                }
            }
        }
        
        // File photos already have MD5s
        // Just ensure status is loaded from disk if needed
    }
}
```

### 2. View-Based Preloading
```swift
// In UnifiedPhotoCollectionViewController
func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // Get visible and near-visible items
    let extendedVisibleItems = getExtendedVisibleItems()
    
    // Preload statuses for upcoming items
    Task {
        await BackupQueueManager.shared.preloadStatuses(for: extendedVisibleItems)
    }
}
```

## Storage Schema

### Persistent Storage Structure
```
~/Library/Application Support/Photolala/
├── backup_status.json          # MD5 -> Status mapping
├── apple_photo_status.json     # LocalIdentifier -> Status mapping
├── apple_photo_md5_cache.json  # LocalIdentifier -> MD5 mapping
└── s3_catalog.json            # S3 inventory
```

### Example Data Structure
```json
// backup_status.json
{
  "a1b2c3d4e5": {
    "status": "uploaded",
    "timestamp": "2024-06-21T10:30:00Z",
    "s3Key": "photos/2024/06/a1b2c3d4e5.jpg"
  }
}

// apple_photo_status.json
{
  "4A6B69B9-3DC4-4D11-9B3A-0123456789AB/L0/001": {
    "status": "uploaded",
    "md5": "a1b2c3d4e5",
    "timestamp": "2024-06-21T10:30:00Z"
  }
}
```

## Migration Strategy

For existing users who might have:
1. Already backed up photos from directories
2. Same photos in Apple Photos Library

```swift
class BackupStatusMigrator {
    func migrateExistingBackups() async {
        // 1. Load existing MD5-based backups
        let existingBackups = loadExistingBackups()
        
        // 2. For each Apple Photo, check if MD5 exists
        for photo in applePhotos {
            if let md5 = await computeMD5(photo),
               existingBackups[md5] != nil {
                // Link Apple Photo to existing backup
                applePhotoStatus[photo.id] = .uploaded
                applePhotoToMD5[photo.id] = md5
            }
        }
    }
}
```

## Edge Cases

### 1. Edited Photos
- Apple Photos might have edited version
- Need to decide: backup original or edited?
- Solution: Always backup original, note if edited version exists

### 2. Live Photos
- Consist of HEIC + MOV files
- Need to track both components
- Solution: Treat as single unit with compound MD5

### 3. iCloud Shared Photos
- Might not have download permission
- Solution: Show special status, handle gracefully

### 4. Deleted from One Source
- Photo deleted from APL but exists in directory
- Solution: Maintain separate status, don't auto-remove

## Implementation Priority

1. **Phase 1: Basic Star Display**
   - Simple APL identifier-based tracking
   - No deduplication
   - Fast and reliable

2. **Phase 2: MD5 Caching**
   - Background MD5 computation
   - Cache persistence
   - Deduplication awareness

3. **Phase 3: Full Integration**
   - Complete duplicate detection
   - Migration tools
   - Performance optimization

## Conclusion

The recommended approach is the Hybrid Solution (Solution 3) which provides:
- Instant star display using cached statuses
- Gradual MD5 computation for deduplication
- Consistent experience across photo sources
- Scalable to large libraries

The key insight is to separate the UI feedback (instant) from the deduplication logic (background), providing the best user experience while maintaining data consistency.