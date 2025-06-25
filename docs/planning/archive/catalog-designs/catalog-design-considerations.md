# Catalog Design Considerations (KY Feedback)

## Key Issues to Address

### 1. Storage Class Updates (180-day lifecycle)
- Photos transition from STANDARD → DEEP_ARCHIVE after 180 days
- Constantly updating catalog for storage class changes is inefficient
- **Solution**: Don't track storage class in local catalogs, only in S3 master

### 2. Backup Status Overhead
- Users backup on/off frequently
- Maintaining backup status in local catalogs creates churn
- **Solution**: Remove backup status from catalog, calculate on-demand via MD5 lookup

### 3. Photo Date Format
- EXIF lacks timezone info (JST, EDT, etc.)
- **Solution**: Use Unix timestamp (seconds since epoch)
- 1-second precision is sufficient for comparison

### 4. Duplicate MD5 Handling

#### Same Directory
- `IMG_001.jpg` and `IMG_001_copy.jpg` with same MD5
- Only need one thumbnail cache entry
- Catalog lists both files, same MD5 is fine

#### Different Directories  
- Each directory has its own `.photolala`
- No conflict even with same filename
- Thumbnail cache is content-based (MD5)

#### Photo Library
- Needs separate catalog system
- Different namespace from file system

### 5. Large Catalog Scalability

For directories with 10K+ photos, single file updates become expensive:

```
.photolala              # Base catalog (snapshot)
.photolala.delta.001    # Changes since base
.photolala.delta.002    # More recent changes
.photolala.delta.003    # Latest changes
```

Periodic consolidation:
- Merge deltas into base when idle
- Keep max 5-10 delta files
- Read order: base → delta.001 → delta.002 → ...

## Revised Catalog Format

### Simplified CSV (Local Directories)
```csv
# .photolala v2.0
filename,size,modified,md5,width,height,photoDate
IMG_0129.jpg,2048576,1718445000,d41d8cd98f00b204e9800998ecf8427e,4032,3024,1718445000
IMG_0130.jpg,1843200,1718445060,e5f7a3b2c1d4e6f8a9b0c1d2e3f4a5b6,4032,3024,1718445060
```

### S3 Master Catalog (JSON)
```json
{
  "version": "2.0",
  "created": 1705493600,
  "photos": {
    "d41d8cd98f00b204e9800998ecf8427e": {
      "size": 2048576,
      "photoDate": 1718445000,
      "uploadDate": 1718531400,
      "storageClass": "DEEP_ARCHIVE"
    }
  }
}
```

## Key Design Changes

1. **No backup status in local catalogs** - Calculate via MD5 lookup
2. **Unix timestamps everywhere** - Consistent, timezone-agnostic
3. **Storage class only in S3** - Where it actually matters
4. **Delta file support** - For large directory scalability
5. **MD5 as primary key in S3** - Deduplication built-in

## Implementation Strategy

### Phase 1: Basic Catalog
- Simple CSV for local directories
- No backup status field
- Unix timestamps

### Phase 2: Delta Support
- Detect large catalogs (>1000 entries)
- Write changes to delta files
- Merge periodically

### Phase 3: S3 Integration
- Download S3 master catalog
- MD5-based status lookup
- No local status tracking

This approach keeps catalogs focused on their primary purpose: fast loading for local directories and offline browsing for S3.