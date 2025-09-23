# Photo Browser Implementation Plan

## Overview

Implement a unified photo browser component that handles local files, Apple Photos, and S3 photos through a single interface. The browser will use native NS/UICollectionView for performance with 100K+ photos, dependency injection for source abstraction, and environment-based configuration instead of UserDefaults.

### Key Design Principles

1. **Opaque Identifiers** - PhotoItem only carries an ID that the source understands, avoiding coupling
2. **Lazy Loading** - All metadata (dates, sizes) loaded on-demand to handle 100K+ files efficiently
3. **Source Abstraction** - The view never knows if an ID represents a file path, Photos identifier, or S3 key
4. **Clean Separation** - Sources encapsulate all knowledge of how to interpret IDs and fetch data

## Goals

1. **Single Browser Component** - One implementation for all photo sources
2. **Native Performance** - Handle 100K+ photos smoothly with cell recycling
3. **Source Agnostic** - Work with local, Apple Photos, and S3 through abstraction
4. **Dependency Injection** - Clean separation of concerns and testability
5. **Environment-Based** - Configuration through environment objects, not UserDefaults

## Architecture

### Component Hierarchy

```
PhotoBrowserView (SwiftUI)
├── Environment Dependencies
│   ├── PhotoSource (injected)
│   ├── ThumbnailLoader (injected)
│   ├── Configuration (injected)
│   └── CacheManager (injected)
└── PhotoCollectionView (UIViewRepresentable)
    └── Native UICollectionView/NSCollectionView
        └── PhotoCell (recycled)
```

### Dependency Injection Structure

```swift
// Core protocols for dependency injection
// Note: PhotoSourceProtocol is defined in section 1.1 with ID-based signatures

protocol ThumbnailLoaderProtocol {
    func loadThumbnail(for itemId: String) async throws -> PlatformImage?
    func cancelLoad(for itemId: String)
    func preloadThumbnails(for itemIds: [String])
}

protocol PhotoBrowserConfiguration {
    var thumbnailSize: CGSize { get }
    var gridSpacing: CGFloat { get }
    var minimumColumns: Int { get }
    var maximumColumns: Int { get }
}

// Environment injection
struct PhotoBrowserEnvironment {
    let source: any PhotoSourceProtocol
    let thumbnailLoader: any ThumbnailLoaderProtocol
    let configuration: PhotoBrowserConfiguration
    let cacheManager: CacheManager
}
```

## Phase 1: Core Components (MVP)

### 1.1 Updated PhotoItem Model

```swift
// Minimal PhotoItem - source-agnostic identifier only
struct PhotoItem: Identifiable, Hashable {
    let id: String  // Opaque identifier that the source understands
    let displayName: String  // For UI display only

    // Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}

// All metadata loaded lazily through protocols
struct PhotoMetadata {
    let fileSize: Int64?
    let creationDate: Date?
    let modificationDate: Date?
    let width: Int?
    let height: Int?
    // Additional metadata as needed
}

// The source knows how to interpret the id
protocol PhotoSourceProtocol {
    func loadPhotos() async throws -> [PhotoItem]
    func loadMetadata(for itemId: String) async throws -> PhotoMetadata
    func loadThumbnail(for itemId: String) async throws -> PlatformImage?
    func loadFullImage(for itemId: String) async throws -> Data
    var photosPublisher: AnyPublisher<[PhotoItem], Never> { get }
}
```

### 1.2 Photo Browser View

```swift
struct PhotoBrowserView: View {
    // Injected dependencies
    let environment: PhotoBrowserEnvironment

    // State
    @State private var photos: [PhotoItem] = []
    @State private var selection = Set<PhotoItem>()
    @State private var isLoading = false

    var body: some View {
        PhotoCollectionViewRepresentable(
            photos: photos,
            selection: $selection,
            environment: environment
        )
        .task {
            await loadPhotos()
        }
        .onReceive(environment.source.photosPublisher) { newPhotos in
            self.photos = newPhotos
        }
    }

    private func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }

        do {
            photos = try await environment.source.loadPhotos()
        } catch {
            // Handle error
        }
    }
}
```

