# Photolala Project Status

Last Updated: June 18, 2025 (Session: Star-Based Backup Queue)

## Current Implementation Status

### ✅ Completed Features

#### Core Models
- **PhotoReference**: Lightweight file representation model
  - `directoryPath: NSString` - Directory path 
  - `filename: String` - Filename only
  - Computed properties for `fileURL` and `filePath`
  - Changed to @Observable class (from struct) for reactive updates
  - Added `thumbnail: XImage?` property for caching thumbnails
  - Added `isLoadingThumbnail: Bool` for loading state
  - Designed for efficient memory usage with large collections

#### Services
- **DirectoryScanner**: Scans directories for image files
  - Supports common image formats (jpg, jpeg, png, heic, heif, tiff, bmp, gif, webp)
  - Creates PhotoReference objects
  - Uses NSString for path manipulation (user's choice)

#### UI Components
- **PhotoCollectionViewController**: Native collection view implementation
  - Cross-platform (NSCollectionView on macOS, UICollectionView on iOS)
  - Consolidated into single file with platform conditionals
  - Uses PhotoReference instead of URLs
  - Basic thumbnail loading (placeholder implementation)
  - Supports selection callbacks for photos and folders
  - Fixed crash issue by removing @IBOutlet (views created programmatically)
  
- **PhotoBrowserView**: SwiftUI wrapper for PhotoCollectionViewController
  - Simple integration point between SwiftUI and native views
  - Displays directory name in navigation title

- **WelcomeView**: Initial app screen
  - Single "Select Folder" button (simplified UI)
  - Shows selected folder information
  - iOS: Automatically navigates to PhotoBrowserView after selection
  - macOS: Opens new window via menu command

#### Platform Features
- **macOS**:
  - Window-per-folder architecture
  - File → Open Folder menu command (Cmd+O)
  - No default window on launch
  
- **iOS**: 
  - Document picker for folder selection
  - Automatic navigation to photo browser
  - NavigationStack-based architecture

#### S3 Backup Service (POC)
- **Authentication**: Sign in with Apple integration
- **Storage**: MD5-based deduplication to S3
- **Subscriptions**: StoreKit 2 with 5 tiers (Free to Family)
- **Archive Retrieval**: Deep Archive restore with cost estimates
- **Metadata Backup**: Binary plist format for EXIF preservation
- **UI**: Test interface in S3BackupTestView

### 🚧 In Progress / Placeholder Implementations

1. ~~**Thumbnail Loading**: Currently loads full images (needs optimization)~~ ✅ Fixed
2. **Photo Detail View**: Not yet implemented
3. **Metadata Extraction**: PhotoReference prepared for expansion
4. ~~**Performance Optimization**: No caching or lazy loading yet~~ ✅ Implemented dual caching

### 📝 Recent Changes

**June 18, 2025 - S3 Implementation Complete**:
- **S3 Backup Service**: Full implementation with photo upload, thumbnail generation, metadata storage
- **S3 Photo Browser**: Catalog-first architecture with 16-shard system
- **Authentication**: Removed test mode, requires Sign in with Apple
- **File Extensions**: Standardized to `.dat` for all files
- **AWS Credentials**: Secure storage in Keychain with configuration UI
- **Development Tools**: Added S3 data cleanup for testing
- **Infrastructure**: Suspended versioning, deferred dev/staging separation
- Fixed S3 client initialization issues across all services
- See `/docs/session-summaries/2025-06-18-s3-implementation.md` for details

**June 16, 2025 - S3 Backup Service Implementation Sessions**:
- Session 1: Implemented cross-platform UI helpers and started archive retrieval UX
- Session 2: Implemented Sign in with Apple and identity management
- Session 3: Added In-App Purchase support with StoreKit 2
- Session 4: Completed archive retrieval system with S3 restore APIs
- Session 5: Implemented metadata backup system with binary plist format
- Session 6: Added batch photo selection for archive retrieval

See sections 30-36 below for detailed implementation notes.

### 📝 Recent Changes (June 15, 2025)

14. **Implemented iOS Selection Mode (June 13 - Session 6)**:
   - Added proper iOS selection mode pattern:
     - "Select" button in navigation bar (via SwiftUI toolbar)
     - Enter/exit selection mode with UI transitions
     - Cancel and Select All buttons replace navigation items
     - Bottom toolbar with Share and Delete actions
   - Visual implementation (refined during session):
     - Initially implemented checkbox overlays (SF Symbols)
     - Changed to border-based selection per user preference:
       - 4px blue border for selected items
       - 15% blue background tint for selected items
       - 1px separator color border for unselected items in selection mode
     - Fixed toolbar background color consistency with safe area:
       - Used UIToolbarAppearance with configureWithOpaqueBackground()
       - Set explicit backgroundColor to .systemBackground
     - Removed iOS focus ring (no keyboard navigation on touch devices)
   - SwiftUI/UIKit integration architecture:
     - Select button placed in PhotoBrowserView's toolbar (not UIViewController)
     - Bidirectional state binding: isSelectionModeActive, photosCount
     - Callbacks: onPhotosLoaded, onSelectionModeChanged
   - Interactions:
     - Tap to toggle selection in selection mode
     - Normal tap navigation disabled during selection
     - Selection count displayed in navigation title
     - Toolbar actions show alerts (placeholder for future implementation)

15. **Implemented Photo Preview/Detail View (June 13 - Session 7)**:
   - Created PhotoPreviewView with full image display:
     - Cross-platform implementation (sheet on macOS, fullScreenCover on iOS)
     - Loads full-resolution images with caching via PhotoManager
     - Shows loading indicator and error states
   - Navigation features:
     - If selection exists: navigates only between selected photos
     - If no selection: navigates through all photos in folder
     - Arrow keys (left/right) on macOS
     - Swipe gestures on iOS
     - Previous/Next buttons with visual indicators
   - Zoom and pan functionality:
     - NSScrollView with magnification on macOS
     - UIScrollView with pinch zoom on iOS
     - Double-tap/click to toggle between fit and 2x zoom
     - Reset zoom button in overlay controls
   - User interface:
     - Auto-hiding overlay controls (3-second timer)
     - Close button (X) and Escape key support
     - Current photo indicator ("3 of 10")
     - Platform-specific presentation (sheet vs full screen)
   - Integration:
     - Double-click opens preview on macOS (already implemented)
     - Single tap opens preview on iOS (non-selection mode)
     - PhotoBrowserView manages preview state and photo selection

16. **Fixed iOS Navigation and Added Selection Preview (June 14 - Session 8)**:
   - Fixed iOS navigation issues:
     - PhotoBrowserView was inside parent NavigationStack but trying to use its own
     - Changed from NavigationPath to @State with .navigationDestination(item:)
     - Now properly navigates to PhotoPreviewView on iOS
   - Enhanced PhotoPreviewView for cross-platform compatibility:
     - Initially had black screen issue on macOS despite successful image loading
     - Rewrote from NSViewRepresentable/UIViewRepresentable to pure SwiftUI
     - Added platform-specific Image initialization helper
     - Implemented gestures: MagnificationGesture for zoom, DragGesture for pan
     - Double-tap to toggle zoom, proper centering and aspect ratio
   - Added preview button for selected photos:
     - Eye icon button appears in toolbar when photos are selected
     - Works on both macOS and iOS
     - Previews only the selected photos in alphabetical order
     - Allows users to preview selection without losing it
   - Selection mode behavior:
     - Normal mode: tap/double-click opens preview directly
     - Selection mode: tap/click selects, eye button previews selection
     - Consistent behavior across platforms

### 📝 Recent Changes (June 15, 2025)

1. **Refactored Photo Model**:
   - Removed complex Photo model with SwiftData dependencies
   - Implemented lightweight PhotoReference
   - Separated directory path and filename for efficiency
   - Changed from struct to @Observable class for reactive UI updates
   - Added thumbnail and isLoadingThumbnail properties for future thumbnail support

2. **Implemented DirectoryScanner**:
   - Replaces previous scanning implementations
   - Simple, focused on file discovery

3. **Updated Collection Views**:
   - Migrated from URL arrays to PhotoReference arrays
   - Fixed type mismatches throughout the codebase
   - Maintained platform-specific implementations
   - Consolidated macOS and iOS PhotoCollectionViewController into single file
   - Added cross-platform type aliases (XCollectionView, XViewController, etc.)
   - Fixed @IBOutlet crash issue - removed IBOutlet since views are created programmatically

4. **Simplified Navigation**:
   - Removed PhotoNavigationView (was causing build issues)
   - PhotoBrowserView now uses PhotoCollectionView directly
   - Cleaner architecture with fewer intermediate layers

5. **UI Cleanup**:
   - Removed "View Sample Photos" button
   - Removed "Test Resources" button
   - Focused on core folder browsing functionality

6. **iOS Navigation Enhancement**:
   - Added automatic navigation after folder selection
   - Better user experience - no extra tap needed

7. **Cross-Platform Improvements**:
   - Enhanced XPlatform.swift with collection view type aliases
   - Better code reuse between macOS and iOS
   - Unified delegate and data source protocols

8. **Implemented PhotoManager with Complete Thumbnail System (June 13)**:
   - Content-based identification using MD5 digest
   - Dual caching system: full images by path, thumbnails by content
   - Async/await API with thread safety via DispatchQueue (QoS: .userInitiated)
   - Proper thumbnail generation:
     - Scales shorter side to 256px maintaining aspect ratio
     - Center-crops longer side to max 512px if needed
     - EXIF orientation handling (automatic on macOS, manual on iOS)
   - Disk cache in ~/Library/Caches/Photolala/thumbnails/
   - Cross-platform implementation without priority inversions
   - Collection views now use PhotoManager instead of loading full images

9. **Fixed Thumbnail Generation Issues (June 13 - Session 2)**:
   - Fixed incorrect thumbnail URL generation (was adding '#' character)
   - Fixed caching to use thumbnailCache instead of imageCache
   - Resolved priority inversion warnings:
     - Set PhotoManager queue to .userInitiated QoS
     - Replaced lockFocus/unlockFocus with Core Graphics on macOS
     - Used NSBitmapImageRep for thread-safe rendering
   - Added proper EXIF orientation handling:
     - iOS: Normalizes orientation before scaling/cropping
     - macOS: Relies on NSImage's automatic orientation handling
   - Updated collection view cells to use async/await with PhotoManager

10. **Added Thumbnail Display Options (June 13 - Session 3)**:
   - Created ThumbnailDisplaySettings model:
     - Display modes: Scale to Fit vs Scale to Fill
     - Predefined sizes: Small (64px), Medium (128px), Large (256px)
     - Per-window settings (not global)
   - Added toolbar controls:
     - Display mode toggle button
     - Size picker (segmented control on macOS, menu on iOS)
   - Implemented dynamic layout updates:
     - Collection view resizes cells when settings change
     - Visible items update display mode immediately
   - Each window maintains independent display settings
   - Cross-platform toolbar implementation in SwiftUI

11. **Enhanced Thumbnail Display System (June 13 - Session 4)**:
   - Renamed ThumbnailSize to ThumbnailOption for better semantics
   - Added dynamic layout properties to ThumbnailOption:
     - spacing: 2px (small), 4px (medium), 8px (large)
     - cornerRadius: 0px (small), 6px (medium), 12px (large)
     - sectionInset: 4px (small), 8px (medium), 12px (large)
   - Simplified settings architecture:
     - Store ThumbnailOption directly instead of CGFloat size
     - Removed unnecessary conversion methods
     - Added default property (medium) for consistency
   - Visual refinements:
     - Small: Compact grid with no rounded corners
     - Medium: Balanced layout with subtle rounding
     - Large: Spacious layout with prominent rounded corners
   - Added app icon from legacy branch (sunflower image)

12. **Disabled Window Restoration (June 13)**:
   - Added NSApplicationDelegate to control state restoration
   - Implemented applicationSupportsSecureRestorableState returning false
   - Windows no longer automatically restore on app launch
   - Users start with a clean state each time
   - Added Photos library entitlement for future features

13. **~~Implemented Selection System (June 13 - Session 5)~~** → **Replaced with System-Native Selection (June 15)**:
   - ~~Created SelectionManager class (per-window)~~ - REMOVED
   - Now uses platform-native selection:
     - iOS: UICollectionView's built-in selection
     - macOS: NSCollectionView's built-in selection
   - Visual feedback implementation:
     - Selected: 3px blue border + light blue background
     - Focus: 2px system focus color border (for keyboard navigation)
   - What works (via native collection views):
     - Single click selection
     - Cmd+click toggle selection
     - Shift+click range selection
     - Arrow key navigation
     - Shift+arrow extending selection
   - Benefits of native approach:
     - No custom state management needed
     - Platform-consistent behavior
     - Built-in keyboard/accessibility support
     - Significantly less code to maintain

### 🐛 Known Issues

1. ~~Thumbnail loading is inefficient (loads full images)~~ ✅ Fixed with PhotoManager
2. ~~No image caching mechanism~~ ✅ Fixed with dual NSCache system
3. ~~No metadata display~~ ✅ Fixed with PhotoMetadata and HUD in preview
4. ~~No photo detail view implementation~~ ✅ Fixed with PhotoPreviewView
5. No error handling for invalid image files
6. Swift 6 Sendable warnings for NSImage/UIImage

### 🎯 Next Steps

1. **~~Implement Proper Thumbnail System~~** ✅ Completed with PhotoManager
2. **~~Implement Selection System~~** ✅ Completed (Phase 1-2, including iOS selection mode)
3. **~~Add Photo Preview/Detail View~~** ✅ Completed (Phase 3):
   - Double-click (macOS) / tap (iOS) to open full image view
   - Navigation between selected photos (if selection exists, shows only selected)
   - Basic zoom and pan (pinch/scroll wheel, double-tap/click to toggle)
   - Escape to close (macOS), X button or swipe down (iOS)
   - Keyboard navigation with arrow keys
   - Auto-hiding overlay controls
   - ~~Metadata HUD display~~ ✅ Added with 'i' key toggle

4. **~~Add Photo Grouping~~** ✅ Completed Phase 1:
   - Group by Year/Month/Day using file dates
   - Section headers in collection view
   - Instant performance (no EXIF parsing)
   - Future: EXIF-based grouping, more group options

5. **Add Selection Operations**:
   - ~~Selection count display~~ ✅ Completed
   - ~~Deselect All functionality~~ ✅ Added with Cmd+D
   - Context menu for selected items
   - Basic operations (Copy, Move, Delete)
   - Prepare for Star/Flag/Label features

5. **Enhance PhotoReference**:
   - ~~Add file size property~~ ✅ Available via PhotoMetadata
   - ~~Add creation/modification date~~ ✅ Available via PhotoMetadata
   - ~~Add basic EXIF data~~ ✅ PhotoMetadata extracts EXIF
   - ~~Consider renaming to PhotoReference~~ ✅ Already renamed throughout codebase

6. **Performance Optimization**:
   - ~~Implement virtualized scrolling~~ ✅ Using LazyHStack for thumbnail strip
   - ~~Add memory management~~ ✅ Cache limits based on RAM
   - Background queue for scanning
   - Replace thumbnail strip with collection view for very large sets (TODO added)

7. **Error Handling**:
   - Handle corrupted images
   - Handle access permissions
   - User-friendly error messages

8. **Sort and Filter**:
   - ~~Sort by date~~ ✅ Implemented (using file dates)
   - Sort by size
   - Filter by file type
   - Search functionality

### 💻 Build Status

- ✅ macOS: Building successfully (with Sendable warnings)
- ✅ iOS: Building successfully  
- ❓ tvOS: Not tested recently

### 📁 File Structure Changes

**Added:**
- `photolala/Models/PhotoReference.swift`
- `photolala/Models/ThumbnailDisplaySettings.swift` - Display mode and size settings
- ~~`photolala/Models/SelectionManager.swift` - Selection state management~~ → REMOVED (June 15)
- `photolala/Models/PhotoMetadata.swift` - Metadata storage class
- `photolala/Models/PhotoSortOption.swift` - Sort options enum
- `photolala/Models/PhotoGroupingOption.swift` - Grouping options enum
- `photolala/Models/PhotoGroup.swift` - Photo group model
- `photolala/Services/DirectoryScanner.swift`
- `photolala/Services/PhotoManager.swift` - Thumbnail generation and caching (enhanced with statistics)
- `photolala/Services/S3BackupService.swift` - AWS S3 backup service (POC)
- `photolala/Services/IdentityManager.swift` - Sign in with Apple and user management
- `photolala/Services/KeychainManager.swift` - Secure credential storage
- `photolala/Views/PhotoPreviewView.swift` - Full image preview with zoom/pan
- `photolala/Views/CacheStatisticsView.swift` - Cache performance monitoring UI
- `photolala/Views/ScalableImageView.swift` - Custom NSImageView for aspect fill on macOS
- `photolala/Views/PhotoContextMenuHeaderView.swift` - Context menu preview header view
- `photolala/Views/ClickedCollectionView.swift` - NSCollectionView subclass for context menu support
- `photolala/Views/PhotoGroupHeaderView.swift` - Section headers for photo groups
- `photolala/Views/S3BackupTestView.swift` - S3 backup POC test interface
- `photolala/Views/SignInPromptView.swift` - Sign in with Apple onboarding
- `photolala/Views/UserAccountView.swift` - User account status display
- `photolala/Views/AWSCredentialsView.swift` - AWS credential configuration (dev only)
- `photolala/Views/SubscriptionView.swift` - IAP subscription selection UI
- `photolala/Views/IAPTestView.swift` - IAP testing interface
- `photolala/Views/PhotoRetrievalView.swift` - Archive photo retrieval dialog
- `photolala/Views/PhotoArchiveBadge.swift` - Visual indicators for archived photos
- `photolala/Models/ArchiveStatus.swift` - S3 storage class and archive lifecycle models
- `photolala/Services/S3RetrievalManager.swift` - Manages photo restoration requests
- `photolala/Services/IAPManager.swift` - StoreKit 2 subscription management
- `photolala/Services/PhotolalaCatalogService.swift` - .photolala catalog file management
- `photolala/Services/S3CatalogSyncService.swift` - Catalog sync with ETag change detection
- `photolala/Services/S3DownloadService.swift` - S3 photo/thumbnail downloads with caching
- `photolala/Services/TestCatalogGenerator.swift` - Debug mode test data generator
- `photolala/PhotolalaProducts.storekit` - IAP product configuration
- `photolala/Models/S3Photo.swift` - S3 photo model combining catalog and S3 metadata
- `photolala/Models/S3MasterCatalog.swift` - S3-specific metadata tracking
- `photolala/Views/S3PhotoBrowserView.swift` - S3 cloud photo browser UI
- `photolala/Views/S3PhotoThumbnailView.swift` - S3 photo thumbnail cell
- `photolala/Views/S3PhotoDetailView.swift` - S3 photo detail view (placeholder)
- `docs/project-status.md` (this file)
- `docs/thumbnail-display-options-design.md` - Design for display options feature
- `docs/thumbnail-display-implementation-plan.md` - Implementation plan
- `docs/selection-and-preview-design.md` - Design for selection and preview features
- `docs/photo-preview-implementation.md` - Implementation plan for preview feature
- `docs/planning/photo-loading-enhancements.md` - Performance optimization plan
- `docs/planning/sort-by-date-feature.md` - Design for sort by date feature
- `docs/planning/macos-context-menu-design.md` - Design and implementation for context menu
- `docs/cache-statistics-guide.md` - Guide for using cache statistics
- `docs/planning/photo-grouping-design.md` - Design for photo grouping feature
- `docs/planning/iap-testing-guide.md` - Complete IAP testing guide
- `docs/current/archive-retrieval-system.md` - Archive retrieval architecture and implementation
- `docs/current/metadata-backup-system.md` - Metadata backup implementation and API reference
- `docs/current/s3-photo-browser-implementation.md` - S3 photo browser architecture and implementation
- `docs/planning/s3-photo-browser-design.md` - S3 photo browser design document
- `docs/planning/s3-browser-implementation-plan.md` - Implementation plan for S3 browser
- `docs/planning/photolala-catalog-design.md` - .photolala catalog file format specification
- `docs/session-summaries/` - Development session summaries
  - `/README.md` - Session index
  - `/2025-06-16-session5.md` - Metadata backup implementation session
- `scripts/create-test-photos.sh` - Script to create test photos with different dates
- `services/s3-backup/` - Complete S3 backup service design documentation
  - `/design/identity-management-design.md` - Identity and authentication architecture
  - `/design/payment-evolution-strategy.md` - IAP to web payment evolution
  - `/design/cross-platform-identity-strategy.md` - Multi-platform expansion plan
  - `/design/CURRENT-pricing-strategy.md` - Current pricing model and strategy
  - `/design/deep-archive-analysis.md` - Deep Archive cost analysis and UX
  - `/design/user-communication-strategy.md` - User messaging for archive features
  - `/design/implementation-checklist.md` - Complete feature implementation checklist
  - `/design/implementation-plan-v2.md` - Updated implementation roadmap
  - `/implementation/aws-sdk-swift-credentials.md` - AWS credential handling
  - `/research/game-industry-identity-patterns.md` - Industry best practices

**Removed:**
- `photolala/Views/PhotoNavigationView.swift`
- Various test/sample code

**Modified:**
- `photolala/Views/PhotoCollectionViewController.swift` - Added selection support, iOS selection mode, prefetching delegates, sort support, section support, archive badge display, click handlers
- `photolala/Views/PhotoBrowserView.swift` - ~~Added SelectionManager~~ → Uses native selection, iOS selection mode, preview presentation, sort picker, grouping menu, archive retrieval dialog
- `photolala/Views/WelcomeView.swift` - Removed test buttons, added iOS auto-navigation
- `photolala/Views/PhotoPreviewView.swift` - Added image preloading for adjacent photos
- `photolala/photolalaApp.swift` - Added NSApplicationDelegate for window restoration control
- `photolala/Models/PhotoReference.swift` - Changed to @Observable class, renamed from PhotoRepresentation, added metadata support, fileCreationDate, archiveInfo property
- `photolala/Models/ThumbnailDisplaySettings.swift` - Added sortOption and groupingOption properties
- `photolala/Utilities/XPlatform.swift` - Added collection view type aliases, jpegData extension, button styles and colors
- `photolala/Services/PhotoManager.swift` - Enhanced with statistics, prefetching, performance monitoring, metadata extraction, groupPhotos method
- `photolala/Services/S3BackupService.swift` - Added restorePhoto, checkRestoreStatus, and batch restore methods
- `photolala/Commands/PhotolalaCommands.swift` - Added View menu with Cache Statistics command
- All files using PhotoRepresentation - Updated to use PhotoReference

17. **Implemented Photo Loading Enhancements (June 14 - Session 9)**:
   - Phase 1 Quick Wins completed:
     - Smart cache limits based on available RAM (16-64 images)
     - Collection view prefetching for smooth scrolling
     - Preview image preloading (±2 images from current)
     - Cache statistics tracking and monitoring
   - Added PhotoManager enhancements:
     - Detailed performance logging with timing
     - Cache hit/miss statistics
     - Disk read/write tracking
     - Memory usage monitoring
   - Added CacheStatisticsView:
     - Real-time display of cache performance
     - Shows hit rates, disk operations, memory usage
     - Reset statistics button
   - Added View menu with Cache Statistics command (⌘⇧I)
   - Performance improvements:
     - Thumbnails prefetch before becoming visible
     - Adjacent images preload during preview navigation
     - Reduced loading delays and smoother user experience

18. **Implemented Sort by Date Feature (June 14 - Session 10)**:
   - Created PhotoMetadata class for storing file metadata:
     - Stores comprehensive metadata but only using file dates for now
     - NSObject subclass for NSCache compatibility
     - Includes properties for future EXIF data extraction
   - Enhanced PhotoReference with metadata support:
     - Added fileModificationDate loaded immediately in init
     - Added metadata property and loading states
     - Added loadPhotoData() for combined thumbnail/metadata loading
   - Created PhotoSortOption enum:
     - Three options: Name, Date (Oldest First), Date (Newest First)
     - Uses file system dates only (no EXIF extraction yet)
     - Integrated with ThumbnailDisplaySettings
   - Updated PhotoManager:
     - Migrated cache directory from 'thumbnails' to 'cache'
     - Added metadata extraction alongside thumbnail generation
     - Stores metadata as .plist files in cache directory
     - Added metadata() and loadPhotoData() public APIs
   - Added sort picker to PhotoBrowserView toolbar:
     - macOS: Menu-style picker showing sort options
     - iOS: Dropdown menu with icons and checkmarks
     - Updates collection view automatically when changed
   - PhotoCollectionViewController changes:
     - Applies sorting when loading photos
     - Re-sorts when sort option changes
     - Shows placeholders immediately while loading
   - Note: Date sorting has issues but will be addressed later

19. **Added Metadata HUD to Photo Preview (June 14 - Session 11)**:
   - Created toggleable metadata overlay for photo preview:
     - Shows filename, dimensions, file size, date, and camera info
     - Semi-transparent black background with rounded corners
     - Positioned to avoid toolbar overlap using shared constants
   - Toggle methods:
     - Keyboard shortcut 'i' for info
     - Info button in control strip (filled icon when active)
     - Smooth fade in/out animation
   - Metadata loading:
     - Loads asynchronously when image loads
     - Shows file modification date immediately if available
     - Displays full metadata when loaded from PhotoManager
   - UI improvements:
     - Removed file path display per user request
     - Repositioned HUD closer to center to avoid toolbar overlap
     - Added shared constants for toolbar height (44pt) and margin (8pt)
   - Performance optimizations for thumbnail strip:
     - Changed HStack to LazyHStack for lazy loading
     - Added task cancellation when thumbnails scroll off-screen
     - Added TODO for future collection view implementation
   - Cross-platform support for both macOS and iOS

20. **Added Deselect All Feature (June 14 - Session 11)**:
   - Added "Deselect All" menu command in Edit menu with Cmd+D shortcut
   - Implemented notification system for cross-window deselect functionality
   - PhotoBrowserView listens for deselect notification
   - PhotoCollectionViewController handles deselect for both platforms:
     - macOS: Clears native collection view selection
     - iOS: Deselects items via collection view API
   - ~~iOS maintains existing "Deselect All" button in selection mode~~ → Removed with selection mode

21. **Implemented Native Thumbnail Strip (June 15 - Session 12)**:
   - Replaced SwiftUI LazyHStack with native collection views for performance:
     - NSCollectionView on macOS, UICollectionView on iOS
     - Cell recycling ensures constant memory usage with large collections
     - Supports 10,000+ photos without performance degradation
   - Created three new components:
     - ThumbnailStripView: SwiftUI wrapper using XViewControllerRepresentable
     - ThumbnailStripViewController: Native collection view controller
     - ThumbnailStripCell: Reusable cells with efficient thumbnail loading
   - Visual design improvements:
     - Selection animation with 1.05x scale and blue border (3px)
     - Regular state with clear border on macOS, white on iOS
     - Smooth 0.2s ease-in-out transitions
     - 2px image inset to ensure borders are visible
   - Performance features:
     - Task cancellation for off-screen cells
     - Prefetching support on iOS
     - Limited to 4 concurrent thumbnail loads
     - Integration with PhotoManager's caching system
   - Added prefetchThumbnails() method to PhotoManager
   - Feature flag in PhotoPreviewView allows toggling between implementations
   - Maintains exact visual design while significantly improving performance

### 🔧 Technical Decisions

1. **NSString for Paths**: User specifically requested NSString for directory paths
2. **Native Collection Views**: Better performance for large collections
3. **Simple Start**: Focus on basic functionality before optimization
4. **Clean Code**: Removed temporary debugging print statements
5. **Per-Window Settings**: Each window has independent display settings for flexibility
6. **Enum-Based Configuration**: ThumbnailOption encapsulates all size-related layout properties
7. **No Window Restoration**: App starts fresh each time for cleaner user experience
8. **Native Collection View Selection**: System-only approach
   - Use platform-native selection APIs exclusively
   - No custom SelectionManager - simpler architecture
   - Selection state maintained by collection views
   - Trade custom behavior for platform consistency
9. **Memory-Aware Caching**: Dynamic cache sizing based on available RAM
10. **Performance Monitoring**: Built-in statistics for optimization feedback
22. **Removed SelectionManager - Switch to System-Native Selection (June 15 - Session 13)**:
   - Completely removed custom SelectionManager class
   - Switched to platform-native selection mechanisms:
     - iOS: UICollectionView's `allowsMultipleSelection` and `indexPathsForSelectedItems`
     - macOS: NSCollectionView's `allowsMultipleSelection` and `selectionIndexPaths`
   - Simplified PhotoCollectionViewController:
     - Removed all selection mode code (iOS now always allows selection)
     - Removed `isSelectionMode`, `enterSelectionMode()`, `exitSelectionMode()`
     - Selection state managed entirely by collection views
     - Added `updateSelectionState()` call in cell's `isSelected` didSet
   - Updated PhotoBrowserView:
     - Replaced `selectionManager` with simple `selectedPhotos` array
     - Selection changes communicated via `onSelectionChanged` callback
   - Benefits:
     - Significantly less code to maintain (593 lines removed)
     - Consistent with platform behavior
     - Free keyboard navigation and accessibility support
     - Simpler state management
   - iOS behavior changes:
     - Single tap now selects/deselects (no selection mode needed)
     - Double tap navigates to preview (avoiding conflict with selection)
     - Selection always available, following system convention
   - Fixed iOS selection issues:
     - Selection now preserved during scrolling
     - Collection view layout updates no longer clear selection
     - Cell reuse properly syncs selection state
     - `reloadData()` saves and restores selection
     - `updateCollectionViewLayout()` uses `invalidateLayout()` instead of `reloadData()`

23. **Improved Cell Update Pattern (June 15 - Session 13)**:
   - Refactored both iOS and macOS cells to use proper layout invalidation pattern
   - Property changes now trigger layout invalidation:
     - iOS: `setNeedsLayout()` → `layoutSubviews()`
     - macOS: `needsLayout = true` → `layout()`
   - All visual updates (display mode, corner radius, selection) happen in one layout pass
   - Benefits:
     - Fixed display mode not being applied on first display
     - More efficient batching of updates
     - Consistent pattern across platforms
     - Prevents timing issues and partial updates

24. **Implemented ScalableImageView for macOS Aspect Fill (June 15 - Session 13)**:
   - Created custom NSImageView subclass to properly handle scale modes
   - Fixed issue where NSImageView lacks proper aspect fill support
   - Implementation details:
     - ScalableImageView with `.scaleToFit` and `.scaleToFill` modes
     - Custom draw method calculates proper aspect ratios
     - Clipping applied for scale-to-fill to prevent overflow
     - Matches iOS UIImageView behavior
   - Fixed issues:
     - Square images (1024x1024) now scale correctly without unwanted zoom
     - Consistent behavior across all image aspect ratios
     - Proper aspect fill that maintains ratio while filling cell
   - Integration:
     - Replaced NSImageView with ScalableImageView in PhotoCollectionViewItem
     - Connected to existing ThumbnailDisplaySettings.displayMode

25. **Improved Thumbnail Loading UI/UX (June 15 - Session 13)**:
   - Added SF Symbol placeholders while thumbnails load:
     - Loading state: "circle.dotted" icon with light gray tint
     - Error state: "exclamationmark.triangle" icon with red tint
   - Fixed potential UI blocking in thumbnail loading:
     - Removed `Task { @MainActor in ... }` pattern
     - Thumbnail loading now runs on background queue
     - Only UI updates use `MainActor.run { }`
   - Improvements applied to both iOS and macOS:
     - Consistent loading indicators across platforms
     - Smooth scrolling performance maintained
     - Better error feedback with visual indicators
   - UI refinements:
     - Made wrapper view transparent on macOS
     - Removed gray background placeholders
     - Icons provide clearer loading state feedback

26. **Implemented macOS Context Menu (June 15 - Session 14)**:
   - Created context menu for quick photo preview and actions:
     - Right-click or Control+click to show menu
     - Large 512x512px preview at top of menu
     - Photo metadata display (filename, dimensions, date, camera)
     - Non-destructive actions only (Open, Quick Look, Reveal, etc.)
   - Implementation details:
     - Custom `ClickedCollectionView` tracks right-clicked items
     - `PhotoContextMenuHeaderView` with dynamic sizing
     - Uses `intrinsicContentSize` for proper layout
     - NSMenuDelegate for dynamic menu building
   - Visual design:
     - Transparent background with 1px border (matches thumbnails)
     - ScalableImageView ensures proper aspect ratio
     - 4px rounded corners for consistency
     - Async metadata loading with "Loading..." placeholder
   - Quick Look integration:
     - Full QLPreviewPanel support
     - Proper delegate/datasource implementation
     - Animation from thumbnail position
   - Actions implemented:
     - Open: Navigate to PhotoPreviewView
     - Quick Look: System preview with spacebar
     - Open With: Dynamic app list submenu
     - Reveal in Finder: Single or multiple files
     - Get Info: System info panel via AppleScript
   - Fixed constraint conflicts with custom NSMenuItem views
   - Control+click properly handled as right-click equivalent

27. **Implemented Help System POC (June 15 - Session 15)**:
   - Created cross-platform help system using WKWebView:
     - Wrapper components for both macOS and iOS
     - Native presentation (window on macOS, sheet on iOS)
     - HTML content with CSS styling
   - Implementation details:
     - `HelpWebView` cross-platform wrapper (NSViewRepresentable/UIViewRepresentable)
     - `HelpView` container with navigation toolbar
     - `HelpWindowController` for macOS window management
     - Help menu command (⌘?) replaces standard Help menu
   - Content structure:
     - 7 HTML help pages covering all features
     - Responsive CSS with dark mode support
     - Platform-specific styling (iOS/macOS detection)
     - Breadcrumb navigation and related topics
   - HTML pages created:
     - index.html: Main help page with topic categories
     - getting-started.html: First steps and interface overview
     - browsing-photos.html: Grid view and navigation
     - organizing.html: Sorting, filtering, folder management
     - searching.html: Search syntax and smart filters
     - keyboard-shortcuts.html: Complete shortcut reference
     - troubleshooting.html: Common issues and solutions
   - Features implemented:
     - External links open in default browser
     - Dark mode automatically detected via CSS media queries
     - Back/forward navigation gestures enabled
     - Resource bundling (Resources/Help folder)
     - Error handling with fallback content
   - Technical approach:
     - Static HelpWindowController to persist window
     - Bundle.main.url for resource loading
     - WKNavigationDelegate for URL handling
     - CSS variables for theme support
   - Known limitations:
     - Navigation buttons UI created but not connected to WKWebView
     - Search functionality not implemented
     - Images are placeholders only
     - Help content to be updated near end of development
   - Documentation: `docs/planning/help-system-design.md`

28. **Thumbnail Size Picker UI Refinement (June 15 - Session 16)**:
   - Changed thumbnail size labels from full words to compact format:
     - "Small", "Medium", "Large" → "S", "M", "L"
     - Applied to both macOS segmented control and iOS menu
   - Benefits:
     - More compact toolbar UI
     - Clearer visual hierarchy
     - Consistent with modern UI patterns
     - Still maintains clarity with help tooltips
   - No functional changes, purely visual refinement

29. **Implemented Photo Grouping Feature (June 15 - Session 17)**:
   - Phase 1 Complete: File-based grouping by Year/Month/Day
   - Created new models:
     - `PhotoGroupingOption`: Enum with none/year/month/day options
     - `PhotoGroup`: Model representing grouped photos with title
   - Enhanced PhotoManager:
     - `groupPhotos()` method using Dictionary(grouping:) by date components
     - Groups sorted by date (newest first within each group)
   - Updated PhotoReference:
     - Changed from `fileModificationDate` to `fileCreationDate`
     - Creation date is closer to photo taken date
   - UI Implementation:
     - Added grouping menu to PhotoBrowserView toolbar
     - Platform-specific: Menu on iOS, Picker on macOS
     - Icons for each grouping option
   - Collection View Sections:
     - PhotoCollectionViewController supports multiple sections
     - Added `PhotoGroupHeaderView` for section headers
     - Headers show group titles (e.g., "2024", "March 2024")
     - Dynamic header sizing based on grouping option
   - Benefits:
     - Instant performance - no EXIF parsing required
     - Works well with network drives
     - Progressive enhancement possible later
   - Test implementation:
     - Created test photos with various dates
     - Verified grouping works correctly
   - Future phases (documented but not implemented):
     - Phase 2: EXIF-based grouping
     - Phase 3: Hybrid approach with caching

30. **S3 Backup Service POC (June 16)**:
   - Created S3BackupService for revolutionary $1.99/TB backup pricing:
     - Uses AWS SDK for Swift with S3 client
     - MD5-based deduplication across all users
     - Stores photos in `users/{userId}/photos/{md5}.dat`
     - Separate thumbnail storage for faster browsing
   - AWS Credentials handling:
     - Primary: Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
     - Fallback: AWS credentials file in app container
     - Documented macOS app sandboxing limitations
   - Test Implementation:
     - S3BackupTestView with photo picker integration
     - Upload photos with automatic MD5 calculation
     - List uploaded photos with metadata
     - Real-time credentials check and diagnostics
   - Technical details:
     - StaticAWSCredentialIdentityResolver for authentication
     - CryptoKit for MD5 hashing
     - Async/await throughout for modern Swift concurrency
   - Documentation:
     - `services/s3-backup/implementation/aws-sdk-swift-credentials.md`: AWS credential handling
     - `services/s3-backup/`: Complete service design documentation
   - Security:
     - Added `xcshareddata/xcschemes/**` to .gitignore to protect credentials
     - Environment variables set in Xcode scheme (not committed)
   - Current Status:
     - ✅ Successfully uploading photos to S3
     - ✅ MD5 deduplication working
     - ✅ Photo listing functionality
     - POC phase - credentials management to be improved for production

31. **Implemented Sign in with Apple and Identity Management (June 16 - Session 2)**:
   - **Identity Management System**:
     - Created IdentityManager with complete Sign in with Apple flow
     - PhotolalaUser model with service ID, Apple ID, and subscription info
     - Secure storage in Keychain for persistent authentication
     - Cross-platform support (iOS/macOS) with platform-specific UI
   - **Authentication Flow**:
     - Users must sign in before accessing cloud backup features
     - Beautiful SignInPromptView shows benefits of creating account
     - Automatic 5GB free tier upon sign-in
     - Graceful upgrade prompts when quota exceeded
   - **Updated S3 Integration**:
     - S3BackupManager now requires authentication
     - Enforces storage quotas based on subscription tier
     - Tracks usage and prevents uploads beyond limits
     - Shows upgrade prompt when storage full
   - **UI Components Added**:
     - SignInPromptView: Onboarding for cloud backup
     - SubscriptionUpgradeView: Quota exceeded handling
     - UserAccountView: Account info in toolbar
     - BackupStatusView: Compact status indicator
   - **Subscription Tiers Defined**:
     - Free: 5 GB
     - Basic: 100 GB ($2.99/mo)
     - Standard: 1 TB ($9.99/mo)
     - Pro: 5 TB ($39.99/mo)
     - Family: 10 TB ($69.99/mo)
   - **Documentation**:
     - Identity management design in services/s3-backup/design/
     - Payment evolution strategy documented
     - Cross-platform identity strategy for future expansion
   - **Next Steps**:
     - Implement StoreKit 2 for IAP subscriptions
     - Replace test AWS credentials with Photolala-managed service
     - Add subscription management UI
     - Implement usage tracking backend

32. **Implemented In-App Purchase Support (June 16 - Session 3)**:
   - **StoreKit 2 Integration**:
     - Created IAPManager for subscription management
     - Added PhotolalaProducts.storekit configuration file
     - Supports auto-renewable subscriptions for all tiers
     - Family sharing enabled for Family tier
   - **UI Components**:
     - SubscriptionView with pricing cards for each tier
     - IAPTestView for development testing
     - Receipt validation check support
   - **Subscription Products**:
     - com.electricwoods.photolala.basic (100GB - $2.99/mo)
     - com.electricwoods.photolala.standard (1TB - $9.99/mo)  
     - com.electricwoods.photolala.pro (5TB - $39.99/mo)
     - com.electricwoods.photolala.family (10TB - $69.99/mo)
   - **Testing Guide**:
     - Created iap-testing-guide.md with complete instructions
     - StoreKit testing in Xcode simulator
     - Sandbox testing with test accounts
     - TestFlight beta testing workflow

33. **Implemented Archive Retrieval System (June 16 - Session 4)**:
   - **Archive Status Models**:
     - Created ArchiveStatus enum for S3 storage classes
     - Added ArchivedPhotoInfo to track archive lifecycle
     - Added originalSize property for cost calculations
     - Integrated with PhotoReference model
   - **Visual Indicators**:
     - PhotoArchiveBadge shows archive state:
       - ❄️ Archived (Deep Archive/Glacier)
       - ⏳ Retrieving (restore in progress)
       - ✨ Recently restored (temporarily available)
       - ⭐ Premium feature indicator
       - ⚠️ Error state
   - **Retrieval UI**:
     - PhotoRetrievalView modal dialog
     - Options: single photo, selected photos, entire album
     - Rush delivery toggle (5-12 hours vs 12-48 hours)
     - Cost estimation based on actual file sizes
   - **Batch Photo Selection (Session 6)**:
     - PhotoRetrievalView accepts array of selected photos
     - Intelligently defaults to "Selected photos" option when multiple archived photos selected
     - Calculates total size and cost for all archived photos in selection
     - Filters out non-archived photos automatically
     - Supports batch restore operations
   - **S3 Integration**:
     - RestoreObject API implementation in S3BackupService
     - Support for expedited and standard retrieval tiers
     - Status checking via HeadObject with restore header parsing
     - Batch restore support for multiple photos
   - **Retrieval Manager**:
     - S3RetrievalManager tracks active retrievals
     - Background monitoring of restore progress
     - Planned: Push notifications on completion
   - **Platform Integration**:
     - Click handlers in PhotoCollectionViewController
     - Sheet presentation in PhotoBrowserView with selected photos
     - Cross-platform support (macOS/iOS)
   - **Error Handling**:
     - PhotoRetrievalError for various failure cases
     - Graceful handling of RestoreAlreadyInProgress
     - Batch operation error aggregation
   - **Documentation**:
     - Created archive-retrieval-system.md in docs/current/
     - Detailed implementation and architecture notes

34. **Implemented Metadata Backup System (June 16 - Session 5)**:
   - **Backup Components**:
     - Automatic metadata extraction during photo upload
     - Property List (plist) serialization with binary encoding
     - Stored in S3 Standard storage class for quick access
   - **S3BackupService Methods**:
     - `uploadMetadata()`: Uploads metadata as plist files
     - `downloadMetadata()`: Retrieves individual metadata
     - `listUserMetadata()`: Bulk retrieves all user metadata
     - `listUserPhotosWithMetadata()`: Combined photos + metadata
   - **Storage Structure**:
     - Metadata stored at `users/{userId}/metadata/{md5}.plist`
     - Free bonus storage (doesn't count against quota)
     - Typical size: 200-400 bytes per photo (binary format)
   - **UI Integration**:
     - S3BackupTestView displays photo dimensions and camera info
     - Updated to use `listUserPhotosWithMetadata()` API
   - **Performance**:
     - Parallel metadata downloads using TaskGroup
     - Efficient bulk operations for large photo collections
   - **Benefits**:
     - Enables future search capabilities
     - Preserves EXIF data permanently
     - Quick photo info without downloading full images
     - Negligible cost (~$0.00007/month for 10,000 photos)
   - **Documentation**:
     - Created metadata-backup-system.md in docs/current/
     - Comprehensive API reference and cost analysis

35. **Implemented New S3 Path Structure (June 17 - Session 7)**:
   - **Path Migration**:
     - Changed from `users/{userId}/photos/` to `photos/{userId}/`
     - Changed from `users/{userId}/thumbs/` to `thumbnails/{userId}/`
     - Changed from `users/{userId}/metadata/` to `metadata/{userId}/`
   - **Code Updates**:
     - Updated all S3BackupService methods to use new paths
     - Fixed calculateStorageStats() to use new prefixes
     - Updated all upload methods (uploadPhoto, uploadThumbnail, uploadMetadata)
     - Updated all list methods (listUserPhotos, listUserMetadata)
     - Updated restore methods (restorePhoto, checkRestoreStatus)
   - **Benefits**:
     - Enables universal lifecycle rules across all users
     - Simpler S3 lifecycle configuration
     - Better performance for S3 operations
     - No migration needed for new project
   - **Related Updates**:
     - configure-s3-lifecycle-final.sh already uses new paths
     - Documentation reflects V5 pricing strategy
     - Universal 180-day archive policy for all users

35. **IAP Developer Tools Consolidation (June 17, 2025 - Session 6)**:
   - **Menu Reorganization**:
     - Created new "Photolala" top-level menu for app-specific features
     - Eliminated confusing duplicate "View" menus
     - Added "Manage Subscription..." to Photolala menu
     - Added "Developer Tools" submenu (DEBUG only) with IAP tools
   - **Created IAPDeveloperView.swift**:
     - Consolidated IAP testing and debugging into single tabbed interface
     - Three tabs: Status, Products, and Actions
     - Status Tab: Shows user status, IAP status, and debug info
     - Products Tab: Lists available products and purchase status
     - Actions Tab: Quick actions and debug tools
   - **Window Management Improvements**:
     - Fixed blank window titles by setting titleVisibility
     - Added miniaturizable to window style mask
     - Proper window sizing (600x700 for developer tools)
   - **Receipt Viewing Enhancement**:
     - Now shows informative content instead of blank window
     - Explains why receipts are missing in development builds
     - Shows receipt URL and size when available
   - **UI Polish**:
     - Removed unnecessary "View" label from segmented picker
     - Improved subscription view window sizing (1000x700)
     - Better integration between IAPManager and IdentityManager
   - **TabView Title Bar Bug Fix**:
     - Discovered TabView with .tabViewStyle(.automatic) pushes content into title bar on macOS
     - Replaced TabView with switch statement inside Group to avoid the issue
     - Maintains same functionality with proper window layout

36. **Implemented S3 Photo Browser (June 18, 2025)**:
   - **Catalog-First Architecture**:
     - Created PhotolalaCatalogService for reading/writing .photolala files
     - 16 sharded CSV files with MD5-based distribution
     - Binary plist manifest with photo count and checksums
     - No S3 ListObjects calls - completely catalog-driven
   - **S3 Integration**:
     - S3CatalogSyncService with ETag-based delta sync
     - Downloads only changed shards for efficiency
     - S3DownloadService with proper ByteStream handling
     - LRU cache for thumbnails with size-based eviction
   - **Debug Mode**:
     - TestCatalogGenerator creates 10 sample photos
     - Hardcoded userId "test-user-123" for development
     - Colored placeholder thumbnails based on MD5 hash
     - No AWS credentials required in debug mode
   - **Data Models**:
     - S3Photo combines catalog and S3 metadata
     - S3MasterCatalog tracks storage class and archive dates
     - Support for archive badges (Deep Archive indication)
   - **UI Implementation**:
     - S3PhotoBrowserView with grid layout
     - Adjustable thumbnail sizes (S/M/L)
     - Archive status badges for Deep Archive photos
     - Context menus for future operations
   - **Bug Fixes**:
     - Fixed manifest photo count not updating
     - Fixed negative hash index crash
     - Fixed AWS ByteStream handling
     - Fixed window resizing constraints
   - **Storage Paths**:
     - macOS: ~/Library/Caches/com.electricwoods.photolala/cloud.s3/{userId}/
     - Sandboxed: ~/Library/Containers/.../Caches/...
   - **Documentation**:
     - Created s3-photo-browser-implementation.md in docs/current/
     - Updated catalog design documentation

37. **S3 Backup Service Phase 2 Complete (June 18, 2025)**:
   - **Testing Mode Support**:
     - Added `isTestingMode` flag with hardcoded `test-s3-user-001`
     - Works without Apple Sign-in for development
     - Shows "Testing Mode" banner when active
     - Dynamic user ID: uses signed-in user or test user
   - **Multi-Photo Upload**:
     - PhotosPicker with `maxSelectionCount: 10`
     - Batch upload with progress indicators
     - Shows "Uploading photo 3 of 5..." status
     - Clears selection after successful upload
   - **Automatic Thumbnail Generation**:
     - Creates 512x512 thumbnails during upload
     - Uploads to `thumbnails/{userId}/{md5}.dat`
     - Cross-platform thumbnail generation
     - No separate thumbnail generation step needed
   - **Catalog Integration**:
     - Generate Catalog button creates .photolala files
     - Supports both signed-in and test users
     - Fixed path issues (catalog/ → catalogs/)
     - Atomic catalog updates with unique temp directories
   - **Bug Fixes**:
     - Fixed credentials error in testing mode
     - Fixed catalog sync file system errors
     - Fixed Generate Thumbnails for correct user paths
     - Removed unnecessary async/await warnings
   - **Testing Results**:
     - Successfully uploaded photos with MD5 hashes
     - Thumbnails generated and uploaded automatically
     - Catalogs created with correct photo entries
     - Both test mode and signed-in mode working
   - **Documentation Updates**:
     - Updated s3-browser-implementation-plan.md with completion status
     - Added technical implementation details
     - Listed next steps for production features

38. **Star-Based Backup Queue Implementation (June 18, 2025)**:
   - **Core Components**:
     - BackupState enum: tracks photo states (none, queued, uploading, uploaded, failed)
     - BackupQueueManager singleton: manages queue with activity timer
     - BackupStatusManager: shared upload progress tracking
     - BackupStatusBar: bottom-of-window progress display
   - **Visual Design**:
     - Badge overlays on photo thumbnails (top-right corner)
     - States: ⭐ (queued), ⬆️ (uploading), ☁️ (uploaded), ❌ (failed)
     - Gray star shown for unstarred photos (click to star)
     - Badges hidden when archive badges are present
   - **User Interaction**:
     - Click badge to star/unstar photos for backup
     - Toolbar shows queue count when photos are starred
     - Context menu "Add to Backup Queue" for bulk operations
     - Manual backup via toolbar button or auto-backup after timer
   - **Auto-Backup Timer**:
     - 10-minute inactivity timer (production)
     - 3-minute timer for DEBUG builds
     - Resets on any star/unstar action
     - Triggers automatic upload of queued photos
   - **Features**:
     - Queue state persists across app launches
     - MD5 computation on-demand when photos are starred
     - Automatic catalog generation after successful uploads
     - Notifications posted for UI updates
     - Status bar shows progress like Safari downloads
   - **Integration**:
     - Enabled via FeatureFlags.isS3BackupEnabled
     - Works with existing S3BackupManager infrastructure
     - Compatible with Sign in with Apple authentication
     - No test mode - requires real authentication
