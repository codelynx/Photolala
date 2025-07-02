# Photolala Scripts

This directory contains utility scripts for the Photolala project.

## generate-credentials.sh

Generates encrypted AWS credentials for both iOS and Android platforms from the source credentials file.

### Usage
```bash
./scripts/generate-credentials.sh
```

### What it does:
1. Reads AWS credentials from `.credential-code/credentials.json`
2. Generates encrypted Swift code for iOS/macOS
3. Generates encrypted Kotlin code for Android
4. Copies the files to their proper locations:
   - iOS: `apple/Photolala/Utilities/Credentials.swift`
   - Android: `android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt`
5. Fixes the Android package name (from `com.example.credentials` to `com.electricwoods.photolala.utils`)
6. Cleans up temporary files

### Prerequisites:
- `.credential-code/credentials.json` must exist with your AWS credentials
- Swift must be installed (for building credential-code tool)

### Security Notes:
- The generated files contain encrypted credentials and are safe to commit
- Never commit `.credential-code/credentials.json` (plaintext credentials)
- Each generation creates different encrypted data (even with same input)

### When to run:
- When AWS credentials change
- When setting up a new development environment
- After updating the credential-code tool

## Other Scripts

### fix-tabs.sh
Fixes indentation in source files (converts spaces to tabs).

### download-and-push-photos.sh (Android)
Downloads sample photos and pushes them to Android emulator for testing.

### delete-photos.sh (Android)
Helper script to delete photos from Android device (for development testing).