### 1.3 Collection View Representable

```swift
struct PhotoCollectionViewRepresentable: UIViewControllerRepresentable {
    let photos: [PhotoItem]
    @Binding var selection: Set<PhotoItem>
    let environment: PhotoBrowserEnvironment

    func makeUIViewController(context: Context) -> PhotoCollectionViewController {
        let controller = PhotoCollectionViewController(environment: environment)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: PhotoCollectionViewController, context: Context) {
        controller.updatePhotos(photos)
        controller.updateSelection(selection)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: PhotoCollectionViewControllerDelegate {
        // Handle selection changes
    }
}
```

### 1.4 Native Collection View Controller

```swift
class PhotoCollectionViewController: UIViewController {
    private let environment: PhotoBrowserEnvironment
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Section, PhotoItem>!

    init(environment: PhotoBrowserEnvironment) {
        self.environment = environment
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupDataSource()
    }

    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)

        // Register cell
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
    }

    private func createLayout() -> UICollectionViewLayout {
        // Compositional layout for responsive grid
        let config = environment.configuration
        // ... layout implementation
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, PhotoItem>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PhotoCell.reuseIdentifier,
                for: indexPath
            ) as! PhotoCell

            cell.configure(with: item, environment: self?.environment)
            return cell
        }
    }
}
```

### 1.5 Photo Cell

```swift
class PhotoCell: UICollectionViewCell {
    static let reuseIdentifier = "PhotoCell"

    private let imageView = UIImageView()
    private var currentItemId: String?
    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        loadTask?.cancel()
        currentItemId = nil
    }

    func configure(with item: PhotoItem, environment: PhotoBrowserEnvironment?) {
        currentItemId = item.id

        // Cancel previous load
        loadTask?.cancel()

        // Load thumbnail off main actor
        loadTask = Task {
            guard let environment = environment else { return }

            do {
                // Load thumbnail on background
                let image = try await environment.thumbnailLoader.loadThumbnail(for: item.id)

                // Only hop to main actor for UI update
                await MainActor.run {
                    // Check if cell is still for same item
                    guard currentItemId == item.id else { return }

                    imageView.image = image
                }
            } catch {
                // Show placeholder or error state
                await MainActor.run {
                    guard currentItemId == item.id else { return }
                    // Set error placeholder
                }
            }
        }
    }
}
```

## Phase 2: Photo Sources

### 2.1 Local Photo Source

```swift
@MainActor
class LocalPhotoSource: PhotoSourceProtocol {
    private let directoryURL: URL
    private let catalogService: CatalogService

    // Map item IDs back to file paths (source's private knowledge)
    private var idToPath: [String: URL] = [:]

    @Published private var photos: [PhotoItem] = []

    nonisolated var photosPublisher: AnyPublisher<[PhotoItem], Never> {
        $photos.eraseToAnyPublisher()
    }

    init(directoryURL: URL, catalogService: CatalogService) {
        self.directoryURL = directoryURL
        self.catalogService = catalogService
    }

    func loadPhotos() async throws -> [PhotoItem] {
        // Capture values before detaching to avoid actor isolation violations
        let directoryURL = self.directoryURL

        // Enumerate files off main actor for performance
        let (items, pathMap) = try await Task.detached {
            let fileManager = FileManager.default
            let enumerator = fileManager.enumerator(at: directoryURL,
                                                    includingPropertiesForKeys: [.isRegularFileKey],
                                                    options: [.skipsHiddenFiles])

            var items: [PhotoItem] = []
            var pathMap: [String: URL] = [:]

            while let url = enumerator?.nextObject() as? URL {
                // Generate ID from path (could use hash or catalog key)
                let id = url.path.replacingOccurrences(of: directoryURL.path, with: "")
                let displayName = url.lastPathComponent

                items.append(PhotoItem(id: id, displayName: displayName))
                pathMap[id] = url
            }

            return (items, pathMap)
        }.value

        // Update state on main actor
        self.idToPath = pathMap
        self.photos = items
        return items
    }

    nonisolated func loadMetadata(for itemId: String) async throws -> PhotoMetadata {
        // Get URL from main actor
        let url = await MainActor.run {
            idToPath[itemId]
        }

        guard let url = url else {
            throw PhotoSourceError.itemNotFound
        }

        // Load attributes off main actor
        return try await Task.detached {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)

            return PhotoMetadata(
                fileSize: attributes[.size] as? Int64,
                creationDate: attributes[.creationDate] as? Date,
                modificationDate: attributes[.modificationDate] as? Date,
                width: nil,  // Would need to read image
                height: nil
            )
        }.value
    }

    nonisolated func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
        // Get URL from main actor
        let url = await MainActor.run {
            idToPath[itemId]
        }

        guard let url = url else {
            throw PhotoSourceError.itemNotFound
        }

        // Load from cache or generate off main actor
        return try await catalogService.loadThumbnail(for: url)
    }

    nonisolated func loadFullImage(for itemId: String) async throws -> Data {
        // Get URL from main actor
        let url = await MainActor.run {
            idToPath[itemId]
        }

        guard let url = url else {
            throw PhotoSourceError.itemNotFound
        }

        // Load data off main actor
        return try await Task.detached {
            try Data(contentsOf: url)
        }.value
    }

    // Removed generateId - ID generation is now inline in loadPhotos to avoid actor isolation issues
}
```

