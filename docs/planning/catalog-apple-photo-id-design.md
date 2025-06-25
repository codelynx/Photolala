# Apple Photo ID Integration in Catalog CSV

## Overview

This document outlines the design for adding Apple Photo IDs to the catalog CSV format, enabling efficient mapping between MD5 hashes and Apple Photo IDs for improved performance and reliability.

**Current Status**: The catalog system uses version 5.0 with a 16-shard CSV structure. Apple Photo IDs exist in the `ApplePhotosBridge` MD5 cache but are not persisted in catalogs.

## Problem Statement

Currently, when working with Apple Photos:
1. We compute MD5 hashes from original photo data
2. No persistent mapping exists between MD5 and Apple Photo IDs
3. Each session requires re-computation or re-mapping

## Proposed Solution

### Enhanced CSV Format

Current format (v5.0):
```csv
md5,filename,size,photodate,modified,width,height
```

Proposed format with Apple Photo ID:
```csv
md5,filename,size,photodate,modified,width,height,applephotoid
3a1b2c3d4e5f6789,IMG_1234.jpg,1024000,1701234567,1701234567,4000,3000,A1B2C3D4-E5F6-7890-ABCD-EF1234567890
4b2c3d4e5f67890a,IMG_1235.jpg,2048000,1701234568,1701234568,4000,3000,B2C3D4E5-F678-9012-BCDE-F23456789012
5c3d4e5f6789012b,DSC_0001.jpg,1536000,1701234569,1701234569,3000,2000,
```

Note: The `applephotoid` field would be empty for non-Apple Photos.

### Implementation Flow

1. **During Catalog Generation**:
   - When processing Apple Photos, retrieve the Apple Photo ID
   - Compute MD5 from original photo data
   - Store both in catalog entry
   - For non-Apple Photos, leave `applephotoid` empty

2. **Catalog Upload**:
   - Upload enhanced catalog with Apple Photo ID mappings
   - S3 catalog becomes authoritative source for MD5↔Apple Photo ID mapping

3. **Client Usage**:
   - Download and cache catalog locally
   - Use cached mapping for quick Apple Photo lookups
   - No need to recompute MD5s for known photos

## Benefits

1. **Performance**: Direct Apple Photo ID lookup without MD5 computation
2. **Reliability**: Persistent mapping survives app restarts
3. **Efficiency**: Reduced CPU usage on repeated access
4. **Compatibility**: Backward compatible (empty field for non-Apple photos)

## Technical Details

### CSV Format Changes

```swift
struct CatalogEntry {
    let md5: String
    let filename: String
    let size: Int64
    let photoDate: Date
    let modificationDate: Date
    let width: Int?
    let height: Int?
    let applePhotoID: String? // New field
}
```

### Parsing Logic

```swift
// Reading catalog (handling both v5.0 and v5.1 formats)
let components = parseCSVLine(line) // Handles proper CSV escaping
let applePhotoID: String? = {
    if components.count > 7 && !components[7].isEmpty {
        return components[7]
    }
    return nil
}()

// Writing catalog v5.1
let csvLine = formatCSVLine([
    md5,
    filename,
    String(size),
    String(Int(photoDate.timeIntervalSince1970)),
    String(Int(modificationDate.timeIntervalSince1970)),
    width.map(String.init) ?? "",
    height.map(String.init) ?? "",
    applePhotoID ?? ""
])
```

### Cache Structure

```swift
class CatalogCache {
    // Existing mappings
    private var md5ToEntry: [String: CatalogEntry] = [:]
    
    // New mapping
    private var applePhotoIDToMD5: [String: String] = [:]
    
    func loadCatalog(_ entries: [CatalogEntry]) {
        for entry in entries {
            md5ToEntry[entry.md5] = entry
            if let appleID = entry.applePhotoID {
                applePhotoIDToMD5[appleID] = entry.md5
            }
        }
    }
}
```

## Migration Strategy

1. **Phase 1**: Update catalog format to support optional `applephotoid`
   - Bump catalog version to "5.1" in manifest.plist
   - Maintain backward compatibility (v5.0 readers ignore extra field)
   
2. **Phase 2**: Implement Apple Photo ID retrieval during backup
   - Use existing `ApplePhotosBridge` MD5-to-photoID mappings
   - Store Apple Photo ID (`PHAsset.localIdentifier`) in catalog
   
3. **Phase 3**: Update catalog parser to handle new format
   - Support both v5.0 (7 fields) and v5.1 (8 fields) formats
   - Gracefully handle missing Apple Photo ID field
   
4. **Phase 4**: Implement cache with dual lookup capability
   - Extend existing `CatalogCache` with Apple Photo ID indexing
   - Fall back to MD5 lookup when Apple Photo ID missing

## Considerations

1. **Privacy**: Apple Photo IDs are device-specific identifiers
2. **Portability**: IDs may not be consistent across devices
3. **Versioning**: Need to handle both old and new catalog formats
4. **Storage**: Minimal increase in catalog size (~36 chars per Apple Photo)
5. **Existing Infrastructure**: Leverage existing MD5-to-photoID cache in UserDefaults
6. **Catalog Sharding**: Maintain 16-shard structure (0.csv through f.csv)
7. **Manifest Updates**: Update manifest.plist version to "5.1"

## Future Enhancements

1. Add other platform-specific IDs (Google Photos, etc.)
2. Include additional metadata (album membership, favorites)
3. Support for incremental catalog updates with ID mappings