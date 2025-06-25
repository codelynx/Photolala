# Key Design Decisions - S3 Backup Service

## Storage Architecture

### MD5-Based Content Addressing
```
s3://photolala/photos/{user-id}/{md5}.dat
s3://photolala/thumbnails/{user-id}/{md5}.dat  
s3://photolala/metadata/{user-id}/{md5}.plist
```

**Benefits:**
- Automatic deduplication (same photo = same MD5)
- Content verification built-in
- Simple, flat structure
- Cache-friendly paths
- Universal references for stars/labels (MD5 only)
- Catalog files for efficient browsing

## Cost Optimization Strategy

### Universal 180-Day Archive Policy

| Content Type | Storage Class | Lifecycle | Monthly Cost/TB | Access Time |
|------------|--------------|-----------|-----------------|-------------|
| Photos < 180 days | STANDARD | - | $23.00 | Instant |
| Photos > 180 days | DEEP_ARCHIVE | Auto-transition | $0.99 | 12-48 hours |
| Thumbnails | INTELLIGENT_TIERING | Immediate | $12.50 | Instant |
| Metadata | STANDARD | Always | $23.00 | Instant |

**Cost Example (1TB):**
- Photos: ~$1.10/month (mostly Deep Archive)
- Thumbnails (41GB): ~$0.50/month 
- Metadata (10GB): ~$0.23/month
- Total: ~$1.83/month

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

### Service Model
- **Photolala-Managed Only**: Service tied to Apple ID
- Fixed region: us-east-1 for simplicity
- No user AWS credentials needed
- Subscription tiers aligned with Apple standards

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
2. ✅ EXIF extraction
3. ✅ Thumbnail generation (400x400)
4. ✅ Basic S3 upload with AWS SDK
5. ✅ SwiftData for local state
6. ✅ Lambda for catalog updates
7. ⏳ Deep Archive retrieval UI
8. ⏳ Subscription billing integration

## Resolved Decisions

1. **File Format**: `.dat` for all photos (type-agnostic)
2. **Metadata**: `.plist` format with full EXIF data
3. **Thumbnails**: 
   - Follow existing app standards (256px min dimension, 512px max)
   - Approximately 0.4-0.5% of original photo size
   - Average 30KB per thumbnail (15-50KB range)
4. **Billing**: Apple subscription tiers via App Store
5. **Authentication**: Apple ID → Photolala API → STS tokens

## Pricing Strategy

### Tier Structure (Universal 180-Day Archive)

| Tier | Price | Photo Storage | Total Storage | Archive Policy | Margin |
|------|-------|---------------|---------------|----------------|--------|
| Free | $0 | 5GB | ~5.2GB | 180 days | - |
| Starter | $0.99 | 500GB | ~525GB | 180 days | 45% |
| Essential | $1.99 | 1TB | ~1.08TB | 180 days | 22% |
| Plus | $2.99 | 2TB | ~2.15TB | 180 days | 40% |
| Family | $5.99 | 5TB | ~5.25TB | 180 days | 35% |

**Key Change:** All tiers use the same 180-day archive policy. Differentiation is by storage quota only.

### Key Pricing Decisions
1. **Aggressive use of DEEP_ARCHIVE** for cost control
2. **Thumbnail browsing** as primary UX (always fast)
3. **Tiered recent access** (0, 6mo, 1yr, 2yr)
4. **$1.99 sweet spot** for mainstream adoption
5. **Consumer-focused naming** (no "Pro" - saves for business)
6. **Future professional tiers** at $19.99+ for studios/agencies

## Success Metrics

- **Cost**: < $1/month for average user (10K photos)
- **Performance**: Browse instantly via thumbnails
- **Reliability**: MD5 ensures data integrity
- **Simplicity**: Selective backup, not complex sync