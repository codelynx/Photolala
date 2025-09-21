# S3 Cloud Features Design Document

## Overview

This document describes the S3 cloud integration features for Photolala, providing cloud backup and browsing capabilities for photo management. The implementation follows a simple, efficient approach with MD5-based deduplication and progressive loading for optimal performance.

## Architecture

### Core Principles

1. **MD5 as Universal Identity**
   - Photos identified by MD5 hash for true deduplication
   - No date conflicts or duplicate uploads
   - Same photo uploaded from different sources only stored once

2. **Sequential Processing**
   - One-by-one uploads for simplicity and reliability
   - Clear progress tracking
   - Easier error handling and recovery

3. **Separation of Concerns**
   - Local and S3 catalogs are independent
   - User-initiated backup (no auto-sync)
   - Explicit control over cloud operations

4. **Cache-First Strategy**
   - Check local cache before S3 downloads
   - Progressive thumbnail loading
   - Minimize API calls and bandwidth usage

## Component Architecture

### 1. PhotoItem Protocol System

The `PhotoItem` protocol provides a unified interface for photos from various sources:

```
┌─────────────────────────────────────┐
│         PhotoItem Protocol          │
├─────────────────────────────────────┤
│ - id: String                        │
│ - displayName: String               │
│ - format: ImageFormat?              │
│ - loadFullData() -> Data           │
│ - loadThumbnail() -> Data          │
│ - computeMD5() -> String           │
└─────────────────────────────────────┘
           ▲              ▲
           │              │
    ┌──────┴──────┐ ┌─────┴──────┐
    │LocalPhotoItem│ │ApplePhotoItem│
    └──────────────┘ └─────────────┘
```

**Benefits:**
- Extensible to new photo sources (iCloud, Google Photos)
- Lazy MD5 computation (only when needed)
- Clean separation between data model and UI state
- Async/await for efficient resource usage

### 2. S3 Service Layer

The S3 service provides low-level AWS operations with environment-based configuration:

```
┌─────────────────────────────────────────────┐
│               S3Service                     │
├─────────────────────────────────────────────┤
│ Environment Configuration:                  │
│ - Development: photolala-dev               │
│ - Staging: photolala-stage                 │
│ - Production: photolala-prod               │
├─────────────────────────────────────────────┤
│ Photo Operations:                           │
│ - checkPhotoExists(md5, userID)           │
│ - uploadPhoto(data, md5, format, userID)  │
│ - downloadPhoto(md5, userID)              │
├─────────────────────────────────────────────┤
│ Thumbnail Operations:                       │
│ - uploadThumbnail(data, md5, userID)      │
│ - downloadThumbnail(md5, userID)          │
├─────────────────────────────────────────────┤
│ Catalog Operations:                         │
│ - uploadCatalog(csvData, md5, userID)     │
│ - downloadCatalog(md5, userID)            │
│ - updateCatalogPointer(md5, userID)       │
│ - downloadCatalogPointer(userID)          │
└─────────────────────────────────────────────┘
```

### 3. Backup Service

The `S3BackupService` handles sequential photo uploads with deduplication:

```
┌──────────────────────────────────────────────┐
│            S3BackupService                  │
├──────────────────────────────────────────────┤
│ Sequential Upload Flow:                     │
│ 1. Compute MD5 hash                        │
│ 2. Check S3 for existing photo             │
│ 3. Skip if exists (deduplication)          │
│ 4. Generate PTM-256 thumbnail              │
│ 5. Upload photo as .dat with metadata      │
│ 6. Upload thumbnail as .jpg                │
│ 7. Update catalog after all photos         │
├──────────────────────────────────────────────┤
│ Progress Tracking:                          │
│ - Track completed/failed/skipped           │
│ - Report progress percentage               │
│ - Maintain upload results dictionary       │
└──────────────────────────────────────────────┘
```

### 4. Cloud Browsing Service

The `S3CloudBrowsingService` provides progressive loading for cloud catalogs:

```
┌──────────────────────────────────────────────┐
│         S3CloudBrowsingService              │
├──────────────────────────────────────────────┤
│ Catalog Loading:                            │
│ 1. Download catalog pointer (.md5)         │
│ 2. Fetch catalog CSV from S3               │
│ 3. Load into read-only CatalogDatabase     │
├──────────────────────────────────────────────┤
│ Progressive Loading:                        │
│ - Memory cache (50 thumbnails)             │
│ - Disk cache (persistent)                  │
│ - S3 download (on-demand)                  │
├──────────────────────────────────────────────┤
│ Cache Management:                           │
│ - LRU eviction for memory cache            │
│ - Prefetch visible thumbnails              │
│ - Clear cache on demand                    │
└──────────────────────────────────────────────┘
```

## S3 Bucket Structure

### Directory Layout

```
photolala-{env}/
├── photos/
│   └── {user-uuid}/
│       └── {photo-md5}.dat          # Photo data (any format)
├── thumbnails/
│   └── {user-uuid}/
│       └── {photo-md5}.jpg          # PTM-256 thumbnail
└── catalogs/
    └── {user-uuid}/
        ├── .photolala.md5            # Current catalog pointer
        └── .photolala.{md5}.csv      # Catalog snapshots
```

