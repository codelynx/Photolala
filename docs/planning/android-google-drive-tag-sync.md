# Android Google Drive Tag Sync Implementation Plan

## Overview

This document outlines the implementation plan for adding Google Drive-based tag synchronization to the Android version of Photolala, providing feature parity with iOS's iCloud Document sync.

## Goals

1. **Cross-device sync**: Tags created on one Android device automatically appear on another
2. **iOS compatibility**: Maintain compatible data format with iOS tag system
3. **Offline support**: Work seamlessly offline with sync when connected
4. **Conflict resolution**: Handle concurrent edits from multiple devices
5. **Zero cost**: Use user's Google Drive storage (no server costs)

## Architecture

### Storage Format

```
Google Drive App Folder/
├── tags.json           # Master tag file (same format as iOS)
├── tags-delta-{deviceId}.json  # Device-specific changes
└── metadata.json       # Sync metadata (last sync time, device info)
```

### Data Model Compatibility

Android will use the same tag identifier format as iOS:
- **MD5-based**: `md5#{hash}` for all photos
- **No iCloud prefix**: Android doesn't have iCloud photos
- Compatible with iOS when user has same photos backed up to S3

### JSON Format (Same as iOS)

```json
[
  {
    "photoIdentifier": "md5#a1b2c3d4e5f6",
    "flags": [1, 3, 5]
  },
  {
    "photoIdentifier": "md5#b2c3d4e5f6g7",
    "flags": [2, 4]
  }
]
```

## Implementation Components

### 1. Google Drive Service

```kotlin
class GoogleDriveTagSyncService(
    private val context: Context,
    private val account: GoogleSignInAccount
) {
    private val driveService: Drive
    
    // Core sync methods
    suspend fun uploadTags(tags: List<PhotoTag>)
    suspend fun downloadTags(): List<PhotoTag>
    suspend fun syncTags(): SyncResult
    suspend fun resolveConflicts(local: List<PhotoTag>, remote: List<PhotoTag>): List<PhotoTag>
}
```

### 2. Sync Manager

```kotlin
class TagSyncManager(
    private val tagRepository: PhotoTagRepository,
    private val driveService: GoogleDriveTagSyncService
) {
    // Sync orchestration
    suspend fun performSync()
    suspend fun exportToGoogleDrive()
    suspend fun importFromGoogleDrive()
    
    // Conflict resolution
    fun mergeTagSets(local: Set<PhotoTag>, remote: Set<PhotoTag>): Set<PhotoTag>
}
```

### 3. Repository Updates

Modify existing `PhotoTagRepository` to support sync:

```kotlin
interface PhotoTagRepository {
    // Existing methods
    suspend fun toggleTag(photoId: String, colorFlag: ColorFlag)
    fun getTagsForPhoto(photoId: String): Flow<List<PhotoTag>>
    
    // New sync methods
    suspend fun getAllTags(): List<PhotoTag>
    suspend fun replaceTags(tags: List<PhotoTag>)
    suspend fun getTagsSince(timestamp: Long): List<PhotoTag>
    suspend fun markSynced(tags: List<PhotoTag>, syncTime: Long)
}
```

### 4. Background Sync

```kotlin
class TagSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        // Perform sync if user is signed in with Google
        // Handle offline gracefully
        // Retry on failure
    }
}
```

## Implementation Phases

### Phase 1: Google Drive Integration (Week 1)
- [ ] Add Google Drive API dependencies
- [ ] Implement GoogleDriveTagSyncService
- [ ] Handle authentication and permissions
- [ ] Create app folder structure

### Phase 2: Basic Sync (Week 2)
- [ ] Implement manual export/import functions
- [ ] Add UI buttons for manual sync
- [ ] Test with simple tag data
- [ ] Handle basic errors

### Phase 3: Automatic Sync (Week 3)
- [ ] Implement background WorkManager sync
- [ ] Add sync status indicators
- [ ] Handle offline/online transitions
- [ ] Implement retry logic

### Phase 4: Conflict Resolution (Week 4)
- [ ] Implement three-way merge algorithm
- [ ] Add device ID tracking
- [ ] Handle concurrent edits
- [ ] Test edge cases

### Phase 5: Migration & Polish (Week 5)
- [ ] Migrate existing local tags to Drive
- [ ] Add sync settings/preferences
- [ ] Performance optimization
- [ ] Comprehensive testing

## Technical Details

### Google Drive API Setup

1. **Dependencies** (build.gradle):
```gradle
implementation 'com.google.android.gms:play-services-auth:20.7.0'
implementation 'com.google.api-client:google-api-client-android:2.2.0'
implementation 'com.google.apis:google-api-services-drive:v3-rev20231128-2.0.0'
```

