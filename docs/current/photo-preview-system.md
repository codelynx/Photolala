# Photo Preview System

## Overview

The photo preview system provides a full-screen, immersive viewing experience for photos across all platforms (iOS, macOS, Android). This document describes the current implementation, identified issues, and planned improvements.

## Current Implementation

### Preview Modes

The preview system supports two distinct modes for viewing photos:

#### 1. Preview All Photos
- **Trigger**: Double-click on any photo, or press Space/Preview button with no selection
- **Behavior**: Shows ALL photos in the current folder/album
- **Starting Point**: The clicked/focused photo
- **Use Case**: Browse entire collection from a specific starting point
- **Visual Indicator**: Shows "3 / 250" in control strip

#### 2. Preview Selected Photos Only
- **Trigger**: Press Space or Preview button when photos are selected
- **Behavior**: Shows ONLY the selected photos
- **Starting Point**: First selected photo
- **Use Case**: Review specific photos without distraction
- **Visual Indicator**: Shows "3 / 5 (selected)" in control strip

**Implementation (DirectoryPhotoBrowserView.swift):**
```swift
// handleSpaceKeyPress - NOW RESPECTS SELECTION
if !self.selectedPhotos.isEmpty {
    // Show selected photos only
    photosToShow = self.selectedPhotos.sorted { $0.filename < $1.filename }
    mode = .selection
} else {
    // Show all photos
    photosToShow = self.allPhotos
    mode = .all
}

// handlePhotoSelection (double-click) - ALWAYS SHOWS ALL
let photosToShow = allPhotos
let mode = PreviewMode.all
```

**Platform Differences:**
- **iOS/macOS**: Both modes fully supported
- **Android**: Only "Preview All" mode (no selection-based preview)

### Navigation Entry Points

#### Apple Platforms (iOS/macOS)

**Trigger Methods:**
1. **Double-click (macOS)** - `PhotoCollectionViewController.swift:1082-1090`
2. **Space key** - `DirectoryPhotoBrowserView.swift:57-59, 302-332`
3. **Enter/Return key** - `PhotoCollectionViewController.swift:678-682`
4. **Context Menu** - Right-click → Preview option
5. **Double-tap (iOS)** - `PhotoCollectionViewController.swift:462-465`

**Navigation Flow:**
```swift
handlePhotoSelection(photo, allPhotos) ->
    Creates PreviewNavigation(photos, initialIndex) ->
    macOS: navigationPath.append(navigation)  // Line 328, 361
    iOS: selectedPhotoNavigation = navigation  // Line 330, 363
```

#### Android

**Trigger Methods:**
1. **Long-press** - `PhotoGridScreen.kt:289-295`
2. **Tap in selection mode** - First tap enters selection, subsequent toggle

**Navigation Flow:**
```kotlin
onPhotoClick = { photo, index ->
    navController.navigate(PhotolalaRoute.PhotoViewer.createRoute(index))
}
```

### Navigation Methods Comparison

| Feature | iOS | macOS | Android |
|---------|-----|-------|---------|
| **Swipe left/right** | ✅ When not zoomed | N/A | ✅ When not zoomed |
| **Arrow keys** | ❌ No | ✅ Yes | ❌ No |
| **Tap zones (edges)** | ✅ Yes (25% edges) | ✅ Yes | ❌ No |
| **Thumbnail strip** | ✅ Yes | ✅ Yes | ❌ No |
| **Page indicator** | ✅ Top (with mode) | ✅ Top (with mode) | ✅ Bottom |
| **Previous/Next buttons** | ❌ No | ❌ No | ✅ Yes (always visible) |
| **Auto-hide controls** | ✅ 6s timer | ✅ 6s timer | ❌ Always visible |
| **Preview button** | ✅ Always visible | ✅ Always visible | ❌ No button |

## Preview Mode System (FIXED ✅)

### Current Behavior (After Fix)

1. **Consistent Space Key Behavior**
   - Space key respects selection: shows selected photos when selection exists
   - Shows all photos when no selection
   - Matches user expectations

2. **Predictable Double-click**
   - Double-click ALWAYS shows all photos from clicked photo
   - Consistent behavior regardless of selection state
   - No ambiguity

3. **Clear Visual Indicators**
   - Shows "3 / 250" when viewing all photos
   - Shows "3 / 5 (selected)" when viewing selection only
   - Users always know which mode they're in

