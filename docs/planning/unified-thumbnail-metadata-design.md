# Unified Thumbnail & Metadata Design Concept

## Terminology

**PhotoDigest** - The unified concept of thumbnail + metadata. Like a message digest (MD5), it represents the essential condensed information of a photo, including both its visual representation (thumbnail) and informational components (metadata). This term aligns well with the project's existing use of MD5 digests.
i reset 
## Two-Level Cache Architecture

### Level 1: Path to MD5 Cache
Maps file identity to content MD5 hash:
- **Key**: `{pathMD5}|{fileSize}|{modTimestamp}`
- **Value**: Content MD5 hash
- **Purpose**: Avoid reading file to compute MD5
- **Storage**: Memory + Disk (persistent JSON)

### Level 2: MD5 to PhotoDigest Cache
Maps content MD5 to thumbnail and metadata:
- **Key**: Content MD5 hash
- **Value**: PhotoDigest (thumbnail + metadata)
- **Purpose**: Store actual thumbnail and metadata
- **Storage**: Memory + Disk (sharded .dat/.json files)

This two-level design enables:
1. Fast MD5 lookup without reading files
2. Content-based deduplication
3. Efficient cache invalidation

## Complete Thumbnailing Process

### Local Directory Photos

When opening a local directory:

1. **Scan photo files** in directory
2. **Create cache key** from:
   - Normalized + lowercased path → MD5
   - File size (Int64)
   - Modification timestamp (seconds only)
   - Key format: `{pathMD5}|{fileSize}|{modTimestamp}`

3. **Check caches** in order:
   - Memory cache (PhotoDigest by cache key)
   - Disk cache (sharded by first 2 chars of content MD5)

4. **On cache miss**:
   - Read file data
   - Compute content MD5 hash
   - Generate thumbnail (256-512px)
   - Extract metadata (EXIF, dimensions, etc.)
   - Create PhotoDigest
   - Save to disk cache: `{first-2-chars}/{md5}.dat` and `{first-2-chars}/{md5}.json`
   - Store in memory cache

### Apple Photos Library

Apple Photos have unique constraints:
- No direct file path access
- Use `localIdentifier` as unique ID
- Photos may be in iCloud (need network access)
- Can't compute MD5 without loading full data

Current implementation:

1. **Use Apple Photo ID** (`asset.localIdentifier`)
2. **Request thumbnail** via Photos framework:
   ```swift
   imageManager.requestImage(
       for: asset,
       targetSize: CGSize(width: 512, height: 512),
       contentMode: .aspectFit,
       options: options
   )
   ```
3. **For backup/catalog**: Load full data to compute MD5

### Proposed Apple Photos with PhotoDigest

To align with the new PhotoDigest design:

1. **Create cache key** from:
   - Apple Photo ID (localIdentifier)
   - No file attributes needed (Photos framework manages changes)
   - Key format: `applePhotos|{localIdentifier}`

2. **Check caches**:
   - Memory cache (PhotoDigest by cache key)
   - Disk cache using ID-based path: `apple-photos/{first-2-chars-of-id}/{localIdentifier}.dat`

3. **On cache miss**:
   - Request thumbnail from Photos framework
   - Request basic metadata (dimensions, dates from PHAsset)
   - Create PhotoDigest (no MD5 initially)
   - Save to Apple Photos specific cache location
   - Store in memory cache

4. **When starred** (for backup):
   - Load full image data from Photos framework
   - Compute content MD5 hash
   - Extract full metadata (EXIF, etc.)
   - Create complete PhotoDigest
   - Save to standard MD5-based cache: `{first-2-chars}/{md5}.dat` and `{first-2-chars}/{md5}.json`
   - Now this Apple Photo has same cache as if it were a local file

This approach means:
- Initial browsing is fast (Apple Photos API)
- Starred photos get full PhotoDigest with MD5
- Deduplication works across local and Apple Photos (same MD5 = same cache)

### S3 Cloud Photos

S3 photos already have MD5 and metadata from catalog:

1. **Create cache key** from:
   - S3 path or MD5 directly
   - Key format: `s3|{userId}|{md5}`

2. **Check caches**:
   - Memory cache (PhotoDigest by cache key)
   - Disk cache: `cloud/s3/{first-2-chars}/{md5}.dat`

3. **On cache miss**:
   - Download thumbnail from S3
   - Use metadata from catalog (no extraction needed)
   - Create PhotoDigest
   - Save to S3-specific cache location
   - Store in memory cache

### Unified Cache Structure

