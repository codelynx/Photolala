# Google Sign-In Setup for Photolala Android

## Current Configuration (Updated: Feb 4, 2025)

Photolala Android uses the unified Google Cloud project shared with iOS/macOS:

- **Project Name**: `Photolala` (project ID: photolala)
- **Project Number**: `75309194504`
- **Web Client ID**: `75309194504-p2sfktq2ju97ataogb1e5fkl70cj2jg3.apps.googleusercontent.com`
- **Android Client ID**: `75309194504-imt63lddcdanccn2e2dsvdfbq5id9rn2.apps.googleusercontent.com`
- **Package Name**: `com.electricwoods.photolala`
- **SHA-1**: `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89`
- **API Key**: `AIzaSyAMbZ_Y8_0jENZachFsJQBrBfmYuGAb3Uk`

## Prerequisites

1. **Google Cloud Console Access**
   - Go to https://console.cloud.google.com/
   - Select the `Photolala` project

2. **Firebase Console** (for google-services.json)
   - Go to https://console.firebase.google.com/
   - Use the same `Photolala` project

## Setup Steps

### 1. Configure OAuth 2.0 Client

#### In Google Cloud Console:
1. Go to APIs & Services → Credentials
2. The Android OAuth client should already exist:
   - Name: Photolala Android
   - Package name: `com.electricwoods.photolala`
   - SHA-1: `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89`
3. If creating a new client, use the values above

#### Get SHA-1 Certificate:
```bash
# Debug certificate
cd android/
./gradlew signingReport

# Or using keytool directly
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

#### In Firebase Console (if using Firebase):
1. Add Android app with package name: `com.electricwoods.photolala`
2. Download `google-services.json`
3. Place in `android/app/` directory

### 2. Configure Web Client ID

You'll need the **Web client ID** (not the Android client ID) for Google Sign-In:

1. In Google Cloud Console → Credentials
2. Create another OAuth 2.0 Client ID of type "Web application"
3. Copy the client ID (looks like: `XXXXXX.apps.googleusercontent.com`)

### 3. Code Configuration

The Web Client ID is already configured in both:
- `GoogleAuthService.kt`
- `GoogleSignInService.kt`

```kotlin
private const val WEB_CLIENT_ID = "75309194504-p2sfktq2ju97ataogb1e5fkl70cj2jg3.apps.googleusercontent.com"
```

### 4. google-services.json

The `google-services.json` file is already configured and committed to the repository at `android/app/google-services.json`. It contains:
- OAuth client configurations
- API key
- Project information

Note: The Google Services Gradle plugin is not used (commented out in build.gradle.kts), but the configuration file is still required by the Google Sign-In SDK.

### 5. Test Configuration

1. Build and run the app
2. Try signing in with Google
3. Check logs for any configuration errors

## Production Setup

For release builds, you'll need to:

1. Add SHA-1 of your release keystore to OAuth client
2. Create separate OAuth clients for debug and release
3. Consider using different Firebase projects for dev/staging/prod

## Troubleshooting

### Common Issues:

1. **"Developer Error" or Error 10**
   - SHA-1 fingerprint doesn't match
   - Package name doesn't match
   - Wrong client ID used

2. **"Configuration Error" or Error 12500**
   - Missing google-services.json
   - Incorrect Web Client ID

3. **Sign-in silently fails**
   - Check if Google Play Services is up to date
   - Verify internet connectivity

### Debug Tips:
- Enable verbose logging in GoogleAuthService
- Check Logcat for detailed error messages
- Verify all IDs match between console and code