### 2.2 Apple Photos Source

```swift
class ApplePhotosSource: PhotoSourceProtocol {
    private let photoLibrary: PHPhotoLibrary
    private let imageManager = PHCachingImageManager()

    @Published private var photos: [PhotoItem] = []

    var photosPublisher: AnyPublisher<[PhotoItem], Never> {
        $photos.eraseToAnyPublisher()
    }

    func loadPhotos() async throws -> [PhotoItem] {
        // Request authorization
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized else {
            throw PhotoSourceError.notAuthorized
        }

        // Fetch all photos
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        var items: [PhotoItem] = []
        results.enumerateObjects { asset, _, _ in
            // Use localIdentifier as opaque ID
            let item = PhotoItem(
                id: asset.localIdentifier,
                displayName: asset.localIdentifier.suffix(8).description
            )
            items.append(item)
        }

        photos = items
        return items
    }

    func loadMetadata(for itemId: String) async throws -> PhotoMetadata {
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [itemId], options: nil)
        guard let asset = results.firstObject else {
            throw PhotoSourceError.assetNotFound
        }

        return PhotoMetadata(
            fileSize: nil,  // Not readily available
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            width: asset.pixelWidth,
            height: asset.pixelHeight
        )
    }

    func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
        // Fetch asset and request image
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [itemId], options: nil)
        guard let asset = results.firstObject else {
            throw PhotoSourceError.assetNotFound
        }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic

            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 256, height: 256),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
```

### 2.3 S3 Photo Source

```swift
class S3PhotoSource: PhotoSourceProtocol {
    private let s3Service: S3Service
    private let userId: String

    @Published private var photos: [PhotoItem] = []

    var photosPublisher: AnyPublisher<[PhotoItem], Never> {
        $photos.eraseToAnyPublisher()
    }

    init(s3Service: S3Service, userId: String) {
        self.s3Service = s3Service
        self.userId = userId
    }

    func loadPhotos() async throws -> [PhotoItem] {
        // Fetch from S3 catalog
        let catalog = try await s3Service.fetchCatalog(for: userId)

        let items = catalog.photos.map { photo in
            PhotoItem(
                id: photo.md5,  // Use MD5 as stable ID
                displayName: photo.filename
            )
        }

        photos = items
        return items
    }

    func loadMetadata(for itemId: String) async throws -> PhotoMetadata {
        // Find photo in catalog by MD5
        guard let photo = findPhotoByMD5(itemId) else {
            throw PhotoSourceError.itemNotFound
        }

        return PhotoMetadata(
            fileSize: photo.size,
            creationDate: photo.photoDate,
            modificationDate: photo.modified,
            width: photo.width,
            height: photo.height
        )
    }

    func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
        // Find photo in catalog and download thumbnail
        guard let photo = findPhotoByMD5(itemId) else {
            throw PhotoSourceError.itemNotFound
        }

        return try await s3Service.downloadThumbnail(key: photo.s3Key, bucket: photo.bucket)
    }
}
```

