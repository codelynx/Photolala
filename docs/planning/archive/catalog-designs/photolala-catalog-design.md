# .photolala Catalog File Design

## Overview

The `.photolala` file evolved from the original "footprint file" concept (CSV format for instant directory loading) into a comprehensive catalog system that bridges local directories and S3 backup storage.

## Evolution from Original Design

### Original Footprint File (Phase 1)
- **Format**: Simple CSV - `filename,size,modified,headerMD5,width,height`
- **Purpose**: Instant photo list without directory scanning
- **Location**: In each photo directory
- **Scope**: Local directory optimization only

### Enhanced Catalog File (Current)
- **Format**: JSON or binary format with full metadata
- **Purpose**: Bridge between local and cloud storage
- **Location**: Both local directories and S3
- **Scope**: Backup status, offline browsing, sync management

[KY] i prefer catalog file to be CSV, columb may be added and flexible enogh
[KY] i like plist binary for each photo metadata (compact and flexible enogh)

## File Placement Strategy

### For S3 Backup
```
s3://photolala/
├── catalog/
│   └── {userId}/
│       └── .photolala          # Master catalog for user's entire backup
├── photos/{userId}/
├── thumbnails/{userId}/
└── metadata/{userId}/
```

### For Local Directories
```
/Volumes/NetworkDrive/MyPhotos/
├── .photolala                  # Catalog for this directory tree
├── IMG_0129.jpg
├── IMG_0130.jpg
└── Vacation2024/
    └── DSC_0001.jpg
```

[KY]
+ MyPhotos/
  + .catalogs
    - vacation-2024.photolala (CSV)
	- graduation-2023.photolala (CSV)


## Catalog Format Options

### Option 1: CSV Format (Simplified - No Status Tracking)
```csv
# .photolala v2.0
filename,size,modified,md5,width,height,photodate
IMG_0129.jpg,2048576,1718445000,d41d8cd98f00b204e9800998ecf8427e,4032,3024,1718445000
IMG_0130.jpg,1843200,1718445060,e5f7a3b2c1d4e6f8a9b0c1d2e3f4a5b6,4032,3024,1718445060
DSC_0001.jpg,3145728,1719846120,f6g8b4c3d2e5f7g9b1c2d3e4f5g6h7i8,5472,3648,1719846120
```
Note: All timestamps are Unix time (seconds wise since epoch)

**Pros**:
- Human readable
- Easy to parse
- Grep-friendly
- Small file size
- Compatible with original design

**Cons**:
- Limited extensibility
- No nested data support

### Option 2: JSON Format (Structured & Extensible)
```json
{
  "version": "2.0",
  "created": "2025-01-17T12:00:00Z",
  "directory": "/Volumes/NetworkDrive/MyPhotos",
  "photos": [
    {
      "filename": "IMG_0129.jpg",
      "size": 2048576,
      "modified": "2024-06-15T10:30:00Z",
      "md5": "d41d8cd98f00b204e9800998ecf8427e",
      "width": 4032,
      "height": 3024,
      "photoDate": "2024-06-15T10:30:00Z",
      "backup": {
        "status": "backed-up",
        "storageClass": "STANDARD",
        "uploadDate": "2024-06-16T08:00:00Z"
      }
    }
  ]
}
```

[KY] we do need to maintain backup or class, undess for important necessecity

**Pros**:
- Extensible
- Structured data
- Industry standard
- Good tool support

**Cons**:
- Larger file size
- Slower to parse than CSV

### Option 3: Delta File Support (For Large Directories)

For directories with thousands of photos:
```
/Photos/
├── .photolala              # Base catalog (10K entries)
├── .photolala.delta.001    # Recent additions/changes
├── .photolala.delta.002    # More recent changes
└── IMG_9999.jpg
```

[KY] simply .photolala.001, .photolala.002
if more than .photolala.999 then something is very wrong

[KY] I came up with this idea

`.photolala` contains `.photolala.001`

when need delta create `.photolala.001.a` or `.photolala.001.b` (need to brush up)
then when time to merge create `photolala.002` from `.photolala.001` + `.photolala.001.a` + `.photolala.001.b`
then complete replace `.photolala` with `.photolala.002`

i think this idea still needs brush up, but potencial


Delta format (same CSV structure):
```csv
# .photolala.delta.001
filename,size,modified,md5,width,height,photodate
NEW_IMG.jpg,2048576,1718445000,a1b2c3d4e5f6...,4032,3024,1718445000
DELETED:OLD_IMG.jpg
```

