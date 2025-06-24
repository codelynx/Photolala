# Bookmark Feature - Implementation Specification

**Created**: June 24, 2025  
**Status**: Ready for Implementation
**Estimated Time**: 4-5 days

## Overview

A simple bookmark system where users mark photos with emojis. Each photo can have one emoji bookmark that syncs across devices via iCloud.

## Core Rules

1. **One emoji per photo** - Changing emoji replaces the previous one
2. **No label management** - Just emojis, no names or hierarchies  
3. **MD5-based** - Bookmarks tied to photo content, not file path
4. **Optional notes** - User can add a text note (not shown in MVP UI)
5. **iCloud sync** - Automatic sync across user's devices

## Data Model

```swift
struct PhotoBookmark: Equatable {
    let md5: String         // Photo content hash
    var emoji: String       // Single emoji character
    var note: String?       // Optional note (future UI)
    let modifiedDate: Date  // For sync conflict resolution
}
```

## File Format (CSV)

### Version 1.0
```csv
md5,emoji,note,modifiedDate
5d41402abc4b2a76b9719d911017c592,⭐,,1750762800
7d793037a0760186574b0282f2f435e7,❤️,Best sunset shot,1750764600
```

- Header row always included
- Note field empty if nil (not "null")
- Date as Unix timestamp (seconds since 1970)
- UTF-8 encoding for emoji support

### Future Version Examples

**Version 2.0** (Multiple emojis):
```csv
version,md5,emojis,note,modifiedDate
2.0,5d41402abc4b2a76b9719d911017c592,⭐❤️,,1750762800
```

**Version 3.0** (With labels):
```csv
version,md5,emoji,label,note,modifiedDate,createdDate
3.0,5d41402abc4b2a76b9719d911017c592,⭐,Portfolio,Best shot,1750762800,1750762000
```

### Version Detection & Migration
```swift
extension BookmarkManager {
    private func detectCSVVersion(_ csvString: String) -> String {
        let firstLine = csvString.components(separatedBy: "\n").first ?? ""
        if firstLine.starts(with: "version,") {
            // v2.0+ has version in header
            return csvString.components(separatedBy: ",").first ?? "1.0"
        } else if firstLine == "md5,emoji,note,modifiedDate" {
            // v1.0 has specific header
            return "1.0"
        }
        return "unknown"
    }
    
    private func migrateIfNeeded(_ csvString: String) -> String {
        let version = detectCSVVersion(csvString)
        switch version {
        case "1.0": return csvString // Current version
        case "2.0": return migrateV2ToV1(csvString) // Downgrade if needed
        default: return csvString
        }
    }
}
```

## Emoji Set (Choose One)

```swift
// Option A: Simplified set (12 emojis) - RECOMMENDED
let quickEmojis = [
    "⭐", "❤️", "👍", "👎",  // Rating
    "✏️", "🗑️", "📤", "🖨️",  // Actions  
    "✅", "🔴", "📌", "💡"   // Status
]

// Option B: Extended set (16 emojis)
let quickEmojis = [
    "⭐", "❤️", "👍", "👎",
    "✏️", "🗑️", "📤", "🖨️",
    "👨‍👩‍👧‍👦", "🌄", "🐾", "🎉",
    "✅", "🔴", "📌", "💡"
]
```

## BookmarkManager API

```swift
@MainActor
class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()
    
    @Published private(set) var bookmarks: [String: PhotoBookmark] = [:]
    
    // Core API
    func setBookmark(photo: any PhotoItem, emoji: String?) async
    func getBookmark(for photo: any PhotoItem) -> PhotoBookmark?
    func isBookmarked(_ photo: any PhotoItem) -> Bool
    func bookmarksCount() -> Int
    func photosByEmoji(_ emoji: String) -> [String] // Returns MD5s
    
    // CSV Persistence
    private func saveToCSV()
    private func loadFromCSV()
    private func escapeCSVField(_ field: String?) -> String
    
    // iCloud
    private func startMonitoring()
    private func handleiCloudChange()
}

// CSV Helper Example
extension BookmarkManager {
    private func saveToCSV() {
        var csv = "md5,emoji,note,modifiedDate\n"
        for bookmark in bookmarks.values.sorted(by: { $0.md5 < $1.md5 }) {
            let note = escapeCSVField(bookmark.note)
            let timestamp = Int(bookmark.modifiedDate.timeIntervalSince1970)
            csv += "\(bookmark.md5),\(bookmark.emoji),\(note),\(timestamp)\n"
        }
        // Write to file...
    }
}
```

## User Interface

### Inspector Integration

