# Photo Browser Architecture

## Overview

The Photolala photo browser is a unified component that displays photos from multiple sources (local filesystem, Apple Photos library, cloud storage) through a single, consistent interface. The architecture emphasizes source abstraction, dependency injection, and performance optimization for handling large photo collections (100K+ images).

## Core Design Principles

### 1. Source Abstraction
Photos are represented by opaque identifiers that only the source understands. The browser view never knows whether an ID represents a file path, Photos library identifier, or S3 object key. This complete abstraction enables seamless source switching and clean separation of concerns.

### 2. Lazy Loading
All expensive operations (metadata retrieval, thumbnail generation, full image loading) are performed on-demand. This enables the browser to handle massive photo collections without loading everything into memory upfront.

### 3. Dependency Injection
All dependencies are injected through a `PhotoBrowserEnvironment` container, making the code testable, configurable, and maintainable. The browser view receives everything it needs through this environment, avoiding global state and tight coupling.

### 4. Platform Optimization
The implementation uses native collection views (NSCollectionView on macOS, UICollectionView on iOS) for optimal performance, with platform-specific optimizations while maintaining a shared SwiftUI interface.

## Architecture Components

### Component Hierarchy

```
PhotoBrowserView (SwiftUI)
├── PhotoBrowserEnvironment (Dependency Container)
│   ├── PhotoSource (Protocol Implementation)
│   ├── Configuration (Layout & Behavior)
│   └── CacheManager (Optional)
├── PhotoCollectionViewRepresentable (SwiftUI ↔ UIKit/AppKit Bridge)
└── PhotoCollectionViewController (Native Controller)
    ├── Collection View (UICollectionView/NSCollectionView)
    ├── Diffable Data Source
    └── PhotoCell (Recycled Cells)
```

### Data Flow

```
1. User Action → PhotoBrowserView
2. PhotoBrowserView → PhotoSource.loadPhotos()
3. PhotoSource → [PhotoBrowserItem] (opaque IDs)
4. Items → CollectionView via Diffable Data Source
5. Cell Display → PhotoSource.loadThumbnail(id)
6. Async Load → Update Cell UI
```

## Key Components

### PhotoBrowserItem
```swift
struct PhotoBrowserItem {
    let id: String          // Opaque identifier
    let displayName: String // UI display name
}
```
Minimal representation using opaque identifiers. The source determines how to interpret the ID.

### PhotoSourceProtocol
```swift
protocol PhotoSourceProtocol {
    func loadPhotos() async throws -> [PhotoBrowserItem]
    func loadMetadata(for itemId: String) async throws -> PhotoBrowserMetadata
    func loadThumbnail(for itemId: String) async throws -> PlatformImage?
    func loadFullImage(for itemId: String) async throws -> Data
    var photosPublisher: AnyPublisher<[PhotoBrowserItem], Never> { get }
    var capabilities: PhotoSourceCapabilities { get }
}
```
The contract that all photo sources must implement. Sources encapsulate all knowledge about their storage backend.

### PhotoBrowserEnvironment
```swift
struct PhotoBrowserEnvironment {
    let source: any PhotoSourceProtocol
    let configuration: PhotoBrowserConfiguration
    let cacheManager: CacheManager?
}
```
Dependency injection container that provides all required dependencies to the browser view.

## Photo Sources

### LocalPhotoSource
- **Purpose**: Browse photos from local filesystem
- **ID Format**: Relative path from root directory
- **Key Features**:
  - Security-scoped resource handling (iOS)
  - Off-main-actor file enumeration
  - CoreGraphics thumbnail generation
  - Direct file access
- **Security Scope Management**:
  - DocumentPicker starts the security scope before dismissing
  - LocalPhotoSource initializer accepts `securityScopeAlreadyStarted` flag
  - Ensures scope is started only once (prevents leaks)
  - Reliable cleanup in `deinit` when `ownsSecurityScopedResource` is true

