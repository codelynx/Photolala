# Enhanced Preview Features Plan

Created: June 14, 2025
Last Updated: June 14, 2025

## Overview

This document outlines the current state and planned enhancements to the PhotoPreviewView and PhotoBrowserView to make them more feature-rich and useful for photo browsing and management. The preview system now includes comprehensive keyboard navigation, automatic controls, and seamless integration between browser and preview modes.

## Implementation Status

### ✅ Completed Features

#### Preview View
- **Control Strip** (top): Back button, progress indicator ("2/10"), filename, fullscreen toggle
- **Thumbnail Strip** (bottom): Smooth scrolling, selection highlighting, auto-scroll to current
- **Auto-hide Controls**: 30-second timer, resets on interaction, extends on thumbnail tap
- **Navigation**: 
  - Tap zones (left 25%, right 25%, center toggle)
  - Keyboard shortcuts (arrows, F, T, ESC, Space, ?)
  - Swipe gestures on iOS
- **Zoom & Pan**: Pinch (0.5x-5x), double-tap (1x/2x), drag when zoomed
- **Focus Management**: Automatic focus on appear, background tap to regain focus

#### Browser View
- **Space Key**: Opens preview showing all photos
  - No selection: Starts from first photo
  - With selection: Starts from first selected photo
  - Always allows navigation through all photos
- **Photo Loading**: Automatic storage of all photos via callbacks
- **Selection Handling**: Preview button for selected photos only

### 🚧 In Progress
- Basic file information display (partially done - filename and index completed)

### 📋 Planned
- EXIF information panel
- Advanced keyboard shortcuts
- Different zoom modes
- Slideshow functionality
- Rating and flagging system
- File operations (copy, share, delete, rotate)
- Performance optimizations (preloading, progressive loading)

## Current State

### Core Display Features
- **Full resolution image display** with black background
- **Zoom capabilities**:
  - Pinch to zoom (0.5x to 5.0x range)
  - Double-tap to toggle between 1x and 2x zoom
  - Pan with drag gesture when zoomed
  - Auto-reset zoom when navigating between photos
- **Loading states**: Progress spinner and error display with icon

### Navigation
- **Tap zones**: 
  - Left 25% of screen: Previous photo
  - Right 25% of screen: Next photo
  - Center 50%: Toggle controls
- **Keyboard shortcuts**:
  - Left/Right arrows: Navigate between photos
  - F: Toggle fullscreen mode
  - T: Toggle thumbnail strip visibility
  - ESC: Exit preview (macOS)
  - Space: Slideshow (placeholder)
  - ?: Help (placeholder)
- **Swipe gestures** (iOS): Left/right with 50px threshold
- **Selection-aware**: Shows only selected photos when selection exists

### Control Strip (Top)
- **Back button**: Chevron left icon to close preview
- **Progress indicator**: "2 / 10" format showing current position
- **Filename display**: Shows current photo filename
- **Fullscreen toggle**: Platform-native fullscreen support
- **Styling**: Semi-transparent black (80% opacity), 44pt height

### Thumbnail Strip (Bottom)
- **Film-style navigation**: Horizontal scrolling thumbnails
- **Thumbnail size**: 60x60 pixels with 8px spacing
- **Selection highlight**: 
  - Selected: White 3px border with 1.1x scale
  - Others: Gray 1px border
- **Auto-scroll**: Centers on current photo
- **Interactive**: Tap to jump to any photo
- **Styling**: Semi-transparent black background (80% opacity)

### Auto-Hide Behavior
- **30-second timer**: Controls hide after 30 seconds of inactivity
- **Timer extension**: Resets when:
  - User taps thumbnails to navigate
  - Controls are toggled
- **Smooth animations**: 0.3s fade transitions

## Proposed Enhancements

### Phase 1: Information Display
Essential information that helps users understand what they're viewing.

#### 1.1 Basic File Information (Partially Implemented)
- **Filename**: Display at top or bottom ✓ (in control strip)
- **File size**: Human-readable format (KB/MB)
- **Dimensions**: Width × Height in pixels
- **Index**: Current position (e.g., "3 of 150") ✓ (shows as "3 / 150")

#### 1.2 EXIF Information Panel
- **Toggle panel**: Keyboard shortcut (I) or button
- **Basic EXIF**: Camera, lens, ISO, aperture, shutter speed
- **Extended data**: GPS location, keywords, copyright
- **Collapsible sections**: Organize data by category

### Phase 2: Enhanced Navigation

#### 2.1 Thumbnail Strip ✅ IMPLEMENTED
- **Position**: Bottom of screen ✓
- **Features**:
  - Show thumbnails centered on current ✓
  - Smooth scrolling ✓
  - Click to jump ✓
  - Current photo highlighted ✓
- **Toggle**: Auto-hide with timer ✓