All photo sources eventually use MD5-based caching:
```
~/Library/Caches/com.electricwoods.photolala/
├── local/photos/{first-2-chars}/
│   ├── {md5}.dat     # Local file thumbnails
│   └── {md5}.json    # Local file metadata
├── apple-photos/temp/{first-2-chars}/
│   ├── {localIdentifier}.dat  # Temporary Apple Photos thumbnails
│   └── {localIdentifier}.json # Temporary Apple Photos metadata
├── photos/{first-2-chars}/      # Unified MD5-based cache
│   ├── {md5}.dat     # Any photo with computed MD5
│   └── {md5}.json    # Shared by local, starred Apple, S3
└── cloud/s3/{first-2-chars}/
    ├── {md5}.dat     # Downloaded S3 thumbnails
    └── {md5}.json    # S3 metadata from catalog
```

The key insight: MD5-based PhotoDigest enables deduplication across all sources!

## Current Architecture (Separated)

Currently, thumbnail and metadata are stored separately:

```
Thumbnail Data:
~/Library/Caches/Photolala/local/thumbnails/{md5}.dat

Metadata Mapping:
~/Library/Application Support/Photolala/thumbnail-metadata.json
```

## Proposed Architecture (Unified)

Treat thumbnail and metadata as an atomic unit:

### Option 1: Single File Container

```
~/Library/Caches/Photolala/photos/{md5}.photolala

Structure:
{
  "version": 1,
  "metadata": {
    "filePath": "/path/to/photo.jpg",
    "fileSize": 1234567,
    "modificationDate": "2025-01-30T10:00:00Z",
    "md5Hash": "abc123...",
    "exif": {
      "camera": "iPhone 16 Pro",
      "dateTaken": "2025-01-25T14:30:00Z",
      "location": {...}
    },
    "dimensions": {
      "width": 4032,
      "height": 3024
    }
  },
  "thumbnail": {
    "data": "<base64 encoded image>",
    "width": 256,
    "height": 192,
    "format": "jpeg"
  },
  "generatedAt": "2025-01-30T10:00:00Z"
}
```

### Option 2: Sharded File Structure (Recommended)

```
~/Library/Caches/com.electricwoods.photolala/local/photos/{first-2-chars}/
  ├── {md5}.dat     (thumbnail image data)
  └── {md5}.json    (metadata)

Example:
~/Library/Caches/com.electricwoods.photolala/local/photos/a7/
  ├── a7b8c9d0e1f2...dat
  └── a7b8c9d0e1f2...json
```

Benefits:
- Avoids too many files in single directory (16^2 = 256 subdirectories)
- Standard practice (git uses similar sharding)
- Easy to locate related files
- Maintains current .dat extension
- Aligns with S3 catalog's 16-shard system

### Sharding Strategy

Both local and S3 systems use MD5-based sharding:

**Local Photos (2-char sharding):**
```
MD5: a7b8c9d0e1f2...
Directory: a7/
Files: a7b8c9d0e1f2...dat, a7b8c9d0e1f2...json
```

**S3 Catalog (16-shard system):**
```
MD5: a7b8c9d0e1f2...
Shard: int(a7, 16) % 16 = shard number
File: catalog_{shard}.csv
```

This provides good distribution:
- Local: 256 directories (00-ff)
- S3: 16 CSV files for catalog entries

### Option 3: Binary Package Format

Custom binary format for efficiency:
```
[Header - 64 bytes]
  - Magic bytes: "PLLA"
  - Version: 4 bytes
  - Metadata offset: 8 bytes
  - Metadata size: 8 bytes
  - Thumbnail offset: 8 bytes
  - Thumbnail size: 8 bytes
  - Reserved: 32 bytes

[Metadata Section]
  - JSON or MessagePack encoded metadata

[Thumbnail Section]
  - JPEG compressed thumbnail data
```

## Benefits of Unified Approach

1. **Atomic Operations**
   - Single read to get both thumbnail and metadata
   - Single write when generating
   - No synchronization issues

2. **Simplified Cache Management**
   - One cache key instead of multiple
   - Easier invalidation
   - Consistent state

3. **Better Performance**
   - Fewer file system operations
   - Better locality of reference
   - Single cache lookup

4. **Easier Backup/Sync**
   - Single unit to backup
   - Easier to sync across devices
   - Clear ownership

## MD5 Computation Optimization

### The Problem
Computing MD5 requires reading the entire file, which is expensive for large photos. We need a fast way to map file paths to their MD5 without recomputing.

### File Attribute Cache Strategy

Use file attributes as a composite cache key to avoid MD5 recomputation:

