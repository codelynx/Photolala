# S3 Photo Backup Service (Simplified)

## Philosophy

Start simple. Add complexity only when needed.

## What This Is

A Photolala-managed cloud backup service using AWS S3 with:
- MD5-based deduplication
- Cost-optimized storage (STANDARD_IA → DEEP_ARCHIVE)
- Browse via thumbnails without downloading originals
- Tied to Apple ID with subscription tiers

## Documentation Structure

- `design/` - Architecture and design documents
  - Core S3 backup service design
  - Identity management design
  - Cross-platform identity strategy
  - Pricing and storage optimization
- `implementation/` - Technical implementation details
  - AWS SDK Swift credentials handling
- `research/` - Background research
  - Game industry identity patterns
- `requirements/` - What we're building (and what we're NOT)
- `api/` - API design (for later)
- `security/` - Security notes

## Current Status

🚧 **POC Implementation** - Core features working, production infrastructure needed

### ✅ Completed
- Sign in with Apple authentication
- Identity management with Keychain storage
- S3 upload/download functionality
- Subscription tier definitions
- Storage quota enforcement
- User interface for auth flow
- StoreKit 2 integration for IAP
- Archive retrieval UI with restore dialog
- S3 RestoreObject API integration
- Metadata backup system (binary plist)

### 🚧 In Progress
- Backend services for user management
- Production AWS credential handling
- Receipt validation endpoint

### ❌ Not Started
- Usage tracking persistence
- S3 lifecycle rules configuration
- Family sharing implementation

## Phase 1 Goals (MVP)

1. Photolala-managed S3 service (us-east-1)
2. MD5 calculation and deduplication
3. EXIF extraction and thumbnail generation
4. Upload selected photos (not folders)
5. Browse via thumbnails + metadata
6. SwiftData for local state
7. Storage class optimization

## What We're NOT Doing

- ❌ User's own AWS credentials
- ❌ Multiple regions (us-east-1 only)
- ❌ Automatic backup (manual selection)
- ❌ Two-way sync
- ❌ Client-side encryption
- ❌ iOS support (Phase 1)
- ❌ Intel Macs
- ❌ Background uploads

## Technical Choices

- **Local Storage**: SwiftData (not JSON files)
- **Cloud Storage**: MD5-based flat structure
- **Platform**: macOS 14+ on Apple Silicon only
- **UI**: Integrated with photo selection
- **Security**: Apple ID authentication
- **Cost**: < $1/month for typical users

## Key Features

### MD5-Based Storage
```
s3://photolala/users/{user-id}/photos/{md5}.dat
s3://photolala/users/{user-id}/thumbs/{md5}.dat
s3://photolala/users/{user-id}/metadata/{md5}.plist
```

### Subscription Tiers
- Free: 5 GB
- Basic: 100 GB ($2.99/mo)
- Standard: 1 TB ($9.99/mo)
- Pro: 5 TB ($39.99/mo)
- Family: 10 TB ($69.99/mo)

### Next Steps

1. ~~Implement AWS SDK integration~~ ✅
2. ~~Build MD5 calculation pipeline~~ ✅
3. ~~Create thumbnail generation~~ ✅
4. ~~Implement Sign in with Apple~~ ✅
5. ~~Add StoreKit 2 for subscriptions~~ ✅
6. ~~Design Deep Archive UX~~ ✅
7. ~~Implement metadata backup~~ ✅
8. Build backend services
9. Production deployment