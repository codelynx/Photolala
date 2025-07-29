# Build Commands

Complete reference for building Photolala on all platforms.

## Apple Platforms (iOS/macOS)

### Prerequisites
- Xcode 15.0 or later
- macOS 14.0 or later
- Development Team ID: 2P97EM4L4N

### Build Commands

```bash
# Navigate to Apple project
cd apple/

# Build for macOS
xcodebuild -scheme Photolala -destination 'platform=macOS' build

# Build for iOS Simulator
xcodebuild -scheme Photolala -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Build for iOS Device (requires provisioning)
xcodebuild -scheme Photolala -destination 'generic/platform=iOS' build

# Clean build
xcodebuild -scheme Photolala clean

# Run tests
xcodebuild -scheme Photolala test

# Archive for release
xcodebuild -scheme Photolala archive -archivePath build/Photolala.xcarchive
```

### Common Issues
- If build fails with signing errors, open Xcode and update signing settings
- For "scheme not found" errors, ensure you're in the `apple/` directory

## Android Platform

### Prerequisites
- Android Studio Arctic Fox or later
- JDK 11 or later
- Android SDK 33 or later
- Gradle 8.0 or later

### Build Commands

```bash
# Navigate to Android project
cd android/

# Build debug APK
./gradlew assembleDebug

# Build release APK
./gradlew assembleRelease

# Install on connected device/emulator
./gradlew installDebug

# Run tests
./gradlew test

# Run lint checks
./gradlew lint

# Clean build
./gradlew clean

# Build bundle for Play Store
./gradlew bundleRelease
```

### Build Variants
- `debug` - Development build with debugging enabled
- `release` - Production build with optimizations

### Output Locations
- Debug APK: `android/app/build/outputs/apk/debug/app-debug.apk`
- Release APK: `android/app/build/outputs/apk/release/app-release.apk`
- Bundle: `android/app/build/outputs/bundle/release/app-release.aab`

## CI/CD Commands

### GitHub Actions
```yaml
# iOS build
- name: Build iOS
  run: |
    cd apple
    xcodebuild -scheme Photolala \
      -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
      build

# Android build
- name: Build Android
  run: |
    cd android
    ./gradlew assembleDebug
```

### Local Testing
```bash
# Run all platform builds
./scripts/build-all.sh

# Validate builds
./scripts/validate-builds.sh
```

## Development Workflow

### Quick Iteration
```bash
# iOS/macOS: Use Xcode for fastest iteration
open apple/Photolala.xcodeproj

# Android: Use Android Studio
open -a "Android Studio" android/
```

### Command Line Development
```bash
# Watch for changes and rebuild (iOS)
cd apple && xcodebuild -scheme Photolala build | xcpretty

# Watch for changes and rebuild (Android)
cd android && ./gradlew build --continuous
```

## Troubleshooting

### iOS/macOS Build Issues
1. **Provisioning profile errors**: Update in Xcode > Signing & Capabilities
2. **Missing dependencies**: Run `cd apple && pod install` if using CocoaPods
3. **Clean build folder**: `rm -rf ~/Library/Developer/Xcode/DerivedData`

### Android Build Issues
1. **Gradle sync failed**: `./gradlew clean build --refresh-dependencies`
2. **SDK not found**: Set `ANDROID_HOME` environment variable
3. **Out of memory**: Add `org.gradle.jvmargs=-Xmx4g` to `gradle.properties`

## Release Builds

### iOS/macOS
1. Update version in `apple/Photolala.xcodeproj`
2. Archive in Xcode
3. Upload to App Store Connect

### Android
1. Update version in `android/app/build.gradle`
2. Generate signed bundle: `./gradlew bundleRelease`
3. Upload to Google Play Console

## Related Documentation
- [Development Setup](./setup/)
- [Testing Guide](./testing-guide.md)
- [Release Process](./release-process.md)