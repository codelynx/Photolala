# SwiftData Catalog Integration Fixes - June 23, 2025

## Overview
Fixed issues with Apple Photos star indicators not showing correctly by ensuring SwiftData catalog entries are properly created and updated throughout the backup lifecycle.

## Key Changes

### 1. Removed ApplePhotosBridge
- **File**: `Photolala/Services/ApplePhotosBridge.swift`
- **Change**: Completely removed this service as it was causing race conditions and unnecessary complexity
- **Reason**: SwiftData catalog should be the single source of truth for backup status

### 2. Made PhotolalaCatalogServiceV2 a Singleton
- **File**: `Photolala/Services/PhotolalaCatalogServiceV2.swift`
- **Changes**:
  - Changed from optional instance to singleton pattern
  - Added `static let shared` property
  - Made initializer private
  - Added `findByMD5()` method for catalog queries
- **Reason**: Resolved SwiftData context errors when multiple instances were created

### 3. Updated BackupQueueManager
- **File**: `Photolala/Services/BackupQueueManager.swift`
- **Changes**:
  - Updated to use `PhotolalaCatalogServiceV2.shared` singleton
  - Added catalog entry updates after successful Apple Photo uploads
  - Fixed enum references to use full type names (e.g., `BackupStatus.uploaded`)
  - Reduced inactivity timer to 15 seconds for development
- **Key Fix**: Now updates catalog entries to `uploaded` status after successful upload

### 4. Enhanced S3PhotoProvider
- **File**: `Photolala/Services/PhotoProvider.swift`
- **Changes**:
  - Updated `populateBackupStatusForApplePhotos()` to create/update catalog entries
  - Ensures all Apple Photos found in S3 have corresponding catalog entries
  - Fixed property references for PhotoS3 model
- **Key Fix**: Creates catalog entries for Apple Photos discovered in S3

### 5. Removed SwiftData Feature Flag
- **File**: `Photolala/Utilities/FeatureFlags.swift`
- **Change**: Removed `useSwiftDataCatalog` flag entirely
- **Reason**: SwiftData catalog is now always enabled

### 6. Updated UI Components
- **Files**: 
  - `Photolala/Views/UnifiedPhotoCell.swift`
  - `Photolala/Views/InspectorView.swift`
  - `Photolala/Views/UnifiedPhotoCollectionViewController.swift`
- **Changes**:
  - Removed feature flag checks
  - Updated to use singleton catalog service
  - Added selection logging to debug star status
  - Enhanced logging to show both `isStarred` and `backupStatus` values

### 7. Fixed PhotoApple
- **File**: `Photolala/Models/PhotoApple.swift`
- **Change**: Updated to use `PhotolalaCatalogServiceV2.shared` singleton

### 8. Minor Updates
- **File**: `Photolala/PhotolalaApp.swift`
- **Change**: Updated to use singleton catalog service
- **File**: `Photolala/Services/S3CatalogSyncServiceV2.swift`
- **Change**: Minor adjustments for singleton pattern

## Star Display Logic

The star indicator appears when EITHER condition is met:
1. `entry.isStarred == true` (manually starred by user)
2. `entry.backupStatus == BackupStatus.uploaded` (successfully uploaded)

## Data Flow

1. **When starring an Apple Photo**:
   - User clicks star in inspector
   - `BackupQueueManager.addApplePhotoToQueue()` creates catalog entry with `isStarred = true`
   - Photo is queued for upload

2. **After successful upload**:
   - `BackupQueueManager` updates catalog entry to `backupStatus = .uploaded`
   - Catalog entry is saved to SwiftData

3. **When opening S3 browser**:
   - `S3PhotoProvider.populateBackupStatusForApplePhotos()` ensures catalog entries exist
   - Updates or creates entries for all Apple Photos found in S3

4. **When displaying thumbnails**:
   - `UnifiedPhotoCell` queries catalog by Apple Photo ID
   - Shows star if `isStarred` OR `backupStatus == .uploaded`

## Debugging

Added selection logging that shows:
```
[Selection] Apple Photo 'IMG_3291.HEIC': isStarred=false, backupStatus=uploaded, SHOULD SHOW STAR=true
```

This helps identify whether the catalog data is correct and if stars should be displayed.

## Next Steps

If stars still aren't showing despite `SHOULD SHOW STAR=true`, investigate:
1. Whether `UnifiedPhotoCell.configure()` is being called after catalog updates
2. If there's a UI refresh issue after catalog changes
3. Whether notifications are properly triggering UI updates