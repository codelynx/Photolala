# Android Platform Planning

## Overview

This document outlines the plan for adding Android support to Photolala, creating a native Android photo browser application that maintains feature parity with the existing iOS/macOS versions while embracing Android platform conventions.

## Project Structure

### Repository Organization

```
Photolala/
├── apple/                      # Renamed from current root (iOS/macOS)
│   ├── Photolala/             # Swift sources
│   ├── PhotolalaTests/
│   └── Photolala.xcodeproj
│
├── android/                    # Android project root
│   ├── app/                   # Main application module
│   │   ├── src/
│   │   │   ├── main/
│   │   │   │   ├── java/com/electricwoods/photolala/
│   │   │   │   ├── res/       # Resources (layouts, strings, etc.)
│   │   │   │   └── AndroidManifest.xml
│   │   │   ├── test/          # Unit tests
│   │   │   └── androidTest/   # Instrumented tests
│   │   └── build.gradle.kts
│   │
│   ├── core/                  # Core business logic module
│   │   ├── data/              # Data layer
│   │   ├── domain/            # Domain models
│   │   └── ui/                # Shared UI utilities
│   │
│   ├── features/              # Feature modules
│   │   ├── browser/           # Photo browser feature
│   │   ├── cloudphotos/       # Cloud photo support
│   │   └── localphotos/       # Local photo access
│   │
│   ├── gradle/                # Gradle configuration
│   ├── build.gradle.kts       # Root build file
│   └── settings.gradle.kts
│
├── shared/                     # Shared resources/assets
│   ├── Photos/                # Sample photos
│   └── icons/                 # App icons for all platforms
│
├── docs/                       # Documentation (existing)
├── scripts/                    # Build and utility scripts
│   ├── build-all.sh           # Build all platforms
│   ├── build-android.sh       # Android-specific build
│   └── build-apple.sh         # Apple platforms build
│
└── README.md                   # Updated with Android instructions
```

### Android Module Structure

#### App Module (`android/app/`)
- Application class and initialization
- MainActivity and navigation setup
- Dependency injection configuration
- Platform-specific implementations

#### Core Module (`android/core/`)
- **data/**: Repositories, data sources, database
- **domain/**: Use cases, business logic
- **ui/**: Common UI components, themes

#### Feature Modules (`android/features/`)
- **browser/**: Main photo browsing UI
- **cloudphotos/**: AWS S3 integration
- **localphotos/**: MediaStore integration

## Technology Stack

### Core Technologies
- **Language**: Kotlin
- **Minimum SDK**: 24 (Android 7.0) - covers 98%+ of devices
- **Target SDK**: 34 (Android 14)
- **UI Framework**: Jetpack Compose
- **Architecture**: MVVM with Clean Architecture

### Key Libraries
- **Compose**: Modern declarative UI
- **Navigation Compose**: Navigation between screens
- **Coil**: Image loading and caching
- **Room**: Local database for metadata
- **WorkManager**: Background tasks
- **CameraX**: Camera integration
- **ExoPlayer**: Video playback
- **AWS SDK**: S3 integration

## Documentation Structure

```
docs/
├── planning/
│   ├── android-platform.md           # This document
│   ├── android-architecture.md       # Detailed architecture design
│   ├── android-ui-design.md         # UI/UX specifications
│   └── android-feature-parity.md    # Feature comparison matrix
│
└── current/                          # After implementation
    ├── android/
    │   ├── architecture.md
    │   ├── navigation-flow.md
    │   ├── photo-access.md
    │   └── testing-strategy.md
    └── cross-platform/
        └── shared-concepts.md
```

## Implementation Phases

### Phase 1: Foundation (Weeks 1-3)
- Set up Android project structure
- Implement basic navigation
- Create photo grid UI with Compose
- Local photo access with MediaStore
- Photo detail view

### Phase 2: Account & Payments (Weeks 4-6)
- User authentication system
- Account management UI
- Google Play Billing integration
- Subscription management

### Phase 3: Cloud Features (Weeks 7-9)
- AWS S3 integration
- Photo backup service
- Background uploads with WorkManager
- Progress tracking

### Phase 4: Polish & Release (Weeks 10-12)
- Performance optimization
- UI polish and animations
- Testing and bug fixes
- Play Store preparation

## Key Design Decisions

### Native Android Approach
- Pure Kotlin implementation (no Flutter/React Native)
- Leverages Android platform capabilities
- Better performance and platform integration
- Consistent with Material Design guidelines

### Modular Architecture
- Feature modules for better organization
- Easier parallel development
- Improved build times
- Better testability

### Compose-First UI
- Modern declarative UI framework
- Better state management
- Easier to maintain
- Native performance

## Next Steps

1. Review and approve this planning document
2. Create detailed architecture design
3. Design UI mockups following Material Design 3
4. Set up initial Android project structure
5. Begin Phase 1 implementation

## Questions to Resolve

1. Should we share any code between iOS and Android (e.g., using Kotlin Multiplatform)?
2. What cloud storage providers beyond S3 should we support?
3. Should we support Android tablets and Chrome OS?
4. What's the minimum Android version we should support?
5. Should we integrate with Google Photos API?