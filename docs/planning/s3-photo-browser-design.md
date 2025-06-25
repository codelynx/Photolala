# S3 Photo Browser Design

## Overview

Browse photos stored in S3 backup service with a responsive user experience by leveraging both S3 thumbnails and local cache.

### Prerequisites
- S3 backup service must be operational with photos uploaded
- User authentication via Apple ID (provides userId)
- Local catalog generation during backup process
- S3 master catalog (master.photolala.json) maintained by backup service

## Goals

1. **Responsive UX**: Use local thumbnails when available, fetch from S3 when needed
2. **Unified View**: Show both local and cloud-only photos
3. **Smart Caching**: Cache S3 thumbnails locally for better performance
4. **Future-Ready**: Design to support albums/labels later

## User Experience

### Phase 1: Basic S3 Browser
- New menu item: "View → Cloud Photos" or "File → Browse Cloud Photos"
- Shows grid of all backed-up photos
- Mixed display of local + cloud-only photos ([KY] both thumbnails and photos and metadata may have cached in local)
- Click to view full size (download if needed)

### Phase 2: Smart Collections (Future)
- "All Photos" - Everything in S3
- "Cloud Only" - Photos not on this device
- "Archived" - Photos in Deep Archive
- User-created albums/labels

## Technical Architecture

### 1. Data Flow (Catalog-First Architecture)

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ .photolala      │────▶│  Photo Browser  │────▶│     Display     │
│ Catalog Cache   │     └─────────────────┘     └─────────────────┘
└─────────────────┘              │                         │
         ↑                       ▼                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   S3 Catalog    │     │  Thumbnail      │────▶│  Thumbnail Grid │
│  (sync only)    │     │    Cache        │     └─────────────────┘
└─────────────────┘     └─────────────────┘
```

**Key Points:**
- **NO S3 ListObjects API calls** - Browse using local catalog cache
- **Instant loading** - Parse local CSV shards (16 files)
- **Offline capable** - Works without network using cached catalog
- **Efficient sync** - Only download changed shards via manifest checksums

### 2. Thumbnail Strategy

```swift
enum ThumbnailSource {
    case local(URL)           // Already on disk
    case cached(URL)          // Downloaded previously
    case remote(S3Key)        // Need to fetch from S3
}

func getThumbnail(for photo: S3Photo) -> ThumbnailSource {
    // 1. Check if we have the original locally
    if let localPath = findLocal(md5: photo.md5) {
        return .local(generateThumbnail(localPath))
    }

    // 2. Check thumbnail cache
    if let cachedThumb = thumbnailCache.get(photo.md5) {
        return .cached(cachedThumb)
    }

    // 3. Fetch from S3
    return .remote(photo.thumbnailKey)
}
```

[KY] regardless, we can download thumbnail for cache, if not presented, but not sure if photos grows 100K+ and not enough local strage for anothor thumbs.


### 3. S3 Photo Model

```swift
struct S3Photo: Identifiable {
    // From .photolala catalog (CSV fields)
    let id: String { md5 }  // Conformance to Identifiable
    let md5: String
    let filename: String
    let size: Int64
    let photoDate: Date     // When photo was taken
    let modified: Date      // File modification date
    let width: Int?
    let height: Int?
    
    // From S3 master catalog (JSON)
    let uploadDate: Date?
    let storageClass: S3StorageClass
    
    // Computed properties (userId from app context)
    var photoKey: String {
        "photos/\(userId)/\(md5).dat"
    }

    var thumbnailKey: String {
        "thumbnails/\(userId)/\(md5).dat"
    }

    var isArchived: Bool {
        storageClass == .deepArchive
    }

    var isLocallyAvailable: Bool {
        // Check if photo exists in local library
    }
    
