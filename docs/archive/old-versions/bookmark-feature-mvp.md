# Bookmark Feature - MVP (Minimum Viable Product)

**Created**: June 24, 2025  
**Status**: Planning - Simplified Approach

## Core Concept

Simple bookmarks that let users mark photos with an emoji, title, and memo. Bookmarks are tied to photo MD5 hashes and sync via iCloud.

## MVP Data Model

```swift
struct PhotoBookmark: Codable {
    let md5: String        // Photo identifier
    let emoji: String      // Single emoji (e.g., "⭐", "❤️", "📷")
    let title: String      // Short title (max 50 chars)
    let memo: String?      // Optional memo (max 200 chars)
    let createdDate: Date
    let deviceName: String // Which device created it
}
```

## Storage Strategy - Keep It Simple

### Use iCloud Key-Value Store
- Simple to implement
- Automatic sync
- No complex setup
- Good enough for thousands of bookmarks

```swift
class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()
    private let store = NSUbiquitousKeyValueStore.default
    
    @Published var bookmarks: [String: PhotoBookmark] = [:] // MD5 -> Bookmark
    
    init() {
        loadBookmarks()
        
        // Listen for iCloud changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
    }
    
    func bookmark(photo: any PhotoItem, emoji: String, title: String, memo: String? = nil) {
        guard let md5 = photo.md5Hash else { return }
        
        let bookmark = PhotoBookmark(
            md5: md5,
            emoji: emoji,
            title: title,
            memo: memo,
            createdDate: Date(),
            deviceName: Host.current().localizedName ?? "Unknown"
        )
        
        bookmarks[md5] = bookmark
        saveBookmark(bookmark)
    }
    
    private func saveBookmark(_ bookmark: PhotoBookmark) {
        // Save individual bookmark to iCloud KV store
        let key = "bookmark.\(bookmark.md5)"
        if let data = try? JSONEncoder().encode(bookmark) {
            store.set(data, forKey: key)
        }
    }
}
```

## User Interface - Minimal

### 1. In Inspector View
```
Photo Details
────────────
[Bookmark Icon] Add Bookmark

When clicked, shows simple popover:

┌─────────────────────┐
│ Bookmark This Photo │
├─────────────────────┤
│ Emoji: [😀] [Pick]  │
│ Title: [________]   │
│ Memo:  [________]   │
│                     │
│ [Cancel] [Save]     │
└─────────────────────┘
```

### 2. On Thumbnails
- Small emoji badge in corner if bookmarked
- No complex UI, just the emoji

### 3. Quick Access
- File → Show Bookmarked Photos (⌘B)
- Shows grid of only bookmarked photos
- Group by emoji if multiple bookmarks

## Implementation Steps

### Phase 1: Core (2-3 days)
1. Create `PhotoBookmark` model
2. Create `BookmarkManager` with local storage
3. Add bookmark button to Inspector
4. Show emoji on thumbnails

### Phase 2: iCloud Sync (1-2 days)
1. Enable iCloud capability
2. Switch to iCloud KV Store
3. Handle sync notifications
4. Test on multiple devices

### Phase 3: Browse Bookmarks (1-2 days)
1. Add "Show Bookmarked" menu item
2. Filter view to show only bookmarked
3. Group by emoji
4. Search by title/memo

## Emoji Picker

Keep it simple with common photo-related emojis:

```swift
let defaultEmojis = [
    "⭐", "❤️", "📷", "🌟", "✨",
    "🏆", "🎯", "🔥", "💎", "🌈",
    "🌅", "🌄", "🏔️", "🌊", "🌺"
]
```

## What We're NOT Doing (Yet)

1. **User Attribution**: Not tracking who bookmarked what
2. **Sharing**: No bookmark sharing between users
3. **Complex Labels**: Just emoji + title, no hierarchies
4. **Conflict Resolution**: Last write wins
5. **Export/Import**: Not in MVP
6. **Thumbnail Storage**: Just reference by MD5

## Benefits of This Approach

1. **Simple**: Can build in a week
2. **Useful**: Solves core problem immediately  
3. **Testable**: Easy to validate with users
4. **Expandable**: Can add features later
5. **Low Risk**: Uses proven Apple technologies

## Technical Notes

### iCloud KV Store Limits
- 1MB total storage
- 1024 keys maximum
- Each bookmark ~200 bytes
- Can store ~5000 bookmarks

### Key Format
```
bookmark.{md5} -> PhotoBookmark data
bookmark.index -> Array of all MD5s (optional)
```

### Sync Behavior
- Automatic background sync
- ~15 second delay typical
- Conflicts: Last write wins
- Works offline

## Future Expansion Ideas

Once MVP is working, we could add:
1. Multiple emojis per photo
2. Bookmark collections/sets
3. Share bookmarks via AirDrop
4. Export as photo album
5. Smart folders based on bookmarks
6. CloudKit for unlimited storage

## Success Criteria

1. User can bookmark any photo with emoji + title
2. Bookmarks sync between devices
3. Can filter to see only bookmarked photos
4. Performance: <100ms to check if bookmarked
5. Works offline

## Questions Resolved

1. **Who bookmarked?** - Track device name only (simple)
2. **User identity?** - Not needed for personal bookmarks
3. **Storage?** - iCloud KV Store (simple, automatic)
4. **UI?** - Minimal, just emoji badge + inspector button