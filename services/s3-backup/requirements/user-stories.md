# S3 Backup Service User Stories

## Epic: Cloud Backup for Photos

As a Photolala user, I want to backup my photos to cloud storage so that I can protect my memories and access them from anywhere.

## User Stories

### 1. Initial Setup

**US-1.1: Provider Selection**
- As a user, I want to choose my S3 storage provider from a list of popular options
- **Acceptance Criteria:**
  - Show presets for AWS S3, Backblaze B2, Wasabi, MinIO
  - Allow custom S3-compatible endpoint
  - Provide brief description of each provider
  - Link to pricing information

**US-1.2: Authentication**
- As a user, I want to securely connect to my S3 account
- **Acceptance Criteria:**
  - Enter access key and secret key
  - Credentials stored securely in system keychain
  - Test connection button
  - Clear error messages for auth failures

**US-1.3: Bucket Setup**
- As a user, I want to select or create a bucket for my photos
- **Acceptance Criteria:**
  - List existing buckets
  - Create new bucket with valid name
  - Select region (if applicable)
  - Warn about potential costs

### 2. Backup Configuration

**US-2.1: Folder Selection**
- As a user, I want to choose which folders to backup
- **Acceptance Criteria:**
  - Browse and select multiple folders
  - See folder sizes and photo counts
  - Remember selections between sessions
  - Quick enable/disable per folder

**US-2.2: Exclude Rules**
- As a user, I want to exclude certain files from backup
- **Acceptance Criteria:**
  - Exclude by file extension
  - Exclude by file size
  - Exclude hidden files option
  - Exclude specific folders

**US-2.3: Backup Schedule**
- As a user, I want to control when backups happen
- **Acceptance Criteria:**
  - Manual backup only
  - Automatic on file change
  - Scheduled intervals (hourly, daily, weekly)
  - Pause/resume capability

### 3. Backup Operations

**US-3.1: Initial Backup**
- As a user, I want to perform my first backup
- **Acceptance Criteria:**
  - Clear progress indication
  - Time remaining estimate
  - Ability to pause/cancel
  - Continue after app restart

**US-3.2: Incremental Backup**
- As a user, I want only new/changed photos to be backed up
- **Acceptance Criteria:**
  - Detect new photos automatically
  - Detect modified photos
  - Skip already uploaded photos
  - Show what will be uploaded

**US-3.3: Upload Progress**
- As a user, I want to see detailed progress of uploads
- **Acceptance Criteria:**
  - Overall progress percentage
  - Current file being uploaded
  - Upload speed
  - Files remaining
  - Estimated time to completion

### 4. Bandwidth Management

**US-4.1: Bandwidth Limits**
- As a user, I want to limit upload bandwidth
- **Acceptance Criteria:**
  - Set maximum upload speed
  - Different limits for different times
  - Pause uploads when on metered connection
  - Resume when conditions improve

**US-4.2: Concurrent Uploads**
- As a user, I want to control how many files upload at once
- **Acceptance Criteria:**
  - Configurable concurrent upload count
  - Default based on connection speed
  - Adjust based on file sizes
  - Prevent system overload

### 5. Status and Monitoring

**US-5.1: Backup Status**
- As a user, I want to see the current backup status at a glance
- **Acceptance Criteria:**
  - Status icon in toolbar/menu
  - Quick stats on hover
  - Click for detailed view
  - Color coding for status

**US-5.2: Backup History**
- As a user, I want to see what has been backed up
- **Acceptance Criteria:**
  - List of recent uploads
  - Search backed up files
  - See upload dates
  - Verify file is in cloud

**US-5.3: Storage Usage**
- As a user, I want to track my cloud storage usage
- **Acceptance Criteria:**
  - Total space used
  - Number of photos stored
  - Growth over time
  - Cost estimation (if possible)

### 6. Error Handling

**US-6.1: Upload Failures**
- As a user, I want failed uploads to retry automatically
- **Acceptance Criteria:**
  - Automatic retry with backoff
  - Clear error messages
  - Option to skip problematic files
  - Log of failed uploads

**US-6.2: Connection Issues**
- As a user, I want backups to resume after connection problems
- **Acceptance Criteria:**
  - Detect connection loss
  - Pause uploads gracefully
  - Resume when connected
  - No duplicate uploads

### 7. Data Management

**US-7.1: Metadata Preservation**
- As a user, I want photo metadata to be preserved
- **Acceptance Criteria:**
  - EXIF data retained
  - File dates preserved
  - Folder structure maintained
  - Custom tags supported (future)

**US-7.2: Verification**
- As a user, I want to verify my backups are complete
- **Acceptance Criteria:**
  - Checksum verification
  - Compare local vs cloud
  - Identify missing files
  - Repair incomplete uploads

### 8. Security and Privacy

**US-8.1: Encryption**
- As a user, I want my photos encrypted in the cloud
- **Acceptance Criteria:**
  - Server-side encryption option
  - Client-side encryption option
  - Key management guidance
  - Performance impact warning

**US-8.2: Access Control**
- As a user, I want to ensure my photos remain private
- **Acceptance Criteria:**
  - Private bucket by default
  - No public URLs generated
  - Secure credential storage
  - Option to revoke access

## Future User Stories (Post-MVP)

### Download and Restore
- Download individual photos
- Restore entire folders
- Disaster recovery

### Sync Features
- Two-way sync option
- Conflict resolution
- Delete propagation

### Sharing
- Generate secure share links
- Time-limited access
- Password protection

### Advanced Features
- Smart previews in cloud
- Search cloud photos
- Face/object recognition
- Deduplication

## Priority Matrix

| Priority | Phase 1 (MVP) | Phase 2 | Phase 3 |
|----------|--------------|---------|---------|
| High | US-1.1, US-1.2, US-1.3, US-2.1, US-3.1, US-3.3, US-5.1 | US-2.2, US-3.2, US-4.1, US-6.1 | US-7.2, US-8.1 |
| Medium | US-5.2 | US-2.3, US-4.2, US-6.2, US-7.1 | US-8.2 |
| Low | | US-5.3 | Future stories |