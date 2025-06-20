# Star Toggle Button Design for Inspector View

## Overview

This document outlines the design for adding a star toggle button to the inspector view, with a simplified approach that only shows actions when the state is clear and unambiguous.

## Design Principles

1. **Clarity**: Only show actions when outcome is clear
2. **Simplicity**: No complex mixed state handling
3. **Visual Feedback**: Always show status with icons

## Single Selection Behavior

For a single photo selection, the star button behavior is straightforward:

### States
1. **Unstarred** - Star icon button, "Star for Backup"
2. **Starred** - Filled star icon (⭐️), "Remove from Queue"
3. **Archived** - Show archive badge, no star button
4. **During Retrieval** - Show retrieval indicator, no star button

## Multiple Selection Behavior

For multiple selections, we only show action buttons when ALL selected photos are in the same state.

### Clear States (Show Action)
1. **All Unstarred** - Show "Star All" button
2. **All Starred** - Show "Unstar All" button with ⭐️ icon

### Mixed States (No Action)
- **Mixed starred/unstarred** - Just show status icons
- **Contains archived** - Just show status icons  
- **Contains retrieving** - Just show status icons

Status is always displayed using icon counts: ⭐️3 📦2 ⏳1

## UI Examples

### Single Photo
```
Quick Actions
─────────────
[⭐ Star for Backup]
[📁 Show in Finder]
[↗️ Share]
```

### Multiple Photos - All Unstarred
```
Quick Actions
─────────────
[⭐ Star All 5 Photos]
[↗️ Share All]
```

### Multiple Photos - All Starred
```
Quick Actions
─────────────
[⭐️ Unstar All 5 Photos]
[↗️ Share All]
```

### Multiple Photos - Mixed State
```
Quick Actions
─────────────
Status: ⭐️2  3 unstarred
[↗️ Share All]

(No star/unstar buttons)
```

### Multiple Photos - With Archived
```
Quick Actions
─────────────
Status: ⭐️2  📦3
[↗️ Share Available]

(No star actions)
```

## Implementation

```swift
// Single selection
if selection.count == 1 {
    if let photo = selection.first as? PhotoFile {
        if BackupQueueManager.shared.queuedPhotos.contains(photo) {
            Button {
                BackupQueueManager.shared.removeFromQueue(photo)
            } label: {
                Label("Remove from Queue", systemImage: "star.fill")
            }
        } else {
            Button {
                BackupQueueManager.shared.addToQueue(photo)
            } label: {
                Label("Star for Backup", systemImage: "star")
            }
        }
    }
} else {
    // Multiple selection - only show button if all same state
    let photoFiles = selection.compactMap { $0 as? PhotoFile }
    let available = photoFiles.filter { !$0.isArchived }
    let starredCount = available.filter { 
        BackupQueueManager.shared.queuedPhotos.contains($0) 
    }.count
    
    if available.count == selection.count && available.count > 0 {
        // All photos are available (not archived/retrieving)
        if starredCount == 0 {
            // All unstarred
            Button("Star All") {
                available.forEach { 
                    BackupQueueManager.shared.addToQueue($0) 
                }
            }
        } else if starredCount == available.count {
            // All starred
            Button {
                available.forEach { 
                    BackupQueueManager.shared.removeFromQueue($0) 
                }
            } label: {
                Label("Unstar All", systemImage: "star.fill")
            }
        }
    }
    
    // Always show status
    StatusIconsView(selection: selection)
}
```

## Status Icons Component

```swift
struct StatusIconsView: View {
    let selection: [any PhotoItem]
    
    var body: some View {
        HStack(spacing: 12) {
            let photoFiles = selection.compactMap { $0 as? PhotoFile }
            let starred = photoFiles.filter { 
                BackupQueueManager.shared.queuedPhotos.contains($0) 
            }.count
            let archived = selection.filter { $0.isArchived }.count
            let retrieving = selection.filter { 
                $0.archiveStatus == .retrieving 
            }.count
            
            if starred > 0 {
                Label("\(starred)", systemImage: "star.fill")
                    .foregroundColor(.yellow)
            }
            
            if archived > 0 {
                Label("\(archived)", systemImage: "archivebox")
                    .foregroundColor(.orange)
            }
            
            if retrieving > 0 {
                Label("\(retrieving)", systemImage: "arrow.down.circle")
                    .foregroundColor(.blue)
            }
            
            let unstarred = photoFiles.count - starred - archived
            if unstarred > 0 && (starred > 0 || archived > 0 || retrieving > 0) {
                Text("\(unstarred) unstarred")
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
    }
}
```

## Benefits

1. **Ultra Simple**: Actions only appear when outcome is unambiguous
2. **No Confusion**: Mixed states show status only, no misleading buttons
3. **Clear Visual Feedback**: Icon-based status is always visible
4. **Easy Implementation**: Straightforward logic with no edge cases

## Next Steps

1. Implement star/unstar button for clear states only
2. Create StatusIconsView component to show icon counts
3. Add to QuickActionsSection in InspectorView
4. Test with various selection combinations:
   - Single photo (starred/unstarred)
   - Multiple all unstarred
   - Multiple all starred  
   - Mixed states (no action shown)
   - With archived/retrieving photos (no action shown)