# Bookmark Feature - Refined Plan

**Created**: June 24, 2025
**Status**: Planning - Balanced Approach

## Core Concept

Photos are bookmarked with **labels** (the actual organizational concept). Each label has an associated emoji for visual identification, but the emoji can be changed without affecting the bookmark relationships.

## Data Model

```swift
// A label is the core organizational unit
struct BookmarkLabel: Codable, Identifiable {
	typealias Identifier = UUID // [KY]
    let id: Identifier 		// [KY]
    var name: String        // e.g., "Portfolio", "Family", "To Edit"
    var emoji: String       // Visual representation (changeable)
    var color: String?      // Optional hex color
    let createdDate: Date	// [KY] may bewedn't need it starter, introduce as we go
}

// A bookmark links a photo to a label
struct PhotoBookmark: Codable, Identifiable {
	typealias Identifier = UUID // [KY]
    let id: Identifier
    let md5: String         // Photo identifier
    let label: BookmarkLabel.Identifier        // Which label [KY]
    var title: String?      // Optional title for this specific photo
    var note: String?       // Optional notes [KY]
    let createdDate: Date	// [KY] may bewedn't need it starter, introduce as we go
    let modifiedDate: Date	// [KY] may bewedn't need it starter, introduce as we go
}

// The document that syncs via iCloud
struct BookmarkDocument: Codable {
	static let versionValue = "1.0" // [KY]
    let version: String = Self.versionValue // [KY]
    var labels: [BookmarkLabel]
    var bookmarks: [PhotoBookmark]
    let metadata: DocumentMetadata // [KY] We don't need it starter, introduce as we go
}

/* [KY]
struct DocumentMetadata: Codable {
    let createdDate: Date
    var modifiedDate: Date
    let deviceName: String
}
*/
```

## Why This Structure?

1. **Labels are stable**: Changing emoji doesn't break bookmarks
2. **Flexible**: Can add multiple bookmarks per photo later
3. **Organized**: Labels can be managed separately
4. **Extensible**: Can add label hierarchies later

## Storage: Simple iCloud Documents

```swift
class BookmarkDocumentManager: ObservableObject {
    static let shared = BookmarkDocumentManager()

    @Published var labels: [UUID: BookmarkLabel] = [:]
    @Published var bookmarksByPhoto: [String: [PhotoBookmark]] = [:] // MD5 -> Bookmarks
    @Published var bookmarksByLabel: [UUID: [PhotoBookmark]] = [:]

    private let documentsURL: URL?
    private let documentName = "photolala-bookmarks.json"

    init() {
        // Get iCloud container
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            documentsURL = containerURL
                .appendingPathComponent("Documents")
                .appendingPathComponent("Bookmarks")

            // Create directory if needed
            try? FileManager.default.createDirectory(
                at: documentsURL!,
                withIntermediateDirectories: true
            )

            loadDocument()
            startMonitoring()
        } else {
            // Fallback to local documents
            documentsURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first?.appendingPathComponent("Bookmarks")
        }
    }

    func createLabel(name: String, emoji: String) -> BookmarkLabel {
        let label = BookmarkLabel(
            id: UUID(),
            name: name,
            emoji: emoji,
            color: nil,
            createdDate: Date()
        )
        labels[label.id] = label
        saveDocument()
        return label
    }

    func bookmarkPhoto(md5: String, labelID: UUID, title: String? = nil, memo: String? = nil) {
        let bookmark = PhotoBookmark(
            id: UUID(),
            md5: md5,
            labelID: labelID,
            title: title,
            memo: memo,
            createdDate: Date(),
            modifiedDate: Date()
        )

        // Update indices
        if bookmarksByPhoto[md5] == nil {
            bookmarksByPhoto[md5] = []
        }
        bookmarksByPhoto[md5]?.append(bookmark)

        if bookmarksByLabel[labelID] == nil {
            bookmarksByLabel[labelID] = []
        }
        bookmarksByLabel[labelID]?.append(bookmark)

        saveDocument()
    }
}
```

## Default Labels

Start with some useful defaults:

```swift
let defaultLabels = [
    ("Favorites", "⭐"),
    ("Portfolio", "🖼️"),
    ("To Edit", "✏️"),
    ("Family", "👨‍👩‍👧‍👦"),
    ("Nature", "🌿"),
    ("Travel", "✈️")
]
```
[KY] Then user can add /change / delete labels
[KY] Wow? should we let use to delete? i am not sure how delete affects to system

## Simple JSON Format

```json
{
  "version": "1.0",
  "metadata": {
    "createdDate": "2025-06-24T10:00:00Z",
    "modifiedDate": "2025-06-24T10:30:00Z",
    "deviceName": "MacBook Pro"
  },
  "labels": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "name": "Portfolio",
      "emoji": "🖼️",
      "color": null,
      "createdDate": "2025-06-24T10:00:00Z"
    }
  ],
  "bookmarks": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440002",
      "md5": "5d41402abc4b2a76b9719d911017c592",
      "labelID": "550e8400-e29b-41d4-a716-446655440001",
      "title": "Sunset at Mt. Fuji",
      "memo": "Best shot from Japan trip",
      "createdDate": "2025-06-24T10:00:00Z",
      "modifiedDate": "2025-06-24T10:00:00Z"
    }
  ]
}
```

## UI Design

### 1. Inspector Panel
```
┌─────────────────────────┐
│ 📷 Photo Details        │
├─────────────────────────┤
│ ...                     │
│                         │
│ [🏷️ Add Label]         │
│                         │
│ Current Labels:         │
│ 🖼️ Portfolio           │
│ ⭐ Favorites            │
└─────────────────────────┘
```

### 2. Add Label Popover
```
┌─────────────────────────┐
│ Add Label               │
├─────────────────────────┤
│ Choose Label:           │
│ ○ ⭐ Favorites          │
│ ● 🖼️ Portfolio         │
│ ○ ✏️ To Edit           │
│ ○ + Create New...       │
│                         │
│ Title (optional):       │
│ [________________]      │
│                         │
│ Memo (optional):        │
│ [________________]      │
│                         │
│ [Cancel] [Add]          │
└─────────────────────────┘
```

### 3. Thumbnail Badge
- Show first label's emoji as badge
- If multiple labels, show count (e.g., "⭐+2")

### 4. Label Management
- Window → Manage Labels
- Add, edit, delete labels
- Change emoji/name without losing bookmarks

## Implementation Phases

### Phase 1: Core (3-4 days)
1. Create data models
2. Local storage first
3. Basic bookmark/unbookmark
4. Show in inspector

### Phase 2: iCloud (2 days)
1. Enable iCloud container
2. Document save/load
3. Change monitoring
4. Conflict handling (last write wins)

### Phase 3: UI Polish (2 days)
1. Label management window
2. Filter by label
3. Batch operations
4. Search bookmarks

## Benefits Over Pure KV Store

1. **No size limits** (within iCloud storage)
2. **Richer data model** without complexity
3. **Better conflict info** (can see device/time)
4. **Extensible format** (can add fields)
5. **Human readable** (JSON for debugging)

## Keeping It Simple

1. **No hierarchical labels** (yet)
2. **One label per bookmark** (can extend later)
3. **No sharing** (personal bookmarks only)
4. **Basic conflict resolution** (last write wins)
5. **No thumbnails in bookmarks** (just MD5 reference)

## Future Compatible

This structure allows future additions:
- Multiple labels per photo (just create multiple bookmarks)
- Label hierarchies (add parentID to labels)
- Sharing (add ownership/sharing fields)
- Collections (group bookmarks into sets)
- Smart labels (based on rules)

But we don't implement these now - keep MVP focused!