### Key Design Decisions

1. **Universal .dat Extension (Design Decision)**
   - All photos stored as `.dat` regardless of format
   - Enables perfect MD5-based deduplication across all formats
   - Original format preserved in S3 object metadata (`x-amz-meta-original-format`)
   - **Rationale**: Same content with different extensions (e.g., photo.jpg vs photo.jpeg) would create duplicates without this approach
   - **MIME Type Resolution**: Lambda functions or CloudFront can read the format metadata to set correct Content-Type headers on delivery

2. **PTM-256 Thumbnails**
   - Standardized 256×256 JPEG format
   - Consistent quality settings across platforms
   - Optimized for grid display
   - **ThumbnailCache Integration**: The cache must provide a method to return JPEG `Data` for S3 upload

3. **CSV-Only Catalog System (No SQLite)**
   - **Important**: `CatalogDatabase` in v2 uses CSV exclusively, not SQLite
   - CSV loaded into memory dictionary for fast access
   - Simple, portable format without database dependencies
   - Human-readable for debugging
   - No conversion needed between CSV and SQLite

## Data Flow

### Upload Flow

```
Local Photos → PhotoItem → S3BackupService → S3Service → AWS S3
     │             │              │              │
     │             │              │              └─> Upload to bucket
     │             │              └─> Deduplication check
     │             └─> MD5 computation
     └─> File selection
```

### Download Flow

```
AWS S3 → S3Service → S3CloudBrowsingService → Cache → UI Display
                            │                     │
                            │                     └─> Local storage
                            └─> Progressive loading
```

## API Specifications

### Photo Upload

**Endpoint:** `PUT /photos/{user-uuid}/{photo-md5}.dat`

**Note on .dat Extension:**
The universal `.dat` extension is intentional for perfect deduplication. The original format is preserved in metadata, allowing downstream services (Lambda, CloudFront) to set correct MIME types when serving content.

**Headers:**
- `Content-Type`: Based on original format (e.g., `image/jpeg`)
- `x-amz-meta-original-format`: Format identifier (e.g., `JPEG`, `PNG`, `HEIF`)

**Response:**
- 200: Upload successful
- 409: Photo already exists (deduplication)

**MIME Type Resolution:**
When serving photos, Lambda@Edge or CloudFront can:
1. Read the `x-amz-meta-original-format` metadata
2. Set appropriate `Content-Type` header
3. Optionally rewrite the response filename with correct extension

### Thumbnail Upload

**Endpoint:** `PUT /thumbnails/{user-uuid}/{photo-md5}.jpg`

**Headers:**
- `Content-Type`: `image/jpeg`

**Specifications:**
- Size: 256×256 pixels
- Format: JPEG
- Quality: 85%
- Color space: sRGB

### Catalog Management

**Catalog Upload:**
`PUT /catalogs/{user-uuid}/.photolala.{catalog-md5}.csv`

**Pointer Update:**
`PUT /catalogs/{user-uuid}/.photolala.md5`

**CSV Format:**
```csv
photo_head_md5,file_size,photo_md5,photo_date,format
abc123def456,1048576,xyz789abc123,1699999999,JPEG
```

## Security and Permissions