[KY] I like `photodate` over `photoDate` in CSV

or we redesign `.photolala` format as

+-,filename,size,modified,md5,width,height,photodate
+,NEW_IMG.jpg,2048576,1718445000,a1b2c3d4e5f6...,4032,3024,1718445000
-,NEW_IMG.jpg,2048576,1718445000,a1b2c3d4e5f6...,4032,3024,1718445000

just like diff, better name for `+-`?

[KY] I don't like your and mine, let's discuss more

**Consolidation**: Merge deltas into base when:
- More than 10 delta files
- Total delta size > 20% of base
- User idle time detected

## Usage Scenarios

### 1. S3 Backup Browsing
```swift
class S3CatalogManager {
    func downloadCatalog() async throws -> PhotoCatalog {
        // Download from s3://photolala/catalog/{userId}/.photolala
        // Cache locally with timestamp
        // Use for offline browsing
    }

    func updateCatalog() async throws {
        // Incremental update based on S3 events
        // Or full rebuild periodically
    }
}
```

### 2. Local Directory Browsing
```swift
class LocalCatalogManager {
    func loadOrCreateCatalog(for directory: URL) -> PhotoCatalog {
        let catalogPath = directory.appendingPathComponent(".photolala")

        if let existing = try? PhotoCatalog(from: catalogPath) {
            return existing
        }

        // Scan directory and create catalog
        return createCatalog(for: directory)
    }
}
```

### 3. Backup Status Check (On-Demand)
```swift
extension PhotoReference {
    func isBackedUp(using s3Catalog: S3PhotoCatalog) -> Bool {
        // Simple MD5 lookup, no status tracking
        return s3Catalog.photosByMD5.contains(self.md5)
    }
}

[KY] how about, just preference notnecessity
return s3Catalog.photos.contains(self.md5)


// S3 catalog stores by MD5 for deduplication
struct S3PhotoCatalog {
    let photosByMD5: Set<Data>  // Just MD5s for quick lookup
    let details: [String: S3PhotoDetails]  // Full details when needed
}
```
[KY] changed some for proposal, I like to use MD5 binary where possible, unlessrequire for text representation

## Implementation Plan

### Phase 1: Local Footprint Files (Original Feature)
- Implement CSV format for `.photolala` files
- Add to DirectoryScanner for instant loading
- Generate on first scan, update incrementally
- Fields: filename, size, modified, md5, width, height

### Phase 2: Enhanced Catalog with Backup Status
- Extend CSV format with backup fields
- Add backup status checking via MD5 lookup
- Show badges in local photo browser
- Cache S3 catalog locally for status checks

### Phase 3: S3 Master Catalog
- Generate comprehensive catalog after backups
- Store in s3://photolala/catalog/{userId}/.photolala
- Support offline S3 browsing
- Periodic sync with local catalogs

### Phase 4: Full Integration
- Merge local and S3 catalog data
- Two-way sync status
- Conflict resolution
- Performance optimization for 100K+ photos

## Catalog Relationship Model

### Local Directory Catalog
- **Location**: `/path/to/photos/.photolala`
- **Scope**: Photos in that directory only
- **Updated**: On directory scan or photo changes
- **Purpose**: Fast loading + backup status display

### S3 Master Catalog
- **Location**: `s3://photolala/catalog/{userId}/.photolala`
- **Scope**: All backed-up photos for user
- **Updated**: After each backup operation
- **Purpose**: Offline S3 browsing + source of truth

### Sync Flow
```
Local/Remote Scan → Generate .photolala → Check against S3 catalog → Show backup status
     ↓                                           ↓
   Upload photos to S3 → Update S3 catalog → Sync back to local
```

## Benefits

1. **Instant Loading**: Original footprint file benefit preserved
2. **Offline Browsing**: Browse both local and S3 photos offline
3. **Fast Sync Status**: MD5-based lookup without S3 API calls
4. **Efficient Updates**: Incremental catalog updates
5. **Scalable**: CSV for local (fast), JSON for S3 (rich)

## Considerations

1. **Catalog Size**: CSV ~100 bytes/photo, JSON ~200 bytes/photo
2. **Update Frequency**: Local on-demand, S3 after backups
3. **Consistency**: MD5 as universal identifier
4. **Privacy**: Catalog reveals photo metadata
5. **Performance**: Parse 10K-line CSV in <100ms
