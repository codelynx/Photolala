# Cache Directory Reorganization Plan

## Current Structure Issues

The current cache structure has several inconsistencies:

```
/Library/Caches/
├── com.electricwoods.photolala/    # SwiftData + S3 caches
│   ├── Cache.db*                   # SwiftData (unused?)
│   ├── cloud.s3/                   # S3 catalog cache
│   ├── photos.s3                   # S3 photos (empty dir)
│   └── thumbnails.s3/              # S3 thumbnails
└── Photolala/                      # Local photo caches
    └── cache/
        └── md5_*.dat               # Local thumbnails
```

### Problems:
1. **Duplicate top-level directories** - Both `Photolala` and `com.electricwoods.photolala`
2. **Inconsistent naming** - Mix of bundle ID and app name
3. **Flat S3 structure** - `.s3` suffix is unclear
4. **Unused SwiftData** - Cache.db files appear unused

## Proposed New Structure

```
/Library/Caches/com.electricwoods.photolala/
├── local/
│   ├── thumbnails/
│   │   └── {md5}.dat              # Local photo thumbnails
│   └── images/
│       └── {path_hash}.dat        # Full-size image cache
├── cloud/
│   ├── s3/
│   │   ├── catalogs/
│   │   │   └── {userId}/
│   │   │       └── .photolala/    # Downloaded catalog files
│   │   ├── photos/
│   │   │   └── {userId}/
│   │   │       └── {md5}.dat     # Downloaded S3 photos
│   │   ├── thumbnails/
│   │   │   └── {userId}/
│   │   │       └── {md5}.dat     # Downloaded S3 thumbnails
│   │   └── metadata/
│   │       └── {userId}/
│   │           └── {md5}.plist    # Downloaded S3 metadata
│   └── icloud/                    # Future: iCloud support
│       └── ...
```


## Benefits of New Structure

1. **Single root directory** - Everything under `com.electricwoods.photolala`
2. **Clear separation** - `local/` vs `cloud/` makes source obvious
3. **Service-agnostic cloud** - Easy to add iCloud, Dropbox, etc.
4. **User isolation** - Each user's cloud data is separate
5. **Consistent paths** - Mirror S3 bucket structure locally
6. **No SwiftData** - Remove unused database files

## Migration Strategy

### Phase 1: Update PhotoManager
```swift
// Old paths (note: md5_ prefix comes from identifier.string = "md5#{hash}")
~/Library/Caches/Photolala/cache/md5_{hash}.dat

// New paths (simplified to just hash)
~/Library/Caches/com.electricwoods.photolala/local/thumbnails/{hash}.dat
```

**Note**: Current PhotoManager uses identifiers like "md5#abc123" which get converted to "md5_abc123.dat" for filesystem safety. In the new structure, we'll store just "{hash}.dat" since the directory already indicates it's MD5-based.


### Phase 2: Update S3 Services
```swift
// Old paths
~/Library/Caches/com.electricwoods.photolala/thumbnails.s3/{md5}
~/Library/Caches/com.electricwoods.photolala/cloud.s3/{userId}/

// New paths
~/Library/Caches/com.electricwoods.photolala/cloud/s3/thumbnails/{userId}/{md5}.dat
~/Library/Caches/com.electricwoods.photolala/cloud/s3/catalogs/{userId}/.photolala/
```

### Phase 3: Migration Code
1. Check if old directories exist
2. Move files to new locations
3. Update path references
4. Delete old directories
5. Add migration flag to prevent re-migration

## Implementation Checklist

- [ ] Create CacheManager class to centralize path management
- [ ] Update PhotoManager thumbnail paths
- [ ] Update S3DownloadService cache paths
- [ ] Update S3CatalogSyncService paths
- [ ] Remove SwiftData Cache.db usage
- [ ] Implement migration for existing users
- [ ] Test on clean install
- [ ] Test migration from old structure
- [ ] Update documentation

## Code Changes Required

### 1. Create CacheManager
```swift
class CacheManager {
    static let shared = CacheManager()

    private let rootURL: URL

    init() {
        rootURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.electricwoods.photolala")
    }

    // Local paths
    func localThumbnailURL(for md5: String) -> URL {
        rootURL
            .appendingPathComponent("local/thumbnails")
            .appendingPathComponent("\(md5).dat")
    }

    // Cloud paths - mirrors S3 bucket structure
    func cloudThumbnailURL(service: CloudService, userId: String, md5: String) -> URL {
        rootURL
            .appendingPathComponent("cloud/\(service.rawValue)/thumbnails/\(userId)")
            .appendingPathComponent("\(md5).dat")
    }
    
    func cloudPhotoURL(service: CloudService, userId: String, md5: String) -> URL {
        rootURL
            .appendingPathComponent("cloud/\(service.rawValue)/photos/\(userId)")
            .appendingPathComponent("\(md5).dat")
    }
    
    func cloudMetadataURL(service: CloudService, userId: String, md5: String) -> URL {
        rootURL
            .appendingPathComponent("cloud/\(service.rawValue)/metadata/\(userId)")
            .appendingPathComponent("\(md5).plist")
    }
    
    func cloudCatalogURL(service: CloudService, userId: String) -> URL {
        rootURL
            .appendingPathComponent("cloud/\(service.rawValue)/catalogs/\(userId)")
            .appendingPathComponent(".photolala")
    }
}

enum CloudService: String {
    case s3 = "s3"
    case icloud = "icloud"
}
```

### 2. Update PhotoManager
- Change thumbnail cache directory
- Use CacheManager for path generation

### 3. Update S3 Services
- S3DownloadService: Use new cache paths
- S3CatalogSyncService: Use new catalog cache location
- Remove .s3 suffix usage

## Questions to Resolve

1. **Should we version the cache structure?**
   - Add version file to detect structure changes?
   - Useful for future migrations

2. **Size limits per service?**
   - Different limits for local vs cloud?
   - Per-user limits for cloud storage?

3. **Cleanup strategy?**
   - When to purge cloud caches?
   - LRU eviction for thumbnails?

4. **Metadata storage?**
   - Store catalog ETags and versions?
   - Track last sync times?

## Alternative Considerations

### Option A: Flatter Structure
```
/Library/Caches/com.electricwoods.photolala/
├── thumbnails-local/
├── thumbnails-s3/
├── photos-local/
├── photos-s3/
└── catalogs-s3/
```
Pros: Simpler
Cons: Harder to add new services

### Option B: By Content Type
```
/Library/Caches/com.electricwoods.photolala/
├── thumbnails/
│   ├── local/
│   └── s3/
├── photos/
│   ├── local/
│   └── s3/
└── catalogs/
    └── s3/
```
Pros: Groups by content
Cons: Splits cloud services

## Next Steps

1. Review and approve structure
2. Implement CacheManager
3. Update services incrementally
4. Test migration thoroughly
5. Deploy with migration code

## Notes

- Consider using `NSFileManager.urls(for:in:)` with `.cachesDirectory` for proper sandboxing
- Ensure proper directory creation with intermediate directories
- Add `.gitkeep` or documentation in each directory?
- Monitor cache sizes and implement cleanup policies
