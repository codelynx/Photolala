# Unified Photo Browser Architecture

## Overview

This document outlines the strategy for creating a unified photo browser architecture that can support multiple data sources:
- Local file system photos (current)
- S3/Cloud storage photos (current)
- Apple Photos Library (future)
- Other photo sources (future)

The goal is to reduce code duplication while maintaining flexibility for source-specific features.

## Current State Analysis

### Common Elements Between Browsers

#### 1. State Variables
- `ThumbnailDisplaySettings` - Display preferences (size, mode, info visibility)
- Selected photos array - Track selection state
- Error handling state - Show error messages
- Refresh state - Track refresh operations
- Inspector state - Show/hide inspector panel

#### 2. UI Components
- **Toolbar Items:**
  - Display mode toggle (aspect fit/fill)
  - Item info toggle
  - Thumbnail size controls
  - Refresh button
  - Inspector button

- **Collection View:**
  - Both use `UnifiedPhotoCollectionViewRepresentable`
  - Handle selection and photo tapping
  - Support for different photo types via `PhotoItem` protocol

#### 3. Functionality
- Photo selection management
- Refresh/reload operations
- Error presentation
- Inspector integration

### Browser-Specific Features

#### PhotoBrowserView (Local)
1. **Navigation:**
   - NavigationPath for folder hierarchy
   - Preview navigation with space key
   - Full preview mode

2. **Backup Features:**
   - Star-based backup queue
   - Upload progress overlay
   - Archive status loading

3. **Organization:**
   - Sort options (name, date)
   - Group options (year, month, day)

4. **Additional UI:**
   - Help sheet
   - Sign-in/upgrade prompts
   - Retrieval dialog

#### S3PhotoBrowserView (Cloud)
1. **Loading States:**
   - Initial catalog loading
   - Empty state view
   - Offline mode indicator

2. **Photo Operations:**
   - Detail view sheet
   - Download functionality
   - Context menu actions

3. **Catalog Management:**
   - Sync with S3
   - Cache handling

## Proposed Architecture

### Core Design Principles

1. **Data Source Abstraction** - Support multiple photo sources through protocols
2. **Composable UI Components** - Reusable UI elements that work with any data source
3. **Feature Modules** - Optional capabilities that data sources can support
4. **Progressive Enhancement** - Basic browsing works for all sources, advanced features are optional

### Data Source Architecture

#### PhotoSource Protocol
```swift
protocol PhotoSource {
    associatedtype Item: PhotoItem

    // Core requirements
    var displayName: String { get }
    var photos: [Item] { get }
    var isLoading: Bool { get }

    // Core operations
    func loadPhotos() async throws
    func refresh() async throws

    // Optional capabilities
    var capabilities: PhotoSourceCapabilities { get }
}

struct PhotoSourceCapabilities: OptionSet {
    let rawValue: Int

    static let hierarchicalNavigation = PhotoSourceCapabilities(rawValue: 1 << 0)
    static let backup = PhotoSourceCapabilities(rawValue: 1 << 1)
    static let download = PhotoSourceCapabilities(rawValue: 1 << 2)
    static let delete = PhotoSourceCapabilities(rawValue: 1 << 3)
    static let albums = PhotoSourceCapabilities(rawValue: 1 << 4)
    static let search = PhotoSourceCapabilities(rawValue: 1 << 5)
    static let sorting = PhotoSourceCapabilities(rawValue: 1 << 6)
    static let grouping = PhotoSourceCapabilities(rawValue: 1 << 7)
}
```

#### Example Implementations
```swift
// Local file system
class DirectoryPhotoSource: PhotoSource { // [KY]
    typealias Item = PhotoFile
    let directoryPath: String
    var capabilities: PhotoSourceCapabilities = [.hierarchicalNavigation, .backup, .sorting, .grouping]
    // ... implementation
}

// S3 cloud storage
class S3PhotoSource: PhotoSource {
    typealias Item = PhotoS3
    let userId: String
    var capabilities: PhotoSourceCapabilities = [.download, .search]
    // ... implementation
}

// Future: Apple Photos
class ApplePhotosLibrarySource: PhotoSource { // [KY]
    typealias Item = PhotoAsset
    let album: PHAssetCollection?
    var capabilities: PhotoSourceCapabilities = [.albums, .search, .sorting]
    // ... implementation
}
```

