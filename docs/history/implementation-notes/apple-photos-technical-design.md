# Apple Photos Browser - Technical Design

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   PhotolalaApp                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────┐  ┌──────────────────┐  ┌────────┐│
│  │  WelcomeView    │  │ApplePhotosBrowser│  │Inspector││
│  │ [Photos Library]│→ │     View         │←→│  View   ││
│  └─────────────────┘  └──────────────────┘  └────────┘│
│                              │                          │
│                              ↓                          │
│              ┌──────────────────────────┐               │
│              │UnifiedPhotoCollection    │               │
│              │ViewRepresentable         │               │
│              └──────────────────────────┘               │
│                              │                          │
│                              ↓                          │
│              ┌──────────────────────────┐               │
│              │  ApplePhotosProvider     │               │
│              │  implements PhotoProvider │               │
│              └──────────────────────────┘               │
│                              │                          │
│                              ↓                          │
│              ┌──────────────────────────┐               │
│              │      PhotoKit API        │               │
│              │   (PHPhotoLibrary)       │               │
│              └──────────────────────────┘               │
└─────────────────────────────────────────────────────────┘
```

## Key Components

### 1. PhotoApple (PhotoItem Implementation)

```swift
import Photos
import SwiftUI

struct PhotoApple: PhotoItem {
    let asset: PHAsset
    private let imageManager = PHCachingImageManager.default()
    
    // MARK: - PhotoItem Protocol
    
    var id: String { asset.localIdentifier }
    
    var filename: String {
        // Try to get original filename from resources
        var result = "IMG_\(asset.localIdentifier.prefix(8)).jpg"
        
        let resources = PHAssetResource.assetResources(for: asset)
        if let resource = resources.first {
            result = resource.originalFilename
        }
        
        return result
    }
    
    var displayName: String {
        filename.deletingPathExtension
    }
    
    var fileSize: Int64? {
        // This requires fetching asset resources
        return nil // Lazy load when needed
    }
    
    var creationDate: Date? {
        asset.creationDate
    }
    
    var modificationDate: Date? {
        asset.modificationDate
    }
    
    var dateTaken: Date? {
        asset.creationDate
    }
    
    var pixelWidth: Int? {
        asset.pixelWidth
    }
    
    var pixelHeight: Int? {
        asset.pixelHeight
    }
    
    var isArchived: Bool { false }
    
    var source: PhotoSource { .applePhotos }
    
    // MARK: - Loading Methods
    
    func loadThumbnail() async throws -> XImage {
        try await withCheckedThrowingContinuation { continuation in
            let targetSize = CGSize(width: 256, height: 256)
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: PhotoError.thumbnailGenerationFailed)
                }
            }
        }
    }
    
    func loadImageData() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: PhotoError.loadFailed)
                }
            }
        }
    }
    
    // MARK: - Context Menu
    
    func contextMenuItems(backupState: BackupState?, selection: [any PhotoItem]) -> [PhotoContextMenuItem] {
        var items: [PhotoContextMenuItem] = []
        
        // View in Photos
        items.append(PhotoContextMenuItem(
            title: "View in Photos",
            systemImage: "photo",
            action: .custom("viewInPhotos")
        ))
        
        // Export
        items.append(PhotoContextMenuItem(
            title: "Export...",
            systemImage: "square.and.arrow.up",
            action: .custom("export")
        ))
        
        // Info
        items.append(PhotoContextMenuItem(
            title: "Get Info",
            systemImage: "info.circle",
            action: .showInspector
        ))
        
        return items
    }
}
```

### 2. ApplePhotosProvider Implementation

```swift
import Photos
import Combine

@MainActor
class ApplePhotosProvider: BasePhotoProvider {
    private var photoLibrary: PHPhotoLibrary?
    private var fetchResult: PHFetchResult<PHAsset>?
    private var currentAlbum: PHAssetCollection?
    private let cachingImageManager = PHCachingImageManager()
    
    // MARK: - Capabilities
    
    override var capabilities: PhotoProviderCapabilities {
        [.albums, .search, .sorting, .grouping, .preview]
    }
    
    override var displayTitle: String { 
        currentAlbum?.localizedTitle ?? "All Photos" 
    }
    
