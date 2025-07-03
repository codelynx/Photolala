# How to Create Apple Service ID for Android

## Prerequisites
- Active Apple Developer account ($99/year)
- Access to Apple Developer Portal
- Your Android app's package name: `com.electricwoods.photolala`

## Step-by-Step Guide

### 1. Sign in to Apple Developer Portal
1. Go to https://developer.apple.com
2. Click "Account" and sign in
3. Navigate to "Certificates, Identifiers & Profiles"

### 2. Create a Service ID

1. In the left sidebar, click **Identifiers**
2. Click the **+** button (blue plus icon)
3. Select **Services IDs** and click **Continue**

### 3. Configure the Service ID

1. **Description**: `Photolala Android`
   - This is what users will see during sign-in
   
2. **Identifier**: `com.electricwoods.photolala.android`
   - Must be unique across all Apple Developer accounts
   - Cannot be the same as your iOS app's bundle ID
   
3. Click **Continue**, then **Register**

### 4. Configure Sign in with Apple

1. Click on your newly created Service ID from the list
2. Check the box next to **Sign in with Apple**
3. Click **Configure** button

### 5. Set up Web Authentication Configuration

In the configuration modal:

1. **Primary App ID**: Select your iOS app ID (if you have one)
   - If you don't have an iOS app, you'll need to create an App ID first

2. **Domains and Subdomains**:
   ```
   photolala.eastlynx.com
   ```
   - This is the domain that hosts your callback handler
   - Must be a verified domain with HTTPS

3. **Return URLs** (Most Important!):
   ```
   https://photolala.eastlynx.com/auth/apple/callback
   ```
   - This is where Apple POSTs the authentication response
   - Your server at this URL must redirect to the app's deep link

4. Click **Next**, then **Done**

5. Click **Continue**, then **Save**

### 6. Update Your Android App

Open `/Users/kyoshikawa/Projects/Photolala/android/app/src/main/java/com/electricwoods/photolala/services/AppleAuthService.kt`

Update line 32:
```kotlin
const val SERVICE_ID = "com.electricwoods.photolala.android"
```

## Important Notes

### About Return URLs
- The return URL must be an HTTPS URL (Apple requirement)
- Apple will POST authentication data to this URL
- Your server must handle the POST and redirect to `photolala://auth/apple`
- The deep link `photolala://auth/apple` is configured in your Android manifest

### Testing Considerations
- Service IDs work immediately after creation (no review needed)
- Test on a physical device (not emulator)
- Make sure you're signed in to an Apple ID on the test device

### Common Issues

1. **"Invalid request" error**:
   - Check that return URL matches exactly
   - Ensure Service ID is saved properly
   - Verify all domains are added

2. **"Invalid client" error**:
   - Service ID in app doesn't match portal
   - Configuration not saved properly

3. **Redirect not working**:
   - Deep link scheme must match exactly
   - Check Android manifest configuration

## Alternative: Without iOS App

If you don't have an iOS app yet:

1. First create an **App ID**:
   - Click Identifiers → + → App IDs
   - Select "App" type
   - Bundle ID: `com.electricwoods.photolala`
   - Enable "Sign in with Apple" capability
   
2. Then create the Service ID as described above

## Verification Steps

After setup:
1. Service ID appears in Identifiers list
2. Sign in with Apple is enabled (green checkmark)
3. Return URL is listed in configuration
4. SERVICE_ID in Android code matches exactly

## Current Implementation Details

### Android App Configuration
- **Service ID**: `com.electricwoods.photolala.android`
- **Redirect URI**: `https://photolala.eastlynx.com/auth/apple/callback`
- **Deep Link**: `photolala://auth/apple`
- **Launch Mode**: `singleTop` (to preserve navigation state)

### Key Files
- **AppleAuthService.kt**: Handles OAuth flow with Chrome Custom Tabs
- **MainActivity.kt**: Processes deep link callbacks
- **IdentityManager.kt**: Manages authentication state
- **AuthenticationEventBus.kt**: Coordinates async authentication events

## Next: Test Your Implementation

```bash
# Build and install
cd /Users/kyoshikawa/Projects/Photolala/android
./gradlew installDebug
```

Then test the full flow on your Android device!