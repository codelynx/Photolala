# .photolala Catalog Design v5.0

## Overview

This document defines the final catalog format for Photolala, incorporating feedback to create a cleaner, more efficient system for storing photo metadata in local and network directories.

## Directory Structure

Use a `.photolala/` directory to contain all catalog files:

```
/Photos/
├── IMG_001.jpg
├── IMG_002.jpg
└── .photolala/
    ├── manifest.plist      # Binary plist with UUID and metadata
    ├── 0.csv              # Shard 0 (for MD5s starting with 0)
    ├── 1.csv              # Shard 1
    ├── ...
    └── f.csv              # Shard f (for MD5s starting with f)
```

## Manifest with UUID

The `manifest.plist` will include a unique directory identifier:

```xml
<dict>
    <key>version</key>
    <string>5.0</string>
    <key>directory-uuid</key>
    <string>550e8400-e29b-41d4-a716-446655440000</string>
    <key>sharding</key>
    <string>hash:16</string>
    <key>shards</key>
    <dict>
        <key>0</key>
        <string>a1b2c3d4...</string>  <!-- MD5 checksum of shard -->
    </dict>
    <key>updated</key>
    <integer>1718445000</integer>
</dict>
```

## Cache Key Strategy

To handle network directories with different paths pointing to same location:

```swift
private func getCacheKey(for directory: URL) -> String {
    // First, try to get UUID from manifest
    if let uuid = getDirectoryUUID(from: directory) {
        return uuid
    }

    // Fallback: Use canonical path
    let canonicalPath = directory.standardizedFileURL.path
    return canonicalPath.md5Hash
}

private func getDirectoryUUID(from directory: URL) -> String? {
    let manifestURL = directory
        .appendingPathComponent(".photolala")
        .appendingPathComponent("manifest.plist")

    guard let data = try? Data(contentsOf: manifestURL),
          let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
          let uuid = plist["directory-uuid"] as? String else {
        return nil
    }

    return uuid
}
```

## Manual Refresh Support

Add manual refresh capability:

```swift
extension CatalogAwarePhotoLoader {
    /// Force refresh catalog, bypassing cache
    func refreshCatalog(for directory: URL) async throws -> [PhotoReference] {
        // Clear cache for this directory
        cacheService.clearCache(for: directory)

        // Reload from source
        return try await loadFromCatalog(directory, bypassCache: true)
    }
}
```

UI Integration:
- Add "Refresh" button or menu item
- Keyboard shortcut: ⌘R
- Pull-to-refresh on iOS

## CSV Format

Each shard file contains photo metadata in CSV format:
```
md5,filename,size,photodate,modified,width,height
d41d8cd98f00b204e9800998ecf8427e,IMG_0129.jpg,2048576,1718445000,1718445000,4032,3024
```

## Sharded Catalog Advantages

### Small Directories (< 1000 photos)
- Single file might be simpler
- But sharding overhead is minimal (16 small files)
- Consistent approach is better

### Large Directories (10K-100K+ photos)
- **Big advantage**: Can read only needed shards
- Example: Scrolling to photos starting with 'IMG_9xxx'
  - Their MD5s might all start with 'e' or 'f'
  - Only need to read 2 shards instead of entire catalog
- Parallel loading possible

### Performance Comparison
| Photos | Single File | 16 Shards | Advantage |
|--------|-------------|-----------|-----------|
| 100    | 10KB       | 16×625B   | Negligible |
| 1,000  | 100KB      | 16×6KB    | Slight overhead |
| 10,000 | 1MB        | 16×62KB   | Parallel ops |
| 100,000| 10MB       | 16×625KB  | Partial reads |
| 1M     | 100MB      | 16×6.25MB | Huge benefit |

## Implementation Priorities

### Phase 1: Essential Features
1. ✅ New `.photolala/` directory structure
2. ✅ UUID in manifest for cache keys
3. ✅ Manual refresh support
4. ✅ Basic caching for network dirs

### Phase 2: Smart Loading (Future)
1. Load only visible shards first
2. Prefetch adjacent shards
3. Memory-mapped files for large catalogs

## Migration from v4.0

### File Structure Changes
- **v4.0**: Files in photo directory (`.photolala`, `.photolala#0`, etc.)
- **v5.0**: All files in `.photolala/` subdirectory

### Compatibility
- Read support for both v4.0 and v5.0 formats
- New catalogs created in v5.0 format only
- Optional background migration for existing catalogs

## Summary

The v5.0 catalog design provides:
- **Cleaner directories**: All catalog files contained in `.photolala/` folder
- **UUID-based caching**: Handles network paths correctly
- **Manual refresh**: User control when needed
- **Scalability**: Sharding architecture supports millions of photos
- **Simplicity**: No complex locking or multi-user features in v1

For the initial implementation, we'll load all shards at once. The architecture allows future optimization for partial loading when dealing with very large catalogs.
