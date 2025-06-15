# S3 Backup Service - Simple Technical Requirements

## Phase 1 Only

### Platform
- macOS 14.0+ (Sonoma)
- Apple Silicon only
- No iOS support

### Dependencies
- AWS SDK for Swift
- macOS Keychain (for credentials)
- Foundation framework

### S3 Operations Needed
1. `ListBuckets` - Show available buckets
2. `PutObject` - Upload photos
3. `HeadObject` - Check if already uploaded

### Data Storage
- **Use SwiftData** (not JSON files)
- Track uploaded photos with MD5, date, size
- Store thumbnail sync state
- Remember user preferences

### Security
- **Option 1**: Photolala Service (Apple ID → S3 credentials)
- **Option 2**: User's own AWS credentials (power users)
- Store credentials in macOS Keychain
- Use HTTPS for all transfers
- Server-side encryption (SSE-S3)

### UI Requirements
- Integration with photo selection
- "Backup Selected" button in toolbar
- Right-click → "Backup to Cloud"
- Progress sheet with details
- Cloud badge on backed-up photos
- Cost estimation display

### What We're NOT Doing (Phase 1)
- ❌ Multiple S3 providers
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
2. Leverages storage classes for cost optimization
3. Enables browsing via thumbnails
4. Integrates with photo selection
5. Keeps it simple!