### Recommended Preview Mode Design

#### Clear Mode Separation
1. **Space Key**: Always preview selection (if exists), otherwise all
2. **Enter Key**: Same as Space (consistency)
3. **Double-click**: Always preview all, starting from clicked photo
4. **Context Menu**: Separate options for "Preview" and "Preview All"

#### Visual Mode Indicators
```
Preview Mode: All Photos (1 of 250)
Preview Mode: Selection (3 of 5 selected)
```

#### Mode Switching
- Add button/shortcut to toggle between modes while in preview
- Remember last mode per session

## Recent Fixes ✅

### Cross-Platform Zoom/Pan Implementation (August 16, 2025)

#### iOS Fixes

1. **Swipe/Zoom Conflict Resolution**
   - Swipe navigation now only works when `zoomScale <= 1.0`
   - When zoomed in, all drag gestures pan the image
   - Clear UX: "Zoom in to examine, zoom out to navigate"
   - Matches iOS Photos app behavior

2. **Simplified Gesture Handling**
   - Removed complex rubber band and momentum features
   - Implemented delta-based scaling to prevent jumps
   - Direct pan application for predictable movement
   - Boundary formula: `maxOffset = (size * (scale - 1)) / 2`

#### Android Implementation

1. **Custom PhotoZoomableImage Component**
   - Created custom implementation replacing `net.engawapg.lib.zoomable`
   - Matches iOS zoom parameters exactly (1x-5x range)
   - Same boundary constraints and formulas
   - Double-tap toggles between 1x and 2x zoom

2. **Navigation Buttons (August 16, 2025)**
   - Added visible `<` and `>` buttons on left/right edges
   - Semi-transparent circular buttons (48dp size)
   - Always visible to solve zoom navigation issue
   - Buttons hide at first/last photo boundaries
   - Work regardless of zoom state

3. **Fixed Drag Gesture for Pan (August 16, 2025)**
   - Added separate `detectDragGestures` for single-finger pan when zoomed
   - `detectTransformGestures` handles pinch-zoom and two-finger pan
   - HorizontalPager's `userScrollEnabled` disabled when zoomed
   - Zoom state tracked and communicated to parent via callback
   - Prevents swipe-to-navigate conflict when panning zoomed image

4. **Cross-Platform Consistency**
   - Both platforms use identical zoom limits
   - Same boundary calculation formula
   - Consistent gesture behavior
   - Position resets when zoomed to 1x

## Known Issues

### Critical Issues 🔴

~~1. **iOS Gesture Conflict** (PhotoPreviewView.swift:250-260)~~ **FIXED**
   - ~~Swipe navigation conflicts with zoom pan gesture~~
   - ~~When zoomed in, pan gesture takes priority~~
   - ~~Swipe only works when NOT zoomed~~
   - ~~Users cannot navigate between photos when zoomed~~

### Major Issues ⚠️

1. ~~**Missing Navigation Buttons**~~ **PARTIALLY FIXED**
   - ✅ Android: Now has visible prev/next buttons
   - ❌ iOS/macOS: Still rely on tap zones/gestures
   - Users on iOS/macOS don't discover tap zones without instructions

2. **Android Feature Gaps**
   - No thumbnail strip for quick navigation
   - No keyboard support
   - Controls always visible (no auto-hide)

3. **Inconsistent UX**
   - Different auto-hide timers (30s vs always visible)
   - Different navigation methods per platform
   - No unified gesture handling
   - Space key behavior inconsistent with selection

## Proposed Improvements

### Unified Preview Design

#### Essential Navigation Controls (All Platforms)

1. **Visible Navigation Buttons**
   - Semi-transparent `<` and `>` buttons on edges
   - Minimum 44pt touch targets
   - Show/hide with other controls
   - Disabled state at boundaries

2. **Fixed Gesture System**
   - iOS: Add navigation buttons as primary method
   - Keep swipe as secondary when not zoomed
   - Or: Implement velocity-based detection

3. **Unified Control Timer**
   - 3-second initial display
   - Hide after 3 seconds of inactivity
   - Any tap shows controls
   - Interaction resets timer

4. **Consistent Thumbnail Strip**
   - Bottom position on all platforms
   - Horizontal scroll with current photo centered
   - Smooth animations
   - 60x60pt thumbnails

