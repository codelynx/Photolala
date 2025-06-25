# Apple Photo Star Indicator Fix

Last Updated: June 23, 2025

## Issue
Apple Photos star indicators (showing backup status) only appeared after opening Cloud Browser first, not when opening Apple Photos browser directly.

## Root Causes
1. The catalog entry wasn't being created with the Apple Photo ID when starring
2. Catalog entries weren't being updated to `uploaded` status after successful upload
3. SwiftData context issues from multiple PhotolalaCatalogServiceV2 instances
4. Feature flag preventing SwiftData catalog usage

## Solution Implemented
Simplified the system by removing `ApplePhotosBridge` entirely and using SwiftData catalog as the single source of truth:

### 1. Removed ApplePhotosBridge
- Deleted `ApplePhotosBridge.swift` file
- Removed all references to `ApplePhotosBridge` throughout the codebase
- No longer maintain a separate UserDefaults cache for Apple Photo ID mappings

### 2. Made PhotolalaCatalogServiceV2 a Singleton
- Changed from optional instance to singleton pattern with `static let shared`
- Resolved SwiftData context errors ("Illegal attempt to insert a model in to a different model context")
- Ensures all code uses the same SwiftData model context

### 3. SwiftData Catalog Integration
Updated all components to use SwiftData catalog as the source of truth:
- Added `findByApplePhotoID()` and `findByMD5()` methods to `PhotolalaCatalogServiceV2`
- Modified `UnifiedPhotoCell` to check SwiftData catalog for backup status
- Updated `PhotoApple.computeMD5Hash()` to check catalog first
- Updated `InspectorView` to use singleton catalog service

### 4. Fixed Catalog Entry Lifecycle
- Updated `addApplePhotoToQueue()` to create/update catalog entries when starring
- Added catalog entry update after successful upload in `BackupQueueManager`
- Updated `S3PhotoProvider.populateBackupStatusForApplePhotos()` to ensure catalog entries exist
- Updated `removeFromQueueByHash()` to update catalog when unstarring

### 5. Removed Feature Flag
- Removed `useSwiftDataCatalog` from FeatureFlags
- SwiftData catalog is now always enabled
- Removed all conditional checks for the feature flag


## Key Changes

### PhotolalaCatalogServiceV2.swift
```swift
// Singleton pattern
static let shared: PhotolalaCatalogServiceV2 = {
    do {
        return try PhotolalaCatalogServiceV2()
    } catch {
        fatalError("Failed to create PhotolalaCatalogServiceV2: \(error)")
    }
}()

// Find entry by Apple Photo ID
func findByApplePhotoID(_ applePhotoID: String) async throws -> CatalogPhotoEntry? {
    let descriptor = FetchDescriptor<CatalogPhotoEntry>(
        predicate: #Predicate { $0.applePhotoID == applePhotoID }
    )
    return try modelContext.fetch(descriptor).first
}

// Find entry by MD5
func findByMD5(_ md5: String) async throws -> CatalogPhotoEntry? {
    let descriptor = FetchDescriptor<CatalogPhotoEntry>(
        predicate: #Predicate { $0.md5 == md5 }
    )
    return try modelContext.fetch(descriptor).first
}
```

### UnifiedPhotoCell.swift
```swift
Task {
    // Query SwiftData catalog for this Apple Photo
    let catalogService = PhotolalaCatalogServiceV2.shared
    if let entry = try? await catalogService.findByApplePhotoID(photoApple.id) {
        await MainActor.run {
            if entry.isStarred || entry.backupStatus == BackupStatus.uploaded {
                starImageView.image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)
                starImageView.contentTintColor = .systemYellow
            }
        }
    }
}
```

### PhotoApple.swift
```swift
func computeMD5Hash() async throws -> String {
    // Check if MD5 is already stored in catalog
    let catalogService = await MainActor.run { PhotolalaCatalogServiceV2.shared }
    if let entry = try? await catalogService.findByApplePhotoID(id) {
        return entry.md5
    }
    
    // Load image data to compute hash
    let data = try await loadImageData()
    let hash = data.md5Digest.hexadecimalString
    return hash
}
```

### BackupQueueManager.swift
```swift
func addApplePhotoToQueue(_ photoID: String, md5: String) {
    // ... queue management code ...
    
    // Create or update catalog entry for Apple Photo
    Task {
        do {
            if let existingEntry = try await catalogServiceV2.findByApplePhotoID(photoID) {
                // Update existing entry
                existingEntry.isStarred = true
                existingEntry.backupStatus = BackupStatus.queued
                try await catalogServiceV2.save()
            } else {
                // Create new entry for Apple Photo
                let entry = CatalogPhotoEntry(...)
                entry.applePhotoID = photoID
                entry.isStarred = true
                entry.backupStatus = BackupStatus.queued
                
                let catalog = try await catalogServiceV2.findOrCreateCatalog(directoryPath: "apple-photos-library")
                try catalogServiceV2.upsertEntry(entry, in: catalog)
            }
        } catch { ... }
    }
}

// After successful upload
if let entry = try await catalogServiceV2.findByApplePhotoID(photoID) {
    entry.backupStatus = BackupStatus.uploaded
    try await catalogServiceV2.save()
}
```

### S3PhotoProvider.swift
Ensures catalog entries exist for all Apple Photos found in S3:
```swift
private func populateBackupStatusForApplePhotos() async {
    let s3Photos = photos.compactMap { $0 as? PhotoS3 }
    guard let catalogService = catalogService else { return }
    
    for photo in s3Photos {
        if let applePhotoID = photo.applePhotoID, !applePhotoID.isEmpty {
            // Update SwiftData catalog entry
            do {
                if let entry = try await catalogService.findByApplePhotoID(applePhotoID) {
                    if entry.backupStatus != BackupStatus.uploaded {
                        entry.backupStatus = BackupStatus.uploaded
                        try await catalogService.save()
                    }
                } else {
                    // Create catalog entry if it doesn't exist
                    let entry = CatalogPhotoEntry(...)
                    entry.applePhotoID = applePhotoID
                    entry.backupStatus = BackupStatus.uploaded
                    // ... create entry in catalog
                }
            } catch { ... }
        }
    }
}
```

### S3BackupManager.swift
When uploading Apple Photos, the Apple Photo ID is included in the metadata:
```swift
func uploadApplePhoto(_ photo: PhotoApple) async throws {
    // ... upload photo and thumbnail ...
    
    // Create PhotoMetadata with Apple Photo ID
    let photoMetadata = PhotoMetadata(
        // ... other fields ...
        applePhotoID: photo.asset.localIdentifier
    )
    try await s3Service.uploadMetadata(photoMetadata, md5: md5, userId: userId)
}
```

## Architecture Benefits
Using SwiftData catalog as the single source of truth provides:
- **Simplicity**: One less service to maintain
- **Consistency**: All backup status comes from one place
- **Persistence**: SwiftData automatically handles data persistence
- **Performance**: No need to maintain separate caches

The catalog contains all necessary information:
- `applePhotoID`: Apple Photos Library ID 
- `isStarred`: Whether photo is starred for backup
- `backupStatus`: Current backup status (.uploaded, .error, etc.)
- `md5`: The computed MD5 hash

This approach ensures backup status is available immediately when opening any browser, as SwiftData automatically loads persisted data.