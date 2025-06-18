# Shopping Cart Style Backup Experience Design

## Overview

Transform the backup experience from a separate test UI to an integrated "shopping cart" style workflow where users can select photos while browsing and then backup their selection in bulk.

## Current State

- Separate S3BackupTestView for testing
- PhotosPicker for selecting photos to upload
- Immediate upload after selection
- No integration with main browsing experience

## Proposed Design

### 1. Integration with Photo Browser

While browsing local photos in PhotoBrowserView:
- Add a "star" or "cart" icon to each photo
- Quick action to mark photos for backup
- Visual indicator for:
  - Already backed up (cloud icon)
  - Marked for backup (star/cart icon)
  - Not backed up (no icon)

### 2. Backup Queue Concept

**Shopping Cart Model:**
- Users browse their local photos naturally
- Click star/cart icon to add to backup queue
- See running count in toolbar (e.g., "12 photos selected")
- Review selection before backing up
- One-click bulk backup

**Visual Flow:**
```
Browse Photos → Select/Star Photos → Review Selection → Backup All
     ↓              ↓                      ↓              ↓
Local Browser   Cart Icon          Backup Queue View   Progress
```

### 3. UI Components

#### A. Photo Cell Enhancement
```swift
PhotoCell:
- Existing: Thumbnail, filename, size
- Add: Backup status indicator
  - ✓ Backed up (green cloud)
  - ⭐ Selected for backup (star)
  - ↑ Uploading (progress)
  - (empty) Not backed up
```

#### B. Toolbar Enhancement
```swift
PhotoBrowserView Toolbar:
- Existing: View options, selection mode
- Add: Backup queue badge (e.g., "🛒 12")
- Click badge → Show backup queue
```

#### C. Backup Queue View
```swift
BackupQueueView:
- List/grid of selected photos
- Total size calculation
- Quota usage preview
- Remove individual items
- Clear all
- "Backup Now" button
```

### 4. State Management

#### BackupQueueManager (Singleton)
```swift
class BackupQueueManager: ObservableObject {
    @Published var queuedPhotos: Set<PhotoReference> = []
    @Published var backupStatus: [String: BackupStatus] = [:] // MD5 -> Status
    
    func addToQueue(_ photo: PhotoReference)
    func removeFromQueue(_ photo: PhotoReference)
    func isQueued(_ photo: PhotoReference) -> Bool
    func isBackedUp(_ photo: PhotoReference) -> Bool
    func startBackup() async
}
```

#### Integration Points
1. PhotoManager checks backup status when loading
2. PhotoCell observes BackupQueueManager
3. Persistent queue across app launches
4. Background upload capability

### 5. Workflow Examples

#### Quick Backup
1. Browse photos normally
2. Tap star on photos to backup
3. See count in toolbar (🛒 5)
4. Tap toolbar badge
5. Confirm and backup

#### Selective Backup
1. Enter selection mode
2. Select multiple photos
3. Toolbar shows "Backup Selection"
4. Add all to queue
5. Review and backup

#### Smart Suggestions
- "Backup all photos from today"
- "Backup favorites"
- "Backup photos > 1 month old"

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

## Questions to Resolve

1. Should we use star (favorite) or cart (shopping) metaphor?
2. How to handle already backed up photos?
3. Should queue persist across app launches?
4. Background upload priority?
5. Integration with existing selection mode?

## Next Steps

1. Review and refine design
2. Create mockups/wireframes
3. Implement Phase 1
4. User testing
5. Iterate based on feedback