# Phase 1: Core Foundation - Detailed Implementation

## Overview

Phase 1 establishes the fundamental architecture of Photolala as a database-free, window-per-folder photo browser. This phase focuses on creating the basic structure without complex features, ensuring a solid foundation for future development.

## Key Architectural Decisions

### 1. No Database Approach
- **Decision**: Use plain Swift structs instead of SwiftData/@Model
- **Rationale**: 
  - Simpler architecture
  - File system is the source of truth
  - No migration headaches
  - Easier debugging (just files)
- **Implementation**: `PhotoReference` struct with computed properties

### 2. Window-Per-Folder Design
- **Decision**: Each window shows one folder's contents
- **Rationale**:
  - Simple mental model
  - Natural for file browsing
  - Easy multi-folder comparison
  - No complex navigation state
- **Implementation**: Separate `MainWindowView` instances

## Core Components Implemented

### 1. PhotoReference Model

```swift
struct PhotoReference: Identifiable, Hashable {
    // Core stored properties (minimal)
    let filePath: String
    let fileSize: Int64
    let createdDate: Date
    let modifiedDate: Date
    
    // Optional enrichment data
    var photoIdentifier: PhotoIdentifier?
    var imageHeader: Data?
    var imageWidth: Int?
    var imageHeight: Int?
    
    // Everything else is computed
    var id: String { filePath }
    var fileName: String { URL(fileURLWithPath: filePath).lastPathComponent }
    var directoryPath: String { URL(fileURLWithPath: filePath).deletingLastPathComponent().path }
}
```

**Key Design Points:**
- Immutable core data (let properties)
- Computed properties for derived values
- No database annotations
- Natural ID (file path)

### 2. SimplePhotoScanner

```swift
actor SimplePhotoScanner {
    static let shared = SimplePhotoScanner()
    
    func scanDirectory(_ directoryURL: URL) async throws -> [PhotoReference] {
        // 1. List directory contents
        // 2. Filter for image files
        // 3. Create PhotoReference for each
        // 4. Return sorted array
    }
}
```

**Key Features:**
- Actor for thread safety
- Simple directory enumeration
- No recursive scanning (single folder)
- Returns array, not database objects

### 3. Project Structure

```
Photolala/
├── photolala/
│   ├── PhotolalaApp.swift          # App entry, no ModelContainer
│   ├── Models/
│   │   ├── PhotoReference.swift
│   │   ├── PhotoIdentifier.swift
│   │   └── Directory.swift         # Simple struct, not @Model
│   ├── Views/
│   │   ├── WelcomeView.swift      # Folder selection
│   │   ├── MainWindowView.swift    # Per-folder browser
│   │   ├── PhotoGridView.swift     # Grid display
│   │   └── ThumbnailView.swift     # Individual thumbnail
│   ├── Services/
│   │   ├── SimplePhotoScanner.swift
│   │   └── ThumbnailService.swift
│   └── Shared/
│       └── XPlatform.swift         # Platform abstractions
├── Platform/
│   ├── iOS/                        # iOS-specific code
│   └── macOS/                      # macOS-specific code
└── docs/                           # Documentation
```

### 4. App Entry Point

```swift
@main
struct PhotolalaApp: App {
    // No @StateObject for ModelContainer
    // No sharedModelContainer
    
    var body: some Scene {
        WindowGroup {
            #if os(iOS)
            iPhoneRootView()  // Navigation-based
            #else
            WelcomeView()     // Direct window
            #endif
        }
        // No .modelContainer modifier
    }
}
```

### 5. Welcome Screen

**macOS:**
- "Select Folder" button
- Uses `NSOpenPanel`
- Opens new window per folder
- No persistence

**iOS:**
- Document picker integration
- Navigation to folder view
- iPad: Multi-scene support

### 6. MainWindowView

```swift
struct MainWindowView: View {
    let folderURL: URL
    @State private var photos: [PhotoReference] = []
    @State private var isScanning = false
    
    var body: some View {
        // Grid or empty state
        // No @Query, no FetchDescriptor
        // Direct array management
    }
    
    private func scanFolder() async {
        photos = try await SimplePhotoScanner.shared.scanDirectory(folderURL)
    }
}
```

## What Was Intentionally Excluded

### 1. Database Layer
- No SwiftData models
- No ModelContainer/ModelContext
- No @Query property wrappers
- No migration systems

### 2. Complex Features
- No recursive folder scanning
- No photo library integration (yet)
- No search/filter/sort
- No selection persistence
- No window state restoration

### 3. Optimizations
- No .photolala footprint files
- No background scanning
- No incremental updates
- No prefetching

## Platform Differences in Phase 1

### macOS
- `NSOpenPanel` for folder selection
- Multiple windows via `WindowGroup`
- Direct file system access
- Keyboard navigation basics

### iOS
- `UIDocumentPickerViewController`
- Single navigation stack (iPhone)
- Security-scoped resources
- Touch-based interaction

## Success Criteria

Phase 1 is complete when:
1. ✅ App launches without database
2. ✅ Can select and open a folder
3. ✅ Shows photos in a grid
4. ✅ Proper thumbnails with caching (PhotoManager)
5. ✅ Works on both macOS and iOS
6. ✅ No SwiftData dependencies
7. ✅ Efficient thumbnail generation (256x256 to 256x512)
8. ✅ EXIF orientation handling

## Lessons Learned

1. **Simplicity Wins**: Removing the database made everything clearer
2. **Computed Properties**: Powerful for avoiding data duplication
3. **File Path as ID**: Natural and unique identifier
4. **Structs over Classes**: Value semantics simplify state management
5. **Progressive Enhancement**: Start simple, add features incrementally

## Foundation for Future Phases

Phase 1 provides:
- Clean architecture without technical debt
- Clear separation of concerns
- Platform-agnostic core logic
- Simple mental model for developers
- Easy testing and debugging

This foundation enables:
- Phase 2: Advanced thumbnail system
- Phase 3: UI polish and performance
- Phase 4: Footprint optimization
- Future: Advanced features without refactoring