5. **Keyboard Support**
   - Arrow keys: Navigate
   - Space: Play slideshow (future)
   - ESC: Exit preview
   - I: Toggle info
   - T: Toggle thumbnails

#### Recommended Layout

```
┌─────────────────────────────────┐
│ [Back] Title      [Info] [More] │ <- Top bar (auto-hide)
├─────────────────────────────────┤
│                                 │
│  [<]        PHOTO         [>]  │ <- Nav buttons (auto-hide)
│                                 │
│                                 │
│           (1 / 25)              │ <- Page indicator
├─────────────────────────────────┤
│ [📷][📷][📷][📷][📷][📷][📷] │ <- Thumbnails (auto-hide)
└─────────────────────────────────┘
```

## Implementation Priority

### ✅ Priority 1: Fix iOS Navigation (COMPLETED)

**Implemented Solutions:**

1. **Conditional Swipe Navigation**
```swift
// PhotoPreviewView.swift:253-261
if self.zoomScale <= 1.0 {
    // Allow swipe navigation only when not zoomed
}
```

2. **Pan Safety Boundaries**
```swift
// PhotoPreviewView.swift:422-461
private func constrainedOffset(for offset: CGSize, zoomScale: CGFloat, geometry: GeometryProxy) -> CGSize {
    // Ensures minimum 25% of image remains visible
    // Auto-centers when image fits within view
    // Spring-back animation on boundaries
}
```

**Results:**
- ✅ No more swipe/zoom conflicts
- ✅ Images can't be lost off-screen
- ✅ Natural spring-back animations
- ✅ Matches iOS Photos app behavior

### Priority 2: Fix Preview Mode Confusion

**Space Key Behavior Fix:**
```swift
private func handleSpaceKeyPress() {
    guard !self.allPhotos.isEmpty else { return }
    
    let photosToShow: [PhotoFile]
    let initialIndex: Int
    
    if !self.selectedPhotos.isEmpty {
        // Show selected photos only
        photosToShow = self.selectedPhotos.sorted { $0.filename < $1.filename }
        initialIndex = 0  // Start from first selected
    } else {
        // Show all photos
        photosToShow = self.allPhotos
        initialIndex = 0
    }
    
    let navigation = PreviewNavigation(
        photos: photosToShow, 
        initialIndex: initialIndex,
        mode: selectedPhotos.isEmpty ? .all : .selection
    )
}
```

**Add Mode Indicator to Preview:**
```swift
// In ControlStrip
Text(previewMode == .all ? 
    "\(currentIndex + 1) of \(totalCount)" :
    "\(currentIndex + 1) of \(totalCount) selected")
```

### Priority 3: Improve Timer Logic

- Show controls for 3 seconds on entry
- Hide after 3 seconds of inactivity
- Any interaction resets timer
- Smooth fade animations (0.3s)

### Priority 4: Android Feature Parity

- Add selection-based preview mode
- Implement preview mode indicators
- Add thumbnail strip using LazyRow
- Implement keyboard navigation
- Add auto-hide controls with timer
- Match iOS/macOS behavior

### Priority 5: Enhanced Feedback

- Loading indicators for images
- Haptic feedback on navigation (iOS)
- Smooth page transitions
- Preload status in thumbnails

## Performance Considerations

### Current Implementation
- iOS/macOS: Preloads ±2 adjacent images
- Android: Relies on Coil caching
- Thumbnail strip loads on-demand

### Recommended Optimizations
- Preload ±3 images for smoother navigation
- Cache full-size images in memory (with limits)
- Progressive loading for large images
- Thumbnail strip virtualization for large collections

## Accessibility

### Required Improvements
- VoiceOver/TalkBack support for buttons
- Keyboard navigation on all platforms
- Clear focus indicators
- Alternative text for images
- Gesture hints for screen readers

## Testing Requirements

### Manual Testing
- [ ] Navigation with 1 photo
- [ ] Navigation at boundaries
- [ ] Zoom and pan interactions
- [ ] Control timer behavior
- [ ] Keyboard shortcuts
- [ ] Rotation handling
- [ ] Memory usage with large collections

### Automated Testing
- Navigation state management
- Timer logic
- Gesture recognizer conflicts
- Image loading states
- Cache behavior

