# Photo Grouping Feature Design

## Overview

This document outlines the design for implementing photo grouping functionality in Photolala, allowing users to view their photos organized in sections (e.g., by year, month, or date).

## Phase 1 Approach (POC)

For the initial proof of concept, we're implementing a **simple file date-based grouping** system:

- **Only file modification dates** - No EXIF extraction
- **Instant performance** - Zero file I/O required
- **Perfect for network drives** - No performance concerns
- **Simple UI** - Just Year/Month/Day/None options

**Important Limitation**: File modification date is NOT the same as photo taken date:
- **Photo taken date**: When the camera captured the image (stored in EXIF)
- **File modification date**: When the file was last saved/edited/copied

This means:
- ✅ Works well for: Photos directly imported from camera (file date ≈ taken date)
- ❌ Misleading for: Edited photos, downloaded images, scanned photos, screenshots

**Why start with this approach?**
1. Validates the grouping UI/UX without performance concerns
2. Provides immediate value for users with camera-imported photos
3. Allows testing the section-based layout system
4. Creates foundation for adding proper photo dates later

## Key Design Questions

1. **Section Headers**:
   - How should section headers look?
   - Should they be sticky while scrolling?
   - What information to display (title, count, date range)?

2. **Grouping Controls**:
   - Where in the UI should grouping controls be placed?
   - Should it be a toggle or always-on with "None" option?
   - How to indicate current grouping mode?

3. **Performance Considerations**:
   - Should we group all photos upfront or lazily?
   - How to handle thousands of photos efficiently?
   - Cache grouped results?

4. **Interaction with Other Features**:
   - How does grouping work with sorting?
   - What happens to selection across groups?
   - How does search/filtering work with groups?

5. **Visual Design**:
   - Should groups have visual separation?
   - Different background for sections?
   - How to handle empty groups?

## Requirements

1. **Group photos by time periods**:
   - Year (e.g., "2024", "2023")
   - Month (e.g., "January 2024", "December 2023")
   - Day (e.g., "June 15, 2024")

2. **Section headers**:
   - Display group name prominently
   - Show photo count per section
   - Sticky headers while scrolling

3. **Toggle grouping**:
   - Enable/disable grouping
   - Switch between grouping modes

4. **Performance**:
   - Efficient grouping of large photo collections
   - Maintain smooth scrolling

## UI Design

### Toolbar Controls
Add grouping controls to the toolbar with a simple menu structure:

**Phase 1 Menu Structure (POC):**
```
Group by: [Current Selection ▼]
├─ Year
├─ Month
├─ Day
├─ ─────────────────
└─ None
```

Simple and clean - all grouping uses file modification dates for instant performance.

### Section Headers
Visual design for section headers:
```
┌─────────────────────────────────────┐
│ 2024                          (125) │  <- Year with photo count
├─────────────────────────────────────┤
│ [Photo thumbnails in grid]          │
└─────────────────────────────────────┘
```

### Grouping Examples

**Year Grouping:**
```
2024 (487 photos)
├── IMG_1234.jpg (Dec 2024)
├── IMG_1233.jpg (Nov 2024)
└── IMG_0001.jpg (Jan 2024)

2023 (892 photos)
├── IMG_9999.jpg (Dec 2023)
└── IMG_8000.jpg (Jan 2023)
```

**Month Grouping:**
```
December 2024 (45 photos)
├── IMG_1234.jpg
└── IMG_1230.jpg

November 2024 (72 photos)
├── IMG_1200.jpg
└── IMG_1150.jpg

April 2023 (38 photos)  <- Different year!
├── IMG_0500.jpg
└── IMG_0480.jpg
```

**Day Grouping:**
```
December 15, 2024 (12 photos)
├── IMG_1234.jpg
└── IMG_1222.jpg

December 14, 2024 (8 photos)
├── IMG_1220.jpg
└── IMG_1210.jpg
```

## Implementation Plan

### 1. Data Model Updates

#### Add GroupingOption enum (Phase 1 - Simple)
```swift
enum PhotoGroupingOption: String, CaseIterable {
    case none = "None"
    case year = "Year"
    case month = "Month"
    case day = "Day"
    
    var systemImage: String {
        switch self {
        case .none: return "square.grid.3x3"
        case .year: return "calendar"
        case .month: return "calendar.badge.clock"
        case .day: return "calendar.circle"
        }
    }
}
```

#### Update ThumbnailDisplaySettings
```swift
@Observable
final class ThumbnailDisplaySettings {
    // Existing properties...
    var groupingOption: PhotoGroupingOption = .none
}
```

### 2. Photo Grouping Logic

#### Create PhotoGroup struct
```swift
struct PhotoGroup: Identifiable {
    let id = UUID()
    let title: String
    let photos: [PhotoReference]
    let date: Date // Representative date for sorting
}
```

