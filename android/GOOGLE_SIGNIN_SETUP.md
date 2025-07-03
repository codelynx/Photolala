# Google Sign-In Setup for Photolala Android

## Prerequisites

1. **Google Cloud Console Access**
   - Go to https://console.cloud.google.com/
   - Create a new project or select existing one

2. **Firebase Console** (Alternative)
   - Go to https://console.firebase.google.com/
   - Create a new project or select existing one

## Setup Steps

### 1. Configure OAuth 2.0 Client

#### In Google Cloud Console:
1. Go to APIs & Services → Credentials
2. Click "Create Credentials" → "OAuth client ID"
3. Select "Android" as application type
4. Enter:
   - Name: Photolala Android
   - Package name: `com.electricwoods.photolala`
   - SHA-1 certificate fingerprint (see below)

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

### 3. Update Code Configuration

In `GoogleAuthService.kt`, update:
```kotlin
private const val WEB_CLIENT_ID = "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
```

### 4. Add google-services.json

1. Copy `android/app/google-services.json.example` to `android/app/google-services.json`
2. Fill in the actual values from Firebase/Google Cloud Console
3. **IMPORTANT**: Add `google-services.json` to `.gitignore`

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