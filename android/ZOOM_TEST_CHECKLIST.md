# Android Photo Viewer Zoom Test Checklist

## Test Date: August 16, 2025

### Custom PhotoZoomableImage Component Testing

#### Basic Functionality
- [ ] Photo loads correctly in viewer
- [ ] Initial zoom scale is 1.0x
- [ ] Pinch to zoom works smoothly
- [ ] Pan/drag works when zoomed in
- [ ] Double-tap toggles between 1x and 2x zoom

#### Zoom Limits
- [ ] Minimum zoom: 1.0x (cannot zoom out beyond original size)
- [ ] Maximum zoom: 5.0x (cannot zoom in beyond 5x)
- [ ] Zoom scale resets to 1.0x when navigating between photos

#### Boundary Constraints
- [ ] Image cannot be dragged completely off-screen when zoomed
- [ ] Boundary formula working: maxOffset = (size * (scale - 1)) / 2
- [ ] Image stays centered when zoom scale is 1.0x
- [ ] Spring-back animation when dragging beyond boundaries

#### Navigation Integration
- [ ] Swipe to next/previous photo works when NOT zoomed (scale = 1.0)
- [ ] Swipe navigation disabled when zoomed in (scale > 1.0)
- [ ] Page indicator shows correct position
- [ ] HorizontalPager scrolls smoothly between photos

#### Performance
- [ ] No lag during zoom gestures
- [ ] Smooth animations for zoom transitions
- [ ] Memory usage remains stable when zooming multiple photos
- [ ] No crashes when rapidly zooming/panning

#### Cross-Platform Parity with iOS
- [x] Same zoom range (1x-5x) as iOS
- [x] Same double-tap behavior (toggle 1x/2x) as iOS
- [x] Same boundary calculation formula as iOS
- [x] Zoom resets when changing photos (matches iOS)

### Test Instructions

1. **Launch the app**
   ```bash
   adb shell am start -n com.electricwoods.photolala/.MainActivity
   ```

2. **Navigate to photo viewer**
   - Grant storage permissions if prompted
   - Tap on Local Browser
   - Select a folder with photos
   - Long-press on a photo to open viewer

3. **Test zoom gestures**
   - Pinch out to zoom in (up to 5x)
   - Pinch in to zoom out (minimum 1x)
   - Double-tap to toggle 2x zoom
   - Drag to pan when zoomed

4. **Test navigation**
   - When at 1x zoom: swipe left/right to change photos
   - When zoomed in: verify swipe changes pan position, not photo
   - Use back button to exit viewer

### Implementation Notes

The custom `PhotoZoomableImage` component replaces the third-party `net.engawapg.lib.zoomable` library with our own implementation that matches iOS behavior exactly:

- Located at: `app/src/main/java/com/electricwoods/photolala/ui/components/PhotoZoomableImage.kt`
- Uses Compose's `detectTransformGestures` for pinch/pan
- Uses `detectTapGestures` for double-tap
- Animated transitions using `animateFloatAsState` with spring physics
- Direct zoom multiplication (scale * zoom) for predictable behavior
- Boundary constraints prevent image loss

### Known Issues
- None identified in current implementation

### Improvements from Previous Implementation
- ✅ Removed dependency on third-party zoomable library
- ✅ Achieved exact parity with iOS zoom behavior
- ✅ Fixed boundary constraints to prevent image disappearing
- ✅ Simplified gesture handling for better stability
- ✅ Added configurable zoom parameters for future customization