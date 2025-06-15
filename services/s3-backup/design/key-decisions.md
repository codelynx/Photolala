# Key Design Decisions - S3 Backup Service

## Storage Architecture

### MD5-Based Content Addressing
```
s3://photolala/{region}/{user-id}/photos/{md5}.dat
s3://photolala/{region}/{user-id}/thumbs/{md5}.dat  
s3://photolala/{region}/{user-id}/metadata/{md5}.plist
```

**Benefits:**
- Automatic deduplication (same photo = same MD5)
- Content verification built-in
- Simple, flat structure
- Cache-friendly paths

## Cost Optimization Strategy

### Storage Classes by Age & Importance

| Photo Type | Storage Class | Monthly Cost/TB | Access Time |
|------------|--------------|-----------------|-------------|
| < 2 years | STANDARD_IA | $12.50 | Instant |
| Starred | STANDARD_IA | $12.50 | Instant |
| > 2 years | DEEP_ARCHIVE | $0.99 | 12-48 hours |
| Thumbnails | STANDARD | $23.00 | Instant |

**Example:** 50GB of photos after 2 years = $0.20/month

### Smart Browsing
1. Always keep thumbnails in STANDARD storage
2. Sync thumbnails + metadata locally
3. Browse without downloading originals
4. Retrieve from archive only when needed

## User Experience

### Selective Backup
- Not folder-based, but selection-based
- Integrate with existing photo selection UI
- Right-click → "Backup to Cloud"
- Toolbar button for selected photos

### Service Options
1. **Photolala Service**: Apple ID authentication, managed S3
2. **BYO S3**: Advanced users bring own AWS credentials

## Technical Choices

### Data Storage
- **SwiftData** for local state (not JSON files)
- Track: MD5, upload date, storage class, star status

### Platform
- macOS 14+ on Apple Silicon only (Phase 1)
- No Intel support
- iOS later if needed

### Implementation Priorities
1. ✅ MD5 calculation and deduplication
2. ✅ Thumbnail generation
3. ✅ Basic S3 upload
4. ✅ SwiftData tracking
5. ✅ Storage class management
6. ⏳ Glacier retrieval UI
7. ⏳ Cost estimation

## Open Questions

1. **File Extensions**
   - Keep `.jpg` or use `.dat`?
   - Pros of `.dat`: Hides file type, consistent
   - Pros of extension: Easier debugging

2. **Metadata Format**
   - `.plist` (Apple native) vs `.json` (universal)?
   - Include EXIF or just basics?

3. **Thumbnail Sizes**
   - Single size (256x256)?
   - Multiple sizes for different views?

4. **Service Integration**
   - How to link Apple ID → S3 access?
   - Billing through App Store?
   - Free tier limits?

## Success Metrics

- **Cost**: < $1/month for average user (10K photos)
- **Performance**: Browse instantly via thumbnails
- **Reliability**: MD5 ensures data integrity
- **Simplicity**: Selective backup, not complex sync