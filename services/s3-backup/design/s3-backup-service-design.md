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
   - Photolala-managed S3 service only
   - Fixed region: us-east-1 (simplest)
   - No user configuration needed

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
├── users/
│   └── {user-id}/
│       ├── photos/
│       │   └── {md5}.dat           # Original photo
│       ├── thumbs/
│       │   └── {md5}.dat           # Thumbnail image
│       ├── metadata/
│       │   └── {md5}.plist         # Photo metadata
│       └── catalogs/               # Browse catalogs
│           ├── 2024/
│           │   └── january.plist   # Monthly catalog
│           └── recent.plist        # Last 30 days
└── service/
    └── config.plist               # Service configuration


### Benefits of MD5 Structure
- **Deduplication**: Same photo uploaded twice = one storage
- **Content verification**: MD5 serves as checksum
- **Flat structure**: No deep folder hierarchies
- **Cache friendly**: Predictable paths
- **Universal references**: Stars, bookmarks, and labels reference MD5 only
  - No need to store with photo data
  - Works across devices and restores

### Local Tracking

Lightweight SwiftData models focused on catalogs:

```swift
@Model
class PhotoCatalog {
    let md5: String
    let uploadDate: Date
    let size: Int64
    let storageClass: String
    // Cached from metadata
    var captureDate: Date?
    var thumbnailData: Data?
}

@Model
class PhotoLabel {
    let md5: String
    let type: LabelType  // star, bookmark, custom
    let value: String?
    let createdAt: Date
}
```

## Storage Class Strategy

### Cost-Optimized Storage Tiers

Optimized storage strategy for cost-effective long-term backup:

- **STANDARD_IA**: Photos from the last 2 years
  - Quick access for recent memories
  - $0.004/GB per month ($4/TB/month)
- **DEEP_ARCHIVE**: Photos older than 2 years  
  - Long-term preservation at minimal cost
  - $0.00099/GB per month ($0.99/TB/month)
  - 88% cost savings vs STANDARD_IA

#### Cost Example (100,000 photos = 1TB)
- Recent photos (STANDARD_IA): $48/year
- Archived photos (DEEP_ARCHIVE): $12/year
- Thumbnails (4-5GB in STANDARD): $12/year
- Blended cost for typical user: ~$20-30/year

### Deep Archive UX Design

#### Core Principles
- **Browse Everything**: Thumbnails always available instantly
- **Clear Communication**: Archive status visible but not intrusive
- **Batch Efficiency**: Encourage album/event retrieval over singles
- **Cost Transparency**: Always show retrieval costs upfront

#### Visual Indicators
- 🕐 Small clock badge on archived photos
- Slight dimming (90% opacity) in grid view
- Progress bars for retrieval status
- Expiration warnings for retrieved photos

#### Retrieval Flow
1. **Discover**: User clicks archived photo
2. **Credit Check**: Show size and credit cost:
   ```
   Europe Trip (485 photos, 4.8GB)
   Cost: 48 credits
   Your balance: 50 credits
   After retrieval: 2 credits
   
   💡 Tip: Retrieve in batches to
      maximize your credit usage
   ```
3. **Options**: Standard (2-3 days) or Express (1 day, 2x credits)
4. **Confirm**: Deduct credits or prompt to purchase more
5. **Progress**: Track retrieval status
6. **Notify**: Email + push when ready
7. **Access**: 30-day window, then auto re-archive

#### Smart Features
- Seasonal suggestions (holidays, anniversaries)
- "Retrieve together" for related photos
- Cost savings dashboard
- Predictive retrieval for upcoming events

See [Deep Archive UX Stories](./deep-archive-ux-stories.md) for detailed user journeys.

### Thumbnail Storage Efficiency
- **Storage ratio**: Thumbnails are ~0.4-0.5% of original size
- **1GB photos** → ~4-5MB thumbnails
- **1TB photos** → ~4-5GB thumbnails
- Always kept in STANDARD storage for instant access

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
   - Check if already uploaded (via catalog)
   - Extract EXIF metadata
   - Generate thumbnail (using existing app standards: 256px min, 512px max)
   - Upload: photo → thumbnail → metadata
   - Trigger Lambda to update catalog
3. Show progress with time estimates

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
   - User's Apple ID tied to Photolala S3 service
   - Fixed us-east-1 region (simplest)
   - Automatic connection test

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
- Secure token exchange with backend
- Never stored locally

## Implementation Plan

### Step 1: Basic S3 Connection (Week 1)
- AWS SDK for Swift (simpler than HTTP API)
- Connect to S3 with Photolala credentials
- Upload single file
- Lambda function to update catalog files

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
- First 2 years: ~$0.20/month (STANDARD_IA)
- After 2 years: ~$0.05/month (DEEP_ARCHIVE)
- Thumbnails: ~$0.05/month (always STANDARD, ~200MB)
- **Total: < $0.10/month for old photo archive**

### Thumbnail Storage Estimates
- **1GB photos** → ~4-5MB thumbnails (0.4-0.5%)
- **1TB photos** → ~4-5GB thumbnails
- Compression: JPEG 80-85% quality
- Dimensions: 256px min, 512px max

## Pricing Model

### Final Pricing Strategy

| Tier | Price | Storage | Hot Window | Credits (GB) | Target Market |
|------|-------|---------|------------|--------------|---------------|
| Starter | $0.99 | 200GB | 7 days | 20 (2GB) | Trial users |
| **Essential** | **$1.99** | **1TB** | **14 days** | **50 (5GB)** | **Most users** |
| Plus | $2.99 | 1.5TB | 21 days | 100 (10GB) | Power users |
| Family | $5.99 | 5TB | 30 days | 200 (20GB) | Families |

