# Apple Photos Backup Implementation

## Overview

This document describes the implementation of Apple Photos backup functionality in Photolala, enabling users to backup photos from their Apple Photos Library to S3 storage. The system uses a dual-path caching approach to balance responsive browsing with comprehensive backup handling.

## Problem Statement

The original `BackupQueueManager` was designed exclusively for `PhotoFile` objects from local directories. Apple Photos (`PhotoApple` objects) couldn't be backed up because:

1. The queue only accepted `PhotoFile` objects
2. Apple Photos require on-demand fetching from the Photos Library
3. The backup timer logic didn't recognize Apple Photos in the queue

## Solution Architecture

### Dual Queue System

We implemented a dual queue system within `BackupQueueManager`:

```swift
@Published var queuedPhotos: Set<PhotoFile> = []      // Local directory photos
private var queuedApplePhotos: Set<String> = []       // Apple Photo IDs
@Published var backupStatus: [String: BackupState] = [:] // Unified status by MD5
```

This separation makes sense because:
- `PhotoFile` and `PhotoApple` are different types with different lifecycles
- Apple Photos are identified by their unique ID until upload time
- MD5 hashes are computed on-demand during the backup process

### Key Changes

#### 1. BackupQueueManager Enhancements

**New Properties:**
- `queuedApplePhotos: Set<String>` - Stores Apple Photo IDs pending backup

**New Methods:**
- `addApplePhotoToQueue(_ photoID: String, md5: String)` - Queues an Apple Photo by ID
- `createPhotoApple(from photoID: String) -> PhotoApple?` - Fetches PHAsset by ID
- `computeApplePhotoMD5(_ photo: PhotoApple) -> String?` - Computes MD5 hash
- `uploadApplePhoto(_ photo: PhotoApple)` - Handles Apple Photo upload

**Modified Methods:**
- `resetInactivityTimer()` - Now checks `queuedApplePhotos` to start timer
- `performBackup()` - Processes both regular photos and Apple Photos
- `saveQueueState()` - Persists Apple Photo queue
- `restoreQueueState()` - Restores Apple Photo queue on app launch

#### 2. Upload Process

The upload process for Apple Photos follows this flow:

1. User stars an Apple Photo in the inspector
2. Photo ID is added to `queuedApplePhotos` 
3. MD5 hash is stored in `backupStatus` as `.queued`
4. Timer starts (30 seconds in DEBUG mode)
5. When timer fires:
   - Fetch PHAsset using the stored ID
   - Process photo comprehensively via `PhotoManager.processApplePhoto()`:
     - Load original image data once
     - Compute MD5 hash
     - Generate proper thumbnail (256x256-512x512)
     - Extract full EXIF metadata
     - Cache everything locally with MD5 key
   - Upload photo, thumbnail, and metadata to S3
   - Update status to `.uploaded`
   - Remove from queue

#### 3. Persistence

The `QueueState` structure was extended to persist Apple Photos:

```swift
private struct QueueState: Codable {
    let queuedPhotos: [String]          // MD5 hashes
    let backupStatus: [String: BackupState]
    let lastActivityTime: Date
    let pathToMD5: [String: String]?
    let photosToDelete: [String]?
    let queuedApplePhotos: [String]?    // Apple Photo IDs (new)
}
```

## Implementation Details

### InspectorView Changes

The `InspectorView` was updated to use the new queue method:

```swift
// Old: BackupQueueManager.shared.addToQueueByHash(md5)
// New:
BackupQueueManager.shared.addApplePhotoToQueue(applePhoto.id, md5: md5)
```

### Dual-Path Caching System

Apple Photos use a sophisticated dual-path caching approach:

**Browsing Path (Fast)**:
- Uses Apple Photo ID as cache key
- Leverages Photos framework for 512x512 thumbnails
- No original data loading
- Instant display for responsive UX

**Backup Path (Comprehensive)**:
- Uses MD5 hash as cache key
- Loads original data once for all operations
- Generates proper thumbnails
- Extracts full EXIF metadata
- Consistent with local file handling

The system is managed by `ApplePhotosMetadataCache` which maintains a persistent photo ID → MD5 mapping.

### Progress Tracking

The progress calculation accounts for both types of photos:

```swift
let totalPhotos = queuedPhotos.count + queuedApplePhotos.count
uploadProgress = Double(photosToUpload.count + index + 1) / Double(totalPhotos)
```

## Benefits

1. **Minimal Code Changes**: The dual queue approach required minimal changes to existing code
2. **Type Safety**: Maintains type safety by keeping `PhotoFile` and `PhotoApple` separate
3. **Efficient**: Apple Photos are only fetched when needed for upload
4. **Persistent**: Queue state survives app restarts
5. **Unified Status**: Single backup status system works for all photo types

## Future Enhancements

1. **Generic PhotoItem Support**: Refactor `S3BackupManager` to accept the `PhotoItem` protocol directly
2. **Batch Processing**: Process multiple Apple Photos in parallel
3. **Error Recovery**: Better handling of Photos Library access errors
4. **Progress Granularity**: Show progress for individual photo operations

## Testing

To test Apple Photos backup:

1. Open Apple Photos Library browser (Window → Apple Photos Library)
2. Select a photo and open the inspector (⌘I)
3. Click the star icon to queue for backup
4. Wait 30 seconds (DEBUG mode) for auto-backup
5. Check Cloud Browser to verify upload

## Performance Considerations

- Photos are fetched on-demand to minimize memory usage
- Dual-path caching optimizes for both browsing and backup scenarios
- MD5 computation is cached persistently to avoid recomputation
- Full metadata extraction happens only once during backup
- Progress updates are batched to reduce UI updates
- Photo ID → MD5 mapping builds gradually over time