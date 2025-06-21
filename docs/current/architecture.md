# Photolala Architecture

Last Updated: June 21, 2025 (Added Apple Photos Library support)

## Overview

Photolala is a cross-platform photo browser application built with SwiftUI, supporting macOS, iOS, and tvOS. It follows a window-per-folder architecture on macOS and uses native collection views for optimal performance with large photo collections. The application now features a unified photo browser architecture that supports multiple photo sources (local files, S3 cloud storage) through a consistent interface.

## Core Architecture Principles

1. **Platform-Native UI**: Uses NSCollectionView (macOS) and UICollectionView (iOS) wrapped in SwiftUI
2. **Efficient Memory Management**: Lightweight PhotoReference model with lazy thumbnail loading
3. **Window-Per-Folder** (macOS): Each folder opens in its own window, allowing side-by-side comparison
4. **Reactive Updates**: @Observable models for automatic UI updates
5. **Protocol-Oriented Design**: PhotoItem protocol enables unified handling of different photo sources
6. **Provider Pattern**: PhotoProvider abstraction allows extensible photo source support

## Component Architecture

### Models

#### PhotoItem Protocol
- Common interface for all photo types (PhotoFile, PhotoS3, PhotoApple)
- Key methods: `loadThumbnail()`, `loadImageData()`, `contextMenuItems()`
- Properties: dimensions, dates, archive status, MD5 hash
- Enables unified UI components to work with any photo source

#### PhotoReference (Legacy)
- Lightweight file representation
- Properties: `directoryPath` (NSString), `filename` (String)
- Computed: `fileURL`, `filePath`
- Observable with thumbnail caching
- Being replaced by PhotoFile in unified architecture

#### PhotoFile
- Enhanced local photo representation implementing PhotoItem
- Includes metadata, archive info, thumbnail state
- Works with PhotoManager for efficient loading

#### ThumbnailDisplaySettings
- Per-window display preferences
- Display modes: Scale to Fit / Scale to Fill
- Size options: Small (64px), Medium (128px), Large (256px)

#### Selection System
- Uses native collection view selection
- No custom SelectionManager
- State maintained by UICollectionView/NSCollectionView
- Selection changes communicated via callbacks

#### S3Photo
- Represents a photo in S3 storage
- Combines catalog entry with S3 metadata
- Properties: md5, filename, size, dates, dimensions
- Computed keys for S3 paths
- Storage class awareness (Standard/Deep Archive)

#### PhotoApple
- Represents a photo from Apple Photos Library
- Wraps PHAsset from PhotoKit framework
- Integrates with PHCachingImageManager for thumbnails
- Supports iCloud Photo Library assets
- Provides metadata from Photos app (location, creation date, etc.)
- Implements PhotoItem protocol for unified browser compatibility

#### PhotoMetadata
- EXIF and file metadata
- Codable for plist serialization
- Camera info, GPS coordinates, dates
- Original filename preservation

#### ArchiveStatus
- Deep Archive restoration states
- Tracks restoration progress
- Expiration dates for restored files

### Services

#### PhotoProvider Protocol & Implementations
- **BasePhotoProvider**: Common functionality, @MainActor for thread safety
- **DirectoryPhotoProvider**: Loads photos from local directories with progressive loading and priority thumbnails
  - Uses ProgressivePhotoLoader for fast initial display (first 200 photos)
  - Integrates PriorityThumbnailLoader for visible-first loading
  - Provides loading progress and status updates
  - Supports dynamic visible range updates from scroll monitoring
- **S3PhotoProvider**: Loads photos from S3 with catalog sync support
- **ApplePhotosProvider**: Integrates with Apple Photos Library via PhotoKit
  - Authorization handling for photo library access
  - Album browsing (smart albums and user collections)
  - Thumbnail caching with PHCachingImageManager
  - Supports iCloud Photo Library assets
- Protocol includes: loading, refreshing, grouping, sorting capabilities
- Observable with Combine publishers for reactive UI updates
- PhotoProviderCapabilities for feature discovery

#### PhotoManager (Singleton)
- Dual caching: memory (NSCache) + disk
- Thumbnail generation with proper scaling
- Content-based identification (MD5)
- Thread-safe with QoS .userInitiated

#### DirectoryScanner
- Scans directories for supported image formats
- Creates PhotoReference objects
- Filters: jpg, jpeg, png, heic, heif, tiff, bmp, gif, webp

#### CatalogAwarePhotoLoader
- Intelligent photo loader with catalog support
- Checks for `.photolala/` catalog directory
- Falls back to DirectoryScanner if no catalog exists
- 5-minute caching for network directories using UUID-based keys
- Background catalog generation for directories with 100+ photos
- Thread-safe UUID management with concurrent queue

