# Thumbnail Cache Optimization Plan

## Current Issues

1. **Unnecessary Thumbnail Regeneration**
   - Thumbnails are regenerated when reopening the same directory
   - Memory cache uses file paths but stores with MD5 identifiers
   - No persistent mapping between file paths and MD5 hashes

2. **Performance Impact**
   - Each cache miss reads entire file to compute MD5
   - Disk cache exists but requires MD5 for lookup
   - No fast path for unchanged files

## Proposed Solutions

### 1. Add File Metadata Cache
Create a persistent cache mapping file paths to:
- MD5 hash
- File modification date
- File size

This allows quick disk cache lookups without reading files.

### 2. Optimize Cache Lookup Order
```swift
// Proposed flow:
1. Check memory cache by file path
2. Check file metadata cache
3. If file unchanged, use cached MD5 to check disk cache
4. Only compute MD5 if file changed or not in metadata cache
```

### 3. Consistent Cache Keys
- Always use file path for memory cache
- Always use MD5 for disk cache
- Maintain clear separation between the two

### 4. Implementation Steps

#### Phase 1: File Metadata Cache
- Create `ThumbnailMetadataCache` class
- Store as JSON/plist in Application Support
- Update on successful thumbnail generation
- Clean up entries for deleted files

#### Phase 2: Optimize PhotoFile
- Make `md5Hash` property persistent in metadata cache
- Load MD5 from cache instead of computing every time
- Only recompute if file modification date changes

#### Phase 3: Streamline Cache Checks
- Modify `PhotoManager.syncThumbnail()` to check metadata first
- Skip MD5 computation for unchanged files
- Use cached MD5 for disk cache lookup

## Expected Benefits

- Near-instant thumbnail display when reopening directories
- Reduced CPU usage (no unnecessary MD5 computation)
- Reduced disk I/O (no unnecessary file reads)
- Better user experience with faster browsing

## Implementation Priority

1. File metadata cache (biggest impact)
2. Optimize cache lookup order
3. Make MD5 persistent
4. Clean up inconsistent cache keys