## Phase 3: Dependency Injection Setup

### 3.1 Environment Configuration

```swift
// Configuration without UserDefaults
struct DefaultPhotoBrowserConfiguration: PhotoBrowserConfiguration {
    let thumbnailSize = CGSize(width: 256, height: 256)
    let gridSpacing: CGFloat = 8
    let minimumColumns = 3
    let maximumColumns = 10
}

// Environment factory
class PhotoBrowserEnvironmentFactory {
    static func makeLocalEnvironment(directoryURL: URL) -> PhotoBrowserEnvironment {
        let catalogService = CatalogService(cacheRoot: .defaultCacheDirectory)
        let source = LocalPhotoSource(directoryURL: directoryURL, catalogService: catalogService)
        let thumbnailLoader = UnifiedThumbnailLoader(source: source)
        let configuration = DefaultPhotoBrowserConfiguration()
        let cacheManager = CacheManager(maxSize: 100_000_000) // 100MB

        return PhotoBrowserEnvironment(
            source: source,
            thumbnailLoader: thumbnailLoader,
            configuration: configuration,
            cacheManager: cacheManager
        )
    }

    static func makeApplePhotosEnvironment() -> PhotoBrowserEnvironment {
        let source = ApplePhotosSource()
        let thumbnailLoader = UnifiedThumbnailLoader(source: source)
        let configuration = DefaultPhotoBrowserConfiguration()
        let cacheManager = CacheManager(maxSize: 100_000_000)

        return PhotoBrowserEnvironment(
            source: source,
            thumbnailLoader: thumbnailLoader,
            configuration: configuration,
            cacheManager: cacheManager
        )
    }

    static func makeS3Environment(credentials: S3Credentials, userId: String) -> PhotoBrowserEnvironment {
        let s3Service = S3Service(credentials: credentials)
        let source = S3PhotoSource(s3Service: s3Service, userId: userId)
        let thumbnailLoader = UnifiedThumbnailLoader(source: source)
        let configuration = DefaultPhotoBrowserConfiguration()
        let cacheManager = CacheManager(maxSize: 100_000_000)

        return PhotoBrowserEnvironment(
            source: source,
            thumbnailLoader: thumbnailLoader,
            configuration: configuration,
            cacheManager: cacheManager
        )
    }
}
```

### 3.2 Usage in SwiftUI

```swift
struct ContentView: View {
    @State private var selectedSource: PhotoSourceType = .local
    @State private var browserEnvironment: PhotoBrowserEnvironment?

    var body: some View {
        NavigationSplitView {
            // Source selector
            List(selection: $selectedSource) {
                Label("Local Photos", systemImage: "folder")
                    .tag(PhotoSourceType.local)
                Label("Apple Photos", systemImage: "photo.on.rectangle")
                    .tag(PhotoSourceType.applePhotos)
                Label("Cloud Photos", systemImage: "cloud")
                    .tag(PhotoSourceType.s3)
            }
        } detail: {
            if let environment = browserEnvironment {
                PhotoBrowserView(environment: environment)
            } else {
                Text("Select a photo source")
            }
        }
        .onChange(of: selectedSource) { _, newSource in
            updateEnvironment(for: newSource)
        }
    }

    private func updateEnvironment(for source: PhotoSourceType) {
        switch source {
        case .local:
            // Get directory from user selection
            let directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
            browserEnvironment = PhotoBrowserEnvironmentFactory.makeLocalEnvironment(directoryURL: directoryURL)

        case .applePhotos:
            browserEnvironment = PhotoBrowserEnvironmentFactory.makeApplePhotosEnvironment()

        case .s3:
            // Get credentials from secure storage (not UserDefaults)
            let credentials = loadS3Credentials()
            let userId = loadUserId()
            browserEnvironment = PhotoBrowserEnvironmentFactory.makeS3Environment(
                credentials: credentials,
                userId: userId
            )
        }
    }
}
```