#### ProgressivePhotoLoader
- Loads photos in stages for better perceived performance
- Initial batch: First 200 photos loaded immediately
- Background loading: Remaining photos in 100-photo batches
- Catalog-aware: Uses catalog for instant loading when available
- Background catalog generation after loading completes

#### PriorityThumbnailLoader
- Priority-based thumbnail loading system
- Priority levels: visible, nearVisible, prefetch, background
- Dynamic priority updates based on scroll position
- Cancels non-visible requests during fast scrolling
- Integrates with PhotoManager for actual thumbnail generation

#### PhotolalaCatalogService
- Manages v5.0 offline catalogs with `.photolala/` directory structure
- 16-way MD5-based sharding for scalability
- CSV format: `md5,filename,size,photodate,modified,width,height`
- Directory UUID for cache invalidation
- Atomic updates for consistency

#### S3BackupService
- Uploads photos to S3 with Deep Archive storage
- Generates and uploads thumbnails (Standard storage)
- Stores metadata in binary plist format
- File naming: `{md5}.dat` for universal format support
- Path structure: `photos/{userId}/`, `thumbnails/{userId}/`, `metadata/{userId}/`

#### S3BackupManager (Singleton)
- Manages S3BackupService lifecycle
- Tracks upload progress and storage usage
- Handles quota enforcement
- AWS credentials from Keychain/environment

#### S3CatalogGenerator
- Creates v5.0 catalog format with `.photolala/` structure
- 16-way sharding based on MD5 hash prefix (0-f)
- CSV format: md5,filename,size,photodate,modified,width,height
- Uploads to `catalogs/{userId}/.photolala/` path
- Enables browsing without ListObjects calls

#### S3CatalogSyncService
- Syncs v5.0 catalog from S3 to local cache
- Downloads from `catalogs/{userId}/.photolala/` path
- Manifest-based change detection with directory UUID
- Atomic updates with temporary directory swap
- Offline mode support

#### S3DownloadService (Actor)
- Downloads thumbnails and photos from S3
- Local caching with LRU eviction
- Handles Deep Archive restore status
- Thread-safe with actor isolation

#### IdentityManager (Singleton)
- Sign in with Apple integration
- User authentication state
- Service user ID mapping
- Keychain persistence

#### BackupQueueManager (Singleton)
- Manages star-based backup queue
- Activity timer (10 min prod, 3 min debug)
- Auto-backup after inactivity
- Queue persistence across launches
- MD5 computation on demand
- Notifications for UI updates

#### BackupStatusManager (Singleton)
- Shared upload progress tracking
- Status bar visibility control
- Speed and time remaining calculations
- Progress state for all windows

#### IAPManager (Singleton)
- StoreKit 2 implementation
- Subscription management
- Receipt validation
- Product loading and purchasing

### Views

#### Unified Photo Browser Components
- **UnifiedPhotoCollectionViewController**: Platform-agnostic controller working with any PhotoProvider
- **UnifiedPhotoCollectionViewRepresentable**: SwiftUI bridge for the unified controller
- **UnifiedPhotoCell**: Collection view cell displaying any PhotoItem
- Used by both PhotoBrowserView and S3PhotoBrowserView for consistency

#### PhotoBrowserView
- Main container with toolbar
- Now uses UnifiedPhotoCollectionViewRepresentable with DirectoryPhotoProvider
- Shows progressive loading status with progress bar
- Platform-specific navigation:
  - macOS: Own NavigationStack
  - iOS: Uses parent NavigationStack
- Manages settings and selection state

#### PhotoCollectionViewController
- NSViewController/UIViewController subclass
- Hosts native collection views
- Handles platform-specific interactions:
  - macOS: Double-click navigation
  - iOS: Tap navigation, selection mode
- Cell update pattern:
  - Property changes trigger layout invalidation
  - All visual updates batched in layout pass
  - Ensures consistency and efficiency

#### PhotoPreviewView
- Pure SwiftUI implementation
- Full image display with zoom/pan
- MagnificationGesture + DragGesture
- Cross-platform image handling

#### S3BackupTestView
- Development UI for S3 backup testing
- Photo upload with PhotosPicker
- AWS credentials configuration
- Catalog generation controls

#### Inspector Panel
- **InspectorView**: Main content view showing photo details
  - Adaptive layout: empty state, single selection, multiple selection
  - Shows information, quick actions, metadata
- **InspectorContainer**: Platform-specific presentation wrapper
  - macOS: Sidebar using HStack layout (content shrinks)
  - iOS/iPad: Modal sheet or popover
