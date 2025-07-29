# Tag System Documentation

## Overview

The Photolala tag system allows users to mark photos with color-coded tags that sync across all their devices using iCloud Documents. This replaces the previous emoji-based bookmark system with a more robust solution supporting cross-device synchronization.

## Key Features

- **Color Tags**: 7 distinct color flags (red, orange, yellow, green, blue, purple, gray)
- **Keyboard Shortcuts**: Quick tagging with keys 1-7
- **Multiple Tags**: Photos can have multiple tags simultaneously
- **Universal Photo ID**: Works across all photo types (local files, Apple Photos, S3)
- **iCloud Sync**: Tags automatically sync between devices
- **No Conflicts**: Master + delta file pattern prevents sync conflicts

## Architecture

### Components

1. **TagManager** (`Services/TagManager.swift`)
   - Singleton service managing all tag operations
   - Handles local storage and iCloud sync
   - Posts notifications for UI updates

2. **TagSyncManager** (`Services/TagSyncManager.swift`)
   - Manages iCloud Documents synchronization
   - Implements master + delta file pattern
   - Handles merge operations

3. **PhotoTag** (`Models/PhotoTag.swift`)
   - Data model for tags
   - Contains photo identifier and set of color flags

4. **ColorFlag** (`Models/ColorFlag.swift`)
   - Enum with Int raw values (1-7)
   - Provides color and UI properties

## Photo Identification

### ID Format

Photos are identified using a universal format that works across devices:

- **iCloud Photos**: `icl#{localIdentifier}` 
  - Example: `icl#12345-ABCD-6789-EF01`
  - Uses PHAsset's localIdentifier for iCloud-synced photos

- **All Others**: `md5#{hash}`
  - Example: `md5#a1b2c3d4e5f6...`
  - Includes: local files, non-iCloud Apple Photos, S3 photos
  - MD5 computed from file content

- **Fallback**: `apl#{localIdentifier}`
  - Used when MD5 computation fails for Apple Photos
  - Ensures every photo can be tagged

### MD5 Cache

To improve performance, MD5 hashes are cached using SwiftData:

```swift
@Model
class MD5Cache {
    let cacheKey: String    // "{identifier}:{modification-unix}"
    let md5Hash: String     // Computed MD5 hash
    let computedDate: Date
}
```

## Tag Storage

### Local Storage

Tags are stored in:
- **JSON**: `~/Library/Application Support/Photolala/tags.json`
- **Format**: Array of PhotoTag objects
- **Auto-save**: Changes persist immediately

### iCloud Storage

Tags sync via iCloud Documents:
- **Master**: `tags.csv` - Consolidated tag data
- **Delta**: `tags-delta-{deviceID}.csv` - Per-device changes
- **Location**: `~/Library/Mobile Documents/iCloud~com~electricwoods~photolala/Documents/`

### CSV Format

Master file format:
```csv
icl#SUNSET-123,1:4:5,1704067600
md5#abc123def,3:7,1704067700
```

Delta file format:
```csv
+,icl#SUNSET-123,1,1704067200,Mac-Bob
-,icl#SUNSET-123,1,1704067400,iPad-Bob
```

## User Interface

### Inspector Panel

Tags are managed in the Inspector's Tag section:
- Grid of 7 color flag buttons
- Visual feedback for active tags
- Keyboard shortcuts (1-7)
- Clear all button when tags exist

### Thumbnail Display

Tagged photos show:
- Small colored flag icons in bottom-left corner
- Multiple flags displayed horizontally
- Auto-hide with other UI elements

### Keyboard Shortcuts

- **1-7**: Toggle specific color tag
- **⌘I**: Show/hide inspector
- Tag operations work in both browser and preview modes

## Sync Operations

### Manual Sync Methods

```swift
// Initial export (first device with tags)
await TagManager.shared.exportToICloudMaster()

// Sync from iCloud (other devices)
await TagManager.shared.syncFromICloud()

// Merge delta files (periodic maintenance)
await TagManager.shared.triggerICloudMerge()
```

### Automatic Operations

- Tag changes automatically write to delta files
- Each device maintains its own delta file
- No conflicts during normal operation

### Sync Flow

1. **Device A** tags a photo → writes to `tags-delta-Mac-A.csv`
2. **Device B** tags a photo → writes to `tags-delta-iPad-B.csv`
3. **Merge** consolidates all deltas → updates `tags.csv`
4. **Devices** reload from master → see all changes

## Implementation Details

### Tag Toggle Logic

```swift
func toggleFlag(_ flag: ColorFlag, for photo: any PhotoItem) async {
    // Get identifier (icl# or md5#)
    guard let identifier = await getIdentifier(for: photo) else { return }
    
    // Update local state
    if var tag = tags[identifier] {
        if tag.flags.contains(flag) {
            tag.flags.remove(flag)
            // Write removal to delta
        } else {
            tag.flags.insert(flag)
            // Write addition to delta
        }
    }
    
    // Save and notify
    saveTags()
    NotificationCenter.default.post(name: .tagsChanged, ...)
}
```

### Cross-Platform Support

- **macOS**: Full keyboard support, inspector panel
- **iOS/iPadOS**: Touch-optimized, fixed photo access issues

## Migration from Bookmarks

The system was migrated from emoji-based bookmarks:
1. All "bookmark" references renamed to "tag"
2. Emoji strings replaced with ColorFlag enum
3. Storage format changed from emoji to numeric (1-7)
4. Added iCloud sync capability

## Future Enhancements

1. **UI Controls**: Add buttons for sync operations
2. **Auto-merge**: Periodic automatic delta merging
3. **Tag Filtering**: Show only photos with specific tags
4. **Bulk Operations**: Apply tags to multiple photos
5. **Tag Sets**: Save and apply tag combinations
6. **Export**: Generate reports of tagged photos

## Troubleshooting

### Tags Not Syncing

1. Check iCloud Documents is enabled in Settings
2. Ensure sufficient iCloud storage
3. Try manual sync: `syncFromICloud()`
4. Check for delta files in iCloud container

### Missing Tags

1. Tags are tied to photo content (MD5)
2. Edited photos get new IDs
3. Check both original and edited versions

### Performance

1. MD5 computation cached for efficiency
2. Initial tagging may be slow for large photos
3. Subsequent operations use cached values