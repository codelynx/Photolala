# Google Sign-In Setup for iOS/macOS

## Overview
This document outlines the steps to implement Google Sign-In for Photolala on iOS and macOS platforms.

## Prerequisites

1. **Google Cloud Console Access**
   - Project: `photolala` (Project ID: photolala)
   - Project Number: 105828093997
   - Existing OAuth clients for Android

2. **Apple Developer Account**
   - Bundle IDs registered:
     - iOS: `com.electricwoods.photolala`
     - macOS: `com.electricwoods.photolala`

## Implementation Steps

### 1. Add Google Sign-In SDK

Add Google Sign-In SDK to the Xcode project via Swift Package Manager:

1. In Xcode, go to File → Add Package Dependencies
2. Add package URL: `https://github.com/google/GoogleSignIn-iOS`
3. Select version: Latest stable (currently 7.1.0)
4. Add to targets: Photolala (iOS) and Photolala (macOS)

### 2. Create OAuth Clients in Google Cloud Console

#### For iOS:
1. Go to [Google Cloud Console](https://console.cloud.google.com/) → Project: photolala
2. APIs & Services → Credentials → Create Credentials → OAuth client ID
3. Application type: iOS
4. Name: "Photolala iOS"
5. Bundle ID: `com.electricwoods.photolala`
6. Create and note the Client ID

#### For macOS:
1. Create another OAuth client
2. Application type: iOS (yes, iOS type for macOS too)
3. Name: "Photolala macOS"
4. Bundle ID: `com.electricwoods.photolala`
5. Create and note the Client ID

### 3. Configure Info.plist

Add the following to Info.plist for both iOS and macOS targets:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Reversed client ID for iOS/macOS -->
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>

<!-- iOS 9+ -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>googlechrome</string>
    <string>googlechrome-x-callback</string>
</array>
```

### 4. Update OAuth Configuration

The Web Client ID from the existing configuration will be reused:
- Web Client ID: `105828093997-qmr9jdj3h4ia0tt2772cnrejh4k0p609.apps.googleusercontent.com`

### 5. Implementation Files

Create/update the following files:

1. **GoogleAuthProvider.swift** - Main authentication service
2. **IdentityManager+Authentication.swift** - Update to support Google
3. **AuthenticationChoiceView.swift** - Remove placeholder, add real implementation
4. **PhotolalaApp.swift** - Handle Google Sign-In URL callbacks

### 6. Testing

1. **iOS Simulator**: Test with different iOS versions
2. **macOS**: Test native macOS app
3. **Cross-platform**: Verify accounts work across iOS/macOS/Android

## Security Considerations

1. The OAuth client IDs are safe to hardcode (they're public)
2. Use Keychain for token storage (already implemented)
3. Handle all error cases appropriately

## Error Handling

Common issues and solutions:
- **Invalid client ID**: Verify the client ID matches the bundle ID
- **URL scheme issues**: Ensure Info.plist is correctly configured
- **Network errors**: Implement proper retry logic

## Next Steps

1. Install Google Sign-In SDK
2. Create OAuth clients for iOS/macOS
3. Implement GoogleAuthProvider
4. Update UI to handle Google Sign-In
5. Test on all platforms