    // Initialize from catalog entry
    init(from catalogEntry: PhotoCatalogEntry, s3Info: S3MasterInfo?) {
        self.md5 = catalogEntry.md5
        self.filename = catalogEntry.filename
        self.size = catalogEntry.size
        self.photoDate = catalogEntry.photoDate
        self.modified = catalogEntry.modified
        self.width = catalogEntry.width
        self.height = catalogEntry.height
        
        self.uploadDate = s3Info?.uploadDate
        self.storageClass = s3Info?.storageClass ?? .standard
    }
}
```

### 4. Browser View Structure

```swift
struct S3PhotoBrowserView: View {
    @StateObject private var viewModel = S3PhotoBrowserViewModel()
    @State private var selectedPhoto: S3Photo?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns) {
                ForEach(viewModel.photos) { photo in
                    S3PhotoThumbnailView(photo: photo)
                        .onTapGesture {
                            selectedPhoto = photo
                        }
                }
            }
        }
        .task {
            await viewModel.loadPhotosFromCatalog()
        }
        .refreshable {
            await viewModel.syncAndReload()
        }
        .sheet(item: $selectedPhoto) { photo in
            S3PhotoDetailView(photo: photo)
        }
        .overlay(alignment: .topTrailing) {
            if viewModel.isOfflineMode {
                OfflineBadge()
            }
        }
    }
}

// ViewModel with catalog-first approach
class S3PhotoBrowserViewModel: ObservableObject {
    @Published var photos: [S3Photo] = []
    @Published var isOfflineMode = false
    
    private var catalogCache: PhotolalaCatalog?
    private var s3MasterCatalog: S3MasterCatalog?
    
    func loadPhotosFromCatalog() async {
        // 1. Try to sync catalog (non-blocking)
        if await syncCatalogIfNeeded() {
            isOfflineMode = false
        } else {
            isOfflineMode = true
        }
        
        // 2. Load from local catalog cache (instant!)
        guard let catalog = loadCachedCatalog() else { return }
        
        // 3. Load S3 master catalog for storage info
        s3MasterCatalog = loadS3MasterCatalog()
        
        // 4. Build photo list - NO S3 API calls!
        await MainActor.run {
            photos = catalog.entries.map { entry in
                S3Photo(from: entry, s3Info: s3MasterCatalog?.photos[entry.md5])
            }
        }
    }
    
    func syncAndReload() async {
        _ = await forceSyncCatalog()
        await loadPhotosFromCatalog()
    }
}
```

### 5. Caching Strategy

#### Thumbnail Cache
```swift
class S3ThumbnailCache {
    private let cacheDir: URL
    private let maxCacheSize: Int64 = 1_000_000_000 // 1GB

    func getCachedThumbnail(md5: String) -> URL? {
        let cacheFile = cacheDir
            .appendingPathComponent(md5)
            .appendingPathExtension("thumb")

        if FileManager.default.fileExists(atPath: cacheFile.path) {
            // Update last access time for LRU
            return cacheFile
        }
        return nil
    }