### Unified Browser View

```swift
struct UnifiedPhotoBrowser<Source: PhotoSource>: View {
    let source: Source
    @State private var settings = ThumbnailDisplaySettings()
    @State private var showingInspector = false
    @State private var selectedPhotos: [Source.Item] = []

    var body: some View {
        NavigationStack {
            UnifiedPhotoCollectionViewRepresentable(
                photoProvider: source,
                settings: settings,
                onSelectPhoto: handlePhotoSelection,
                onSelectionChanged: { selectedPhotos = $0 }
            )
            .unifiedToolbar(
                source: source,
                settings: $settings,
                showingInspector: $showingInspector,
                selectedPhotos: selectedPhotos
            )
            .inspector(
                isPresented: $showingInspector,
                selection: selectedPhotos.map { $0 as any PhotoItem }
            )
        }
    }
}
```

### Benefits
1. **Extensibility** - Easy to add new photo sources
2. **Type Safety** - Each source maintains its specific photo type
3. **Feature Discovery** - UI adapts based on source capabilities
4. **Code Reuse** - Common UI and logic shared across all sources
5. **Maintainable** - Clear separation between sources and UI

### Components to Extract

#### 1. PhotoBrowserToolbar
```swift
struct PhotoBrowserToolbar: ToolbarContent {
    @Binding var settings: ThumbnailDisplaySettings
    @Binding var showingInspector: Bool
    let isRefreshing: Bool
    let onRefresh: () async -> Void
    let selectionCount: Int

    // Optional customization
    let additionalItems: (() -> AnyView)?

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            // Common items: display mode, info, size, refresh, inspector
            // ... implementation

            // Custom items from each browser
            if let additionalItems = additionalItems {
                additionalItems()
            }
        }
    }
}
```

#### 2. PhotoLoadingOverlay
```swift
struct PhotoLoadingOverlay: ViewModifier {
    let isLoading: Bool
    let progress: Double?
    let statusText: String?

    func body(content: Content) -> some View {
        content.overlay {
            if isLoading {
                // Unified loading UI
            }
        }
    }
}
```

#### 3. PhotoErrorHandler
```swift
struct PhotoErrorHandler: ViewModifier {
    @Binding var showingError: Bool
    @Binding var errorMessage: String

    func body(content: Content) -> some View {
        content.alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
}
```

#### 4. Inspector Integration
The existing `.inspector()` modifier already provides the unified approach we need:
- Works with any `[PhotoItem]` array
- Handles platform differences (sidebar vs sheet)
- Already implemented in `InspectorContainer`

### Implementation Plan

#### Phase 1: Inspector Support (Immediate)
1. Add inspector state to S3PhotoBrowserView
2. Add inspector button to toolbar
3. Apply `.inspector()` modifier
4. Test with S3 photos

#### Phase 2: Extract Common Toolbar (Next)
1. Create `PhotoBrowserToolbar` component
2. Migrate PhotoBrowserView toolbar
3. Migrate S3PhotoBrowserView toolbar
4. Ensure browser-specific items still work

#### Phase 3: Loading & Error Components (Future)
1. Extract loading overlay patterns
2. Create unified error handling
3. Apply to both browsers

#### Phase 4: State Protocol (Optional)
1. Define common state protocol
2. Create default implementations
3. Refactor browsers to use protocol

## Example Usage

### Current (S3PhotoBrowserView with Inspector)
```swift
struct S3PhotoBrowserView: View {
    @State private var showingInspector = false

    private var inspectorSelection: [any PhotoItem] {
        selectedPhotos.map { $0 as any PhotoItem }
    }

    var body: some View {
        NavigationStack {
            // ... content
        }
        .toolbar {
            ToolbarItemGroup {
                // ... existing items

                Button(action: {
                    showingInspector.toggle()
                }) {
                    Label("Inspector", systemImage: "info.circle")
                }
            }
        }
        .inspector(
            isPresented: $showingInspector,
            selection: inspectorSelection
        )
    }
}
```

### Future (With Unified Architecture)

[KY] i don't like TabView, struct ContentView<T: PhotoSource>: View {}
[KY] can we do something like this, or other alternative?