#### 2.2 Keyboard Shortcuts (Mostly Implemented)
- **In Browser View**:
  - Space: Open preview mode ✓ (shows all photos, starts from selected if any)
- **In Preview View**:
  - Left/Right arrows: Navigate photos ✓ (works in all states)
  - ESC: Exit preview (macOS) ✓
  - F: Toggle fullscreen ✓
  - T: Toggle thumbnail strip ✓
  - Space: Slideshow placeholder ✓ (key captured, feature pending)
  - ?: Help placeholder ✓ (key captured, feature pending)
- **Planned shortcuts**:
  - I: Toggle info panel
  - Delete: Mark for deletion
  - 1-5: Rate photo

### Phase 3: Viewing Modes

#### 3.1 Zoom Modes
- **Fit**: Current implementation (default)
- **Fill**: Fill screen, crop if needed
- **Actual Size**: 1:1 pixel mapping
- **Percentage**: 50%, 100%, 200%, etc.

#### 3.2 Slideshow
- **Controls**: Play/pause, speed adjustment
- **Transitions**: Fade, slide, none
- **Options**:
  - Loop
  - Random order
  - Timer (2-10 seconds)

### Phase 4: Quick Actions

#### 4.1 Rating and Flagging
- **Star rating**: 1-5 stars (keyboard 1-5)
- **Flags**: Flag/unflag (keyboard F)
- **Labels**: Color labels (keyboard 6-9)
- **Visual feedback**: Show rating/flag on photo

#### 4.2 File Operations
- **Copy**: Copy to clipboard
- **Share**: System share sheet
- **Delete**: Move to trash with confirmation
- **Rotate**: 90° increments (R key)

### Phase 5: Performance Optimizations

#### 5.1 Image Preloading
- **Adjacent images**: Preload ±2 images
- **Memory management**: Limit cache size
- **Progressive loading**: Low-res first, then full

#### 5.2 Smooth Transitions
- **Cross-fade**: Between photos
- **Maintain zoom**: Option to keep zoom level
- **Gesture continuity**: Swipe momentum

## Implementation Priority

### High Priority (Phase 1)
1. Basic file information display ✅ (Partially - filename and index done)
2. Keyboard shortcuts for existing features ✅ (Completed - all major shortcuts)
3. Simple EXIF display

### Medium Priority (Phase 2-3)
1. Thumbnail strip ✅ (Completed)
2. Slideshow mode (Space key ready, implementation pending)
3. Different zoom modes

### Low Priority (Phase 4-5)
1. Rating system
2. Advanced EXIF panel
3. Performance optimizations

## Technical Implementation Details

### Key Code Changes

#### PhotoPreviewView.swift
- Added `@FocusState private var isFocused: Bool` for keyboard focus
- Background Color view made `.focusable()` and `.focused($isFocused)`
- Keyboard handlers using `.onKeyPress(keys: ["f"])` syntax for character keys
- Timer management in `handleTapGesture` and `extendControlsTimer()`
- Focus delay: `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)`

#### PhotoBrowserView.swift
- Added `@State private var allPhotos: [PhotoReference] = []`
- Space key handler: `.onKeyPress(.space)` on NavigationStack
- `handleSpaceKeyPress()` creates PreviewNavigation with all photos
- Photos populated via `onPhotosLoaded` callback from collection view

#### PhotoCollectionViewController.swift
- Added `onPhotosLoadedWithReferences: (([PhotoReference]) -> Void)?`
- Called in `loadPhotos()` after scanning directory
- Separate from iOS count-only callback for compatibility

### Focus Flow
1. Preview appears → 0.1s delay → Focus set
2. If focus lost → Tap background → Focus regained
3. All keyboard shortcuts require focus to work

## Technical Considerations

### Data Requirements
- **EXIF Reading**: Need to extract metadata from images
- **Persistence**: Ratings/flags need storage solution
- **Performance**: Preloading without memory issues

### UI/UX Guidelines
- **Non-intrusive**: Information should not obscure photo
- **Consistent**: Follow platform conventions
- **Accessible**: Keyboard navigation for all features
- **Responsive**: Adapt to different screen sizes

### Platform Differences
- **macOS**: Full keyboard support, menu items
- **iOS**: Touch-optimized, gesture-based
- **Storage**: Consider iCloud sync for ratings

## User Stories

1. **As a photographer**, I want to see EXIF data to understand camera settings
2. **As a photo organizer**, I want to rate photos for later sorting
3. **As a casual user**, I want slideshow mode for easy viewing
4. **As a power user**, I want keyboard shortcuts for efficiency

## Success Metrics

- Preview opens with no noticeable delay
- Information displays within 100ms
- Smooth transitions between photos
- No memory issues with large collections
- Intuitive controls that don't require documentation

## Next Steps

1. Review and approve feature set
2. Create detailed technical design
3. Implement Phase 1 features
4. Test and gather feedback
5. Iterate on subsequent phases