    func cacheThumbnail(md5: String, data: Data) {
        // Save to cache with LRU eviction
    }
}
```

#### Catalog Cache Location
Local copies of S3 `.photolala` catalogs are stored at:
- **macOS**: `~/Library/Caches/com.electricwoods.photolala/cloud.s3/{userId}/`
- **iOS**: `Library/Caches/cloud.s3/{userId}/`

Structure:
```
cloud.s3/{userId}/
├── .photolala          # Binary plist manifest with shard checksums
├── .photolala#0        # Shard 0 (CSV format)
├── .photolala#1        # Shard 1 (CSV format)
├── ... (up to .photolala#f)
└── master.photolala.json  # S3 master catalog (upload dates, storage classes)
```

**Note**: These are separate from local `.photolala` catalogs in photo directories. The S3 browser uses only the cached cloud catalogs.

#### Catalog Sync Mechanism
```swift
class S3CatalogSync {
    private let cacheDir: URL
    private let s3Client: S3Client
    
    func syncCatalogIfNeeded() async throws -> Bool {
        // 1. Check manifest ETag first (HeadObject - no download)
        let manifestKey = "catalog/\(userId)/.photolala"
        guard let manifestNeedsUpdate = try? await checkETag(key: manifestKey) else {
            return false // Offline or error
        }
        
        if !manifestNeedsUpdate {
            return false // Already up to date
        }
        
        // 2. Download manifest only if changed
        guard let s3Manifest = try? await downloadFile(".photolala") else {
            return false
        }
        
        let localManifest = loadLocalManifest()
        
        // 3. Check each shard's ETag before downloading
        var shardsToDownload: [String] = []
        for shardIndex in 0..<16 {
            let shardHex = String(format: "%x", shardIndex)
            let shardKey = "catalog/\(userId)/.photolala#\(shardHex)"
            
            // Use S3 HeadObject to get ETag without downloading
            if let needsUpdate = try? await checkETag(key: shardKey),
               needsUpdate {
                shardsToDownload.append(shardHex)
            }
        }
        
        // 4. Download only changed shards
        for shardHex in shardsToDownload {
            try await downloadFile(".photolala#\(shardHex)")
        }
        
        // 5. Atomic update - move all files at once
        try await atomicUpdateCatalog()
        
        // 6. Also check master catalog ETag
        if try await checkETag(key: "catalog/\(userId)/master.photolala.json") {
            try await downloadFile("master.photolala.json")
        }
        
        return true
    }
    
    private func checkETag(key: String) async throws -> Bool {
        // Use S3 HeadObject to get ETag without downloading
        let headRequest = HeadObjectInput(
            bucket: "photolala",
            key: key
        )
        
        let response = try await s3Client.headObject(input: headRequest)
        let remoteETag = response.eTag?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        // Compare with stored ETag
        let localETag = loadStoredETag(for: key)
        return remoteETag != localETag
    }
    
    private func atomicUpdateCatalog() async throws {
        // Atomic update strategy to prevent corruption:
        // 1. Download all files to temp directory
        // 2. Verify checksums match manifest
        // 3. Use FileManager.replaceItem for atomic swap
        // 4. Store ETags for future comparisons
        
        let tempDir = cacheDir.appendingPathComponent(".tmp")
        let finalDir = cacheDir.appendingPathComponent("cloud.s3/\(userId)")
        
        // Verify all shards match manifest checksums
        let manifest = try loadManifest(from: tempDir)
        for (index, checksum) in manifest.shardChecksums {
            let shardData = try Data(contentsOf: tempDir.appendingPathComponent(".photolala#\(index)"))
            let calculatedChecksum = SHA256.hash(data: shardData).hexString()
            guard calculatedChecksum == checksum else {
                throw CatalogError.shardCorrupted(index)
            }
        }
        
        // Atomic replace
        _ = try FileManager.default.replaceItemAt(finalDir, withItemAt: tempDir)
    }
}
```

Sync triggers:
- On app launch (if > 15 min since last check)
- When opening "Browse Cloud Backup"
- Pull-to-refresh in S3 browser
- After local backup completes

#### Catalog Loading Strategy
```swift
class PhotolalaCatalog {
    let entries: [PhotoCatalogEntry]
    
    init(from cacheDir: URL) throws {
        // Load manifest
        let manifest = try PropertyListDecoder().decode(
            PhotolalaManifest.self,
            from: Data(contentsOf: cacheDir.appendingPathComponent(".photolala"))
        )
        
        // Load all shards in parallel
        entries = try await withTaskGroup(of: [PhotoCatalogEntry].self) { group in
            for shardIndex in 0..<16 {
                group.addTask {
                    let shardHex = String(format: "%x", shardIndex)
                    return try loadShard(at: cacheDir.appendingPathComponent(".photolala#\(shardHex)"))
                }
            }
            
            var allEntries: [PhotoCatalogEntry] = []
            for await shardEntries in group {
                allEntries.append(contentsOf: shardEntries)
            }
            return allEntries
        }
    }
}
```

## Implementation Plan

### Week 1: Core Infrastructure (Catalog Foundation)
- [ ] Implement `.photolala` catalog reader (CSV shards + manifest)
- [ ] Create S3 catalog sync mechanism (manifest-based delta sync)
- [ ] Build S3Photo model from catalog entries
- [ ] Set up local catalog cache at `cloud.s3/{userId}/`
- [ ] Integrate with S3 master catalog for storage class info

### Week 2: UI Polish
- [ ] Thumbnail loading with placeholders
- [ ] Progress indicators
- [ ] Error handling
- [ ] Full-size photo viewing

### Week 3: Performance
- [ ] Implement prefetching
- [ ] Optimize cache eviction
- [ ] Add refresh capability
- [ ] Handle large libraries (10k+ photos)

## Performance Considerations

### Catalog-First Benefits
1. **No S3 API calls for browsing** - Everything loads from local CSV files
2. **Instant photo list** - Parse 16 shards in parallel (~100ms for 100K photos)
3. **Minimal bandwidth** - Only sync changed shards (typically 1-2 per update)
4. **Offline browsing** - Full functionality with cached catalog

### Thumbnail Optimization
1. **Lazy Loading**: Only load visible thumbnails
2. **Prefetching**: Load next/previous page thumbnails
3. **Cache Warming**: Background download of recent thumbnails
4. **Memory Management**: Limit in-memory thumbnail count
5. **LRU Eviction**: Keep most recently viewed thumbnails

## Future Enhancements

1. **Albums/Labels**
   - User-created collections
   - Smart albums (by date, location, etc.)
   - Shared albums

2. **Search**
   - By date
   - By metadata (camera, location)
   - By content (with ML)

3. **Sync Status**
   - Show upload progress
   - Indicate sync conflicts
   - Handle deletions

## Success Metrics

1. **Catalog Performance**: Initial load <100ms for 100K photos
2. **No S3 API Calls**: Browse photos without ListObjects calls
3. **Sync Efficiency**: Only download changed shards (~1-5MB typical)
4. **Grid Load Time**: <500ms from cached catalog
5. **Thumbnail Responsiveness**: Appear within 500ms
6. **Cache Hit Rate**: >80% for recently viewed
7. **Memory Usage**: <200MB for 1000 photos
8. **Offline Support**: Full browsing with cached catalog

## Design Decisions (Based on KY Feedback)

1. **Catalog-First Architecture**
   - Primary data source is `.photolala` catalog cache, not S3 API
   - Instant browsing without S3 ListObjects calls
   - Catalog stored at: `~/Library/Caches/com.electricwoods.photolala/cloud.s3/{userId}/`
   - 16 sharded CSV files + binary plist manifest

2. **Separate Browsing Modes**
   - Local/Network Drive Browser: Shows backup status badges
   - S3 Backup Browser: Shows only backed-up photos
   - No mixing of local and cloud in same view

3. **Backup Status Indication**
   - While browsing local: Show ✓ badge for backed-up photos
   - Use MD5 matching from `.photolala` catalog
   - Fast lookup without S3 API calls
   - Cross-reference with S3 master catalog for storage class

4. **Archive Handling**
   - Show archived photos with special badge in S3 browser
   - Indicate archive status in local browser too
   - Storage class info from `master.photolala.json`

5. **Thumbnail Strategy**
   - Small thumbnails (~50KB) for quick S3 fetching
   - LRU cache eviction for old thumbnails
   - 1GB cache limit by default

6. **Offline Mode**
   - Use `.photolala` catalog for browsing
   - Show cached thumbnails when available
   - Indicate online-only content
   - Gracefully degrade when network unavailable

## Error Handling

### Catalog Sync Errors
```swift
enum CatalogError: Error {
    case manifestMissing
    case shardCorrupted(String)
    case versionMismatch(String) 
    case syncFailed(Error)
    case networkTimeout
    case insufficientStorage
}
```

### Recovery Strategies
1. **Partial sync failure**: Keep existing catalog, retry failed shards
2. **Corrupted shard**: Re-download specific shard
3. **Network timeout**: Exponential backoff with max retries
4. **Storage full**: Prompt user to clear cache or increase limit

## Performance Considerations

### Large Catalog Handling
- **100K photos**: ~20MB catalog (16 shards × ~1.25MB each)
- **Parallel shard loading**: Use TaskGroup for concurrent parsing
- **Memory optimization**: Stream parse CSV instead of loading entire file
- **Cache size**: Consider dynamic sizing based on library size

## Future Considerations

### Archive Restoration UI
- Show restore button for archived photos
- Display restoration time/cost estimates
- Queue multiple restorations
- Track restoration progress

### Apple Photos Library Integration
- Challenge: Apple may not expose raw photo data for MD5
- Solution: Use Apple's photo identifiers + fingerprinting
- Consider: Photos edited in Apple Photos get new MD5
- Alternative: Use perceptual hashing for similarity matching
