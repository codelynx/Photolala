# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Structure

This is Photolala v2, a photo management application for Apple platforms. The codebase is organized as:
- `/apple/` - Apple platform implementation (macOS, iOS, iPadOS, visionOS)
- `/docs/` - Architecture documentation

## Build Commands

### macOS
```bash
xcodebuild -scheme Photolala -destination 'platform=macOS' build
```

### iOS Simulator
```bash
xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### Run Tests
```bash
xcodebuild -scheme Photolala -destination 'platform=macOS' test
```

### Generate/Update Credentials
```bash
# After adding or updating credentials in .credentials/
./scripts/generate-credentials.sh
```

## Architecture

### MVVM with Nested View Models
Views and their models are co-located in the same file using Swift's nested types:

```swift
struct SomeView: View {
    @State private var model = Model()
    var body: some View { /* ... */ }
}

extension SomeView {
    @Observable
    final class Model { /* ... */ }
}
```

### Photolala Directory Catalog System
The app uses a sophisticated catalog system for managing 100K+ images:
- **Fast Photo Key**: `{photo-head-md5}:{file-size}` for quick identity
- **Immutable Catalogs**: SQLite snapshots stored as `.photolala.{catalog-md5}.sqlite`
- **Sharded Caches**: Thumbnails and metadata organized by MD5 prefix
- **Multi-tier Storage**: Local, Apple Photos, and S3 backed storage

Key paths:
- Catalog: `{directory}/.photolala.{catalog-md5}.sqlite`
- Pointer: `{directory}/.photolala.md5`
- Thumbnails: `{cache-root}/{source}/thumbnails/{prefix}/{photo-md5}.jpg`

### AWS Integration
The app integrates with AWS services (S3, Lambda, Athena) for cloud storage and processing. Environment-specific buckets:
- Development: `photolala-dev`
- Staging: `photolala-stage`
- Production: `photolala-prod`

Environment selection is handled in-app via UserDefaults (iOS/macOS), not through external config files. All environment credentials are embedded in the binary using credential-code encryption.

### Project Configuration
- Team ID: 2P97EM4L4N
- Bundle ID: com.electricwoods.photolala
- Minimum Deployment: macOS 14.0+, iOS 18.0+, visionOS 2.0+
- Xcode 16.0+ required

### Credential Management
- All credentials stored in `.credentials/` directory (gitignored)
- Encrypted using credential-code tool into `Credentials.swift`
- All environments (dev/stage/prod) embedded in single binary
- Environment selection via UserDefaults in-app (no external config)
- Production builds locked to production environment
- See `docs/security.md` and `docs/credential-security.md` for details