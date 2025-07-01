# Photolala for Android

This directory contains the Photolala implementation for Android.

## Structure

```
android/
├── app/                    # Main application module
│   ├── src/main/          # Main source set
│   │   ├── java/          # Kotlin source files
│   │   └── res/           # Resources (layouts, strings, etc.)
│   └── build.gradle.kts   # App module build configuration
├── gradle/                 # Gradle wrapper and configuration
├── build.gradle.kts        # Root build configuration
└── settings.gradle.kts     # Project settings
```

Note: The project currently uses a single-module structure. Multi-module architecture (core/, features/) may be added in future iterations.

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

- Android Studio Ladybug (2024.2.1) or newer
- JDK 17
- Android SDK 36
- Kotlin 2.0.21

## Device Requirements

- Minimum SDK: 33 (Android 13)
- Target SDK: 36 (Android 14+)

See the main project README for more information.