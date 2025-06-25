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
- **No SQL database**
- Use JSON file: `~/Library/Application Support/Photolala/backup-state.json`
- Track uploaded files with path, date, size

[KY] No NoSQL - but may be SwiftData

### Security
- Store AWS credentials in macOS Keychain
- Use HTTPS for all transfers
- No custom encryption (use S3's)

[KY] option1:
  - user's apple-id ties to S3 credential
  - user signup own AWS credentials (unlikely)

### UI Requirements
- Simple SwiftUI view
- "Backup Folder" button
- Progress indicator
- Status text

[KY] i like user to select one / multiple/ or group of photos to backup to S3, so selectbly
- yah, but i could be pain for user

### What We're NOT Doing
- ❌ Multiple S3 providers
- ❌ Automatic backup
- ❌ Resume/pause
- ❌ Bandwidth throttling
- ❌ Client-side encryption
- ❌ Metadata extraction
- ❌ Intel support
- ❌ iOS support
- ❌ Background uploads
- ❌ Concurrent uploads

### Success Metrics
- Can connect to AWS S3
- Can upload a folder of photos
- Skips already uploaded files
- Shows progress
- Remembers state between launches

## That's It!

Keep it simple. Get it working. Add features later if needed.
