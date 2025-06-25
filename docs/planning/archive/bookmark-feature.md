# Bookmark Feature Planning

**Created**: June 24, 2025
**Status**: Planning

## Concept Overview

The bookmark feature in Photolala allows users to label photos using their MD5 hash as a universal identifier. Unlike traditional bookmarks that point to file locations, our bookmarks are content-based, making them universally unique and portable across devices and storage locations.

## Key Principles

1. **Content-Based Identification**: Bookmarks are tied to photo MD5 hashes, not file paths
2. **Universal Uniqueness**: Same photo will have same bookmark regardless of location
3. **Cloud Sync**: Bookmarks sync across devices via iCloud
4. **Storage Independent**: Works whether photo is local, in Apple Photos, or on S3

## Proposed Architecture

### Data Model

```swift
struct PhotoBookmark: Codable {
    let id: UUID
    let md5: String
    let label: String
    let createdDate: Date
    let modifiedDate: Date
    let color: BookmarkColor? // For visual organization
    let notes: String? // Optional user notes
}

enum BookmarkColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, gray
}
```

### Storage Options

#### Option 1: iCloud Key-Value Store (Simple)
- **Pros**:
  - Easy to implement
  - Automatic sync
  - No user authentication needed
- **Cons**:
  - 1MB total limit
  - 1024 key limit
  - Limited to ~1000 bookmarks with metadata

#### Option 2: iCloud Documents (Recommended)
- **Pros**:
  - Much larger storage capacity
  - Can store thousands of bookmarks
  - Support for attachments/thumbnails
  - Conflict resolution
- **Cons**:
  - More complex implementation
  - Requires iCloud container setup

#### Option 3: CloudKit
- **Pros**:
  - Most scalable
  - Rich query capabilities
  - Push notifications for changes
- **Cons**:
  - Most complex
  - Requires CloudKit dashboard setup

### iCloud Document Format (Recommended Approach)

#### Document Structure

```swift
// BookmarkDocument.swift
class BookmarkDocument: NSDocument {
    var bookmarkData: BookmarkData?
    
    override func contents(forType typeName: String) throws -> Any {
        // Serialize to JSON or PropertyList
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(bookmarkData)
    }
    
    override func read(from data: Data, ofType typeName: String) throws {
        let decoder = JSONDecoder()
        bookmarkData = try decoder.decode(BookmarkData.self, from: data)
    }
}

// Data structure for the document
struct BookmarkData: Codable {
    let version: String = "1.0"
    let bookmarks: [PhotoBookmark]
    let labels: [Label]
    let metadata: DocumentMetadata
}

struct DocumentMetadata: Codable {
    let createdDate: Date
    let modifiedDate: Date
    let deviceName: String
    let appVersion: String
}

struct Label: Codable {
    let id: UUID
    let name: String
    let color: BookmarkColor
    let parentID: UUID? // For hierarchical labels
    let createdDate: Date
}
```

#### File Organization in iCloud

```
iCloud Container/
├── Documents/
│   └── Photolala/
│       ├── bookmarks.photolala  // Main bookmark file
│       ├── bookmarks-backup.photolala  // Auto backup
│       └── thumbnails/  // Optional thumbnail cache
│           ├── {md5}-thumb.jpg
│           └── ...
└── .conflicts/  // iOS/macOS managed conflict versions
```

#### Sync Strategy

```swift
class iCloudBookmarkManager {
    private let containerURL: URL?
    private var metadataQuery: NSMetadataQuery?
    
    init() {
        // Get iCloud container
        containerURL = FileManager.default.url(forUbiquityContainerIdentifier: 
            "iCloud.com.electricwoods.photolala")
        
        // Setup metadata query for changes
        setupMetadataQuery()
    }
    
    private func setupMetadataQuery() {
        metadataQuery = NSMetadataQuery()
        metadataQuery?.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery?.predicate = NSPredicate(format: "%K LIKE '*.photolala'", 
            NSMetadataItemFSNameKey)
        
        // Monitor for changes
        NotificationCenter.default.addObserver(self,
            selector: #selector(queryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: metadataQuery)
    }
}
```

#### Conflict Resolution

```swift
struct ConflictResolution {
    enum Strategy {
        case keepLocal
        case keepRemote
        case merge
        case askUser
    }
    
    static func resolveBookmarkConflicts(
        local: BookmarkData,
        remote: BookmarkData,
        strategy: Strategy = .merge
    ) -> BookmarkData {
        switch strategy {
        case .merge:
            // Merge bookmarks by MD5, keeping newest
            var merged = [String: PhotoBookmark]()
            
            // Add all local bookmarks
            for bookmark in local.bookmarks {
                merged[bookmark.md5] = bookmark
            }
            
            // Merge remote, keeping newer modifications
            for bookmark in remote.bookmarks {
                if let existing = merged[bookmark.md5] {
                    if bookmark.modifiedDate > existing.modifiedDate {
                        merged[bookmark.md5] = bookmark
                    }
                } else {
                    merged[bookmark.md5] = bookmark
                }
            }
            
            return BookmarkData(
                bookmarks: Array(merged.values),
                labels: mergeLabels(local.labels, remote.labels),
                metadata: DocumentMetadata(...)
            )
            
        case .keepLocal:
            return local
            
        case .keepRemote:
            return remote
            
        case .askUser:
            // Present UI for manual resolution
            fatalError("Not implemented")
        }
    }
}
```

