# S3 Backup Service - Simple Technical Requirements

## Phase 1 Only

### Platform
- macOS 14.0+ (Sonoma)
- Apple Silicon only
- No iOS support

### Dependencies
- AWS SDK for Swift
- SwiftData for local state
- Foundation framework
- CoreImage (thumbnail generation)
- ImageIO (EXIF extraction)

### S3 Operations Needed
1. `PutObject` - Upload photos, thumbnails, metadata
2. `GetObject` - Download thumbnails and catalogs
3. `ListObjectsV2` - List user's photos (backup use)
4. `RestoreObject` - Restore from Deep Archive
5. Lambda triggers for catalog updates

### Data Storage
- **Use SwiftData** (not JSON files)
- Track uploaded photos with MD5, date, size
- Store thumbnail sync state
- Remember user preferences

### Security
- **Photolala-Managed Service Only**
- Apple ID authentication
- Backend API exchanges for STS tokens
- No local credential storage
- HTTPS/TLS 1.3 for all transfers
- Server-side encryption (SSE-S3)
- Per-user S3 prefix isolation

### UI Requirements
- Integration with photo selection
- "Backup Selected" button in toolbar
- Right-click → "Backup to Cloud"
- Progress sheet with details
- Cloud badge on backed-up photos
- Cost estimation display

### What We're NOT Doing (Phase 1)
- ❌ User's own AWS credentials
- ❌ Multiple regions (us-east-1 only)
- ❌ Automatic backup
- ❌ Client-side encryption
- ❌ Intel support
- ❌ iOS support
- ❌ Background uploads

### Success Metrics
- Can backup selected photos
- MD5 deduplication works
- Thumbnails sync for browsing
- Deep Archive for old photos
- Cost stays under $1/month for most users

## Summary

Build a cost-effective cloud backup that:
1. Uses MD5 for deduplication
2. Leverages storage classes (STANDARD_IA → DEEP_ARCHIVE)
3. Enables browsing via thumbnails without downloading originals
4. Integrates with existing photo selection UI
5. Photolala-managed service tied to Apple ID
6. Simple subscription tiers aligned with Apple standards
