# Project Restructuring Plan for Multi-Platform Support

## Overview

This document details the plan for restructuring the Photolala project to support both Apple platforms (iOS/macOS) and Android, while maintaining a clean, organized codebase.

## Current Structure

```
Photolala/
├── Photolala/              # Swift sources
├── PhotolalaTests/         # Unit tests
├── PhotolalaUITests/       # UI tests
├── Photolala.xcodeproj     # Xcode project
├── Photos/                 # Sample photos
├── docs/                   # Documentation
├── scripts/                # Utility scripts
└── CLAUDE.md              # AI assistance guide
```

## Proposed Structure

```
Photolala/
├── apple/                  # All Apple platform code
│   ├── Photolala/         # Swift sources (moved)
│   ├── PhotolalaTests/    # Unit tests (moved)
│   ├── PhotolalaUITests/  # UI tests (moved)
│   ├── Photolala.xcodeproj # Xcode project (moved)
│   └── README.md          # Apple-specific instructions
│
├── android/               # All Android platform code
│   ├── app/              # Main application module
│   ├── core/             # Core business logic
│   ├── features/         # Feature modules
│   ├── gradle/           # Gradle configuration
│   ├── build.gradle.kts  # Root build file
│   ├── settings.gradle.kts
│   └── README.md         # Android-specific instructions
│
├── shared/                # Shared resources
│   ├── Photos/           # Sample photos (moved)
│   ├── icons/            # App icons for all platforms
│   ├── assets/           # Other shared assets
│   └── README.md         # Shared resources guide
│
├── docs/                  # Documentation (existing)
│   ├── README.md         # Documentation index
│   ├── current/          # Current implementation
│   │   ├── apple/        # Apple-specific docs
│   │   ├── android/      # Android-specific docs
│   │   └── shared/       # Cross-platform concepts
│   ├── planning/         # Planning documents
│   └── history/          # Historical documents
│
├── scripts/              # Build and utility scripts
│   ├── apple/           # Apple-specific scripts
│   │   ├── build.sh     # Build Apple platforms
│   │   └── fix-tabs.sh  # Fix indentation (moved)
│   ├── android/         # Android-specific scripts
│   │   ├── build.sh     # Build Android app
│   │   └── release.sh   # Create release APK
│   └── common/          # Cross-platform scripts
│       ├── setup.sh     # Setup development environment
│       └── clean.sh     # Clean all build artifacts
│
├── .github/              # GitHub configuration
│   └── workflows/        # CI/CD workflows
│       ├── apple.yml     # Apple platforms CI
│       ├── android.yml   # Android CI
│       └── docs.yml      # Documentation checks
│
├── README.md             # Project overview
├── CLAUDE.md            # AI assistance guide (updated)
├── LICENSE              # License file
└── .gitignore           # Git ignore (updated)
```

## Migration Steps

### Phase 1: Prepare Structure (No Breaking Changes)
1. Create new directories:
   ```bash
   mkdir -p apple android shared/assets shared/icons
   mkdir -p scripts/apple scripts/android scripts/common
   mkdir -p docs/current/apple docs/current/android docs/current/shared
   ```

2. Create platform-specific README files
3. Update documentation structure

### Phase 2: Move Apple Code
1. Git move Apple-specific files:
   ```bash
   git mv Photolala apple/
   git mv PhotolalaTests apple/
   git mv PhotolalaUITests apple/
   git mv Photolala.xcodeproj apple/
   git mv scripts/fix-tabs.sh scripts/apple/
   ```

2. Update Xcode project paths
3. Test build still works

### Phase 3: Move Shared Resources
1. Git move shared resources:
   ```bash
   git mv Photos shared/
   ```

2. Update Xcode project to reference new Photos location
3. Extract app icons to shared/icons

### Phase 4: Update Configuration
1. Update .gitignore for both platforms
2. Update CLAUDE.md with new structure
3. Update root README.md
4. Create platform-specific build scripts

### Phase 5: Add Android Project
1. Create Android project structure
2. Set up Gradle configuration
3. Add basic MainActivity
4. Configure for Photos access

## Benefits of This Structure

### 1. Clear Separation
- Platform-specific code is isolated
- Shared resources are centralized
- Easy to navigate and understand

### 2. Parallel Development
- iOS and Android teams can work independently
- No merge conflicts between platforms
- Clear ownership boundaries

### 3. CI/CD Friendly
- Separate workflows for each platform
- Can build/test platforms independently
- Easier to set up platform-specific tools

### 4. Scalability
- Easy to add more platforms (e.g., Web, Windows)
- Modular structure supports growth
- Clean dependency management

## Considerations

### 1. Xcode Project Updates
- Need to update all file references
- Update build settings for new paths
- Test all targets still build correctly

### 2. Git History
- Using `git mv` preserves history
- Create clear commit messages
- Tag current version before restructuring

### 3. Development Workflow
- Developers need to navigate to platform directories
- Update documentation for new structure
- Provide clear setup instructions

### 4. Shared Code Strategy
- Currently no shared code between platforms
- Could explore Kotlin Multiplatform in future
- Keep door open for code sharing

## Implementation Checklist

- [ ] Create directory structure
- [ ] Write platform-specific READMEs
- [ ] Move Apple code to apple/ directory
- [ ] Move shared resources to shared/
- [ ] Update Xcode project references
- [ ] Update build scripts
- [ ] Update CI/CD workflows
- [ ] Update root documentation
- [ ] Test Apple platforms still build
- [ ] Create initial Android project
- [ ] Update CLAUDE.md
- [ ] Tag release before restructuring
- [ ] Announce changes to team

## Alternative Approaches Considered

### 1. Monorepo Tools
- **Nx**: Powerful but complex for this project size
- **Lerna**: More for JavaScript/TypeScript
- **Bazel**: Too heavy for current needs

### 2. Keep Flat Structure
- **Pros**: Simpler, no migration needed
- **Cons**: Will become messy with Android code mixed in

### 3. Separate Repositories
- **Pros**: Complete isolation
- **Cons**: Harder to share resources, more overhead

## Conclusion

The proposed structure provides a clean separation between platforms while keeping everything in a single repository. This approach balances organization with simplicity and sets up the project for long-term maintainability.