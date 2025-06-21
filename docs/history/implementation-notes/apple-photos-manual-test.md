# Apple Photos Library Browser - Manual Testing Guide

## Prerequisites

1. **Build the app in Xcode**:
   - Open `Photolala.xcodeproj` in Xcode
   - Select the macOS target
   - Build and run (⌘R)

2. **Add Info.plist entry** (if not already added):
   - In Xcode, select the Photolala target
   - Go to Info tab
   - Add a new row with key: `NSPhotoLibraryUsageDescription`
   - Value: `Photolala needs access to your photo library to browse and organize your photos.`

## Test Scenarios

### 1. Initial Permission Request

**Steps:**
1. Launch Photolala
2. Click "Photos Library" button on welcome screen

**Expected:**
- System permission dialog appears
- Dialog shows the usage description
- Options to grant or deny access

**Test Cases:**
- ✅ Grant full access - should open Photos Library browser
- ✅ Grant limited access - should open with limited photos
- ✅ Deny access - should show error message

### 2. Basic Photo Browsing

**Steps:**
1. Open Photos Library browser
2. Observe the photo grid

**Expected:**
- Photos load and display as thumbnails
- Shows "All Photos" in title
- Displays photo count in subtitle
- Thumbnails load progressively

**Test Cases:**
- ✅ Scroll through photos
- ✅ Verify thumbnails load correctly
- ✅ Check memory usage with large library

### 3. Album Selection

**Steps:**
1. Click "Albums" button in toolbar
2. Select different albums

**Expected:**
- Album picker sheet appears
- Shows system albums (Favorites, Recents, etc.)
- Shows user-created albums
- Current album has checkmark

**Test Cases:**
- ✅ Select "All Photos"
- ✅ Select "Favorites"
- ✅ Select user album
- ✅ Cancel album selection

### 4. Photo Selection

**Steps:**
1. Click on photos to select
2. Use Cmd+Click for multiple selection
3. Use Shift+Click for range selection

**Expected:**
- Selected photos show highlight
- Selection count updates
- Standard macOS selection behavior

### 5. Inspector Panel

**Steps:**
1. Select one or more photos
2. Click Inspector button or press Cmd+I

**Expected:**
- Inspector shows photo details
- Displays filename, size, dimensions
- Shows creation date
- Multiple selection shows summary

### 6. Context Menu

**Steps:**
1. Right-click on a photo

**Expected:**
- Context menu appears with:
  - "View in Photos" (macOS only)
  - "Export..."
  - "Get Info"

### 7. Display Settings

**Steps:**
1. Use toolbar controls to adjust:
   - Display mode (fit/fill)
   - Thumbnail size slider
   - Item info toggle

**Expected:**
- Changes apply immediately
- Settings persist during session

### 8. Window Management (macOS)

**Steps:**
1. Open folder browser and Photos Library simultaneously
2. Switch between windows

**Expected:**
- Both windows work independently
- Can have multiple browsers open
- Window titles distinguish source

## Performance Testing

### Large Library Test
- Test with 10,000+ photos
- Monitor memory usage
- Check scrolling performance
- Verify thumbnail caching

### iCloud Photos Test
- Test with iCloud Photo Library enabled
- Verify download on demand works
- Check network usage

## Edge Cases

1. **Empty Library**: No photos in library
2. **Permission Changes**: Revoke permission while app running
3. **Library Updates**: Add/remove photos while browsing
4. **Memory Pressure**: Browse with low memory

## Known Issues

1. Build warnings about Swift 6 concurrency (doesn't affect functionality)
2. Need to add Info.plist entry manually in Xcode
3. Photos Library window title might show URL instead of "Photos Library"

## Troubleshooting

1. **Photos don't appear**:
   - Check Photo Library permissions in System Settings
   - Ensure Photos app has synced if using iCloud

2. **Crashes on launch**:
   - Check console for permission errors
   - Verify PhotoKit framework is linked

3. **Album picker empty**:
   - Ensure albums contain at least one photo
   - Check album permissions