### ApplePhotosSource
- **Purpose**: Browse photos from Apple Photos library
- **ID Format**: PHAsset localIdentifier
- **Key Features**:
  - PhotoKit integration
  - Authorization handling
  - PHCachingImageManager for performance
  - iCloud photo support

### S3PhotoSource (Planned)
- **Purpose**: Browse photos from cloud storage
- **ID Format**: S3 object key or MD5 hash
- **Key Features**:
  - Catalog-based browsing
  - Progressive loading
  - Bandwidth optimization
  - Offline cache support

## Performance Optimizations

### Current Implementations

1. **Cell Recycling**: Reuse collection view cells with proper cleanup
2. **Async Loading**: All I/O operations off main thread
3. **Task Cancellation**: Cancel thumbnail loads when cells are recycled
4. **Lazy Metadata**: Load metadata only when needed
5. **Native Views**: Use platform-native collection views for optimal scrolling

### Future Optimizations

1. **Unified Cache Layer**
   - Shared memory cache across sources
   - Disk cache for thumbnails
   - Cache size management
   - LRU eviction policy

2. **Scroll Performance**
   - Pause background loads during scrolling
   - Prioritize visible cells
   - Prefetch adjacent cells
   - Adaptive quality based on scroll velocity

3. **Progressive Loading**
   - Load low-quality placeholders first
   - Update with high-quality images
   - Cancel upgrades if scrolled away

## Multi-Window Architecture (macOS)

The macOS implementation supports multiple windows, each showing a different photo source:

```swift
PhotoWindowManager (Singleton)
├── Window Controllers (Array)
├── Observer Tokens (Cleanup)
└── Window Factory Methods
    ├── openWindow(for: URL)
    ├── openApplePhotosWindow()
    └── openCloudPhotosWindow()
```

Each window contains its own NavigationStack and PhotoBrowserView with independent environment.

## Platform Differences

### iOS
- Single window with NavigationStack
- DocumentPickerView (UIDocumentPicker wrapper) starts the security scope before dismissing, then pushes the browser via NavigationStack
- Security-scoped resource handling with proper scope lifecycle management
- Sheet-based navigation with careful dismissal timing to avoid SwiftUI navigation bugs
- Touch-optimized interactions

### macOS
- Multiple windows support
- Direct folder selection
- Menu bar integration
- Keyboard shortcuts
- Mouse hover effects

## Configuration

### PhotoBrowserConfiguration Protocol
```swift
protocol PhotoBrowserConfiguration {
    var thumbnailSize: CGSize { get }
    var gridSpacing: CGFloat { get }
    var minimumColumns: Int { get }
    var maximumColumns: Int { get }
    var allowsMultipleSelection: Bool { get }
    var showsItemInfo: Bool { get }
}
```

Configuration is injected through the environment, not stored in UserDefaults, maintaining testability and avoiding global state.

## Future Refactoring Notes

### High Priority Refactoring

1. **Extract Thumbnail Loading**
   ```swift
   // Create unified thumbnail loader
   actor ThumbnailLoader {
       private let cache: NSCache<NSString, PlatformImage>
       private let diskCache: DiskCache?
       private var loadingTasks: [String: Task<PlatformImage?, Error>]

       func loadThumbnail(for id: String, from source: PhotoSourceProtocol) async throws -> PlatformImage?
   }
   ```
   Benefits: Shared caching, deduplication, better memory management

2. **Implement Factory Pattern**
   ```swift
   enum PhotoSourceType {
       case local(URL)
       case applePhotos
       case s3(credentials: S3Credentials)
   }

   class PhotoBrowserEnvironmentFactory {
       static func makeEnvironment(for type: PhotoSourceType) -> PhotoBrowserEnvironment
   }
   ```
   Benefits: Cleaner initialization, easier testing, consistent setup