    override var displaySubtitle: String {
        let count = photos.count
        if count == 1 {
            return "1 photo"
        } else {
            return "\(count) photos"
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupPhotoLibrary()
    }
    
    private func setupPhotoLibrary() {
        // Check authorization status
        Task {
            await checkAndRequestAuthorization()
        }
    }
    
    private func checkAndRequestAuthorization() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            photoLibrary = PHPhotoLibrary.shared()
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if newStatus == .authorized || newStatus == .limited {
                photoLibrary = PHPhotoLibrary.shared()
            }
        default:
            // Handle denied or restricted
            break
        }
    }
    
    // MARK: - Loading
    
    override func loadPhotos() async throws {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized ||
              PHPhotoLibrary.authorizationStatus(for: .readWrite) == .limited else {
            throw ApplePhotosError.unauthorized
        }
        
        setLoading(true)
        defer { setLoading(false) }
        
        // Fetch all photos if no album selected
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeHiddenAssets = false
        
        if let album = currentAlbum {
            fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
        } else {
            fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        }
        
        // Convert to PhotoApple items
        var photos: [PhotoApple] = []
        fetchResult?.enumerateObjects { asset, _, _ in
            photos.append(PhotoApple(asset: asset))
        }
        
        updatePhotos(photos)
        
        // Start caching thumbnails for visible range
        startCachingThumbnails()
    }
    
    // MARK: - Album Management
    
    func fetchAlbums() async -> [PHAssetCollection] {
        var albums: [PHAssetCollection] = []
        
        // Smart albums
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        smartAlbums.enumerateObjects { collection, _, _ in
            if collection.estimatedAssetCount > 0 {
                albums.append(collection)
            }
        }
        
        // User albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        userAlbums.enumerateObjects { collection, _, _ in
            albums.append(collection)
        }
        
        return albums
    }
    
    func selectAlbum(_ album: PHAssetCollection?) async throws {
        currentAlbum = album
        try await loadPhotos()
    }
    
    // MARK: - Caching
    
    private func startCachingThumbnails() {
        guard let assets = fetchResult else { return }
        
        let thumbnailSize = CGSize(width: 256, height: 256)
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        // Cache first 100 thumbnails
        let count = min(100, assets.count)
        var assetsToCache: [PHAsset] = []
        
        for i in 0..<count {
            assetsToCache.append(assets.object(at: i))
        }
        
        cachingImageManager.startCachingImages(
            for: assetsToCache,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        )
    }
    
    func updateVisibleRange(_ range: Range<Int>) {
        // Update caching based on visible range
        guard let assets = fetchResult else { return }
        
        let thumbnailSize = CGSize(width: 256, height: 256)
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic
        
        // Stop caching all
        cachingImageManager.stopCachingImagesForAllAssets()
        
        // Cache visible range + buffer
        let buffer = 50
        let start = max(0, range.lowerBound - buffer)
        let end = min(assets.count, range.upperBound + buffer)
        
        var assetsToCache: [PHAsset] = []
        for i in start..<end {
            assetsToCache.append(assets.object(at: i))
        }
        
        cachingImageManager.startCachingImages(
            for: assetsToCache,
            targetSize: thumbnailSize,
            contentMode: .aspectFill,
            options: options
        )
    }
}

// MARK: - Errors

enum ApplePhotosError: LocalizedError {
    case unauthorized
    case loadFailed
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Photo Library access is required to browse your photos"
        case .loadFailed:
            return "Failed to load photos from library"
        }
    }
}
```

### 3. Permission Handling

Add to Info.plist:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Photolala needs access to your photo library to browse and organize your photos.</string>
```

### 4. Integration Points

1. **WelcomeView**: Add Photos Library button
2. **PhotolalaApp**: Handle navigation to ApplePhotosBrowserView
3. **PhotoSource enum**: Add `.applePhotos` case
4. **PhotoManager**: Ensure caching works with PHAsset identifiers

## Implementation Order

1. **Add PhotoKit framework** to project
2. **Create PhotoApple struct** with basic PhotoItem implementation
3. **Create ApplePhotosProvider** with basic loading
4. **Add permission handling** and Info.plist entries
5. **Create ApplePhotosBrowserView** using existing components
6. **Add navigation** from WelcomeView
7. **Implement album selection** UI
8. **Add caching optimization**
9. **Add platform-specific features**
10. **Write tests** and handle edge cases

## Performance Considerations

1. **Lazy Loading**: Only load photo data when needed
2. **Thumbnail Caching**: Use PHCachingImageManager
3. **Memory Management**: Release unused PHAsset references
4. **Progressive Loading**: Load photos in batches
5. **Background Processing**: Fetch metadata asynchronously

## Testing Strategy

1. **Mock PHPhotoLibrary** for unit tests
2. **Test permission flows** in different states
3. **Performance testing** with large libraries
4. **Memory profiling** to prevent leaks
5. **UI testing** for navigation flows