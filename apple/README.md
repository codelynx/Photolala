# Photolala for Apple Platforms

This directory contains the Photolala implementation for Apple platforms (iOS, macOS, tvOS).

## Structure

```
apple/
├── Photolala/              # Swift source files
├── PhotolalaTests/         # Unit tests
├── PhotolalaUITests/       # UI tests
└── Photolala.xcodeproj     # Xcode project file
```

## Building

### macOS
```bash
xcodebuild -scheme Photolala -destination 'platform=macOS' build
```

### iOS Simulator
```bash
xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### tvOS Simulator
```bash
xcodebuild -scheme Photolala -destination 'platform=tvOS Simulator,name=Apple TV' build
```

## Development

1. Open `Photolala.xcodeproj` in Xcode
2. Select your target platform
3. Build and run (⌘R)

## Requirements

- Xcode 15.0+
- macOS 14.0+ (for development)
- Swift 5.9+

## Platform Requirements

- macOS 14.0+
- iOS 18.5+
- tvOS 18.0+

See the main project README for more information.