#### Advantages of This Format

1. **Human Readable**: JSON format can be inspected/edited if needed
2. **Versioned**: Supports future format changes
3. **Efficient Sync**: Only syncs changed documents
4. **Conflict Handling**: Built-in iOS/macOS conflict resolution
5. **Offline Support**: Full local cache with background sync
6. **Backup Friendly**: Easy to backup/restore

#### Implementation Details

##### 1. Enable iCloud in Capabilities
```xml
<!-- Info.plist -->
<key>NSUbiquitousContainers</key>
<dict>
    <key>iCloud.com.electricwoods.photolala</key>
    <dict>
        <key>NSUbiquitousContainerIsDocumentScopePublic</key>
        <true/>
        <key>NSUbiquitousContainerName</key>
        <string>Photolala</string>
    </dict>
</dict>
```

##### 2. Document Type Registration
```xml
<!-- Info.plist -->
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>Photolala Bookmarks</string>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.electricwoods.photolala.bookmarks</string>
        </array>
        <key>LSHandlerRank</key>
        <string>Owner</string>
    </dict>
</array>

<key>UTExportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>com.electricwoods.photolala.bookmarks</string>
        <key>UTTypeDescription</key>
        <string>Photolala Bookmarks</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.json</string>
        </array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>photolala</string>
            </array>
        </dict>
    </dict>
</array>
```

##### 3. Bookmark File Format Example
```json
{
  "version": "1.0",
  "metadata": {
    "createdDate": "2025-06-24T10:00:00Z",
    "modifiedDate": "2025-06-24T10:30:00Z",
    "deviceName": "Kaz's MacBook Pro",
    "appVersion": "1.0.0"
  },
  "labels": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "name": "Portfolio",
      "color": "blue",
      "parentID": null,
      "createdDate": "2025-06-24T10:00:00Z"
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440002",
      "name": "Family",
      "color": "red",
      "parentID": null,
      "createdDate": "2025-06-24T10:00:00Z"
    }
  ],
  "bookmarks": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440003",
      "md5": "5d41402abc4b2a76b9719d911017c592",
      "label": "Portfolio",
      "createdDate": "2025-06-24T10:00:00Z",
      "modifiedDate": "2025-06-24T10:00:00Z",
      "color": "blue",
      "notes": "Best sunset photo from Iceland trip",
      "metadata": {
        "originalFilename": "IMG_1234.jpg",
        "lastSeenPath": "/Users/kaz/Photos/Iceland/IMG_1234.jpg",
        "thumbnailMD5": "7d793037a0760186574b0282f2f435e7"
      }
    }
  ]
}
```

##### 4. Local Cache Strategy
```swift
class BookmarkCache {
    private let cacheURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                   in: .userDomainMask).first!
        cacheURL = appSupport
            .appendingPathComponent("Photolala")
            .appendingPathComponent("BookmarkCache")
        
        try? FileManager.default.createDirectory(at: cacheURL, 
                                                 withIntermediateDirectories: true)
    }
    
    func cacheBookmarks(_ data: BookmarkData) {
        // Save local cache for offline access
        let localURL = cacheURL.appendingPathComponent("bookmarks-local.json")
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: localURL)
        }
    }
    
    func loadCachedBookmarks() -> BookmarkData? {
        let localURL = cacheURL.appendingPathComponent("bookmarks-local.json")
        guard let data = try? Data(contentsOf: localURL) else { return nil }
        return try? JSONDecoder().decode(BookmarkData.self, from: data)
    }
}
```

### Bookmark Manager

```swift
@MainActor
class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()

    @Published var bookmarks: [String: PhotoBookmark] = [:] // MD5 -> Bookmark
    @Published var labels: Set<String> = [] // All unique labels

    func addBookmark(md5: String, label: String, notes: String? = nil)
    func removeBookmark(md5: String)
    func updateBookmark(md5: String, label: String?, notes: String?)
    func bookmarksForLabel(_ label: String) -> [PhotoBookmark]
    func isBookmarked(md5: String) -> Bool
}
```

## User Interface

### 1. Quick Bookmark (Inspector)
- Star icon for backup, Bookmark icon for labels
- Click bookmark icon → Quick add with default label
- Long press → Show label picker

### 2. Bookmark Management View
- Accessible via Window → Bookmarks (⌘B)
- List all bookmarks grouped by label
- Search and filter capabilities
- Batch operations

### 3. Photo Browser Integration
- Show bookmark badge on thumbnails
- Different colors for different labels
- Filter view by bookmark labels

## Use Cases

### 1. Photo Organization
- User bookmarks favorite photos across different folders
- Labels like "Portfolio", "Family", "Work", etc.
- Find bookmarked photos regardless of current location

### 2. Cross-Device Workflow
- Bookmark on Mac, view on iPad
- Bookmarks sync automatically via iCloud
- Works even if photos are in different locations on each device