```
Photo Details
─────────────
[... existing content ...]

Bookmark
────────
Current: ⭐ (or "None")

[⭐][❤️][👍][👎]
[✏️][🗑️][📤][🖨️]  
[✅][🔴][📌][💡]

[Clear]
```

**Behavior:**
- Tap emoji → Set bookmark (instant)
- Tap current emoji → Remove bookmark
- Tap different emoji → Replace bookmark
- Tap Clear → Remove bookmark
- Visual feedback on tap (brief highlight)

### Thumbnail Badge

```
┌─────────┐
│ Photo   │ ⭐  <- Small badge
│         │
└─────────┘
```

**Position:** Top-right corner
**Size:** 16pt on macOS, 20pt on iOS
**Background:** Semi-transparent black circle
**Visibility:** Only if bookmarked

### Menu Items

```
View
├── Show All Photos
├── Show Bookmarked     ⌘B
├── Show by Emoji      ►
│   ├── ⭐ (3)
│   ├── ❤️ (12)
│   └── ✏️ (5)
└── ...
```

## Implementation Phases

### Phase 1: Local Storage (2 days)
- [ ] Create `PhotoBookmark` model
- [ ] Implement `BookmarkManager` with local storage
- [ ] Add bookmark section to `InspectorView`
- [ ] Show emoji badges on `UnifiedPhotoCell`
- [ ] Save to `~/Library/Application Support/Photolala/bookmarks.csv`

### Phase 2: Filtering (1 day)
- [ ] Add "Show Bookmarked" menu command
- [ ] Add "Show by Emoji" submenu
- [ ] Update `PhotoProvider` protocol for filtering
- [ ] Implement filtered views

### Phase 3: iCloud Sync (1-2 days)
- [ ] Enable iCloud capability
- [ ] Move storage to iCloud Documents
- [ ] Implement `NSMetadataQuery` monitoring
- [ ] Handle sync conflicts (last write wins)
- [ ] Add offline fallback

## Technical Decisions

### Naming Conventions
- **App Name**: Photolala (capital P)
- **Bundle ID**: com.electricwoods.photolala (lowercase, can't change)
- **S3 Bucket**: photolala (lowercase, AWS requirement)
- **iCloud Container**: iCloud.com.electricwoods.photolala (lowercase, matches bundle ID)

### Why MD5?
- Photos keep bookmarks even if moved/renamed
- Works across local files, Apple Photos, and S3
- Natural deduplication
- Consistent with existing PhotoManager

### Why Single Emoji?
- Simplest possible UX
- No management overhead
- Can extend to multiple later
- Covers 90% of use cases

### Why CSV?
- Much smaller than JSON (30-50% size reduction)
- Simple structure fits perfectly
- Still human readable
- Fast parsing
- Standard format

### Why iCloud Documents?
- Automatic sync
- No size limits (within reason)
- Works offline
- Handles CSV files perfectly

### Conflict Resolution
- Last write wins (based on modifiedDate)
- No merge logic in v1
- User's most recent action takes precedence

## Edge Cases & Behaviors

1. **Photo without MD5**: Cannot be bookmarked (ignore)
2. **Deleted photo**: Bookmark remains (cleanup in v2)
3. **No iCloud**: Fall back to local storage
4. **Sync conflict**: Latest modifiedDate wins
5. **Invalid emoji**: Validation on input (emoji only)
6. **Large bookmark count**: No practical limit

## Not in v1 (Future)

### v1.1 - Quick Improvements
- Note editing UI
- Keyboard shortcuts (1-9 for emojis)
- Cleanup orphaned bookmarks command
- Bookmark count in status bar

### v2.0 - Multiple Emojis
- Multiple emojis per photo
- CSV format with `emojis` field
- Backward compatible reading
- UI for adding/removing individual emojis

### v3.0 - Full Labels
- Named labels with emojis
- Label management UI
- Hierarchical labels
- CSV format with label names

### Other Future Ideas
- Bookmark export/import
- Custom emoji sets
- Smart collections
- Sharing bookmarks
- Bookmark history/undo

## Success Metrics

- User can bookmark/unbookmark in < 1 second
- Bookmarks sync across devices in < 30 seconds
- Filter views update instantly
- No data loss on sync conflicts
- Works offline

## File Organization

```
Photolala/
├── Models/
│   └── PhotoBookmark.swift
├── Services/
│   └── BookmarkManager.swift
├── Views/
│   └── InspectorView+Bookmarks.swift
└── Extensions/
    └── UnifiedPhotoCell+Bookmark.swift
```

## Summary

This specification provides a minimal but complete bookmark system that:
- Solves the core user need (mark photos)
- Leverages unique MD5 approach
- Ships quickly (under a week)
- Has clear expansion path
- Matches Photolala's simplicity