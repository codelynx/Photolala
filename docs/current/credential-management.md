# Credential Management

This document describes how AWS credentials are securely managed in the Photolala project using the credential-code tool.

## Overview

Photolala uses encrypted credentials that are safe to commit to the repository. The credential-code tool encrypts sensitive credentials (AWS keys) at build time, and they are only decrypted at runtime within the app.

## Credential Files Location

### Source Credentials (NOT in repository)
- `/Users/kyoshikawa/Projects/Photolala/.credential-code/credentials.json`
- Contains plaintext AWS credentials
- Should NEVER be committed to the repository
- Each developer needs their own copy

### Encrypted Credentials (Safe to commit)
- **iOS/macOS**: `/apple/Photolala/Utilities/Credentials.swift`
- **Android**: `/android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt`
- Contains encrypted AWS credentials
- Safe to commit to repository
- Decrypted at runtime only

## Credential Structure

The `credentials.json` file should contain:
```json
{
  "credentials": {
    "AWS_ACCESS_KEY_ID": "AKIA...",
    "AWS_SECRET_ACCESS_KEY": "...",
    "AWS_DEFAULT_REGION": "us-east-1"
  }
}
```

## Generating New Credentials

When AWS credentials need to be updated:

### 1. Update the source credentials
```bash
# Edit the credentials file
vim .credential-code/credentials.json
```

### 2. Use the automated script (Recommended)
```bash
# Run the credential generation script
./scripts/generate-credentials.sh
```

This script will:
- Generate Swift credentials for iOS/macOS
- Generate Kotlin credentials for Android
- Copy files to the correct locations
- Fix Android package names automatically
- Clean up temporary files

### 3. Manual generation (Alternative method)
```bash
# Generate Swift credentials
cd /Users/kyoshikawa/Projects/Photolala
.credential-code-tool/.build/release/credential-code generate --language swift
cp Generated/Credentials.swift apple/Photolala/Utilities/

# Generate Kotlin credentials
.credential-code-tool/.build/release/credential-code generate --language kotlin
cp Generated/Credentials.kt android/app/src/main/java/com/electricwoods/photolala/utils/

# Fix the package name (credential-code generates with com.example.credentials)
# On macOS:
sed -i '' 's/package com.example.credentials/package com.electricwoods.photolala.utils/g' \
  android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt
```

### 4. Commit the encrypted files
```bash
git add apple/Photolala/Utilities/Credentials.swift
git add android/app/src/main/java/com/electricwoods/photolala/utils/Credentials.kt
git commit -m "Update encrypted AWS credentials"
```

## Security Notes

1. **Different Encryption Each Time**: The credential-code tool generates different encrypted data each time, even with the same input. This is a security feature using different encryption keys and nonces.

2. **Platform-Specific**: iOS and Android files will have different encrypted data but decrypt to the same credentials.

3. **Runtime Decryption**: Credentials are only decrypted when needed at runtime, minimizing exposure.

4. **No Plaintext in Memory**: The decryption process is designed to minimize how long plaintext credentials exist in memory.

## Credential Priority (iOS/macOS)

The iOS/macOS app loads credentials in this order:
1. **Keychain** - User's custom credentials (entered via Settings)
2. **Environment Variables** - For development/testing
3. **Encrypted Credentials** - Built-in fallback from Credentials.swift

## Building the credential-code Tool

If you need to rebuild the tool:
```bash
cd .credential-code-tool
swift build -c release
```

The binary will be at `.build/release/credential-code`

## Troubleshooting

### "No such module" error
- Ensure the Credentials.swift/kt file is added to the appropriate target in Xcode/Android Studio

### Wrong package name in Android
- The tool generates `package com.example.credentials` by default
- Must be changed to `package com.electricwoods.photolala.utils`

### Different credentials between platforms
- Check that both platforms were generated from the same credentials.json
- Remember that encrypted data will look different even with same source credentials

## Important Files

- `.credential-code/credentials.json` - Your AWS credentials (git-ignored)
- `.credential-code-tool/` - The credential encryption tool
- `apple/Photolala/Utilities/Credentials.swift` - iOS encrypted credentials
- `android/.../utils/Credentials.kt` - Android encrypted credentials
- `apple/Photolala/Services/KeychainManager.swift` - iOS credential management
- `android/.../services/AWSCredentialProvider.kt` - Android credential provider
- `scripts/generate-credentials.sh` - Automated credential generation script