```swift
struct FileIdentityKey {
    let normalizedPath: String  // Canonical path
    let fileSize: Int64         // Most reliable change indicator
    let modificationTimestamp: Int  // Unix timestamp in seconds
    
    var cacheKey: String {
        // Combine for unique key
        "\(normalizedPath)|\(fileSize)|\(modificationTimestamp)"
    }
}
```

### Alternative: Path MD5 Strategy

Instead of using the full path string, compute MD5 of the normalized path:

```swift
struct FileIdentityKey {
    let pathMD5: String         // MD5 of normalized + lowercased path
    let fileSize: Int64         // Most reliable change indicator
    let modificationTimestamp: Int  // Unix timestamp in seconds
    
    init(path: String, size: Int64, modTimestamp: Int) {
        // Normalize path, convert to lowercase, then MD5
        // This handles case-insensitive filesystems (HFS+, NTFS, FAT32)
        let normalizedLowercasePath = path.normalized.lowercased()
        self.pathMD5 = MD5(string: normalizedLowercasePath)
        self.fileSize = size
        self.modificationTimestamp = modTimestamp
    }
    
    var cacheKey: String {
        // Shorter, fixed-length key
        "\(pathMD5)|\(fileSize)|\(modificationTimestamp)"
    }
}
```

Benefits of Normalized + Lowercase Path MD5:
1. **Fixed length keys** - All cache keys are same length
2. **Privacy** - Cache doesn't reveal actual file paths
3. **Efficient storage** - Shorter keys in persistent cache
4. **Consistent hashing** - Works well with sharded storage
5. **Path-agnostic** - Moving files doesn't expose old paths
6. **Case-insensitive** - Handles filesystems that are case-insensitive:
   - macOS (HFS+ and APFS by default)
   - Windows (NTFS, FAT32)
   - Android internal storage (ext4/F2FS but case-insensitive since Android 10)
   - Android SD cards (usually FAT32 or exFAT - case-insensitive)
   - iOS (APFS case-insensitive)
   - Most external drives
   - `/Users/Photos/IMG.JPG` and `/users/photos/img.jpg` map to same cache

Considerations:
1. **Extra computation** - Need to MD5 the path (but paths are short)
2. **Not human-readable** - Harder to debug cache issues
3. **Case-sensitive filesystem edge cases**:
   - Linux ext4 (different case = different files)
   - Android < 10 internal storage (was case-sensitive)
   - Some NAS systems configured as case-sensitive

### Complete Two-Level Cache Flow

```
LEVEL 1: Path → MD5
==================
1. File Path (user input)
   ↓
2. Normalize + lowercase path → compute pathMD5
   ↓
3. Get file attributes (size, timestamp)
   ↓
4. Create key: {pathMD5}|{fileSize}|{modTimestamp}
   ↓
5. Check Level 1 caches:
   - Memory: pathKey → contentMD5
   - Disk: path-to-md5-cache.json
   ↓ HIT                    ↓ MISS
6. Got content MD5         6. Read file & compute MD5
   ↓                         ↓
   ↓                       7. Store in Level 1 caches
   ↓                         ↓
LEVEL 2: MD5 → PhotoDigest
==========================
8. Use content MD5 as key
   ↓
9. Check Level 2 caches:
   - Memory: MD5 → PhotoDigest
   - Disk: {first-2-chars}/{md5}.dat + .json
   ↓ HIT                    ↓ MISS
10. Return PhotoDigest     10. Generate thumbnail
                             ↓
                          11. Extract metadata
                             ↓
                          12. Create PhotoDigest
                             ↓
                          13. Store in Level 2 caches
                             ↓
                          14. Return PhotoDigest
```

### Two-Level Cache Storage Implementation

#### Level 1: Path → MD5 Cache
Both memory and disk storage:

```swift
// Memory cache
private var pathToMD5Cache: [String: String] = [:]  // pathKey → contentMD5

// Disk cache (JSON file)
// ~/Library/Caches/com.electricwoods.photolala/path-to-md5-cache.json
{
  "a7b8c9d0|4567890|1706698800": "e5f6g7h8i9j0...",  // pathMD5|size|timestamp → contentMD5
  "b8c9d0e1|3456789|1706698900": "f6g7h8i9j0k1..."
}
```

#### Level 2: MD5 → PhotoDigest Cache
Both memory and disk storage:

```swift
// Memory cache
private let photoDigestCache = NSCache<NSString, PhotoDigest>()

// Disk cache (sharded files)
~/Library/Caches/com.electricwoods.photolala/photos/{first-2-chars}/
  ├── {md5}.dat     // Thumbnail image data
  └── {md5}.json    // PhotoDigest metadata
```