## Phase 4: Performance Optimizations

### 4.1 Thumbnail Loading Strategy

```swift
// Actor-isolated to prevent data races
actor UnifiedThumbnailLoader: ThumbnailLoaderProtocol {
    private let source: any PhotoSourceProtocol
    private let cache = NSCache<NSString, PlatformImage>()
    private var loadingTasks: [String: Task<PlatformImage?, Error>] = [:]

    init(source: any PhotoSourceProtocol) {
        self.source = source
        cache.countLimit = 1000
    }

    func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
        // Check cache first
        if let cached = cache.object(forKey: itemId as NSString) {
            return cached
        }

        // Check if already loading
        if let existingTask = loadingTasks[itemId] {
            return try await existingTask.value
        }

        // Create new load task
        let task = Task<PlatformImage?, Error> {
            // Load off the actor
            let image = try await source.loadThumbnail(for: itemId)

            // Cache and cleanup back on actor
            await self.cacheImage(image, for: itemId)
            return image
        }

        loadingTasks[itemId] = task
        return try await task.value
    }

    private func cacheImage(_ image: PlatformImage?, for itemId: String) {
        if let image = image {
            cache.setObject(image, forKey: itemId as NSString)
        }
        loadingTasks.removeValue(forKey: itemId)
    }

    func cancelLoad(for itemId: String) {
        loadingTasks[itemId]?.cancel()
        loadingTasks.removeValue(forKey: itemId)
    }

    func preloadThumbnails(for itemIds: [String]) {
        // Preload in background with low priority
        Task(priority: .background) {
            for itemId in itemIds {
                try? await loadThumbnail(for: itemId)
            }
        }
    }

    // Additional methods for scroll performance
    func pauseBackgroundLoads() {
        // Cancel low-priority loads
    }

    func prioritizeLoads(for itemIds: [String]) {
        // Reorder load queue
    }
}
```

### 4.2 Scroll Performance

```swift
extension PhotoCollectionViewController {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Pause non-visible loads during scrolling
        environment.thumbnailLoader.pauseBackgroundLoads()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Resume and prioritize visible cells
        let visiblePaths = collectionView.indexPathsForVisibleItems
        let visibleItems = visiblePaths.compactMap { dataSource.itemIdentifier(for: $0) }
        environment.thumbnailLoader.prioritizeLoads(for: visibleItems)
    }
}
```

## Testing Strategy

### Unit Tests
- Test each PhotoSource independently
- Mock dependencies for isolation
- Test thumbnail loading and caching
- Test collection view data source updates

### Integration Tests
- Test source switching
- Test memory management with large datasets
- Test scroll performance
- Test cell reuse

### Performance Tests
- Load 100K+ items
- Measure scroll frame rate
- Monitor memory usage
- Profile CPU usage

## Migration Path

1. **Phase 1**: Implement core browser with local photos
2. **Phase 2**: Add Apple Photos support
3. **Phase 3**: Add S3 support
4. **Phase 4**: Performance optimizations
5. **Phase 5**: Advanced features (selection, batch operations)

## Success Metrics

- Smooth scrolling at 60fps with 100K+ photos
- Memory usage under 100MB for browser view
- Thumbnail load time < 100ms for cached items
- Source switching < 500ms
- Zero UserDefaults dependencies

## Risk Mitigation

- **Performance**: Use Instruments profiling early and often
- **Memory**: Implement strict cache limits
- **Compatibility**: Test on minimum supported OS versions
- **Source Differences**: Abstract through protocols, not concrete types
- **Testing**: Maintain high test coverage for each source

## Future Enhancements

- Multi-selection support
- Drag and drop
- Search and filtering
- Album/collection support
- Export functionality
- Batch operations (delete, move, copy)