### 3. Backup Strategy
- Bookmark important photos
- Even if local copies deleted, can identify from S3
- Bookmarks persist independent of photo location

## Implementation Phases

### Phase 1: Core Functionality
- [ ] Create BookmarkManager service
- [ ] Add bookmark/unbookmark functionality
- [ ] Store bookmarks locally first
- [ ] Update inspector with bookmark UI

### Phase 2: iCloud Sync
- [ ] Implement iCloud document storage
- [ ] Handle sync conflicts
- [ ] Add sync status indicators
- [ ] Test multi-device scenarios

### Phase 3: UI Enhancement
- [ ] Bookmark management window
- [ ] Label organization
- [ ] Color coding system
- [ ] Batch operations

### Phase 4: Advanced Features
- [ ] Smart collections based on bookmarks
- [ ] Bookmark sharing between users
- [ ] Export/import bookmark sets
- [ ] Bookmark history/versioning

## Technical Considerations

### 1. MD5 Computation
- Leverage existing PhotoManager MD5 computation
- Cache MD5s for performance
- Handle photos without MD5 gracefully

### 2. iCloud Integration
```swift
// Enable iCloud in Capabilities
// Add iCloud container: iCloud.com.electricwoods.photolala
// Use NSUbiquitousKeyValueStore or Document-based storage
```

### 3. Performance
- Lazy load bookmarks
- Index by MD5 for O(1) lookup
- Batch sync operations
- Local cache for offline access

### 4. Data Migration
- Version bookmark format
- Handle schema changes
- Provide export/backup options

## Questions to Resolve

1. **Label System**:
   - Predefined labels vs free-form text?
   - Multiple labels per photo?
   - Hierarchical labels (e.g., Work/Clients/Apple)?

2. **Sync Behavior**:
   - Conflict resolution strategy?
   - Offline changes handling?
   - Sync frequency?

3. **UI/UX**:
   - How prominent should bookmarks be?
   - Keyboard shortcuts?
   - Touch gestures for iOS?

4. **Storage Limits**:
   - Maximum bookmarks per user?
   - Thumbnail storage in bookmarks?
   - Metadata to include?

5. **Integration**:
   - Show bookmarks in Apple Photos browser?
   - Bookmark S3 photos before download?
   - Bookmark search/filter priority?

## Next Steps

1. Decide on storage mechanism (recommend iCloud Documents)
2. Design detailed UI mockups
3. Create BookmarkManager implementation
4. Add to SwiftData catalog or keep separate?
5. Define bookmark-photo relationship

## Alternative Considerations

### Tags vs Labels
- Tags: Multiple per photo, more flexible
- Labels: Single per photo, simpler
- Hybrid: Primary label + additional tags

### Local vs Cloud First
- Local first: Better performance, offline support
- Cloud first: Better sync, single source of truth
- Recommended: Local with cloud sync

### Bookmark Sharing
- Private by default
- Share individual bookmarks
- Share bookmark collections
- Public bookmark feeds?

## Alternative: Simpler iCloud Key-Value Store Approach

If we want to start simpler, we could use iCloud Key-Value Store with a compressed format:

```swift
// Simpler approach using iCloud KV Store
class SimpleBookmarkSync {
    private let store = NSUbiquitousKeyValueStore.default
    private let bookmarkKey = "com.photolala.bookmarks.v1"
    
    struct CompactBookmark: Codable {
        let m: String  // md5 (shortened key)
        let l: String  // label
        let d: Date    // date
        let n: String? // notes (optional)
    }
    
    func syncBookmarks(_ bookmarks: [PhotoBookmark]) {
        // Convert to compact format
        let compact = bookmarks.map { bookmark in
            CompactBookmark(
                m: bookmark.md5,
                l: bookmark.label,
                d: bookmark.modifiedDate,
                n: bookmark.notes
            )
        }
        
        // Compress with zlib
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(compact),
           let compressed = data.compressed(using: .zlib) {
            
            // Store if under 1MB limit
            if compressed.count < 1_000_000 {
                store.set(compressed, forKey: bookmarkKey)
                store.synchronize()
            }
        }
    }
}
```

### Hybrid Approach

We could also use a hybrid approach:
1. **iCloud KV Store**: For quick sync of bookmark existence (MD5 list only)
2. **iCloud Documents**: For full bookmark data with notes, labels, etc.
3. **Local Cache**: For offline access and performance

This gives us:
- Fast sync of "is this photo bookmarked?" (KV Store)
- Rich data sync when needed (Documents)
- Best of both worlds

## Decision Points

1. **Start Simple or Full Featured?**
   - Simple: iCloud KV Store with basic bookmarks
   - Full: iCloud Documents with rich features

2. **Label System**
   - Single label per photo (simpler)
   - Multiple tags per photo (more flexible)
   - Hierarchical labels (most complex)

3. **Sync Priority**
   - Real-time sync (battery impact)
   - Batch sync (better performance)
   - Manual sync (user control)

4. **Storage Format**
   - JSON (human readable, larger)
   - Binary plist (smaller, faster)
   - Custom binary format (smallest, least flexible)