3. **Add Coordinator Pattern**
   ```swift
   protocol PhotoBrowserCoordinator {
       func showDetail(for item: PhotoBrowserItem)
       func showEditor(for item: PhotoBrowserItem)
       func handleError(_ error: Error)
   }
   ```
   Benefits: Decoupled navigation, reusable flows, better testability

### Medium Priority Refactoring

1. **Performance Monitoring**
   - Add metrics collection for load times
   - Track scroll performance (FPS)
   - Monitor memory usage
   - Log cache hit rates

2. **Error Recovery**
   - Retry failed thumbnail loads
   - Fallback to lower quality
   - Offline mode handling
   - User-friendly error messages

3. **Advanced Caching**
   - Implement disk cache for thumbnails
   - Add cache warming for likely views
   - Smart eviction based on usage patterns
   - Cross-session cache persistence

### Low Priority Enhancements

1. **Search and Filtering**
   - Add search bar to browser
   - Filter by date, type, size
   - Smart albums/collections
   - Face/object detection integration

2. **Batch Operations**
   - Multi-select with keyboard modifiers
   - Bulk delete/export
   - Drag and drop support
   - Context menus

3. **View Options**
   - List view alternative
   - Adjustable thumbnail sizes
   - Sort options
   - Grouping by date/album

## Testing Strategy

### Unit Testing
```swift
// Test photo sources in isolation
class MockPhotoSource: PhotoSourceProtocol {
    var mockPhotos: [PhotoBrowserItem] = []
    var loadPhotosCalled = false

    func loadPhotos() async throws -> [PhotoBrowserItem] {
        loadPhotosCalled = true
        return mockPhotos
    }
}
```

### Integration Testing
- Test source switching
- Verify memory management
- Test error handling
- Validate state updates

### Performance Testing
- Measure scroll performance with 10K+ items
- Profile memory usage
- Benchmark thumbnail loading
- Test cache effectiveness

## Migration Path

### Phase 1: Current State ✅
- Basic photo browsing
- Local and Apple Photos sources
- Simple dependency injection

### Phase 2: Performance Layer
- Add unified thumbnail loader
- Implement caching strategy
- Add scroll optimizations

### Phase 3: Cloud Integration
- Implement S3PhotoSource
- Add sync capabilities
- Offline support

### Phase 4: Advanced Features
- Search and filtering
- Batch operations
- Smart collections

## Design Decisions

### Why Opaque IDs?
Using opaque identifiers instead of typed unions keeps the browser truly source-agnostic. The browser doesn't need to know about file paths, asset identifiers, or S3 keys - it just passes IDs back to the source.

### Why Protocol-Based?
Protocols provide a clean contract without inheritance complexity. They enable easy mocking for tests and allow sources to be actors, classes, or structs as needed.

### Why Environment Injection?
Passing dependencies through an environment container makes them explicit, testable, and configurable. It avoids hidden dependencies and global state.

### Why Native Collection Views?
SwiftUI's grid views don't yet match the performance of UICollectionView/NSCollectionView for large datasets. Native views provide cell recycling, prefetching, and optimal scrolling.

## Common Pitfalls to Avoid

1. **Don't Load All Metadata Upfront**
   - Metadata should be loaded on-demand
   - Initial load should be minimal

2. **Don't Block the Main Thread**
   - All I/O must be async
   - Image processing off main thread

3. **Don't Leak Memory**
   - Cancel tasks when cells are recycled
   - Clear caches on memory warnings
   - Use weak references in closures

4. **Don't Assume Source Availability**
   - Network sources may be offline
   - Photos access may be revoked
   - Files may be deleted

5. **Don't Ignore Platform Differences**
   - iOS needs security scopes
   - macOS supports multiple windows
   - Different interaction patterns

## Conclusion

The photo browser architecture provides a solid foundation for displaying photos from multiple sources with good performance and clean separation of concerns. The design is extensible, testable, and maintainable. Future enhancements should focus on performance optimization and user features while maintaining the clean architecture established here.