- **Integration**: 
  - Toggle via toolbar button, ⌘I shortcut, or View menu
  - Responsive to selection changes
  - Smooth slide animation

#### S3PhotoBrowserView
- Browse photos from S3 catalog
- Grid layout with thumbnails
- Offline mode support
- Thumbnail size options
- Selection for batch operations

#### AWSCredentialsView
- AWS access key configuration
- Secure Keychain storage
- Connection testing
- Form-based input

#### PhotoRetrievalView
- Deep Archive restoration UI
- Batch selection support
- Cost estimation display

#### BackupStatusBar
- Shared progress display at window bottom
- Shows upload count, speed, time remaining
- Safari-style download bar appearance
- Auto-hides when complete

#### PhotoCellBadge
- Badge overlay for backup states
- Click to toggle star/unstar
- Visual states: ⭐ ⬆️ ☁️ ❌
- Hover effects and tooltips
- Restoration progress tracking

#### UserAccountView
- Sign in with Apple UI
- Subscription status display
- Account information
- Sign out functionality

## Navigation Architecture

### macOS
```
App Launch → No default window
    ↓
File → Open Folder (⌘O) → NSOpenPanel
    ↓
New Window with NavigationStack → PhotoBrowserView
    ↓
Double-click folder → Push new PhotoBrowserView
    ↓
Double-click photo → Push PhotoPreviewView
```

### iOS
```
App Launch → Root NavigationStack → WelcomeView
    ↓
Select Folder → Document Picker
    ↓
Auto-navigate → PhotoBrowserView
    ↓
Tap folder → Push new PhotoBrowserView
    ↓
Tap photo → Push PhotoPreviewView
```

## Data Flow

1. **Photo Loading**: 
   - CatalogAwarePhotoLoader checks for `.photolala/` catalog
   - If catalog exists: Load from catalog (fast path)
   - If no catalog: DirectoryScanner → [PhotoReference]
   - Background catalog generation for 100+ photos
2. **Thumbnail Loading**: PhotoReference → PhotoManager → Cached Thumbnail
3. **Selection**: User Interaction → Native Collection View → Callback → UI Updates
4. **Navigation**: Selection/Tap → NavigationStack → New View

## Platform Differences

### macOS
- Multiple windows support
- Menu-driven operations
- Keyboard navigation focus
- Double-click interactions
- NSCollectionView with built-in selection

### iOS/iPadOS
- Single window with NavigationStack
- Touch interactions
- Selection mode with toolbar
- Swipe gestures
- UICollectionView with custom selection UI

## Performance Optimizations

1. **Lazy Loading**: Thumbnails generated on-demand
2. **Dual Caching**: Memory cache + disk cache
3. **Content-Based Keys**: Prevents duplicate processing
4. **Proper Sizing**: Thumbnails scaled appropriately
5. **Native Collection Views**: Better performance than SwiftUI Grid
6. **Catalog-Based Loading**: Instant photo listing for cataloged directories
7. **16-Way Sharding**: Scalable catalog storage for large collections
8. **Network Directory Caching**: 5-minute cache with UUID-based invalidation

## Thread Safety

- PhotoManager uses serial DispatchQueue
- Main actor for UI updates
- Async/await for image operations
- No priority inversions (fixed in implementation)

## Implementation Patterns

### ScalableImageView (macOS)
Custom NSImageView subclass that provides proper aspect fill/fit modes:
- Implements custom `draw(_:)` method
- Provides `.scaleToFit` and `.scaleToFill` modes
- Matches iOS UIImageView content mode behavior
- Handles aspect ratio calculations and clipping

### Cell Update Pattern
Both iOS and macOS cells use a consistent update pattern:

```swift
// iOS
override func layoutSubviews() {
    super.layoutSubviews()
    updateDisplayMode()
    updateCornerRadius()
    updateSelectionState()
}

// macOS
override func layout() {
    super.layout()
    updateDisplayMode()
    updateCornerRadius()
    updateSelectionState()
}
```

Benefits:
- Single update pass for all visual changes
- Automatic batching of property changes
- Consistent timing and state
- Platform-appropriate implementation

### Async Thumbnail Loading Pattern
Proper threading to avoid UI blocking:

```swift
Task {
    // Heavy work on background queue
    let thumbnail = try await loadThumbnail()
    
    // UI updates on main thread
    await MainActor.run {
        imageView.image = thumbnail
    }
}
```

Benefits:
- Thumbnail loading/decoding happens off main thread
- UI remains responsive during loading
- Smooth scrolling in collection views
- Loading indicators shown immediately