#### Option 1: Generic Window/View Creation (Preferred)
```swift
// Each window is strongly typed with its source
struct PhotoBrowserWindow<Source: PhotoSource>: View {
    let source: Source
    
    var body: some View {
        UnifiedPhotoBrowser(source: source)
    }
}

// Usage in app - each window maintains its type
@main
struct PhotolalaApp: App {
    var body: some Scene {
        // File browser windows
        WindowGroup("File Browser", id: "file-browser") {
            PhotoBrowserWindow(source: DirectoryPhotoSource(directoryPath: "/"))
        }
        
        // Cloud browser window
        WindowGroup("Cloud Photos", id: "cloud-browser") {
            PhotoBrowserWindow(source: S3PhotoSource(userId: "user123"))
        }
        
        Commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Folder...") {
                    // Opens new file browser window
                }
                Button("Open Cloud Photos") {
                    // Opens cloud browser window
                }
            }
        }
    }
}
```

#### Option 2: Protocol-Based Navigation (Clean but needs type erasure)
```swift
// If we need dynamic source switching
struct PhotoBrowserContainer: View {
    @State private var currentSource: AnyPhotoSource
    
    var body: some View {
        UnifiedPhotoBrowser(source: currentSource)
            .navigationDestination(for: PhotoSourceNavigation.self) { navigation in
                switch navigation {
                case .directory(let path):
                    PhotoBrowserWindow(source: DirectoryPhotoSource(directoryPath: path))
                case .s3(let userId):
                    PhotoBrowserWindow(source: S3PhotoSource(userId: userId))
                case .applePhotos(let album):
                    PhotoBrowserWindow(source: ApplePhotosLibrarySource(album: album))
                }
            }
    }
}
```

#### Option 3: Source Factory Pattern (Avoids some type erasure)
```swift
protocol PhotoSourceFactory {
    associatedtype Source: PhotoSource
    func createSource() -> Source
}

struct DirectorySourceFactory: PhotoSourceFactory {
    let path: String
    func createSource() -> DirectoryPhotoSource {
        DirectoryPhotoSource(directoryPath: path)
    }
}

// Window that works with any factory
struct PhotoBrowserWindow<Factory: PhotoSourceFactory>: View {
    let factory: Factory
    @StateObject private var source: Factory.Source
    
    init(factory: Factory) {
        self.factory = factory
        self._source = StateObject(wrappedValue: factory.createSource())
    }
    
    var body: some View {
        UnifiedPhotoBrowser(source: source)
    }
}
```



### Capability-Based UI Adaptation
```swift
extension View {
    func unifiedToolbar<Source: PhotoSource>(
        source: Source,
        settings: Binding<ThumbnailDisplaySettings>,
        showingInspector: Binding<Bool>,
        selectedPhotos: [Source.Item]
    ) -> some View {
        self.toolbar {
            ToolbarItemGroup {
                // Always available
                PhotoBrowserCoreTools(
                    settings: settings,
                    showingInspector: showingInspector
                )

                // Conditional based on capabilities
                if source.capabilities.contains(.sorting) {
                    PhotoSortPicker(source: source)
                }

                if source.capabilities.contains(.grouping) {
                    PhotoGroupPicker(source: source)
                }

                if source.capabilities.contains(.backup) && !selectedPhotos.isEmpty {
                    BackupButton(photos: selectedPhotos)
                }

                if source.capabilities.contains(.download) && !selectedPhotos.isEmpty {
                    DownloadButton(photos: selectedPhotos)
                }
            }
        }
    }
}
```

## Decision Points

### Approach Comparison

#### Option A: Full Unification (PhotoSource Protocol)
**Pros:**
- Single browser implementation for all sources
- Automatic UI adaptation based on capabilities
- Easy to add new photo sources
- Consistent user experience

**Cons:**
- More complex initial implementation
- May over-abstract simple cases
- Requires refactoring existing code

#### Option B: Composable Components (Current Plan)
**Pros:**
- Simpler, incremental approach
- Each browser stays independent
- Easier to understand
- Less refactoring needed

**Cons:**
- Some duplication remains
- Need to update multiple places for new features
- Harder to add new photo sources

[KY] how about try plan A first, if stuck then move to B, i know it might be hard so step by step to moving forward

