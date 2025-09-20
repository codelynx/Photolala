# Photolala (apple-x)

This is the reworked version of Photolala for Apple platforms (macOS, iOS, iPadOS, visionOS).

## Project Structure

```
apple-x/
├── Photolala.xcodeproj        # Xcode project file
├── Photolala/                 # Main app source code
│   ├── PhotolalaApp.swift     # App entry point
│   ├── Info.plist             # App configuration
│   ├── Photolala.entitlements # App entitlements
│   ├── Assets.xcassets/       # Images and colors
│   ├── Views/                 # SwiftUI views with nested models
│   │   └── ContentView.swift
│   ├── Models/                # Data models
│   ├── Services/              # Business logic and API services
│   ├── Utilities/             # Helper classes and functions
│   ├── Extensions/            # Swift extensions
│   ├── Commands/              # Menu commands (macOS)
│   ├── Protocols/             # Protocol definitions
│   └── Resources/             # Other resources (JSON, etc.)
└── docs/                      # Documentation
    └── catalog-system.md

```

## Build Instructions

### macOS
```bash
xcodebuild -scheme Photolala -destination 'platform=macOS' build
```

### iOS Simulator
```bash
xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## Architecture

This project uses a simplified MVVM pattern with nested view models to keep related code together:

```swift
struct SomeView: View {
    @State private var model = Model()

    var body: some View {
        // View implementation
    }
}

extension SomeView {
    @Observable
    final class Model {
        // View model implementation
    }
}
```

This approach:
- Keeps view and view model code together in the same file
- Reduces file navigation and cognitive overhead
- Makes the codebase simpler and more maintainable
- Uses Swift's nested types for better organization

## Requirements

- Xcode 16.0+
- macOS 14.0+
- iOS 18.0+
- visionOS 2.0+

## Development Team

- Team ID: 2P97EM4L4N
- Bundle ID: com.electricwoods.photolala