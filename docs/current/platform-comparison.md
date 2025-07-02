# Platform Comparison

This document outlines the key differences in implementation approaches across macOS, iOS, and Android platforms while maintaining feature parity.

## Grid View

### Responsive Sizing
All platforms now support device-aware thumbnail sizing within the 256px generation limit:

| Platform | Small Devices | Medium Devices | Large Devices |
|----------|--------------|----------------|---------------|
| iOS      | 64/80/100pt  | 80/100/128pt   | 100/128/160pt |
| Android  | 64/80/100dp  | 80/100/128dp   | 100/128/160dp |
| macOS    | 64/128/256pt | 64/128/256pt   | 64/128/256pt  |

### Column Calculation
- **iOS/Android**: Automatic based on screen width and thumbnail size
- **macOS**: Automatic with flow layout

### Scale Modes
All platforms support two display modes:
- **Fit**: Shows entire image with letterboxing (aspect fit)
- **Fill**: Crops to fill thumbnail area (aspect fill)

Implementation:
- **iOS**: `UIImageView.contentMode` (.scaleAspectFit/.scaleAspectFill)
- **Android**: `ContentScale.Fit`/`ContentScale.FillBounds`
- **macOS**: Custom `ScalableImageView` with scale modes

## Selection System

### Selection Behavior
- **iOS/macOS**: Always-active selection (tap to select/deselect)
- **Android**: Modal selection (long-press to enter, toolbar to exit)

### Visual Feedback
- **iOS**: 3pt blue border, rounded corners
- **Android**: 3dp blue border + 12% blue tint overlay
- **macOS**: 3pt accent color border, rounded corners

### Selection Controls
- **iOS/macOS**: Direct multi-selection support
- **Android**: Selection toolbar with counter and operations

## Tag System

### User Interface
- **iOS/macOS**: Inspector panel with tag section
- **Android**: Modal dialog (press T key)

### Storage
- **iOS/macOS**: JSON file with iCloud sync
- **Android**: Room database (local only)

### Keyboard Shortcuts
All platforms support number keys 1-7 for quick tag assignment:
- 1 = Red flag
- 2 = Orange flag
- 3 = Yellow flag
- 4 = Green flag
- 5 = Blue flag
- 6 = Purple flag
- 7 = Gray flag
- 0 = Clear all flags (macOS only)
- S = Toggle star (macOS only)

## Toolbar Design

### iOS (Limited Space)
- Consolidated gear menu containing:
  - Thumbnail size options
  - Scale mode toggle
  - Info bar visibility
- Separate refresh and inspector buttons

### Android
- Photo Viewer: Three-dot menu with scale mode
- Grid View: Options menu with thumbnail size and scale mode
- Material3 dropdown menus

### macOS (Ample Space)
- Individual toolbar buttons for each option
- Segmented control for thumbnail size
- Toggle buttons for display mode and info bar

## Navigation Patterns

### Folder Navigation
- **iOS**: NavigationStack with back button
- **Android**: Jetpack Navigation with back button
- **macOS**: Window-per-folder (no back button)

### Photo Sources
- **All platforms**: Local directories
- **iOS/macOS**: Apple Photos Library integration
- **All platforms**: S3 cloud browser

## Status Indicators

### Backup Status (Star Icon)
All platforms use consistent indicators in the info bar:
- ⭐ Yellow star = Backed up or queued for S3
- ❌ Red exclamation = Backup failed
- ☁️ Blue cloud = S3 photos

### Tag Indicators (Flag Icons)
Colored flags appear next to the star to show user-assigned tags.

## Platform-Specific Features

### macOS
- Multi-window support
- Menu bar integration
- Keyboard-driven navigation
- No welcome screen (direct to browser)

### iOS
- Touch-optimized interactions
- Swipe gestures
- Device rotation support
- Compact toolbar design

### Android
- Material Design 3
- System back button integration
- Touch-optimized with keyboard support
- Modal selection pattern

## Implementation Technologies

| Component | macOS | iOS | Android |
|-----------|-------|-----|---------|
| UI Framework | SwiftUI + AppKit | SwiftUI + UIKit | Jetpack Compose |
| Collection View | NSCollectionView | UICollectionView | LazyVerticalGrid |
| Navigation | WindowGroup | NavigationStack | NavController |
| State Management | @Observable | @Observable | ViewModel + StateFlow |
| Image Loading | NSImage | UIImage | Coil |
| Storage | SwiftData/JSON | SwiftData/JSON | Room Database |

## Design Philosophy

The implementations follow platform conventions while maintaining feature parity:
- **macOS**: Desktop-first with keyboard shortcuts and multi-window
- **iOS**: Touch-first with gesture support and space optimization
- **Android**: Material Design with modal interactions and clear affordances

Each platform respects its native design guidelines while providing the same core functionality.