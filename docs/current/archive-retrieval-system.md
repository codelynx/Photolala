# Archive Retrieval System

## Overview

The archive retrieval system allows users to restore photos that have been automatically moved to S3 Deep Archive storage after 6 months. This feature is part of the S3 backup service and provides a cost-effective way to store rarely accessed photos while maintaining the ability to retrieve them when needed.

## Architecture

### Components

1. **Archive Status Models** (`Models/ArchiveStatus.swift`)
   - Defines storage classes (STANDARD, DEEP_ARCHIVE, GLACIER, INTELLIGENT_TIERING)
   - Tracks archive lifecycle information with ArchivedPhotoInfo
   - Stores original file size for cost calculations
   - Determines immediate accessibility

2. **Visual Indicators** (`Views/PhotoArchiveBadge.swift`)
   - Displays badges on archived photos:
     - ❄️ Archived (not immediately accessible)
     - ⏳ Retrieving (restore in progress)
     - ✨ Recently restored (temporarily available)
     - ⭐ Premium feature indicator
     - ⚠️ Error state

3. **Retrieval Dialog** (`Views/PhotoRetrievalView.swift`)
   - Modal interface for initiating photo restoration
   - Options for single photo, selected photos, or entire album
   - Rush delivery toggle (12-48 hours vs 5-12 hours)
   - Cost estimation display based on actual file sizes
   - Batch selection support:
     - Accepts array of selected photos
     - Automatically filters archived photos
     - Defaults to "Selected photos" option when multiple archived photos selected
     - Calculates total size and cost for batch operations

4. **Retrieval Manager** (`Services/S3RetrievalManager.swift`)
   - Manages active retrieval requests
   - Monitors restore progress
   - Handles batch operations
   - Provides status updates

5. **S3 Integration** (`Services/S3BackupService.swift`)
   - AWS SDK integration for RestoreObject API
   - Status checking via HeadObject
   - Support for expedited and standard retrieval tiers

## User Flow

1. **Discovery**
   - User browses photo collection
   - Archived photos display ❄️ badge
   - Hovering shows "Archived" tooltip

2. **Initiation**
   - User clicks on archived photo
   - PhotoRetrievalView dialog appears
   - User selects retrieval option and delivery speed

3. **Processing**
   - S3 RestoreObject request initiated
   - Photo badge changes to ⏳ (retrieving)
   - Background monitoring begins

4. **Completion**
   - Photo restored to temporary accessibility
   - Badge changes to ✨ (recently restored)
   - User notified of availability
   - Photo remains accessible for 30 days

## Implementation Details

### S3 Restore API

```swift
func restorePhoto(md5: String, userId: String, rushDelivery: Bool = false) async throws {
    let key = "users/\(userId)/photos/\(md5).dat"
    
    let input = RestoreObjectInput(
        bucket: bucketName,
        key: key,
        restoreRequest: S3ClientTypes.RestoreRequest(
            days: 30,
            glacierJobParameters: S3ClientTypes.GlacierJobParameters(
                tier: rushDelivery ? .expedited : .standard
            )
        )
    )
    
    _ = try await client.restoreObject(input: input)
}
```

### Status Checking

```swift
func checkRestoreStatus(md5: String, userId: String) async throws -> RestoreStatus {
    let key = "users/\(userId)/photos/\(md5).dat"
    
    let input = HeadObjectInput(bucket: bucketName, key: key)
    let response = try await client.headObject(input: input)
    
    if let restore = response.restore {
        if restore.contains("ongoing-request=\"true\"") {
            return .inProgress(estimatedCompletion: parseEstimatedTime(from: restore))
        } else if restore.contains("ongoing-request=\"false\"") {
            return .completed(expiresAt: parseExpiryTime(from: restore))
        }
    }
    
    return .notStarted
}
```

### Error Handling

The system handles several error cases:
- `PhotoRetrievalError.missingMD5`: Photo identifier cannot be computed
- `PhotoRetrievalError.missingUserInfo`: User not signed in
- `PhotoRetrievalError.alreadyRetrieving`: Restore already in progress
- `PhotoRetrievalError.batchErrors`: Multiple failures in batch operation

### Platform Differences

- **macOS**: Uses NSCollectionView with click gestures
- **iOS/iPadOS**: Uses UICollectionView with tap gestures
- Both platforms share the same retrieval dialog and backend logic

## Cost Model

Based on S3 Deep Archive pricing:
- Standard retrieval: $0.025 per GB (12-48 hours)
- Expedited retrieval: $0.10 per GB (5-12 hours)
- Restored data: Standard S3 rates for 30 days

## Future Enhancements

1. ~~**Batch Selection UI**: Allow users to select multiple photos for retrieval~~ ✅ Implemented
2. **Progress Notifications**: Push notifications when retrieval completes
3. **Retrieval History**: Track and display past retrieval requests
4. **Smart Pre-warming**: Predictively restore photos based on usage patterns
5. **Cost Optimization**: Suggest batch retrieval for better value

## Related Documentation

- [S3 Backup Service Design](../../services/s3-backup/design/s3-backup-service-design.md)
- [Deep Archive Analysis](../../services/s3-backup/design/deep-archive-analysis.md)
- [Pricing Strategy](../../services/s3-backup/design/CURRENT-pricing-strategy.md)