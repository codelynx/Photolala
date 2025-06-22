# Backup Status Persistence System

## Overview

The backup status persistence system ensures that star states (indicating S3 backup status) are maintained across app restarts. It uses a dual-key approach with both MD5 hashes and file paths.

## Key Components

### BackupQueueManager

The `BackupQueueManager` singleton manages backup queue and status persistence:

- **backupStatus**: `[String: BackupState]` - Maps MD5 hash to backup state
- **pathToMD5**: `[String: String]` - Maps file path to MD5 hash for persistence
- **queuedPhotos**: `Set<PhotoFile>` - Currently queued local photos
- **queuedApplePhotos**: `Set<String>` - Currently queued Apple Photo IDs

### Backup States

```swift
enum BackupState: String, Codable {
    case none
    case queued     // Photo is queued for backup
    case uploading  // Currently uploading
    case uploaded   // Successfully uploaded
    case failed     // Upload failed
}
```

### Persistence Flow

1. **When Starring a Photo**:
   - Compute MD5 hash if not already computed
   - Store in both `backupStatus[md5]` and `pathToMD5[filepath]`
   - Save state to UserDefaults

2. **On App Launch**:
   - Restore saved state from UserDefaults
   - Load both backupStatus and pathToMD5 mappings

3. **When Loading Photos**:
   - Call `matchPhotosWithBackupStatus()` after loading
   - Use pathToMD5 to quickly restore MD5 hashes
   - Match photos with their saved backup status

## Apple Photos Support

### Persistence for Apple Photos

Apple Photos are handled differently from local photos:

1. **Queuing**:
   - Photo ID is stored in `queuedApplePhotos` Set
   - MD5 hash is computed and stored in `backupStatus`
   - Both are persisted to UserDefaults

2. **Upload Process**:
   - PHAsset is fetched by ID when backup timer fires
   - Image data is loaded from Photos Library
   - Temporary file is created for S3 upload
   - After upload, photo ID is removed from queue

3. **Star State**:
   - Managed by `ApplePhotosBridge` (separate from backup queue)
   - Stars persist across app sessions
   - MD5 hashes are cached to avoid recomputation

## Visual Indicators

### Local Photos (PhotoFile)
- ⭐ Yellow star: Queued or uploaded
- ❗ Red exclamation: Failed upload
- No icon: Not backed up

### Apple Photos (PhotoApple)
- Same visual indicators as local photos
- Star state synced with ApplePhotosBridge
- Backup status tracked by MD5 hash

### Cloud Photos (PhotoS3)
- ☁️ Blue cloud: Always shown (already in cloud)

## Implementation Details

### File Changes

1. **BackupQueueManager.swift**:
   - Added `pathToMD5` dictionary
   - Updated `QueueState` struct to include path mappings
   - Enhanced save/restore logic
   - Improved matching algorithm

2. **UnifiedPhotoCell.swift**:
   - Added photo type checking (PhotoFile vs PhotoS3)
   - Show appropriate icons based on photo type
   - Consistent behavior across macOS and iOS

### Data Storage

Backup state is stored in UserDefaults under the key `"BackupQueueState"` as JSON:

```json
{
  "queuedPhotos": ["md5_hash1", "md5_hash2"],
  "backupStatus": {
    "md5_hash1": "queued",
    "md5_hash2": "uploaded"
  },
  "lastActivityTime": "2025-06-20T08:00:00Z",
  "pathToMD5": {
    "/path/to/photo1.jpg": "md5_hash1",
    "/path/to/photo2.jpg": "md5_hash2"
  },
  "queuedApplePhotos": ["photoID1", "photoID2"]
}
```

## Usage

The system works automatically:

1. Users star photos for backup
2. Status is saved immediately
3. On app restart, status is restored
4. Stars reappear on the same photos

No manual intervention required.