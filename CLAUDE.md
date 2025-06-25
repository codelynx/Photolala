# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photolala is a cross-platform photo browser application similar to Adobe Bridge, supporting macOS, iOS, and tvOS. It uses a window-per-folder architecture where each window displays photos from a single folder. The app provides efficient browsing of large photo collections with thumbnail generation, metadata management, and multi-selection capabilities.

## Build Commands

Build commands for different platforms:

```bash
# Build for macOS
xcodebuild -scheme Photolala -destination 'platform=macOS' build

# Build for iOS Simulator
xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Build for tvOS Simulator  
xcodebuild -scheme Photolala -destination 'platform=tvOS Simulator,name=Apple TV' build

# Clean build
xcodebuild -scheme Photolala clean

# Run tests
xcodebuild -scheme Photolala test
```

## Project Structure

```
Photolala/
├── Photolala/              # Main app target
│   ├── Models/            # Data models (PhotoReference, Directory, PhotoBookmark)
│   ├── Views/             # SwiftUI views
│   ├── ViewModels/        # Observable view models
│   ├── Services/          # Business logic (PhotoManager, BookmarkManager)
│   ├── Utilities/         # Helper utilities (XPlatform, BundlePhotosHelper)
│   ├── Commands/          # Menu commands (PhotolalaCommands)
│   └── PhotolalaApp.swift # App entry point
├── PhotolalaTests/        # Unit tests
├── PhotolalaUITests/      # UI tests
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
- **App Status**: Pre-release (no migration needed for breaking changes)
- Key features implemented:
  - Window-per-folder architecture (each window shows one folder)
  - Menu-driven folder selection on macOS (⌘O)
  - Apple Photos Library browser (Window → Apple Photos Library, ⌘⌥L)
  - Cloud browser for S3 storage (Window → Cloud Browser, ⌘⌥B)
  - NavigationStack for folder hierarchy navigation
  - Native collection views (NSCollectionView/UICollectionView)
  - Star-based backup queue system (supports both local and Apple Photos)
  - Platform-specific navigation patterns
  - No welcome screen on macOS (opens directly to browser)
  - Multi-window support on macOS
  - Bundle resource support (Photos folder reference)
  - Unified photo browser architecture supporting multiple sources
  - Bookmark feature with emoji marking (❤️ 👍 👎 ✏️ 🗑️ 📤 🖨️ ✅ 🔴 📌 💡)
  - MD5-based photo identification for bookmarks

## Navigation Architecture

### macOS
- Opens directly to photo browser (no welcome screen)
- File → Open Folder... (⌘O) for folder selection
- Window → Apple Photos Library (⌘⌥L) for Photos app browsing
- Window → Cloud Browser (⌘⌥B) for S3 cloud storage
- Each source opens in its own window
- NavigationStack within each window for navigation

### iOS/iPadOS
- Welcome screen for initial folder selection
- Single NavigationStack for all navigation
- Touch-optimized interactions

## Documentation Structure

The `docs/` directory is organized as follows:

```
docs/
├── README.md                    # Documentation overview and navigation
├── PROJECT_STATUS.md           # Current implementation status
│
├── current/                    # Current architecture and implementation
│   ├── architecture.md         # System architecture overview
│   ├── navigation-flow.md      # Navigation patterns
│   ├── thumbnail-system.md     # Thumbnail generation and caching
│   └── selection-system.md     # Selection management
│
├── history/                    # Historical documents
│   ├── design-decisions/       # Original design documents
│   └── implementation-notes/   # Implementation journey
│
└── planning/                   # Future features and roadmap
```

## Development Process

Before implementing major features:
1. Create documentation in `docs/planning/` describing what will be implemented
2. Review and discuss the design
3. Wait for approval before proceeding with coding
4. After implementation, move docs to `history/` and update `current/`
5. Update PROJECT_STATUS.md with implementation details

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

## AWS Credential Management

The project uses credential-code for secure AWS credential management:

1. **Encrypted Credentials**: AWS credentials are encrypted and built into the app using credential-code
2. **Credential Loading Priority**:
   - Keychain (user's custom credentials)
   - Environment variables (development)
   - Encrypted credentials (built-in fallback)

To update AWS credentials:
```bash
# Edit credentials
vim .credential-code/credentials.json

# Regenerate encrypted file
.credential-code-tool/.build/release/credential-code generate --language swift

# Move to project
mv Generated/Credentials.swift Photolala/Utilities/
```

## Memories

- 1, question is semi-real user id or sphedo user id?