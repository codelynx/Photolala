# Bookmark System

## Overview

Photolala includes a bookmark feature that allows users to mark photos with emojis. Each photo can have one emoji bookmark that persists across app launches and works with all photo types (local files, Apple Photos, and S3 photos).

## Architecture

### Components

1. **PhotoBookmark Model** (`Models/PhotoBookmark.swift`)
   - Simple struct containing MD5 hash, emoji, optional note, and modification date
   - Supports CSV serialization/deserialization

2. **BookmarkManager Service** (`Services/BookmarkManager.swift`)
   - Singleton service managing all bookmark operations
   - Stores bookmarks in CSV format for efficiency
   - Uses MD5-based identification for universal photo support

3. **UI Integration**
   - **InspectorView**: Bookmark section with emoji grid
   - **UnifiedPhotoCell**: Emoji badge display on thumbnails

### Storage

Bookmarks are stored in a CSV file:
- Location: `~/Library/Containers/com.electricwoods.photolala/Data/Library/Application Support/Photolala/bookmarks.csv`
- Format: `md5,emoji,note,modifiedDate`
- Example: `01b5f961daa96a5c9c3aecb6d8b0b63d,❤️,,1750799679`

### Available Emojis

The system provides 12 quick emojis:
- **Rating**: ⭐ ❤️ 👍 👎
- **Actions**: ✏️ 🗑️ 📤 🖨️
- **Status**: ✅ 🔴 📌 💡

## User Interface

### Inspector Panel
- Shows current bookmark status ("None" or the emoji)
- Grid of 12 emoji buttons for quick selection
- Clear button to remove bookmark
- Tap same emoji to toggle off, different emoji to change

### Thumbnail Badges
- Emoji displayed in top-right corner of photo thumbnails
- Semi-transparent black background for visibility
- 28pt size on macOS, 32pt on iOS

## Implementation Details

### MD5-Based Identification
- Photos identified by content hash, not file path
- Bookmarks survive file moves/renames
- Works consistently across all photo sources

### Performance
- Bookmarks loaded once at app startup
- In-memory dictionary for fast lookups
- Atomic writes to prevent data corruption

### Future Enhancements (Phase 2 & 3)
- Filter views by bookmark status
- Show photos by specific emoji
- iCloud sync across devices
- Multiple emojis per photo
- Named labels with emojis

## API Usage

```swift
// Set a bookmark
await BookmarkManager.shared.setBookmark(photo: photo, emoji: "⭐")

// Get bookmark for a photo
let bookmark = await BookmarkManager.shared.getBookmark(for: photo)

// Remove bookmark
await BookmarkManager.shared.setBookmark(photo: photo, emoji: nil)

// Get all photos with specific emoji
let md5s = BookmarkManager.shared.photosByEmoji("❤️")
```

## Testing

Test scripts are available:
- `scripts/test-bookmarks.swift` - Verify bookmark functionality
- `scripts/debug-bookmarks.swift` - Debug file locations and issues