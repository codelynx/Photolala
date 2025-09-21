# S3 Integration Implementation Plan

## Overview
This plan outlines the implementation of S3 integration for Photolala, focusing on cloud backup and browsing capabilities with a simple, sequential approach.

## Core Principles
- **Sequential uploads** (one-by-one) for simplicity
- **MD5 as identity** - no date conflicts, true deduplication
- **Local and S3 catalogs are separate** - no auto-sync
- **User-initiated backup** - explicit action required
- **Cache-first downloads** - check local before S3

## Phase 1: Foundation Components

### 1. Extend Thumbnail Specification
**File**: `docs/catalog-system.md` (extend existing document)
- Add PTM-256 thumbnail specification section to existing catalog docs
- Define exact 256×256 JPEG specifications
- Quality settings and compression parameters
- Consistent thumbnail generation across platforms
- Keeps specs consolidated in one living document

### 2. Create PhotoItem Protocol
**File**: `apple/Photolala/Models/PhotoItem.swift`

Protocol-based design to support multiple photo sources:

```swift
// Base protocol for any photo item
protocol PhotoItem: Sendable {
    var id: String { get }  // Unique identifier
    var displayName: String { get }
    var format: ImageFormat? { get }

    // Async loading methods
    func loadFullData() async throws -> Data
    func loadThumbnail() async throws -> Data
    func computeMD5() async throws -> String  // Computes full MD5
}

// Local file implementation
struct LocalPhotoItem: PhotoItem {
    let photoEntry: PhotoEntry  // Has PhotoID with FastPhotoKey
    let url: URL

    var id: String { photoEntry.id.fastKey.stringValue }
    var displayName: String { photoEntry.fileName }
    var format: ImageFormat? { photoEntry.id.fastKey.detectedFormat }

    func loadFullData() async throws -> Data {
        try Data(contentsOf: url)
    }

    func loadThumbnail() async throws -> Data {
        // ThumbnailCache returns URL, not Data - need conversion
        let photoMD5 = try await computeMD5()
        let thumbnailURL = await ThumbnailCache.shared.getThumbnail(
            for: PhotoMD5(photoMD5),
            sourceURL: url
        )

        // Read JPEG data from cached file for S3 upload
        return try Data(contentsOf: thumbnailURL)
    }

    func computeMD5() async throws -> String {
        if let md5 = photoEntry.id.fullMD5?.value {
            return md5
        }
        // Compute if not already available
        let photoMD5 = try await PhotoMD5(contentsOf: url)
        return photoMD5.value
    }
}

// Implementation Notes:
// 1. ThumbnailCache.getThumbnail now returns URL to cached JPEG file
// 2. loadThumbnail() reads Data from the cached file URL
// 3. This avoids keeping large image data in memory
}

// Apple Photos implementation (future)
struct ApplePhotoItem: PhotoItem {
    let assetID: String  // PHAsset identifier
    private var cachedMD5: String?

    var id: String { assetID }
    var displayName: String { /* from PHAsset */ }
    var format: ImageFormat? { /* detect from PHAsset */ }

    func loadFullData() async throws -> Data {
        // Load from Photos framework
        // This is when MD5 can be computed
    }

    func loadThumbnail() async throws -> Data {
        // Request thumbnail from Photos framework
    }

    func computeMD5() async throws -> String {
        // Must load full data first for Apple Photos
        let data = try await loadFullData()
        let md5 = Insecure.MD5.hash(data: data)
        return md5.map { String(format: "%02x", $0) }.joined()
    }
}

// Simple upload result tracking
enum UploadResult {
    case completed
    case failed(Error)
    case skipped  // Already exists in S3
}
```

**Note**: FastPhotoKey struct already exists in `PhotoIdentity.swift` as:
```swift
public struct FastPhotoKey: Hashable, Codable, Sendable {
    let headMD5: String
    let fileSize: Int64
}
```

## Phase 2: S3 Upload Components

### 3. Extend S3Service
**File**: `apple/Photolala/Services/S3Service.swift`

