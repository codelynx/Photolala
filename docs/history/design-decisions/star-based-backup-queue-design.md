# Star-Based Backup Queue Design

## Overview

Transform the backup experience from a separate test UI to an integrated star-based workflow where users can mark photos for backup while browsing and then upload their selection automatically or manually.

**Key Concept**: Users "star" photos to mark them for backup, similar to favoriting. After a period of inactivity (10 minutes), starred photos are automatically backed up to S3.

**Note**: The `.photolala` catalog format will be updated in a future iteration to track backup status for better performance.

## Current State

- Separate S3BackupTestView for testing
- PhotosPicker for selecting photos to upload
- Immediate upload after selection
- No integration with main browsing experience

## Proposed Design

### 1. Integration with Photo Browser

While browsing local photos in PhotoBrowserView:
- Badge overlay on photo thumbnails (top-right corner)
- Click badge to toggle backup queue status
- Visual states:
  - No badge: Not backed up
  - ⭐ Star badge: Queued for backup
  - ⬆️ Arrow badge: Currently uploading (animated)
  - ☁️ Cloud badge: Already backed up
  - ❌ Error badge: Upload failed

**Integration with existing selection**: The current multi-selection mode (PhotoBrowserView → PhotoPreviewView) will include a "Backup Selected" action.

### 2. Backup Queue Concept

**Star-Based Queue Model:**
- Users browse their local photos naturally
- Click photo badge to star/unstar for backup
- Toolbar shows queue count when photos are starred
- Automatic backup after 10 minutes of inactivity
- Manual "Backup Now" option available

**Activity Timer Behavior:**
- Any star/unstar action resets the 10-minute timer
- Timer persists across app launches
- Different triggers can have different timers (future enhancement)

**Visual Flow:**
```
Browse → Star Photos → (Wait 10 min) → Auto Backup
  ↓          ↓              ↓               ↓
Local    Badge Click    Timer Runs    Background Upload
```

### 3. UI Components

#### A. Photo Cell Enhancement
```swift
PhotoCell:
- Existing: Thumbnail, filename, size
- Add: Badge overlay (top-right corner)
  - Design: 24x24 circle with shadow
  - Position: 8px from top and right edges
  - Interactive: Click to toggle state
  - Hover: Tooltip with status info
```

**Badge Implementation:**
- Integrated with NSCollectionViewItem
- Observes BackupQueueManager state
- Smooth animations for state changes

#### B. Toolbar Enhancement
```swift
PhotoBrowserView Toolbar:
- Existing: View options, selection mode
- Add: Backup queue indicator
  - Shows only when photos are starred
  - Format: "⭐ 12" (star icon with count)
  - Click to show queue details or backup now
```

#### C. Progress Display
```swift
BackupStatusBar:
- Shared across all windows (singleton state)
- Appears at bottom of window during uploads
- Shows: progress bar, current file, speed, time remaining
- Similar to Safari's download bar
- Auto-hides when complete
```

**Benefits of status bar approach:**
- Consistent location across all windows
- Non-intrusive to browsing experience
- Persists when switching folders/windows
- Familiar UI pattern for users

### 4. State Management

#### BackupQueueManager (Singleton)
```swift
class BackupQueueManager: ObservableObject {
    static let shared = BackupQueueManager()
    
    @Published var queuedPhotos: Set<PhotoReference> = []
    @Published var backupStatus: [String: BackupState] = [:] // MD5 -> State
    
    // Activity timer
    private var inactivityTimer: Timer?
    private let inactivityInterval: TimeInterval = 600 // 10 minutes
    
    func toggleStar(for photo: PhotoReference)
    func backupState(for photo: PhotoReference) -> BackupState
    private func resetInactivityTimer()
    private func performAutoBackup() async
    
    // Persistence
    func saveQueueState()
    func restoreQueueState()
}
```

#### Integration Points
1. PhotoManager checks backup status when loading
2. PhotoCell observes BackupQueueManager
3. Persistent queue across app launches
4. Background upload capability

### 5. Workflow Examples

#### Auto Backup Flow
1. Browse photos normally
2. Click badge to star photos for backup
3. Continue browsing and starring
4. After 10 minutes of no starring activity → auto backup starts
5. Status bar shows progress
6. Stars removed after successful upload

#### Manual Backup Flow
1. Star multiple photos while browsing
2. See count in toolbar (⭐ 12)
3. Click toolbar badge → "Backup Now"
4. Immediate upload begins
5. Progress in status bar

#### Multi-Select Integration
1. Enter selection mode (existing feature)
2. Select multiple photos
3. Choose "Add to Backup Queue" from context menu
4. All selected photos get starred
5. Timer starts for auto-backup

### 6. Technical Considerations

#### Performance
- Lazy checking of backup status
- Cache MD5 calculations
- Batch status checks
- Background queue processing

#### Storage
- Persist queue to UserDefaults/CoreData
- Track upload progress
- Resume interrupted uploads

#### Integration
- Minimal changes to existing PhotoBrowserView
- New BackupQueueManager service
- Enhance PhotoCell with status
- New BackupQueueView

### 7. Benefits

1. **Natural Workflow**: Backup while browsing
2. **Bulk Operations**: Efficient for many photos
3. **Visual Feedback**: Clear status indicators
4. **User Control**: Review before uploading
5. **Flexibility**: Various selection methods

### 8. Implementation Phases

#### Phase 1: Basic Queue
- BackupQueueManager
- Star/unstar functionality
- Queue count in toolbar

#### Phase 2: Queue View
- BackupQueueView
- Bulk backup functionality
- Progress tracking

#### Phase 3: Smart Features
- Backup status indicators
- Duplicate detection
- Smart suggestions
- Background uploads

### 9. Future Enhancements

- Auto-backup rules
- Scheduled backups
- Wi-Fi only option
- Folder-based backup
- Incremental sync

## Design Decisions

1. **Icon Choice**: Star (⭐) for backup queue - simple and familiar
2. **Auto-backup Timer**: 10 minutes of inactivity triggers upload
3. **Queue Persistence**: Yes, queue state saved and restored on app launch
4. **Progress Display**: Shared status bar at bottom of windows
5. **Multi-device Conflicts**: Deferred - will add warnings if needed during field testing

## Future Considerations

- **Album Integration**: Future album/grouping features could have auto-backup rules
- **Smart Tags**: Different tags (heart, flag) could have different backup behaviors
- **Background Sync**: Could extend to sync deletions (unstar = remove from S3)

## Next Steps

1. Review and refine design
2. Create mockups/wireframes
3. Implement Phase 1
4. User testing
5. Iterate based on feedback