This two-level architecture ensures:
- Level 1 prevents file reads for MD5 computation
- Level 2 stores actual thumbnails and metadata
- Both levels have memory + disk for persistence
- Memory caches provide fastest access
- Disk caches survive app restarts

### Platform Considerations

1. **macOS/iOS**: 
   - Use `stat` attributes (reliable)
   - `NSFileManager.attributesOfItem` provides size & dates
   - APFS: nanosecond precision
   - HFS+: second precision

2. **Network Drives (NAS/SMB)**:
   - Modification dates may be unreliable
   - File size is usually accurate
   - SMB: 2-second precision (DOS time)
   - NFS: varies by server

3. **External Drives**:
   - FAT32: 2-second precision
   - ExFAT: 10ms precision
   - NTFS: 100ns precision
   - Different precision = comparison issues

### Timestamp Normalization Strategy

Always truncate to seconds for cross-platform compatibility:

```swift
extension Date {
    var truncatedToSeconds: Int {
        Int(self.timeIntervalSince1970)  // Drops fractional seconds
    }
}

struct FileIdentityKey {
    let pathMD5: String
    let fileSize: Int64
    let modificationSeconds: Int  // Unix timestamp in seconds
    
    init(path: String, size: Int64, modDate: Date) {
        self.pathMD5 = MD5(string: path.normalized)
        self.fileSize = size
        self.modificationSeconds = modDate.truncatedToSeconds
    }
    
    var cacheKey: String {
        "\(pathMD5)|\(fileSize)|\(modificationSeconds)"
    }
}
```

Benefits:
- **Consistent across filesystems** - FAT32, NTFS, HFS+, APFS all work
- **Avoids precision mismatches** - No false cache misses
- **Smaller storage** - Int vs Double with fractional seconds
- **Human readable** - Unix timestamps are familiar

### Implementation Example

```swift
class MD5CacheManager {
    private var cache: [String: String] = [:]
    
    func getMD5(for url: URL) async throws -> String {
        // Normalize path
        let path = url.standardizedFileURL.path
        
        // Get file attributes
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let size = attrs[.size] as? Int64 ?? 0
        let modDate = attrs[.modificationDate] as? Date ?? Date()
        let modTimestamp = Int(modDate.timeIntervalSince1970)
        
        // Create cache key
        let cacheKey = "\(path)|\(size)|\(modTimestamp)"
        
        // Check cache
        if let cachedMD5 = cache[cacheKey] {
            return cachedMD5
        }
        
        // Compute MD5
        let md5 = try await computeMD5(for: url)
        
        // Cache it
        cache[cacheKey] = md5
        
        return md5
    }
}
```

### Benefits

1. **Performance**: Avoid reading multi-MB files repeatedly
2. **Accuracy**: File size changes indicate content changes
3. **Compatibility**: Works across filesystems
4. **Simplicity**: No complex file watching needed

## Implementation Considerations

### Memory Cache Structure

```swift
struct PhotoDigest {
    let thumbnail: XThumbnail
    let metadata: PhotoMetadata
    let cacheKey: String  // MD5
    let lastAccessed: Date
}

// Single cache instead of multiple
private let photoDigestCache = NSCache<NSString, PhotoDigest>()
```

### Loading Flow

```
1. Request PhotoDigest for file path
   ↓
2. Check memory cache → HIT: Return PhotoDigest
   ↓ MISS
3. Check file attributes
   ↓
4. Compute/lookup MD5
   ↓
5. Load PhotoDigest from disk → HIT: Parse and return
   ↓ MISS
6. Read original photo
   ↓
7. Generate thumbnail AND extract metadata
   ↓
8. Save PhotoDigest to disk
   ↓
9. Store PhotoDigest in memory cache
   ↓
10. Return PhotoDigest
```

### Migration Strategy

1. **Compatibility Mode**
   - Read from old locations if unified cache miss
   - Write to both during transition
   - Gradually migrate on access

2. **Background Migration**
   - Low priority task to unify existing caches
   - Preserve modification times
   - Clean up old files after verification

## Pros and Cons

### Pros
- Atomic operations reduce race conditions
- Fewer files to manage
- Better performance (single I/O)
- Cleaner architecture
- Easier to add more metadata later

### Cons
- Migration complexity
- Larger memory footprint per item
- All-or-nothing loading
- Format versioning needed

## Recommendation

Start with **Option 1 (JSON container)** for simplicity:
- Human-readable for debugging
- Easy to implement
- Standard format
- Can optimize to binary later if needed

This unified approach aligns well with the concept that a thumbnail is meaningless without its metadata, and metadata often needs its thumbnail for display.