#### Add grouping method to PhotoManager
```swift
extension PhotoManager {
    
    func groupPhotos(_ photos: [PhotoReference], by option: PhotoGroupingOption) -> [PhotoGroup] {
        guard option != .none else {
            // Single group with all photos
            return [PhotoGroup(title: "", photos: photos, date: Date())]
        }
        
        let calendar = Calendar.current
        let sortedPhotos = photos.sorted { ($0.modificationDate ?? Date()) > ($1.modificationDate ?? Date()) }
        
        switch option {
        case .year:
            let grouped = Dictionary(grouping: sortedPhotos) { photo in
                calendar.component(.year, from: photo.modificationDate ?? Date())
            }
            
            return grouped.map { year, photos in
                PhotoGroup(
                    title: "\(year)",
                    photos: photos,
                    date: calendar.date(from: DateComponents(year: year)) ?? Date()
                )
            }.sorted { $0.date > $1.date }
            
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"  // e.g., "April 2024"
            
            let grouped = Dictionary(grouping: sortedPhotos) { photo in
                let date = photo.modificationDate ?? Date()
                let components = calendar.dateComponents([.year, .month], from: date)
                return calendar.date(from: components) ?? date
            }
            
            return grouped.map { monthDate, photos in
                PhotoGroup(
                    title: formatter.string(from: monthDate),
                    photos: photos,
                    date: monthDate
                )
            }.sorted { $0.date > $1.date }
            
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"  // e.g., "April 15, 2024"
            
            let grouped = Dictionary(grouping: sortedPhotos) { photo in
                let date = photo.modificationDate ?? Date()
                let components = calendar.dateComponents([.year, .month, .day], from: date)
                return calendar.date(from: components) ?? date
            }
            
            return grouped.map { dayDate, photos in
                PhotoGroup(
                    title: formatter.string(from: dayDate),
                    photos: photos,
                    date: dayDate
                )
            }.sorted { $0.date > $1.date }
            
        default:
            return [PhotoGroup(title: "", photos: photos, date: Date())]
        }
    }
}
```

### 3. Collection View Updates

#### macOS - NSCollectionView with Sections
- Use `NSCollectionViewCompositionalLayout` for section support
- Implement section headers as supplementary views
- Register header view class

#### iOS - UICollectionView with Sections
- Already supports sections natively
- Update data source to use sections
- Implement section header views

### 4. UI Integration

#### Update PhotoBrowserView toolbar (Phase 1 - Simple)
```swift
// Add grouping controls
Menu {
    Button(action: { settings.groupingOption = .year }) {
        Label("Year", systemImage: "calendar")
    }
    Button(action: { settings.groupingOption = .month }) {
        Label("Month", systemImage: "calendar.badge.clock")
    }
    Button(action: { settings.groupingOption = .day }) {
        Label("Day", systemImage: "calendar.circle")
    }
    
    Divider()
    
    Button(action: { settings.groupingOption = .none }) {
        Label("None", systemImage: "square.grid.3x3")
    }
} label: {
    if settings.groupingOption != .none {
        Label(settings.groupingOption.rawValue, systemImage: settings.groupingOption.systemImage)
    } else {
        Image(systemName: "calendar")
    }
}
.help("Group photos by date")
```

## Technical Considerations

### Performance
1. **Lazy grouping**: Only group visible sections
2. **Cache groups**: Store grouped data to avoid recomputation
3. **Background processing**: Group large collections on background queue

### Date Handling - The Performance Challenge

**The Problem:**
- Extracting EXIF dates from thousands of photos is very slow
- Network drives make this even worse (each file access is a network request)
- Users expect immediate grouping when they click the button

**Proposed Solution: Progressive Enhancement**

```swift
enum PhotoDateSource {
    case filesystem     // Fast, immediate
    case cached        // Fast, from our cache
    case exif          // Slow, most accurate
}
```

**Phase 1: Immediate Filesystem Grouping**
- Use file modification date (already available, no I/O)
- Group photos instantly
- Show UI immediately

**Phase 2: Background EXIF Enhancement**
- Scan EXIF data in background
- Update groups as real dates are found
- Cache the extracted dates

**Phase 3: Smart Caching**
```swift
// Cache structure per photo
struct PhotoDateCache {
    let fileIdentifier: String  // MD5 of path
    let photoDate: Date?       // Renamed from exifDate for clarity
    let fileModDate: Date
    let lastScanned: Date
}
```

**User Experience:**
1. User clicks "Group by Year"
2. Photos immediately group by file date
3. Background process starts extracting EXIF
4. Groups smoothly update as real dates are found
5. Next time, uses cached dates (instant)

