# S3 Backup Service Design (Simplified)

Version: 0.2.0
Date: June 15, 2025
Status: Draft
Philosophy: Start simple, evolve as needed

## Table of Contents

1. [Introduction](#introduction)
2. [Core Principles](#core-principles)
3. [Minimal Requirements](#minimal-requirements)
4. [Simple Architecture](#simple-architecture)
5. [Data Storage](#data-storage)
6. [Basic Flow](#basic-flow)
7. [User Experience](#user-experience)
8. [Implementation Plan](#implementation-plan)
9. [Future Considerations](#future-considerations)

## Introduction

A simple, reliable way to backup photos to S3-compatible storage. Start with the basics, add complexity only when needed.

## Core Principles

1. **Simple First** - Basic upload functionality before advanced features
2. **No Databases** - Use simple file-based tracking
3. **Apple Silicon Only** - Optimize for modern Macs
4. **Minimal Dependencies** - Use native frameworks where possible
5. **User Control** - Manual backup first, automation later

## Minimal Requirements

### Phase 1: Basic Backup (MVP)

1. **Connect to S3**
   - Single S3 provider (start with AWS S3)
   - Enter credentials
   - Select bucket

2. **Upload Photos**
   - Manual "Backup This Folder" button
   - Upload one folder at a time
   - Show progress

3. **Track Uploads**
   - Simple file to track what's uploaded
   - Skip already uploaded files
   - Basic retry on failure

### Phase 2: Improvements (Later)

- Multiple providers
- Automatic backup
- Folder watching
- Bandwidth limits

### Phase 3: Advanced (Much Later)

- Encryption
- Metadata preservation
- Selective sync
- Versioning

## Simple Architecture

```
┌─────────────────────────────────────┐
│         Photolala App               │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────┐  ┌──────────────┐ │
│  │   Backup    │  │   Progress   │ │
│  │   Button    │  │     View     │ │
│  └──────┬──────┘  └──────▲───────┘ │
│         │                 │         │
│  ┌──────▼─────────────────┴───────┐ │
│  │      Simple Backup Service     │ │
│  │  - Upload photos               │ │
│  │  - Track progress              │ │
│  │  - Remember uploaded files     │ │
│  └──────────────┬─────────────────┘ │
│                 │                   │
└─────────────────┼───────────────────┘
                  │
            ┌─────▼─────┐
            │  AWS S3   │
            └───────────┘
```

## Data Storage

### MD5-Based Storage Structure

Photos are stored using content-based addressing with MD5 hashes:

```
s3://photolala/
├── {region}/
│   └── {user-id}/
│       ├── photos/
│       │   └── {md5}.dat           # Original photo
│       ├── thumbs/
│       │   └── {md5}.dat           # Thumbnail image
│       └── metadata/
│           └── {md5}.plist         # Photo metadata
```

Example:
- Photo: `s3://photolala/us-west-2/user123/photos/d41d8cd98f00b204e9800998ecf8427e.dat`
- Thumb: `s3://photolala/us-west-2/user123/thumbs/d41d8cd98f00b204e9800998ecf8427e.dat`
- Info: `s3://photolala/us-west-2/user123/metadata/d41d8cd98f00b204e9800998ecf8427e.plist`

### Benefits of MD5 Structure
- **Deduplication**: Same photo uploaded twice = one storage
- **Content verification**: MD5 serves as checksum
- **Flat structure**: No deep folder hierarchies
- **Cache friendly**: Predictable paths

### Local Tracking

SwiftData model to track uploads:
```swift
@Model
class UploadedPhoto {
    let localPath: String
    let md5: String
    let uploadDate: Date
    let size: Int64
    let isStarred: Bool = false
    let lastAccessDate: Date?
}
```

## Storage Class Strategy

### Cost-Optimized Storage Tiers

1. **Recent & Starred Photos** (< 2 years or starred)
   - Storage Class: `STANDARD` or `STANDARD_IA`
   - Quick access for browsing
   - Thumbnails always in STANDARD

2. **Archive Photos** (> 2 years, not starred)
   - Storage Class: `GLACIER_DEEP_ARCHIVE`
   - 12-48 hour retrieval time acceptable
   - Dramatic cost savings (~$1/TB/month)

3. **Smart Browsing**
   - Download thumbnails + metadata first
   - Browse photos without downloading originals
   - Request full photo only when needed

### Example Lifecycle Policy
```xml
<LifecycleConfiguration>
    <Rule>
        <ID>ArchiveOldPhotos</ID>
        <Status>Enabled</Status>
        <Transition>
            <Days>730</Days> <!-- 2 years -->
            <StorageClass>DEEP_ARCHIVE</StorageClass>
        </Transition>
    </Rule>
</LifecycleConfiguration>
```

## Basic Flow

### Upload Process (Phase 1)
1. User selects photos to backup
2. For each photo:
   - Calculate MD5 hash
   - Check if already uploaded
   - Generate thumbnail
   - Upload: photo, thumbnail, metadata
   - Update SwiftData
3. Show progress

### Browsing Flow
1. Sync thumbnails + metadata to local
2. Display grid using local thumbnails
3. On photo select:
   - Check if local copy exists
   - If in DEEP_ARCHIVE, show retrieval UI
   - Otherwise, download and display

## User Experience

### Phase 1: Setup
1. **Service Configuration**
   - Option 1: User's Apple ID tied to Photolala S3 service
   - Option 2: User provides own AWS credentials (advanced)
   - Choose region for data residency
   - Test connection

2. **Selective Backup UI**
   ```
   ┌─────────────────────────────┐
   │  Cloud Backup               │
   ├─────────────────────────────┤
   │                             │
   │  Status: Ready              │
   │  Storage: 45 GB used        │
   │                             │
   │  [Backup Selected] (23)     │
   │  [Backup Current Folder]    │
   │                             │
   │  ☁️ 1,234 photos backed up  │
   │  💰 Est. cost: $2.50/month  │
   │                             │
   └─────────────────────────────┘
   ```

3. **Selection Integration**
   - Use existing photo selection
   - Right-click → "Backup to Cloud"
   - Toolbar button when photos selected
   - Show cloud badge on backed-up photos

### Credentials
- Photolala Service: Tied to Apple ID
- Custom S3: Store in macOS Keychain
- Never in files or logs

## Implementation Plan

### Step 1: Basic S3 Connection (Week 1)
- Use AWS SDK for Swift
- Connect to S3
- List buckets
- Upload single file

### Step 2: Folder Backup (Week 2)
- Scan folder for photos
- Upload each photo
- Track progress
- Update JSON state file

### Step 3: Skip Duplicates (Week 3)
- Check JSON before upload
- Compare file size/date
- Skip if already uploaded

### Step 4: Basic UI (Week 4)
- Simple SwiftUI view
- Backup button
- Progress display
- Status text

## Future Considerations

Things we're NOT doing in Phase 1:
- ❌ Multiple providers (just AWS S3)
- ❌ Automatic backup (manual only)
- ❌ Encryption (use S3's encryption)
- ❌ Metadata extraction (just upload files)
- ❌ Resume/pause (simple upload only)
- ❌ Bandwidth limits (full speed)
- ❌ Intel support (Apple Silicon only)

These can be added later if needed.

## Key Design Decisions

1. **MD5-based storage**: Content-addressed for deduplication
2. **Storage classes**: Recent/starred in STANDARD, old in DEEP_ARCHIVE
3. **Selective backup**: Not whole folders, but selected photos
4. **Browse without download**: Use thumbnails + metadata
5. **SwiftData**: For local state tracking (not JSON files)

## Success Criteria

Phase 1 is successful if:
- User can backup selected photos
- MD5 deduplication works
- Thumbnails enable fast browsing
- Storage costs are minimized
- Progress and status are clear

## Cost Example

For 10,000 photos (50GB):
- First 2 years: ~$1.15/month (STANDARD_IA)
- After 2 years: ~$0.05/month (DEEP_ARCHIVE)
- Thumbnails: ~$0.10/month (always STANDARD)
- **Total: < $0.20/month for old photo archive**

## Open Design Questions

1. **Naming convention**: 
   - `{md5}.dat` vs `{md5}.jpg` for photos?
   - `.plist` vs `.json` for metadata?
   
2. **Thumbnail size**: 
   - 256x256 or 512x512?
   - Multiple sizes?

3. **Photolala Service**:
   - How to tie Apple ID to S3 credentials?
   - Billing integration?
   - Free tier limits?