### AWS IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:HeadObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::photolala-*/*",
        "arn:aws:s3:::photolala-*"
      ]
    }
  ]
}
```

### Environment-Based Access Control

- **Development**: Full access to photolala-dev bucket
- **Staging**: Full access to photolala-stage bucket
- **Production**: Restricted access with additional monitoring

### Credential Management

- Credentials stored in encrypted format using credential-code
- Environment selection via UserDefaults (in-app)
- No plaintext credentials in source code or config files
- All environments embedded in single binary

## Performance Optimizations

### Deduplication Strategy

1. **MD5 Check Before Upload**
   - HEAD request to check existence
   - Skip upload if photo exists
   - Significant bandwidth savings

2. **Batch Catalog Updates**
   - Upload catalog once after all photos
   - Reduces API calls
   - Maintains consistency

### Caching Strategy

1. **Three-Tier Cache**
   - Memory: 50 most recent thumbnails
   - Disk: Persistent local cache
   - S3: Source of truth

2. **Progressive Loading**
   - Load visible thumbnails first
   - Prefetch adjacent items
   - Lazy load full photos

### Network Efficiency

1. **Sequential Processing**
   - Controlled resource usage
   - Predictable performance
   - Easy cancellation

2. **Compression**
   - PTM-256 thumbnails (~20KB each)
   - JPEG quality optimized for size/quality
   - CSV catalog compression

## Error Handling

### Upload Errors

```swift
enum UploadResult {
    case completed       // Successfully uploaded
    case failed(Error)   // Upload failed with error
    case skipped        // Already exists (deduplication)
}
```

### Recovery Strategies

1. **Partial Upload Recovery**
   - Track successful uploads
   - Resume from last successful item
   - Skip already uploaded items

2. **Network Failures**
   - Exponential backoff retry
   - User notification
   - Manual retry option

3. **Validation Failures**
   - MD5 verification
   - Format detection
   - Size limits

## Testing Strategy

### Unit Tests

- `S3ServiceTests`: AWS SDK integration
- `S3BackupServiceTests`: Upload logic and deduplication
- `S3CloudBrowsingServiceTests`: Download and caching
- `PhotoItemTests`: Protocol implementations

### Integration Tests

- End-to-end upload flow
- Catalog synchronization
- Thumbnail generation
- Cache management

### Test Data

- Sample photos in `PhotolalaTests/sample-photos/`
- Mock implementations for testing
- Real S3 integration tests (development environment)

## Future Enhancements

### Phase 2 Features

1. **Parallel Uploads**
   - Concurrent upload queues
   - Bandwidth optimization
   - Progress aggregation

2. **Apple Photos Integration**
   - Direct backup from Photos library
   - Smart album support
   - Live Photos handling

3. **Conflict Resolution**
   - Multiple device sync
   - Merge strategies
   - Version tracking

### Phase 3 Features

1. **Smart Sync**
   - Automatic backup rules
   - Background uploads
   - Selective sync

2. **Sharing Features**
   - Shared albums
   - Public links
   - Collaboration

3. **Advanced Search**
   - S3 Select queries
   - Metadata search
   - ML-based tagging

## Migration Considerations

### From Local to Cloud

1. **Incremental Migration**
   - Upload in batches
   - Maintain local copies
   - Verify uploads

2. **Catalog Conversion**
   - Export local catalog to CSV
   - Upload to S3
   - Maintain pointer

### Between Environments

1. **Dev to Staging**
   - Export catalog
   - Bulk copy photos
   - Update pointers

2. **Staging to Production**
   - Validation checks
   - Performance testing
   - Rollback plan

## Monitoring and Analytics

### Key Metrics

1. **Upload Performance**
   - Photos per minute
   - Deduplication rate
   - Error rate

2. **Storage Efficiency**
   - Total storage used
   - Deduplication savings
   - Thumbnail cache hit rate

3. **User Experience**
   - Load times
   - Cache effectiveness
   - Network usage

### Logging

- Upload/download operations
- Deduplication events
- Cache hits/misses
- Error conditions

## Compliance and Privacy

### Data Protection

1. **Encryption**
   - TLS for transit
   - S3 server-side encryption
   - Local cache encryption (future)

2. **Access Control**
   - User-specific paths
   - No cross-user access
   - Audit logging

3. **Data Retention**
   - User-controlled deletion
   - Catalog history
   - Compliance with regulations

## Implementation Requirements

### ThumbnailCache Extensions

The current `ThumbnailCache` returns `CGImage` or file URLs. For S3 upload, we need JPEG `Data`:

```swift
extension ThumbnailCache {
    /// Get thumbnail as JPEG Data for S3 upload
    func getThumbnailData(for photoMD5: PhotoMD5, sourceURL: URL) async throws -> Data {
        let thumbnailURL = try await getThumbnail(for: photoMD5, sourceURL: sourceURL)
        return try Data(contentsOf: thumbnailURL)
    }
}
```

### CatalogDatabase CSV Support

**Important:** The current `CatalogDatabase` implementation is CSV-only, not SQLite:

```swift
// CatalogDatabase loads CSV directly into memory
let database = try await CatalogDatabase(path: csvPath, readOnly: true)
// The initializer reads CSV and populates an in-memory dictionary
// No SQLite conversion is needed
```

This design choice simplifies the implementation and removes SQLite dependencies for cloud catalogs.

## Appendix

### A. PTM-256 Thumbnail Specification

- Resolution: 256×256 pixels
- Format: JPEG
- Quality: 85%
- Color Space: sRGB
- Aspect Ratio: Maintain with center crop
- File Size: Target ~20KB
- **Data Access**: ThumbnailCache must provide method to return JPEG `Data` for upload

### B. Image Format Support

| Format | Extension | MIME Type | Support Status |
|--------|-----------|-----------|----------------|
| JPEG | .jpg/.jpeg | image/jpeg | ✅ Full |
| PNG | .png | image/png | ✅ Full |
| HEIF | .heic | image/heif | ✅ Full |
| TIFF | .tiff | image/tiff | ✅ Full |
| GIF | .gif | image/gif | ⚠️ Static only |
| RAW | Various | image/x-raw | 🔄 Planned |

### C. Environment Configuration

| Environment | Bucket | Region | Purpose |
|------------|---------|---------|----------|
| Development | photolala-dev | us-east-1 | Testing and development |
| Staging | photolala-stage | us-east-1 | Pre-production validation |
| Production | photolala-prod | us-east-1 | Live user data |

### D. Error Codes

| Code | Description | Recovery Action |
|------|-------------|-----------------|
| E001 | Network timeout | Retry with backoff |
| E002 | Invalid credentials | Check configuration |
| E003 | Bucket not found | Verify environment |
| E004 | MD5 mismatch | Re-compute and retry |
| E005 | Quota exceeded | Check storage limits |
| E006 | Format unsupported | Skip or convert |

---

*Last Updated: September 2024*
*Version: 1.0*
*Status: Implemented (Phase 1)*