## Migration Plan

1. **Phase 1**: Fix iOS swipe conflict (immediate)
2. **Phase 2**: Add navigation buttons (all platforms)
3. **Phase 3**: Unify timer behavior
4. **Phase 4**: Add missing features to Android
5. **Phase 5**: Polish and optimize

## Preview Mode Specifications

### Selection-Based Preview

When users select multiple photos and initiate preview:

1. **Photo Set**: Only selected photos are loaded
2. **Navigation Boundaries**: Cannot navigate beyond selection
3. **Order**: Photos shown in selection order or sorted by filename
4. **Exit Behavior**: Returns to grid with selection maintained

### All Photos Preview

When users preview without selection or explicitly choose "Preview All":

1. **Photo Set**: All photos in current folder/album
2. **Navigation**: Can navigate through entire collection
3. **Starting Point**: Photo that was clicked/focused
4. **Performance**: Lazy loading with ±3 photo prefetch

### Context Menu Design

```
┌─────────────────────────┐
│ [Photo Thumbnail]       │
│ Filename.jpg            │
│ 2.3 MB • 1920x1080      │
├─────────────────────────┤
│ Preview                 │ <- Preview selected (if multiple selected)
│ Preview All             │ <- Always available
│ ─────────────           │
│ Quick Look              │
│ Open With >             │
│ Get Info                │
│ ─────────────           │
│ Add to Backup Queue     │
└─────────────────────────┘
```

## Platform-Specific Considerations

### iOS Constraints
- No right-click menu (use long-press)
- Limited keyboard support (external only)
- Touch gestures primary interaction
- Screen size varies greatly

### macOS Advantages
- Full keyboard support
- Right-click context menus
- Larger screens allow more UI
- Multiple windows possible

### Android Gaps
- No selection-based preview yet
- Missing thumbnail strip
- No keyboard navigation
- Always visible controls

## User Experience Guidelines

### Clear Mode Communication
1. Always show which mode is active
2. Display count of photos in current set
3. Indicate selection state visually
4. Provide mode switching capability

### Predictable Behavior
1. Consistent trigger actions across platforms
2. Same gesture = same result
3. Visual feedback for all actions
4. Clear navigation boundaries

### Performance Optimization
1. Preload adjacent photos based on mode
2. Smaller prefetch for selection mode
3. Aggressive prefetch for all photos mode
4. Cancel unused prefetch operations

## Implementation Checklist

### Immediate Fixes (P0)
- [ ] Fix iOS swipe/zoom conflict
- [ ] Add navigation buttons to iOS
- [ ] Fix Space key behavior for selection

### Short Term (P1)
- [ ] Add preview mode indicator
- [ ] Implement mode switching in preview
- [ ] Unify timer behavior
- [ ] Add visual navigation hints

### Medium Term (P2)
- [ ] Android selection preview
- [ ] Android thumbnail strip
- [ ] Keyboard support (all platforms)
- [ ] Haptic feedback

### Long Term (P3)
- [ ] Slideshow mode
- [ ] Video support
- [ ] Edit capabilities
- [ ] Share sheet integration

## Testing Scenarios

### Preview Mode Testing
1. **No Selection**
   - Space key → Preview all
   - Double-click → Preview all from clicked
   
2. **With Selection**
   - Space key → Preview selected only
   - Enter key → Preview selected only
   - Context menu → Both options available
   
3. **Mixed State**
   - Click selected photo → Preview selected
   - Click unselected photo → Preview all
   
4. **Edge Cases**
   - Single photo selected
   - All photos selected
   - Non-contiguous selection
   - Large selection (100+ photos)

### Navigation Testing
1. **Gesture Conflicts**
   - Zoom in and try to swipe
   - Pinch while swiping
   - Double-tap while zoomed
   
2. **Boundary Conditions**
   - Navigate at first/last photo
   - Preview with 1 photo only
   - Preview with 0 photos (error state)
   
3. **Performance**
   - Large photos (RAW files)
   - Many photos (1000+)
   - Fast navigation (rapid swipes)
   - Memory pressure scenarios

## Related Documentation

- [Navigation Flow](navigation-flow.md)
- [Thumbnail System](thumbnail-system.md)
- [Selection System](selection-system.md)
- [Gesture Handling](../architecture/gesture-handling.md)