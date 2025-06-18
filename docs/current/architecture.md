# Photolala Architecture

Last Updated: June 18, 2025 (Added Backup Queue System)

## Overview

Photolala is a cross-platform photo browser application built with SwiftUI, supporting macOS, iOS, and tvOS. It follows a window-per-folder architecture on macOS and uses native collection views for optimal performance with large photo collections.

## Core Architecture Principles

1. **Platform-Native UI**: Uses NSCollectionView (macOS) and UICollectionView (iOS) wrapped in SwiftUI
2. **Efficient Memory Management**: Lightweight PhotoReference model with lazy thumbnail loading
3. **Window-Per-Folder** (macOS): Each folder opens in its own window, allowing side-by-side comparison
4. **Reactive Updates**: @Observable models for automatic UI updates

## Component Architecture

### Models

#### PhotoReference
- Lightweight file representation
- Properties: `directoryPath` (NSString), `filename` (String)
- Computed: `fileURL`, `filePath`
- Observable with thumbnail caching

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

#### PhotoManager (Singleton)
- Dual caching: memory (NSCache) + disk
- Thumbnail generation with proper scaling
- Content-based identification (MD5)
- Thread-safe with QoS .userInitiated

#### DirectoryScanner
- Scans directories for supported image formats
- Creates PhotoReference objects
- Filters: jpg, jpeg, png, heic, heif, tiff, bmp, gif, webp

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
- Creates 16-shard .photolala catalog format
- Shards based on MD5 hash prefix (0-f)
- CSV format: md5,filename,size,photoDate,modified,width,height
- Enables browsing without ListObjects calls

#### S3CatalogSyncService
- Syncs catalog from S3 to local cache
- Manifest-based change detection
- Atomic updates for consistency
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

#### PhotoBrowserView
- Main container with toolbar
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
- DEBUG: Clean up all user data

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

1. **Directory Scanning**: DirectoryScanner → [PhotoReference]
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