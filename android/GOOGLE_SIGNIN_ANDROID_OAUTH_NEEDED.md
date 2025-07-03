# Fix for Google Sign-In Error Code 10

## Current Issue
Getting "Authentication failed: Error code: 10" which indicates a configuration mismatch.

## Root Cause
We only created a Web OAuth client, but Google Sign-In for Android requires BOTH:
1. An Android OAuth client (for app authentication)
2. A Web OAuth client (for getting the ID token)

## Steps to Fix

### 1. Create Android OAuth Client
In Google Cloud Console (https://console.cloud.google.com/):

1. Go to your project: photolala-4b5ed
2. Navigate to APIs & Services → Credentials
3. Click "Create Credentials" → "OAuth client ID"
4. Select "Android" as application type
5. Enter:
   - Name: Photolala Android Debug
   - Package name: `com.electricwoods.photolala`
   - SHA-1 certificate fingerprint: `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89`
6. Click "Create"

### 2. Keep the Web OAuth Client
The Web client ID `663233468053-2g2it4le41amcvcven8jv7b7t2kd7795.apps.googleusercontent.com` is still needed in the code for requesting the ID token.

### 3. Update google-services.json
After creating the Android OAuth client, you may need to:
1. Go to Firebase Console (if using Firebase)
2. Download a fresh google-services.json
3. Replace the one in android/app/

Or manually add the Android client to the existing google-services.json.

### 4. Verify Setup
After creating the Android OAuth client:
- The Android client handles app authentication
- The Web client ID in code gets the ID token
- Both must be from the same project (photolala-4b5ed)

## Important Notes
- Error code 10 specifically means the app's SHA-1 and package name don't match any Android OAuth client
- The Web client ID in the code is correct and should not be changed
- You need both types of OAuth clients for Google Sign-In to work properly