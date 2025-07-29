# Photo ID System - Cross-Device Identification

## Overview

This document outlines the design for a unified photo identification system that enables consistent photo tracking across macOS and iOS devices. The system will allow users to maintain tags and other metadata synchronized across their devices.

### Terminology Change: Bookmarks → Tags

We are changing from "bookmarks" to "tags" throughout the application to:
- Match macOS Finder's official terminology
- Provide a more familiar user experience
- Simplify the mental model (users already understand tags from Finder)
- Better represent the feature (multiple colored tags per photo)

### Why MD5 Hash is the Ideal Solution

MD5 hash provides a beautiful, unified way to identify photos because:
- **Universal**: Works identically for Photos Library, local files, and cloud storage
- **Content-based**: Automatically handles edited photos (new content = new hash)
- **Cross-device**: Same photo always produces same hash on any device
- **Version-specific**: Each edit is treated as a unique photo
- **Simple**: No complex logic for `localIdentifier` + `modificationDate` combinations

## Final Design

### Photo ID Format
- **iCloud Photos**: `icl#{cloudIdentifier}` (no hash needed)
- **Everything else**: `md5#{hash}` (computed and cached)
  - Local Apple Photos (non-iCloud)
  - Local files 
  - S3 cloud storage

### MD5 Cache
- Key: `{identifier}:{modification-unix}`
- Value: MD5 hash
- Only cache stable identifiers (PHAsset, S3)
- Local files always compute fresh (unstable paths)

### Tag Storage (iCloud Documents)

**Master file**: `tags.csv`
```csv
icl#SUNSET-123,1:4:5,1704067600
md5#abc123def,3:7,1704067700
```

**Delta files**: `tags-delta-{deviceID}.csv`
```csv
+,icl#SUNSET-123,1,1704067200,Mac-Bob
-,icl#SUNSET-123,1,1704067400,iPad-Bob
```

### Color Tag System
- Replaced emoji bookmarks with number-based tags
- Tags: 1=red, 2=orange, 3=yellow, 4=green, 5=blue, 6=purple, 7=gray
- Multiple tags per photo: `1:4:5` = red, green, blue
- Extensible for future tags (8, 9, 10...)

## Implementation Details

### Photo ID Generation

```swift
func getPhotoID(for asset: PHAsset) async -> String {
    // 1. iCloud Photos - instant, no computation
    if let cloudID = asset.cloudIdentifier {
        return "icl#\(cloudID)"
    }
    
    // 2. Non-iCloud - check cache first
    let modUnix = Int(asset.modificationDate?.timeIntervalSince1970 ?? 0)
    let cacheKey = "\(asset.localIdentifier):\(modUnix)"
    
    if let cached = await cache.md5Hash(for: cacheKey) {
        return "md5#\(cached)"
    }
    
    // 3. Compute and cache
    let md5Hash = await computeMD5(for: asset)
    await cache.store(md5Hash: md5Hash, for: cacheKey)
    return "md5#\(md5Hash)"
}
```

### Master + Delta Sync Architecture

```
iCloud Documents/
├── tags.csv                    # Master (merged state)
├── tags-delta-Mac-Bob.csv      # Mac's pending changes
├── tags-delta-iPhone-Bob.csv   # iPhone's pending changes
└── tags-delta-iPad-Bob.csv     # iPad's pending changes
```

**Sync Process**:
1. Each device writes to its own delta file
2. No conflicts during normal operation
3. Periodic merge (hourly or on-demand):
   - Read all delta files
   - Apply operations in timestamp order
   - Write new master
   - Delete delta files
4. Each device reloads from new master

### Data Models

```swift
// MD5 cache for performance
@Model
class MD5Cache {
    let cacheKey: String    // "{identifier}:{modification-unix}"
    let md5Hash: String     // Computed MD5 hash
    let computedDate: Date
}

// CSV parsing structures
struct TagEntry {
    let photoID: String     // icl#... or md5#...
    let tags: Set<Int>      // 1-7 for color tags
    let timestamp: TimeInterval
}

struct DeltaOperation {
    let operation: String   // "+" or "-"
    let photoID: String
    let tag: Int
    let timestamp: TimeInterval
    let deviceID: String
}
```

### Conflict Resolution

**No conflicts in normal operation** - each device writes to its own delta file.

**During merge**:
1. Apply all operations in timestamp order
2. Last operation wins for same photo/tag combo
3. Example:
   - 10:00 Mac adds red to SUNSET
   - 10:05 iPad removes red from SUNSET
   - Result: SUNSET has no red tag

**File conflicts** (if iCloud creates duplicates):
- Merge all `tags-delta-*.csv` files
- Merge all `tags (conflicted).csv` files
- Apply operations by timestamp

## Implementation Plan

### Phase 1: New ID System (Ready to implement)
1. Add `icl#` prefix for iCloud photos
2. Keep `md5#` prefix for others
3. Implement MD5 cache with SwiftData
4. Update TagManager to use new IDs

### Phase 2: CSV Sync via iCloud Documents
1. Implement master + delta file structure
2. Add merge logic
3. File watching for auto-reload
4. Test multi-device scenarios

## Key Decisions Made

1. **Photo IDs**: `icl#` for iCloud photos, `md5#` for everything else
2. **Sync Storage**: iCloud Documents with CSV (not CloudKit)
3. **Conflict Resolution**: Master + delta pattern
4. **Tags**: Color tags with numbers (1-7)
5. **No Migration**: App not released yet
6. **Performance**: Progressive hash computation with caching

## Summary

This system provides:
- Universal photo identification across devices
- Efficient sync using iCloud Documents
- No conflicts during normal operation
- Progressive enhancement (works immediately, improves over time)
- Simple CSV format for debugging and data portability

Ready for implementation!