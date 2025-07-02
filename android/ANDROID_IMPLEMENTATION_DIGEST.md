# Android Implementation Digest - Actionable Plan

Based on KY's review notes, here's a simplified, phased approach to Android development.

**Updated July 2, 2025**: Phase 1 and Phase 2 are now COMPLETE! ✅

## Key Principles from Review
- **Step by step** - Don't implement everything at once
- **Small tasks** - Break complex features into manageable pieces  
- **POC when needed** - Create proof of concepts for uncertain areas
- **100K+ photos** - Target smooth browsing of large collections
- **Minimum features first** - Build core functionality before extras
- **Ask for decisions** - Consult when facing architectural choices

## Phase 1: Basic Photo Browsing ✅ COMPLETE

### 1.1 MediaStore Integration (Small Steps)
```
[x] Create MediaStoreService interface
[x] Implement basic photo query (just IDs and URIs)
[x] Add pagination support (load 100 at a time)
[x] Create simple test to verify it works
```

### 1.2 Simple Photo Grid UI
```
[x] Create PhotoGridScreen composable
[x] Use LazyVerticalGrid with fixed 3 columns
[x] Display gray placeholders initially
[x] Add refresh button (instead of pull-to-refresh)
```

### 1.3 Thumbnail Loading with Coil
```
[x] Configure Coil with memory/disk cache
[x] Create PhotoThumbnail composable
[x] Load thumbnails using MediaStore URI
[x] Show loading indicator
```

### 1.4 Basic Navigation
```
[x] Add Navigation Compose dependency (already added)
[x] Create NavHost with 2 screens: Welcome, PhotoGrid
[x] Simple "Browse Photos" button on Welcome
[x] Back button handling
```

## Phase 2: Photo Viewer ✅ COMPLETE

### 2.1 Full Screen Photo View
```
[x] Create PhotoViewerScreen
[x] Implement pinch-to-zoom (using zoomable library)
[x] Add swipe between photos (HorizontalPager)
[x] Show basic info (filename, size, dimensions, date)
```

### 2.2 Navigation Integration
```
[x] Navigate from grid to viewer on tap
[x] Pass photo list and selected index
[x] Basic transition (no shared element yet)
```

## Phase 3: Services Layer (Week 4)

### 3.1 PhotoManager Service
```
[ ] Create interface first
[ ] Implement thumbnail generation
[ ] Add caching logic
[ ] Memory management for 100K+ photos
```

### iOS/macOS Feature Parity Goals:
- Dynamic grid columns (not just fixed 3)
- Multiple thumbnail sizes (S/M/L)
- Info bar overlay on thumbnails
- Star badges for backup status

### 3.2 Repository Pattern
```
[ ] Create PhotoRepository interface
[ ] Implement with MediaStore + Room
[ ] Add simple in-memory cache
[ ] Test with large datasets
```

## Phase 4: Selection & Operations (Week 5)

### 4.1 Selection Mode ✅ Partially Complete
```
[x] Tap to select/deselect (enters selection mode automatically)
[x] Long-press to preview photo
[x] Visual feedback (3px border + subtle background tint)
[x] Show selection count in toolbar
[x] Exit selection mode (manual or auto when all deselected)
[ ] Keyboard shortcuts (1-7 for colors, S for star)
[ ] Selection persistence across navigation
```

### 4.2 Basic Operations
```
[ ] Share selected photos
[ ] Delete (move to trash)
[ ] Copy to folder
```

## POC List (Proof of Concepts)

### POC 1: Credential Storage
**Question**: What's the Kotlin equivalent of credential-code?
```
- Research Android Keystore API
- Test storing AWS credentials
- Create simple wrapper class
- Document security considerations
```

### POC 2: 100K Photo Performance
```
- Generate test dataset
- Measure scroll performance
- Test memory usage
- Optimize based on findings
```

### POC 3: Navigation Patterns
**Note**: "not confident, i prefer navigation"
```
- Try Navigation Compose with bottom nav
- Test drawer navigation
- Evaluate which feels better
- Get feedback before proceeding
```

### POC 4: Error Handling
```
- Create Result<T> wrapper
- Test network error scenarios  
- Design user-friendly messages
- Implement retry logic
```

## Questions to Answer

### What is Hilt?
- Google's dependency injection framework
- Built on top of Dagger
- Simplifies DI setup with annotations
- Already configured in the project

### Alternative to ViewModels?
- ViewModels are standard in Android
- Alternatives: MVI pattern, Redux-style
- Recommendation: Stick with ViewModels for now

### Kotlin Credential Storage?
- Android Keystore for secure storage
- EncryptedSharedPreferences for simpler data
- Need to evaluate based on security requirements

## Decision Points (Ask KY)

1. **Navigation Style**
   - Bottom navigation bar?
   - Navigation drawer?
   - Simple back stack?

2. **Photo Grid Layout**
   - Fixed 3 columns?
   - Adaptive based on screen size?
   - User adjustable like iOS?

3. **Caching Strategy**
   - How much disk space to use?
   - When to clear cache?
   - Thumbnail sizes?

4. **Error Messages**
   - Toast messages?
   - Snackbar?
   - Dialog boxes?

5. **Build Variants**
   - Need dev/staging/prod?
   - Different API endpoints?
   - Debug features?

## iOS/macOS Design Patterns to Follow

### Grid View Features (from UnifiedPhotoCollectionViewController):
1. **Thumbnail Sizes**: Small (64px), Medium (128px), Large (256px)
2. **Selection Visual**: 3px blue border when selected
3. **Metadata Bar**: 24px height showing file size and flags
4. **Star Badge**: Backup status indicator
5. **Color Flags**: 7 color options for tagging
6. **Display Modes**: Scale to Fit vs Scale to Fill
7. **Context Menus**: Right-click/long-press actions

### Viewer Features (from PhotoPreviewView):
1. **Zoom Range**: 0.5x to 5.0x with spring animation
2. **Double-tap**: Toggle between 1x and 2x zoom
3. **Navigation**: Swipe, tap zones, keyboard arrows
4. **Auto-hide Controls**: 30-second timer
5. **Thumbnail Strip**: Horizontal scrolling preview
6. **Metadata HUD**: Floating info overlay

### Performance Patterns:
1. **Prefetching**: Load adjacent items
2. **Priority Loading**: Based on visibility
3. **Cell Reuse**: Efficient recycling
4. **Cancellation**: Stop loads on scroll

## Next Immediate Action

~~Start with **Phase 1.1 - MediaStore Integration**~~ ✅ COMPLETE!

Next: **Phase 3.1 - PhotoManager Service** with iOS/macOS feature parity in mind.

This approach ensures we build incrementally, test each piece, and don't get overwhelmed by the full scope.