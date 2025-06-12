# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photolala is a cross-platform photo browser application similar to Adobe Bridge, supporting macOS, iOS, and tvOS. It uses a window-per-folder architecture where each window displays photos from a single folder. The app provides efficient browsing of large photo collections with thumbnail generation, metadata management, and multi-selection capabilities.

## Build Commands

Build commands for different platforms:

```bash
# Build for macOS
xcodebuild -scheme photolala -destination 'platform=macOS' build

# Build for iOS Simulator
xcodebuild -scheme photolala -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Build for tvOS Simulator  
xcodebuild -scheme photolala -destination 'platform=tvOS Simulator,name=Apple TV' build

# Clean build
xcodebuild -scheme photolala clean

# Run tests
xcodebuild -scheme photolala test
```

## Project Structure

```
Photolala/
├── photolala/              # Main app target
│   ├── Models/            # Data models (PhotoRepresentation, Directory)
│   ├── Views/             # SwiftUI views
│   ├── ViewModels/        # Observable view models
│   ├── Services/          # Business logic
│   ├── Utilities/         # Helper utilities (XPlatform, BundlePhotosHelper)
│   ├── Commands/          # Menu commands (PhotolalaCommands)
│   └── PhotolalaApp.swift # App entry point
├── photolalaTests/        # Unit tests
├── photolalaUITests/      # UI tests
├── Photos/                # Sample photos (folder reference)
├── docs/                  # Design documents and implementation notes
├── scripts/               # Utility scripts
└── .swiftformat          # Swift formatting rules
```

## Development Notes

- Development Team ID: 2P97EM4L4N
- Bundle ID: com.electricwoods.photolala
- Supported platforms: macOS 14.0+, iOS 18.5+, tvOS 18.0+
- Architecture: SwiftUI (no SwiftData for core functionality)
- Key features implemented:
  - Window-per-folder architecture (each window shows one folder)
  - Menu-driven folder selection on macOS (⌘O)
  - NavigationStack for folder hierarchy navigation
  - Native collection views (NSCollectionView/UICollectionView)
  - Platform-specific navigation patterns
  - No welcome screen on macOS (opens directly to browser)
  - Multi-window support on macOS
  - Bundle resource support (Photos folder reference)

## Navigation Architecture

### macOS
- Opens directly to photo browser (no welcome screen)
- File → Open Folder... (⌘O) for folder selection
- Each folder opens in its own window
- NavigationStack within each window for subfolder navigation

### iOS/iPadOS
- Welcome screen for initial folder selection
- Single NavigationStack for all navigation
- Touch-optimized interactions

## Development Process

Before implementing major features:
1. Create documentation in the `docs/` directory describing what will be implemented
2. Review and discuss the design
3. Wait for approval before proceeding with coding
4. Only start implementation after the documentation is approved

## Code Style

- **Indentation**: Use tabs (not spaces) with tab width of 4
- **Line endings**: LF (Unix style)
- **Trailing whitespace**: Remove
- **Final newline**: Always include
- Configuration files: `.editorconfig`, `.swiftformat`, `.vscode/settings.json`

### Fixing Indentation

If files get converted to spaces, run:
```bash
./scripts/fix-tabs.sh
```

### Xcode Settings
- Xcode → Settings → Text Editing → Indentation
- Check "Prefer indent using: Tabs"
- Set "Tab width" and "Indent width" to 4