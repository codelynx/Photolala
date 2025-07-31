# Android Implementation Gaps

This document tracks remaining implementation gaps in the Android platform as of July 31, 2025.

## High Priority

### 1. Thumbnail Generation During Upload
- **Current State**: Photos upload at full size only
- **Missing**: Thumbnail generation and upload to `thumbnails/` path
- **Impact**: Cloud browser can't show thumbnails efficiently
- **Location**: `BackupQueueManager.kt` line 205 (TODO comment)
- **iOS Reference**: iOS generates thumbnails during upload

### 2. PhotoDigest Two-Level Cache
- **Current State**: Implementation started but has build errors on develop branch
- **Missing**: Complete implementation matching iOS architecture
- **Impact**: Can't leverage fast cached thumbnails with metadata
- **Files**: `PhotoDigest.kt`, `PhotoDigestCache.kt`, `PhotoDigestViewModel.kt`
- **iOS Reference**: See `docs/planning/unified-thumbnail-metadata-design.md`

### 3. Build Configuration for Debug/Release
- **Current State**: Timer hardcoded to 1 minute for all builds
- **Missing**: Proper BuildConfig detection for debug vs release
- **Impact**: Can't use 15-second timer for development
- **Location**: `BackupQueueManager.kt` line 37-38
- **Solution**: Need to properly configure BuildConfig generation

## Medium Priority

### 4. Catalog Update Race Condition
- **Current State**: Catalog updates can be cancelled when backup state changes
- **Impact**: Catalog might not always reflect uploaded photos
- **Workaround**: Object listing fallback works correctly
- **Location**: `BackupQueueManager.kt` - monitoring flow restarts on state change

### 5. Apple Sign-In Deep Link on Emulator
- **Current State**: Deep link redirect doesn't work automatically on emulator
- **Impact**: Must manually return to app after Apple Sign-In
- **Note**: May be emulator-specific limitation

### 6. Missing Features from iOS

#### Photo Browser Features
- Photo grouping by date
- Sort options (filename, date)
- Inspector panel for metadata
- Thumbnail size options (S/M/L)
- Scale mode toggle (fit/fill) - partially implemented
- Selection system with multi-select
- Context menus
- Keyboard shortcuts

#### Navigation Features  
- Folder hierarchy navigation
- Recent folders
- Bookmarks/favorites

#### Advanced Features
- EXIF metadata reading
- GPS location display
- RAW file support
- Video support
- Archive tier management

## Low Priority

### 7. Unsupported Image Formats
- **Current State**: Some images show decode errors
- **Impact**: A few photos may not display thumbnails
- **Example**: `content://media/external/images/media/23`
- **Note**: Likely HEIF or other formats needing additional decoders

### 8. Performance Optimizations
- Implement progressive photo loading
- Add memory cache for thumbnails
- Optimize RecyclerView with DiffUtil
- Add pagination for large photo sets

### 9. UI Polish
- Loading states and progress indicators
- Empty states for no photos
- Error handling UI
- Pull-to-refresh
- Animations and transitions

## Implementation Notes

Most of these gaps are expected for a platform in early development. The core functionality works:
- ✅ Authentication (Apple & Google)
- ✅ Photo browsing (local)
- ✅ Star and backup to S3
- ✅ Cloud browser
- ✅ Account management
- ✅ Basic catalog support

The Android app has reached functional parity with iOS for the core backup workflow, which was the primary goal.