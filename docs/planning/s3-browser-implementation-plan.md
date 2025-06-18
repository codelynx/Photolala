# S3 Photo Browser Implementation Plan

## Phase 1: Foundation (Week 1)

### 1. Create `.photolala` Catalog System
```swift
// Models/PhotoCatalog.swift
struct PhotoCatalog: Codable {
    let version: String
    let created: Date
    let photos: [String: CatalogEntry] // MD5 -> Entry
}

struct CatalogEntry: Codable {
    let md5: String
    let size: Int64
    let photoDate: Date
    let path: String
    let storageClass: String
    let isArchived: Bool
}
```

### 2. Add S3 Catalog Management
- Generate catalog after backup operations
- Upload to `s3://photolala/catalog/{userId}/.photolala`
- Download and cache locally
- Incremental updates

### 3. Update Local Browser
- Load `.photolala` if exists in directory
- Show backup status badges on photos
- Fast MD5-based lookup

## Phase 2: S3 Browser View (Week 2)

### 1. Create Dedicated S3 Browser
- New menu: "File → Browse Cloud Backup"
- Separate window from local browser
- Load photos from catalog first
- Fetch thumbnails as needed

### 2. Thumbnail Management
- Check local thumbnail cache first
- Download from S3 if missing
- LRU eviction when cache full
- Progress indicators

### 3. Photo Detail View
- Show full metadata
- Archive status indication
- Restore button for archived
- Download original option

## Phase 3: Polish & Performance (Week 3)

### 1. Offline Support
- Full catalog-based browsing
- Show cached thumbnails
- Indicate what needs internet
- Sync status in UI

### 2. Performance Optimization
- Virtualized grid (only render visible)
- Thumbnail prefetching
- Catalog pagination for 100K+ photos
- Memory usage monitoring

### 3. User Experience
- Search by date/metadata
- Sort options
- Bulk operations
- Export catalog

## Key Design Decisions

1. **Clear Separation**: S3 browser is completely separate from local browser
2. **Catalog-First**: Always use catalog for listing, S3 API only for downloads
3. **Smart Caching**: Balance between performance and storage use
4. **Offline-Ready**: Full functionality with catalog + cached thumbnails

## Success Criteria

- S3 browser opens instantly (catalog-based)
- Thumbnails load within 500ms (cached) or 2s (S3)
- Works offline with degraded functionality
- Handles 100K+ photos smoothly
- Clear backup status in local browser