**Performance Strategies:**
- **Prioritize visible photos**: Extract EXIF for currently visible items first
- **Batch processing**: Process 10-20 photos at a time
- **Network awareness**: Detect network drives and adjust batch size
- **Progressive loading**: Show progress indicator "Refining dates... 45%"

### Sorting
1. **Within groups**: Maintain current sort option
2. **Group order**: Always chronological (newest first)

## Platform Differences

### macOS
- Compositional layout for sections
- Sticky section headers
- Hover effects on headers

### iOS
- Native section support
- Collapsible sections (future)
- Touch-friendly headers

## Future Enhancements

1. **Custom grouping**:
   - By location
   - By camera/device
   - By file type

2. **Section actions**:
   - Collapse/expand sections
   - Select all in section
   - Export section

3. **Smart groups**:
   - Favorites
   - Recently added
   - Edited photos

## Implementation Approach for Performance

### Option 1: Simple File Date Grouping (Recommended for MVP)
**Pros:**
- Instant grouping (no file I/O)
- Works reliably on all systems
- Simple to implement
- Good enough for many users

**Cons:**
- Not the "true" photo date
- May group incorrectly for imported photos

### Option 2: Progressive Enhancement
**Pros:**
- Best of both worlds
- Instant UI response
- Eventually accurate

**Cons:**
- Complex implementation
- UI updates might be confusing
- Need to manage background tasks

### Option 3: Lazy EXIF Loading
**Pros:**
- Only load what's needed
- More efficient than full scan

**Cons:**
- Groups might "jump around" as dates load
- Still slow for initial view

### Alternative Date Sources to Consider

1. **File Creation Date** (Better than modification date?)
   - Sometimes preserves original photo date better
   - But unreliable when copying between file systems
   - Still not the actual photo taken date

2. **Filename Parsing** (Many cameras use date in filename)
   - Example: `IMG_20240615_142035.jpg`
   - Fast to extract (no file I/O)
   - But not all photos follow this pattern

3. **Hybrid Approach for Phase 1**
   - Try filename parsing first (instant)
   - Fall back to file modification date
   - Still avoids EXIF extraction

4. **Progressive Enhancement Path**
   - Phase 1: File dates (instant but inaccurate)
   - Phase 2: Add filename parsing (still instant, more accurate)
   - Phase 3: Add EXIF support (slow but accurate)

### Recommended Approach for Phase 1:
1. **Start with file dates only** (acknowledge the limitation)
2. **Clearly label as "File Date" in UI** so users understand
3. **Consider filename parsing in Phase 1.5** if many photos use date patterns
4. **Add proper EXIF dates later** with caching and performance warnings

## Implementation Phases

### Phase 1: File Date Grouping POC
1. Add simple PhotoGroupingOption enum (none/year/month/day)
2. Update ThumbnailDisplaySettings with groupingOption property
3. Implement grouping logic using file modification dates only
4. Update collection views to support sections
5. Add toolbar menu with simple options
6. Test performance with large photo collections

### Phase 2: UI Polish and Refinement
1. Add sticky section headers
2. Show photo counts in section headers
3. Smooth animations when changing grouping
4. Remember grouping preference per folder
5. Optimize section layout performance

### Phase 3: Future Enhancements (After POC Success)
1. Consider EXIF date support (with performance warnings)
2. Add date caching system
3. Custom grouping options (camera, location)
4. Collapsible sections
5. Section batch operations

## Success Criteria

1. Photos grouped correctly by selected time period
2. Section headers clearly visible
3. No performance degradation
4. Intuitive UI controls
5. Consistent behavior across platforms

## Implementation Challenges

### 1. Collection View Architecture
- **NSCollectionView** (macOS) has limited section support
- Need to use **NSCollectionViewCompositionalLayout** for proper sections
- Alternative: Simulate sections with custom layout

### 2. Data Source Management
- Need to transform flat photo array into sectioned data
- Keep track of section indices for navigation
- Update sections when photos change

### 3. Selection Handling
- Current selection is index-based
- With sections, need (section, item) index paths
- Multi-selection across sections

### 4. Performance
- Grouping 10,000+ photos could be slow
- Date extraction from files is I/O heavy
- Need background processing

## Open Questions

1. **UI/UX Questions**:
   - Should we remember grouping preference per folder?
   - Should sections be collapsible?
   - What's the minimum photos for a group (hide small groups)?
   - How to show "ungrouped" photos (no date)?

2. **Technical Questions**:
   - Use compositional layout or custom implementation?
   - Cache grouping results to disk?
   - How to handle date extraction efficiently?

3. **Feature Scope**:
   - Start with just year grouping?
   - Add month/day later?
   - Custom grouping in future (by camera, location)?