2. **Permissions**:
- Drive.SCOPE_FILE (access app folder)
- No additional Android permissions needed

3. **Authentication**:
- Use existing Google Sign-In
- Request Drive scope during sign-in

### Sync Algorithm

```kotlin
suspend fun syncTags() {
    // 1. Download remote tags.json
    val remoteTags = driveService.downloadTags()
    
    // 2. Get local tags
    val localTags = repository.getAllTags()
    
    // 3. Get last sync timestamp
    val lastSync = preferences.lastSyncTime
    
    // 4. Three-way merge
    val localChanges = repository.getTagsSince(lastSync)
    val merged = mergeChanges(localTags, remoteTags, localChanges)
    
    // 5. Update local database
    repository.replaceTags(merged)
    
    // 6. Upload merged result
    driveService.uploadTags(merged)
    
    // 7. Update sync timestamp
    preferences.lastSyncTime = System.currentTimeMillis()
}
```

### Conflict Resolution Strategy

1. **Union approach**: If photo has tags on multiple devices, combine them
2. **Latest wins**: For same flag conflicts, use most recent change
3. **Never lose data**: Always preserve tags unless explicitly removed

### Delta Files (Future Enhancement)

Similar to iOS implementation:
```
tags-delta-{deviceId}.json format:
{
  "device": "Pixel-7-Bob",
  "changes": [
    {"op": "add", "photoId": "md5#abc123", "flag": 1, "timestamp": 1234567890},
    {"op": "remove", "photoId": "md5#abc123", "flag": 3, "timestamp": 1234567891}
  ]
}
```

## Migration Strategy

### For Existing Users

1. **On first sync**:
   - Check if tags.json exists in Google Drive
   - If not, upload local tags as initial dataset
   - If yes, merge with local tags

2. **Preserve local data**:
   - Never delete local tags without user confirmation
   - Always merge, don't replace

### Database Schema Updates

Add sync metadata to Room:
```kotlin
@Entity
data class TagEntity(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val photoId: String,
    val colorFlag: ColorFlag,
    val timestamp: Long,
    val syncStatus: SyncStatus = SyncStatus.PENDING,
    val lastSyncTime: Long? = null
)

enum class SyncStatus {
    PENDING, SYNCED, CONFLICT
}
```

## Error Handling

### Network Errors
- Queue changes for later sync
- Show sync status in UI
- Retry with exponential backoff

### Authentication Errors
- Prompt user to re-authenticate
- Don't lose local data
- Clear sync error after re-auth

### Storage Quota
- Warn user if approaching quota
- Tags typically < 1MB, unlikely issue
- Provide option to clean old tags

## UI Changes

### Settings Screen
```
Tag Sync
├── Status: Synced ✓ (2 min ago)
├── Last sync: Oct 31, 2:45 PM
├── Sync now [Button]
└── Auto-sync: ON [Toggle]
```

### Photo Grid
- Sync indicator when changes pending
- Pull-to-refresh triggers sync
- Show sync errors with retry option

## Testing Plan

### Unit Tests
- Tag merge algorithm
- Conflict resolution
- JSON serialization

### Integration Tests
- Google Drive API calls
- Full sync flow
- Error scenarios

### Manual Testing
- Two devices, concurrent edits
- Offline/online transitions
- Large tag datasets
- Fresh install scenarios

## Success Metrics

1. **Sync reliability**: 99%+ successful syncs
2. **Performance**: Sync < 2 seconds for typical usage
3. **Data integrity**: Zero tag loss reports
4. **User adoption**: 80%+ of Google users enable sync

## Future Enhancements

1. **Selective sync**: Choose which folders to sync tags
2. **Tag history**: View tag changes over time
3. **Bulk operations**: Tag multiple photos with sync
4. **Cross-platform**: Share tags between iOS/Android (via S3)

## Security Considerations

1. **App folder isolation**: Only Photolala can access
2. **Encrypted at rest**: Google Drive encryption
3. **No sensitive data**: Only photo IDs and color numbers
4. **User control**: Can disable sync anytime

## Comparison with iOS

| Feature | iOS (iCloud) | Android (Drive) |
|---------|--------------|-----------------|
| Storage | iCloud Documents | Drive App Folder |
| Format | JSON + CSV | JSON |
| Sync | Automatic | Automatic |
| Conflicts | Delta files | Three-way merge |
| Cost | Free (5GB) | Free (15GB) |

## Implementation Timeline

- **Week 1-2**: Core implementation
- **Week 3-4**: Testing and polish
- **Week 5**: Beta release
- **Week 6**: Production release

## Conclusion

This implementation will bring Android to feature parity with iOS for tag synchronization, providing users with a seamless cross-device experience while maintaining data format compatibility for future cross-platform features.