Add methods for basic S3 operations:
```swift
// Deduplication check
func checkPhotoExists(md5: String, userID: String) async -> Bool

// Upload photo with format preservation
func uploadPhoto(data: Data, md5: String, format: ImageFormat, userID: String) async throws
// Implementation:
//   let key = "photos/{userID}/{md5}.dat"  // Always .dat for deduplication
//   let contentType = format.mimeType      // e.g., "image/jpeg"
//   let tag = "Format={format.rawValue}"   // e.g., "Format=JPEG"
// S3 Tag enables format detection when downloading

// Upload PTM-256 thumbnail
func uploadThumbnail(data: Data, md5: String, userID: String) async throws
// S3 Key: thumbnails/{user-uuid}/{photo-md5}.jpg

// Upload catalog snapshot
func uploadCatalog(csvData: Data, catalogMD5: String, userID: String) async throws
// S3 Key: catalogs/{user-uuid}/.photolala.{catalog-md5}.csv

// Update catalog pointer
func updateCatalogPointer(catalogMD5: String, userID: String) async throws
// S3 Key: catalogs/{user-uuid}/.photolala.md5
```

### 4. Create S3BackupService
**File**: `apple/Photolala/Services/S3BackupService.swift`

Sequential backup processor using protocol-based PhotoItem:
```swift
actor S3BackupService {
    private let s3Service: S3Service
    private let thumbnailGenerator: ThumbnailGenerator

    // Track results for reporting
    private var uploadResults: [String: UploadResult] = [:]

    func backupPhotos(_ items: [PhotoItem], userID: String) async -> [String: UploadResult] {
        uploadResults.removeAll()

        for item in items {
            do {
                // 1. Compute MD5 (may require loading full data for Apple Photos)
                let md5 = try await item.computeMD5()

                // 2. Check if exists (deduplication)
                if await s3Service.checkPhotoExists(md5: md5, userID: userID) {
                    uploadResults[item.id] = .skipped
                    continue
                }

                // 3. Load photo data
                let photoData = try await item.loadFullData()

                // 4. Generate PTM-256 thumbnail
                let thumbnail = try await generatePTM256Thumbnail(from: photoData)

                // 5. Upload photo as .dat with Format tag
                let format = item.format ?? .unknown
                try await s3Service.uploadPhoto(
                    data: photoData,
                    md5: md5,
                    format: format,  // Used for Format tag, not extension
                    userID: userID
                )
                // S3Service will create key: photos/{userID}/{md5}.dat

                // 6. Upload thumbnail
                try await s3Service.uploadThumbnail(
                    data: thumbnail,
                    md5: md5,
                    userID: userID
                )

                uploadResults[item.id] = .completed

            } catch {
                uploadResults[item.id] = .failed(error)
            }
        }

        // 7. Upload catalog snapshot after all photos
        await uploadCatalogSnapshot(userID: userID)

        return uploadResults
    }

    private func generatePTM256Thumbnail(from data: Data) async throws -> Data {
        // PTM-256 spec implementation
        // 256x256 JPEG with specific quality settings
    }
}
```

## Phase 3: S3 Download Components

### 5. Create S3CloudBrowser
**File**: `apple/Photolala/Services/S3CloudBrowser.swift`

Cloud catalog browsing and progressive loading:
```swift
actor S3CloudBrowser {
    private let s3Service: S3Service
    private let cacheManager: CacheManager

    // Download catalog from S3
    func loadCloudCatalog(userID: String) async throws -> CatalogDatabase {
        // 1. Get catalog pointer
        let pointer = try await s3Service.downloadCatalogPointer(userID: userID)

        // 2. Download catalog CSV
        let csvData = try await s3Service.downloadCatalog(
            catalogMD5: pointer,
            userID: userID
        )

        // 3. Write CSV to temporary file
        let tempCSVPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-catalog.csv")
        try csvData.write(to: tempCSVPath)

        // 4. Create read-only database from CSV
        // CatalogDatabase is CSV-based (no SQLite)
        // It reads the CSV and populates entries dictionary in memory
        return try await CatalogDatabase(path: tempCSVPath, readOnly: true)
    }

    // Implementation Note:
    // CatalogDatabase uses CSV exclusively - no SQLite involved
    // The initializer reads CSV rows into memory for fast access
    // This aligns with the CSV-only catalog system design

    // Progressive thumbnail loading
    func loadThumbnail(photoMD5: String, userID: String) async -> Data? {
        // 1. Check local cache first
        if let cached = await cacheManager.getThumbnailData(photoMD5: photoMD5) {
            return cached
        }

        // 2. Download from S3
        guard let data = try? await s3Service.downloadThumbnail(
            md5: photoMD5,
            userID: userID
        ) else { return nil }

        // 3. Save to local cache
        await cacheManager.storeThumbnail(data, photoMD5: photoMD5)

        return data
    }

    // On-demand full photo download
    func downloadPhoto(photoMD5: String, format: ImageFormat, userID: String) async throws -> Data {
        // Check cache first, then download
        return try await s3Service.downloadPhoto(
            md5: photoMD5,
            userID: userID
        )
    }
}
```