### Updated Recommendation Based on Feedback

You're right - let's start with Option A (Full Unification) and see how far we can get. If we hit type erasure issues or complexity walls, we can fall back to Option B. Here's the revised approach:

1. **Phase 1 (Now)**: Start with composable components
   - Add inspector to S3PhotoBrowserView
   - Extract common toolbar components
   - Validate the approach works

2. **Phase 2 (Before Apple Photos)**: Introduce PhotoSource protocol
   - Define the protocol and capabilities
   - Adapt existing providers to conform
   - Keep existing browser views initially

3. **Phase 3 (With Apple Photos)**: Implement unified browser
   - Create UnifiedPhotoBrowser with Apple Photos
   - Gradually migrate other browsers
   - Maintain backwards compatibility

This gives us the benefits of both approaches while managing complexity.

## Implementation Roadmap

### Phase 1: Composable Components (Current Sprint)
1. **Inspector Support**
   - Add to S3PhotoBrowserView ✓
   - Test with different photo types
   - Document usage patterns

2. **Common Toolbar**
   - Extract PhotoBrowserToolbar component
   - Support custom items per browser
   - Maintain type safety

3. **Shared Modifiers**
   - Error handling modifier
   - Loading overlay modifier
   - Refresh capability

### Phase 2: Data Source Abstraction (Pre-Apple Photos)
1. **Define Protocols**
   - PhotoSource protocol
   - PhotoSourceCapabilities
   - Navigation strategies

2. **Adapt Existing Code**
   - Make providers conform to PhotoSource
   - Add capability declarations
   - Test compatibility

3. **Migration Helpers**
   - Bridge existing browsers
   - Maintain API compatibility
   - Gradual adoption

### Phase 3: Unified Browser (With Apple Photos)
1. **Implement UnifiedPhotoBrowser**
   - Generic over PhotoSource
   - Capability-based UI
   - Extensible architecture

2. **Apple Photos Integration**
   - PHPhotoLibrary wrapper
   - Asset management
   - Privacy handling

3. **Migration**
   - Update existing browsers
   - Deprecate old implementations
   - Full documentation

## Success Metrics

1. **Extensibility** - Time to add new photo source < 1 day
2. **Code Reuse** - 70%+ shared code between browsers
3. **Type Safety** - No runtime type casting needed
4. **Performance** - No degradation from current implementation
5. **User Experience** - Consistent across all photo sources

## Technical Considerations

### Apple Photos Specific Requirements
- Photos framework integration
- Privacy permissions handling
- Asset vs file-based operations
- iCloud Photo Library support
- Live Photos and other media types

### Architecture Benefits for Apple Photos
- PhotoSource protocol handles different item types
- Capabilities system manages feature differences
- Inspector already works with PhotoItem protocol
- Thumbnail system is abstracted

## Conclusion

The proposed architecture evolution balances immediate needs with future extensibility. Starting with composable components validates our approach while the PhotoSource protocol prepares us for Apple Photos integration. This phased approach minimizes risk while ensuring we build the right abstractions based on real requirements rather than speculation.

The key insight is that photo browsing has common patterns (display, selection, inspection) regardless of source, while source-specific features (navigation, operations) can be handled through capabilities. This architecture will serve us well as we expand beyond file system and cloud storage to platform-specific photo libraries.

[KY] if we start facing type erasure or need to work on super non-straight way to implement this abort implementation and find the way together

### Type Erasure Mitigation Strategies

If we encounter type erasure challenges, here are fallback approaches:

1. **Keep Windows/Views Strongly Typed**
   - Each source type gets its own window type
   - No dynamic switching between sources in same window
   - Clear, simple, type-safe

2. **Use Enum-Based Dispatch**
   ```swift
   enum PhotoSourceType {
       case directory(DirectoryPhotoSource)
       case s3(S3PhotoSource)
       case applePhotos(ApplePhotosLibrarySource)
   }
   ```

3. **Wrapper Types Only Where Needed**
   - Keep concrete types as long as possible
   - Only erase types at boundaries (e.g., navigation)
   - Document why type erasure is used

4. **Progressive Migration**
   - Start with concrete implementations
   - Extract common code gradually
   - Only abstract when pattern is clear

Let's proceed with Option A and adjust as we learn!
