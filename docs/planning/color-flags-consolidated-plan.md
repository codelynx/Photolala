# Color Flags Feature - Consolidated Plan

## Overview

Replace the current single emoji bookmark system with Finder-style color flags, allowing multiple flags per photo for flexible organization.

## Core Design

### Data Model
```swift
struct PhotoBookmark: Codable {
    let photoIdentifier: String
    let flags: Set<ColorFlag>  // Multiple flags per photo
}

enum ColorFlag: String, Codable, CaseIterable {
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case gray = "gray"
    
    var color: XColor {
        switch self {
        case .red: return .systemRed
        case .orange: return .systemOrange
        case .yellow: return .systemYellow
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        case .gray: return .systemGray
        }
    }
    
    @ViewBuilder
    var flagView: some View {
        Image(systemName: "flag.fill")
            .foregroundColor(Color(color))
            .font(.system(size: 10))
    }
}
```

### Storage Format
```json
{
    "photoIdentifier": "md5#abc123",
    "flags": ["red", "blue", "green"]
}
```
- Store in existing `bookmarks.json` file
- JSON array format for Set<ColorFlag>
- Alternative: CSV string `"red,blue,green"` also possible

## UI Implementation

### Display
- Use SF Symbol `flag.fill` for flag icons
- Show flags after star indicator: `[Photo] ⭐ 🚩🚩🚩`
- When space limited: clip flags (no "more" indicator)
- Consistent order: red → orange → yellow → green → blue → purple → gray
- Flag size: 10pt with 2pt spacing

### Keyboard Shortcuts
- `1` = Red flag
- `2` = Orange flag
- `3` = Yellow flag
- `4` = Green flag
- `5` = Blue flag
- `6` = Purple flag
- `7` = Gray flag
- `0` = Clear all flags
- `S` = Star (unchanged, for backup queue)

### Context Menu
```
Flag Photo >
  ✓ Red (1)
    Orange (2)
    Yellow (3)
  ✓ Green (4)
    Blue (5)
    Purple (6)
    Gray (7)
  ─────────
    Clear All Flags
```

## Implementation Details

### Files to Update
1. `PhotoBookmark.swift` - Change from single bookmark to Set<ColorFlag>
2. `BookmarkManager.swift` - Update CRUD operations for sets
3. `UnifiedPhotoCell.swift` - Display flags instead of emoji
4. `PhotolalaCommands.swift` - Update keyboard shortcuts
5. `PhotoDetailView.swift` - Update context menus

### Code Changes

#### PhotoBookmark Model
```swift
import Foundation

struct PhotoBookmark: Codable, Identifiable {
    let photoIdentifier: String
    var flags: Set<ColorFlag>
    
    var id: String { photoIdentifier }
    
    init(photoIdentifier: String, flags: Set<ColorFlag> = []) {
        self.photoIdentifier = photoIdentifier
        self.flags = flags
    }
}
```

#### BookmarkManager Updates
```swift
// Toggle a flag
func toggleFlag(_ flag: ColorFlag, for identifier: String) {
    if var bookmark = getBookmark(for: identifier) {
        if bookmark.flags.contains(flag) {
            bookmark.flags.remove(flag)
        } else {
            bookmark.flags.insert(flag)
        }
        updateBookmark(bookmark)
    } else {
        let bookmark = PhotoBookmark(photoIdentifier: identifier, flags: [flag])
        addBookmark(bookmark)
    }
}

// Clear all flags
func clearFlags(for identifier: String) {
    removeBookmark(for: identifier)
}
```

#### UI Display in Cell
```swift
// In UnifiedPhotoCell
HStack(spacing: 2) {
    if photo.isStarred {
        Text("⭐")
            .font(.system(size: 12))
    }
    
    ForEach(sortedFlags, id: \.self) { flag in
        flag.flagView
    }
}
.frame(maxWidth: cellSize.width - 8, alignment: .trailing)
.clipped()  // Clip when too many flags
```

## Key Decisions

1. **No Migration Needed** - Pre-release, so we can change directly
2. **Clip on Overflow** - No "more" indicator when flags don't fit
3. **Keep Star Separate** - Star (⭐) remains for backup queue only
4. **User-Defined Meanings** - No built-in meanings for colors
5. **JSON Storage** - Continue using JSON, not switching to CSV
6. **Set Data Structure** - Efficient operations, no duplicates

## Performance Considerations

- Set operations are O(1) for add/remove/contains
- Index bookmarks by photoIdentifier for fast lookup
- Consider future bitfield optimization (7 flags = 7 bits)
- Batch operations for multiple selections

## Testing Scenarios

1. Toggle individual flags
2. Clear all flags
3. Multiple flags on one photo
4. Large selections (100+ photos)
5. Keyboard shortcut responsiveness
6. UI clipping behavior
7. JSON file size with many flagged photos

## Future Enhancements (Not in MVP)

1. **Flag-Based Filtering**
   - Show only photos with specific flags
   - AND/OR logic for complex filters

2. **Virtual Albums**
   - Create temporary albums from flag combinations
   - Smart folders that update automatically

3. **Batch Operations**
   - Apply flags to entire selection
   - Remove specific flag from all photos

4. **Flag Presets**
   - Save common flag combinations
   - Quick apply workflow flags

## Example User Workflows

### Photography Workflow
- Red = Needs editing
- Orange = In progress
- Yellow = Review with client
- Green = Client approved
- Blue = Personal favorite
- Purple = Print candidate
- Gray = Maybe delete

### Project Organization
- Red = Urgent
- Orange = This week
- Yellow = Next week
- Green = Completed
- Blue = Reference
- Purple = Archive
- Gray = Low priority

## Implementation Timeline

1. **Phase 1** (Current)
   - Update data model
   - Implement basic flag toggle
   - Replace emoji UI with flags

2. **Phase 2**
   - Batch operations
   - Basic filtering

3. **Phase 3** (Future)
   - Virtual albums
   - Smart folders
   - Advanced filtering

## Success Criteria

- Clean, simple UI with colored flags
- Fast flag toggling via keyboard
- No performance degradation
- Intuitive user experience
- Room for future enhancements