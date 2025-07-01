# Photolala for Android

This directory contains the Photolala implementation for Android.

## Structure

```
android/
├── app/                    # Main application module
├── core/                   # Core business logic and shared code
├── features/               # Feature modules
├── gradle/                 # Gradle wrapper and configuration
├── build.gradle.kts        # Root build configuration
└── settings.gradle.kts     # Project settings
```

## Building

### Debug Build
```bash
./gradlew assembleDebug
```

### Release Build
```bash
./gradlew assembleRelease
```

### Run Tests
```bash
./gradlew test
```

### Install on Device
```bash
./gradlew installDebug
```

## Development

1. Open the `android/` directory in Android Studio
2. Sync project with Gradle files
3. Run the app on emulator or device

## Requirements

- Android Studio Hedgehog (2023.1.1) or newer
- JDK 17
- Android SDK 34
- Kotlin 1.9.0+

## Device Requirements

- Minimum SDK: 24 (Android 7.0)
- Target SDK: 34 (Android 14)

See the main project README for more information.