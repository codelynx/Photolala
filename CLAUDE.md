# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Photolala is a cross-platform photo browser application similar to Adobe Bridge, supporting macOS, iOS, and Android. It uses a window-per-folder architecture where each window displays photos from a single folder. The app provides efficient browsing of large photo collections with thumbnail generation, metadata management, and multi-selection capabilities.

## Build Commands

Build commands for different platforms:

### Apple Platforms

```bash
# Build for macOS
cd apple && xcodebuild -scheme Photolala -destination 'platform=macOS' build

# Build for iOS Simulator
cd apple && xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Clean build
cd apple && xcodebuild -scheme Photolala clean

# Run tests
cd apple && xcodebuild -scheme Photolala test

# Or navigate first:
cd apple/
xcodebuild -scheme Photolala -destination 'platform=macOS' build
```

### Android Platform

```bash
# Build debug APK
cd android && ./gradlew assembleDebug

# Build release APK
cd android && ./gradlew assembleRelease

# Install on connected device/emulator
cd android && ./gradlew installDebug

# Run tests
cd android && ./gradlew test

# Clean build
cd android && ./gradlew clean

# Or navigate first:
cd android/
./gradlew assembleDebug
```

## Project Structure

```
Photolala/
├── apple/                  # Apple platform code (iOS/macOS)
│   ├── Photolala/         # Main app target
│   │   ├── Models/        # Data models
│   │   ├── Views/         # SwiftUI views
│   │   ├── Services/      # Business logic
│   │   ├── Utilities/     # Helper utilities
│   │   ├── Commands/      # Menu commands
│   │   └── PhotolalaApp.swift
│   ├── photolalaTests/    # Unit tests
│   ├── photolalaUITests/  # UI tests
│   └── Photolala.xcodeproj
├── android/               # Android platform code
├── shared/                # Shared resources
│   ├── TestPhotos/        # Sample photos
│   ├── icons/             # App icons for all platforms
│   └── assets/            # Other shared assets
├── docs/                  # Documentation
├── scripts/               # Utility scripts
│   ├── apple/             # Apple-specific scripts
│   ├── android/           # Android-specific scripts
│   └── common/            # Cross-platform scripts
└── services/              # Backend services
```

## Development Notes

- Development Team ID: 2P97EM4L4N
- Bundle ID: com.electricwoods.photolala
- Supported platforms: macOS 14.0+, iOS 18.5+, Android 13+
- Architecture: SwiftUI (Apple), Jetpack Compose (Android)
- **App Status**: Pre-release (no migration needed for breaking changes)
- Key features implemented:
  - Window-per-folder architecture (each window shows one folder)
  - Menu-driven folder selection on macOS (⌘O)
  - Apple Photos Library browser (Window → Apple Photos Library, ⌘⌥L)
  - Cloud browser for S3 storage (Window → Cloud Browser, ⌘⌥B)
  - NavigationStack for folder hierarchy navigation
  - Native collection views (NSCollectionView/UICollectionView)
  - Star-based backup queue system (supports both local and Apple Photos)
  - 1-minute backup timer (was 5 minutes, now aligned across platforms)
  - Platform-specific navigation patterns
  - No welcome screen on macOS (opens directly to browser)
  - Multi-window support on macOS
  - Bundle resource support (Photos folder reference)
  - Unified photo browser architecture supporting multiple sources
  - Bookmark feature with emoji marking (❤️ 👍 👎 ✏️ 🗑️ 📤 🖨️ ✅ 🔴 📌 💡)
  - MD5-based photo identification for bookmarks
  - Multi-provider authentication (Apple ID and Google)
  - Account linking across providers with S3 identity mapping
  - Cross-platform account settings UI
  - Catalog.json support for Android (CSV format matching iOS)

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

### Android
- Welcome screen with sign-in status
- Account Settings accessible when signed in
- Jetpack Navigation for navigation flow
- Material3 design system
- Touch-optimized interactions
- Deep link handling for Apple Sign-In callbacks

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

### Review Changes Process
When asked to "review changes", this means:
1. Review the implementation and summarize what was done
2. Update PROJECT_STATUS.md with recent changes
3. Update or create relevant documentation in `docs/`
4. Ensure planning documents reflect the final implementation
5. Commit any documentation updates along with the review

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

# For iOS/macOS:
.credential-code-tool/.build/release/credential-code generate --language swift
mv Generated/Credentials.swift apple/Photolala/Utilities/

# For Android:
.credential-code-tool/.build/release/credential-code generate --language kotlin
mv Generated/Credentials.kt android/app/src/main/java/com/electricwoods/photolala/utils/

# Or use the convenience script:
./scripts/generate-credentials.sh
```

## Pricing Strategy

The project uses an ultra-aggressive pricing model leveraging AWS Glacier Deep Archive. All photos automatically archive after 14 days while thumbnails remain instantly accessible. This enables pricing 85-90% below competitors.

For detailed pricing strategy and tiers, see: `docs/planning/final-pricing-strategy-v3.md`

## Memories

- 1, question is semi-real user id or sphedo user id?

## Google Cloud Project Configuration

### Apple Platforms OAuth Setup (Completed: Feb 3, 2025)
- **Project Created**: `Photolala` (unified project) under kyoshikawa@electricwoods.com
- **OAuth Configuration**:
  - Web Client ID: `75309194504-p2sfktq2ju97ataogb1e5fkl70cj2jg3.apps.googleusercontent.com` (for server-side verification)
  - iOS Client ID: `75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv.apps.googleusercontent.com` (used for both iOS and macOS)
  - Redirect URI: `com.googleusercontent.apps.75309194504-g1a4hr3pc68301vuh21tibauh9ar1nkv:/oauth2redirect`
- **Implementation Details**:
  - iOS: Uses Google Sign-In SDK with ASWebAuthenticationSession fallback
  - macOS: Uses direct browser OAuth flow (ASWebAuthenticationSession has reliability issues on macOS)
  - Configuration is centralized in `GoogleOAuthConfiguration` struct
- **Note**: The iOS client ID works better with ASWebAuthenticationSession on macOS than the Desktop client type

### Android OAuth Setup (Updated: Feb 4, 2025)
- **Project**: Uses the same unified `Photolala` project as Apple platforms
- **OAuth Configuration**:
  - Web Client ID: `75309194504-p2sfktq2ju97ataogb1e5fkl70cj2jg3.apps.googleusercontent.com` (same as Apple platforms)
  - Android Client ID: `75309194504-imt63lddcdanccn2e2dsvdfbq5id9rn2.apps.googleusercontent.com`
  - Package name: `com.electricwoods.photolala` (no debug suffix)
  - SHA-1 fingerprint: `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89`
- **API Keys**:
  - Current API key: `AIzaSyAMbZ_Y8_0jENZachFsJQBrBfmYuGAb3Uk`
- **Implementation**: Uses Google Sign-In SDK with google-services.json configuration
- **Important**: Google Photos Library API support was removed (March 31, 2025 restrictions)

