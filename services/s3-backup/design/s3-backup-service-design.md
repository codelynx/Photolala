# S3 Backup Service Design

Version: 0.1.0  
Date: June 15, 2025  
Status: Draft

## Table of Contents

1. [Introduction](#introduction)
2. [Requirements](#requirements)
3. [Architecture Overview](#architecture-overview)
4. [Core Components](#core-components)
5. [Data Flow](#data-flow)
6. [Security Model](#security-model)
7. [Configuration](#configuration)
8. [User Experience](#user-experience)
9. [Implementation Phases](#implementation-phases)
10. [Open Questions](#open-questions)

## Introduction

The S3 Backup Service provides Photolala users with the ability to automatically backup their photo collections to S3-compatible cloud storage services. This design focuses on reliability, efficiency, and user privacy.

## Requirements

### Functional Requirements

1. **Backup Management**
   - Automatic backup of new/modified photos
   - Manual backup triggers
   - Selective folder backup
   - Exclude patterns (file types, sizes, folders)

2. **Storage Providers**
   - Support standard S3 API
   - Provider presets (AWS S3, Backblaze B2, Wasabi, MinIO)
   - Custom endpoint configuration
   - Multi-bucket support

3. **Transfer Features**
   - Resumable uploads
   - Bandwidth throttling
   - Parallel uploads (configurable)
   - Progress tracking
   - Error retry with exponential backoff

4. **Data Organization**
   - Preserve folder structure
   - Maintain file metadata
   - Support for photo metadata (EXIF, XMP)
   - Versioning support (optional)

### Non-Functional Requirements

1. **Performance**
   - Minimal impact on app performance
   - Efficient memory usage
   - Smart chunking for large files

2. **Reliability**
   - Handle network interruptions
   - Crash recovery
   - Data integrity verification (checksums)

3. **Security**
   - Encrypted transfers (TLS)
   - Secure credential storage
   - Optional client-side encryption

4. **Usability**
   - Simple setup wizard
   - Clear status indicators
   - Meaningful error messages

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Photolala App                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │   UI Layer  │  │ Photo Browser │  │  Preferences  │ │
│  └──────┬──────┘  └──────┬───────┘  └───────┬───────┘ │
│         │                │                   │         │
│  ┌──────▼───────────────▼───────────────────▼───────┐ │
│  │            Backup Service Manager                 │ │
│  └──────┬───────────────┬───────────────────┬───────┘ │
│         │               │                   │         │
│  ┌──────▼──────┐ ┌──────▼──────┐  ┌────────▼──────┐ │
│  │   Upload    │ │   Sync      │  │   Metadata    │ │
│  │   Queue     │ │   Engine    │  │   Manager     │ │
│  └──────┬──────┘ └──────┬──────┘  └────────┬──────┘ │
│         │               │                   │         │
│  ┌──────▼───────────────▼───────────────────▼───────┐ │
│  │              S3 Client Abstraction                │ │
│  └──────────────────────┬───────────────────────────┘ │
│                         │                             │
└─────────────────────────┼─────────────────────────────┘
                          │
                    ┌─────▼─────┐
                    │  S3 API   │
                    └───────────┘
```

## Core Components

### 1. Backup Service Manager
- Central coordinator for all backup operations
- Manages service lifecycle
- Handles configuration changes
- Provides status updates to UI

### 2. Upload Queue
- Maintains queue of files to upload
- Prioritizes uploads (new files first)
- Handles retry logic
- Persists queue state

### 3. Sync Engine
- Compares local and remote state
- Determines what needs backing up
- Handles conflict resolution
- Manages deletion propagation (optional)

### 4. Metadata Manager
- Extracts and packages photo metadata
- Creates sidecar files for metadata
- Handles metadata versioning
- Manages thumbnail generation for quick previews

### 5. S3 Client Abstraction
- Wraps S3 SDK functionality
- Provides consistent interface
- Handles provider-specific quirks
- Manages authentication and sessions

## Data Flow

### Upload Flow
1. File watcher detects new/modified photo
2. Photo added to upload queue
3. Metadata extracted and prepared
4. File uploaded in chunks
5. Checksum verified
6. Local database updated
7. UI notified of completion

### Download Flow (Future)
1. User requests photo/folder
2. Check local cache
3. Download from S3 if needed
4. Verify integrity
5. Update local cache
6. Display to user

## Security Model

### Credential Management
- Credentials stored in system keychain
- Support for IAM roles (AWS)
- Temporary credentials with refresh
- API keys never logged

### Data Protection
- All transfers use TLS
- Optional client-side encryption
- Encryption key derivation from user passphrase
- Zero-knowledge architecture option

### Access Control
- Minimal S3 permissions required
- Bucket-specific policies
- No public access by default
- Audit logging support

## Configuration

### Provider Configuration
```yaml
provider:
  type: "s3"  # or "b2", "wasabi", "minio"
  endpoint: "https://s3.amazonaws.com"
  region: "us-east-1"
  bucket: "my-photos-backup"
  
credentials:
  access_key_id: "stored-in-keychain"
  secret_access_key: "stored-in-keychain"
  
options:
  storage_class: "STANDARD_IA"
  encryption: "AES256"
  versioning: true
```

### Backup Configuration
```yaml
backup:
  folders:
    - path: "/Photos/Family"
      enabled: true
    - path: "/Photos/Work"
      enabled: false
      
  exclude:
    patterns:
      - "*.tmp"
      - ".*"
    max_file_size: "5GB"
    
  schedule:
    mode: "automatic"  # or "manual"
    interval: "hourly"
    
  bandwidth:
    max_upload_rate: "10MB/s"
    concurrent_uploads: 3
```

## User Experience

### Initial Setup
1. **Provider Selection**
   - Choose from preset providers
   - Or configure custom S3 endpoint

2. **Authentication**
   - Enter credentials
   - Test connection
   - Select/create bucket

3. **Folder Selection**
   - Choose folders to backup
   - Set exclude rules
   - Configure options

4. **Start Backup**
   - Initial scan
   - Progress indication
   - Completion notification

### Ongoing Usage
- Status bar icon shows sync status
- Click for detailed progress
- Pause/resume capability
- History of recent uploads

### Settings Panel
- Provider configuration
- Folder management
- Bandwidth controls
- Storage usage stats
- Backup history

## Implementation Phases

### Phase 1: Foundation (MVP)
- Basic S3 client implementation
- Simple upload queue
- Manual backup trigger
- AWS S3 support only
- Basic progress reporting

### Phase 2: Enhanced Features
- Multiple provider support
- Automatic backup
- Bandwidth throttling
- Resumable uploads
- Metadata preservation

### Phase 3: Advanced Features
- Selective sync
- Client-side encryption
- Versioning support
- Conflict resolution
- Download/restore capability

### Phase 4: Optimization
- Deduplication
- Compression options
- Smart caching
- Delta sync
- Performance tuning

## Open Questions

1. **Licensing**: Which S3 SDK to use? Native AWS SDK or alternative?
2. **Threading**: Background upload strategy on macOS/iOS?
3. **Storage**: Local database for tracking uploaded files?
4. **UI Integration**: Separate window or integrated panel?
5. **Pricing**: How to help users estimate costs?
6. **Thumbnails**: Generate and store thumbnails in S3?
7. **Sharing**: Future support for generating share links?
8. **Mobile**: iOS background upload limitations?

## Next Steps

1. Gather feedback on design
2. Research S3 SDK options
3. Create detailed API specifications
4. Design UI mockups
5. Plan Phase 1 implementation