**Key Innovation**: Recent photos (within hot window) are instant access. Older photos require 12-24 hour retrieval. This enables 10X more storage at 70% lower cost than competitors.

See [Final Pricing Strategy](./FINAL-pricing-strategy.md) for full analysis.

### Photo Credits System

#### How Credits Work
- **1 credit = 100MB** (clean, simple ratio)
- Credits included monthly with subscription
- Unused credits roll over (up to 3 months)
- Purchase additional credits via In-App Purchase
- Minimum charge: 1 credit (even for small files)

#### Credit Usage Examples
| Retrieval Type | Size | Credits |
|----------------|------|----------|
| Few photos | < 100MB | 1 |
| Small album | 500MB | 5 |
| Large album | 2GB | 20 |
| Wedding photos | 5GB | 50 |
| Year archive | 50GB | 500 |
| Express delivery | Same | 2x credits |

#### Additional Credits (IAP)
- 10 credits (1GB): $0.99
- 50 credits (5GB): $3.99  
- 100 credits (10GB): $6.99
- 500 credits (50GB): $24.99

### Future Professional Tiers (Phase 2)

| Tier | Price | Storage | Features | Target |
|------|-------|---------|----------|--------|
| Studio | $19.99 | 5TB | All in STANDARD_IA, API access | Photo studios |
| Business | $49.99 | 20TB | Team management, SSO | Production companies |
| Enterprise | Custom | Custom | SLA, dedicated support | Publishing houses |

### Storage Strategy by Tier

#### Free & Starter Tiers ($0 - $0.99)
- **Photos**: DEEP_ARCHIVE only ($0.99/TB/month)
- **Thumbnails**: STANDARD (instant access)
- **Use case**: Long-term backup, minimal access
- **Target**: Casual users, price-sensitive

#### Essential Tier ($1.99) - **SWEET SPOT**
- **Recent photos (< 6 months)**: STANDARD_IA ($4/TB/month)
- **Older photos**: DEEP_ARCHIVE ($0.99/TB/month)
- **Smart balance**: ~25% recent, 75% archived
- **Use case**: Regular users who access recent photos
- **Target**: Most mainstream users

#### Plus & Family Tiers ($3.99+)
- **Recent photos (1-2 years)**: STANDARD_IA
- **Smart caching**: Frequently accessed in STANDARD
- **Use case**: Enthusiasts, families with lots of photos
- **Target**: High-storage needs, frequent access

#### Professional Tiers (Future)
- **All photos**: STANDARD_IA or STANDARD
- **No archiving**: Instant access always
- **Business features**: Teams, API, SSO, SLA
- **Target**: Studios, agencies, publishers

### Revenue Breakdown
- Apple App Store: 30%
- AWS costs: 20-50% (varies by tier)
- **Photolala profit: 20-50%**

### Why $1.99 is the Sweet Spot
1. **Psychological**: Under $2 feels negligible
2. **Comparison**: "Less than a coffee"
3. **Conversion**: Low friction for trial → paid
4. **Profitability**: 68% margin after all costs
5. **Storage**: 200GB covers most users' needs
6. **Access**: 6 months recent is reasonable
7. **Credits**: 50 monthly credits = 5GB of retrievals

## Future Features

### Label System
Since photos use MD5 addressing, we can add arbitrary labels:
- Stars: Only photo owner can star (keeps it simple)
- Bookmarks, flags stored as `labels/{user-id}/{type}/{md5}.plist`
- Custom tags and albums per user
- Smart collections based on metadata
- Personal labels, not shared across family

### Deep Archive UX
- Clear indicators for archived photos
- Batch restore for events/trips
- Cost estimates before restore
- Email notifications when ready
- Option to keep restored copies for X days

### Tier-Specific Features

#### Archive Tier ($0.99)
- Monthly retrieval allowance (1GB)
- Basic metadata search
- Email notifications

#### Active Tier ($2.99)
- Faster retrieval options
- Advanced search and filters  
- Shared album links
- Activity reports

#### Plus Tier ($3.99)
- Advanced search and filters
- Bulk operations
- Priority processing
- Download queue management

#### Family Tier ($5.99)
- Share with up to 5 family members
- Separate storage quotas
- Family album sharing
- Parental controls

## Cancellation Policy

### Grace Period Approach
- **30 days** full access after cancellation
- **90 days** browse-only (thumbnails visible)
- **365 days** data retention before deletion
- **Recovery options** available throughout

### What Happens When You Cancel
1. **Days 0-30**: Download everything, full access
2. **Days 31-90**: Browse thumbnails, can reactivate
3. **Days 91-365**: Reactivation with $19.99 fee
4. **Day 365+**: Data permanently deleted

### Always Preserved (Even After Cancellation)
- Thumbnail previews
- Photo metadata
- Folder structure
- Browse capabilities

### Recovery Options
- **Reactivate**: Resume subscription anytime
- **Recovery Pass**: $9.99 for 7-day download access
- **Data Export**: Organized ZIP downloads

See [Cancellation Policy](./cancellation-policy.md) for full details.

## Security & Privacy

### Apple ID Integration
- **Sign in with Apple** for authentication
- Apple provides stable, opaque user identifier
- We generate internal UUID for each user
- S3 paths use our UUID, not Apple ID
- No email/name storage unless user provides

### Security Architecture
- **Encrypted transfer**: HTTPS/TLS 1.3 minimum
- **Encrypted at rest**: S3 SSE-S3
- **User isolation**: Each user has unique S3 prefix
- **Token management**: 1-hour access, 30-day refresh
- **No direct S3 access**: All through authenticated API

### Privacy by Design
- Minimal data collection
- Clear data retention policies
- User-controlled data export
- GDPR compliant deletion
- No cross-user analytics

See [Security Architecture](./security-privacy-architecture.md) for implementation details.