## Phase 4: UI Integration

### 6. Create PhotoSelectionView
**File**: `apple/Photolala/Views/PhotoSelectionView.swift`

Multi-select interface for backup:
```swift
struct PhotoSelectionView: View {
    @State private var selectedItems: Set<String> = []  // Track by PhotoItem.id
    @State private var uploadResults: [String: UploadResult] = [:]
    @State private var isUploading = false

    let photoItems: [PhotoItem]  // From catalog

    var body: some View {
        // Grid view with selection
        // Selection state tracked in Set<String>
        // No UI state in PhotoItem itself
    }

    func backupSelected() async {
        let selected = photoItems.filter { selectedItems.contains($0.id) }
        uploadResults = await backupService.backupPhotos(selected, userID: userID)
    }
}
```

**Note**: Selection and progress are managed by the view, not the PhotoItem model

### 7. Create CloudBrowserView
**File**: `apple/Photolala/Views/CloudBrowserView.swift`

Cloud photo browsing:
- Load catalog from S3 on open
- Grid view with progressive thumbnail loading
- Placeholder while thumbnails load
- Tap thumbnail to view full photo
- Cache management in background

## Implementation Timeline

### Day 1: Foundation
- Extend docs/catalog-system.md with PTM-256 spec
- Create PhotoItem protocol aligned with current models
- Add ThumbnailCache helper for Data extraction
- Set up plans directory structure

### Day 2: S3 Upload Infrastructure
- Extend S3Service with upload methods
- Add deduplication check
- Implement proper extension handling (not .dat)
- Add Format tag as metadata

### Day 3: Backup Service
- Implement S3BackupService
- PTM-256 thumbnail generation
- Sequential upload logic
- Progress tracking

### Day 4: Cloud Browser
- Implement S3CloudBrowser
- Use existing CatalogDatabase CSV support
- Progressive thumbnail loading
- Local cache integration
- On-demand photo downloads

### Day 5: UI Integration
- Create PhotoSelectionView
- Create CloudBrowserView
- Wire up to services
- Testing and refinement

## Key Implementation Notes

### Protocol-Based Design Benefits
- **Flexibility**: Support local files and Apple Photos with same interface
- **Lazy MD5**: Compute MD5 only when needed (especially for Apple Photos)
- **Clean separation**: PhotoItem is pure data, no UI state
- **Extensibility**: Easy to add new photo sources (iCloud, Google Photos, etc.)

### Deduplication
- Always check S3 for existing MD5 before upload
- Skip upload if exists (saves bandwidth/time)
- Report as "skipped" in progress

### Format Preservation
- Upload all photos with `.dat` extension for perfect deduplication
- S3 Key format: `photos/{user-uuid}/{photo-md5}.dat`
- Add S3 object tag `Format=JPEG` (or PNG, HEIF, etc.) for format identification
- Same MD5 = same S3 key regardless of source format
- Lambda/CloudFront can read Format tag to set correct Content-Type header

### Catalog Management
- Local catalog: represents local directory state
- S3 catalog: represents what's uploaded to S3
- No automatic sync between them
- User explicitly chooses what to backup

### CSV Catalog Flow
- **Upload**: Export entries to CSV → Upload to S3 → Update pointer
- **Download**: Fetch CSV from S3 → Load into CatalogDatabase (CSV-only, no SQLite)
- **Pointer rule**: "Who writes .photolala.md5 last wins"
- **Storage**: All catalogs are CSV files, loaded into memory for fast access

### Apple Photos Considerations
- MD5 not available until full image is loaded
- May need to load full image during backup process
- Cache MD5 once computed to avoid recomputation

### Error Handling
- Return UploadResult for each item
- Simple approach: just completed/failed/skipped
- Can add retry logic later if needed

### Performance Considerations
- Start with sequential (one-by-one) uploads
- AWS SDK provides progress callbacks if needed
- Can optimize to parallel later if needed
- Cache thumbnails aggressively
- Progressive loading for better UX

## Success Criteria
1. Users can select and backup photos to S3
2. Deduplication prevents redundant uploads
3. Cloud browser loads catalog and thumbnails progressively
4. PTM-256 thumbnails display correctly
5. Format preservation works (correct tags on S3)
6. Local cache reduces S3 API calls
7. Clear progress indication during operations