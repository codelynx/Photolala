# .photolala Directory Structure Proposal

## Current Structure (v4.0)
```
/Photos/
├── IMG_001.jpg
├── IMG_002.jpg
├── .photolala              # Binary plist manifest
├── .photolala#0            # CSV shard 0
├── .photolala#1            # CSV shard 1
├── ...
└── .photolala#f            # CSV shard 15
```
**Problem**: 17 files cluttering the photo directory

## Proposed Structure (v5.0)
```
/Photos/
├── IMG_001.jpg
├── IMG_002.jpg
└── .photolala/             # Single directory containing all catalog files
    ├── manifest.plist      # Binary plist manifest
    ├── shard-0.csv         # CSV shard 0
    ├── shard-1.csv         # CSV shard 1
    ├── ...
    └── shard-f.csv         # CSV shard 15
```

## Benefits

1. **Cleaner Directory View**
   - Only one `.photolala` entry in file listings
   - Less visual clutter in S3 browser
   - Easier to identify photo-only directories

2. **Better Organization**
   - All catalog files grouped together
   - Easy to delete/move entire catalog
   - Clear separation of photos vs metadata

3. **Future Extensibility**
   - Can add more files without cluttering
   - Lock files, temp files, etc. stay organized
   - Potential for catalog versioning

## Migration Strategy

### Option 1: Gradual Migration (Recommended)
```swift
class PhotolalaCatalogService {
    func readCatalog(from directory: URL) async throws -> PhotolalaCatalog {
        // Try v5.0 structure first
        let v5CatalogDir = directory.appendingPathComponent(".photolala")
        if FileManager.default.fileExists(atPath: v5CatalogDir.path) {
            return try await readV5Catalog(from: v5CatalogDir)
        }
        
        // Fall back to v4.0 structure
        let v4Manifest = directory.appendingPathComponent(".photolala")
        if FileManager.default.fileExists(atPath: v4Manifest.path) {
            let catalog = try await readV4Catalog(from: directory)
            
            // Optionally migrate in background
            Task.detached {
                try? await self.migrateToV5(catalog, at: directory)
            }
            
            return catalog
        }
        
        throw CatalogError.notFound
    }
}
```

### Option 2: Clean Break
- Only support v5.0 for new catalogs
- Keep v4.0 read support indefinitely
- No automatic migration

## Implementation Changes

### 1. PhotolalaCatalogService Updates
```swift
private func catalogURL(for directory: URL, version: CatalogVersion = .v5) -> URL {
    switch version {
    case .v4:
        return directory.appendingPathComponent(".photolala")
    case .v5:
        return directory.appendingPathComponent(".photolala").appendingPathComponent("manifest.plist")
    }
}

private func shardURL(for directory: URL, index: Int, version: CatalogVersion = .v5) -> URL {
    switch version {
    case .v4:
        return directory.appendingPathComponent(".photolala#\(String(format: "%x", index))")
    case .v5:
        return directory.appendingPathComponent(".photolala").appendingPathComponent("shard-\(String(format: "%x", index)).csv")
    }
}
```

### 2. S3 Catalog Structure
For S3, this would be even cleaner:
```
s3://photolala-us-east-1/photos/{userId}/2024/06/
├── IMG_001.jpg
├── IMG_002.jpg
└── .photolala/
    ├── manifest.plist
    ├── shard-0.csv
    └── ...
```

## Backward Compatibility

1. **Reading**: Support both v4.0 and v5.0 indefinitely
2. **Writing**: New catalogs use v5.0 structure
3. **Migration**: Optional, on-demand or background
4. **S3 Sync**: Handle both structures during transition

## Decision Points

1. **Should we auto-migrate v4 to v5?**
   - Pro: Cleaner directories everywhere
   - Con: More S3 operations, potential for errors

2. **File naming in .photolala directory?**
   - Option A: `shard-0.csv` (clear, descriptive)
   - Option B: `0.csv` (minimal, clean)
   - Option C: `0` (no extension, like git objects)

3. **When to implement?**
   - Option A: Before shipping catalog support (clean start)
   - Option B: After v1, as enhancement
   - Option C: Only for new catalogs, keep v4 working

## Recommendation

Implement v5.0 structure now, before the initial release:
1. Cleaner from the start
2. No migration burden for users
3. Better S3 organization
4. Worth the small delay

The change is relatively simple - mostly updating path construction in PhotolalaCatalogService.