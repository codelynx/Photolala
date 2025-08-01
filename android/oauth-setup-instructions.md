# OAuth Setup Instructions for Photolala Android

## Current Situation
- Project: `photolala-android` (owned by kyoshikawa@electricwoods.com)
- You need to sign in with the **electricwoods.com** account, not the Gmail account

## Steps to Fix Browser Access:

1. **Open an incognito/private browser window** to avoid account conflicts

2. **Go to Google Cloud Console**:
   ```
   https://console.cloud.google.com/
   ```

3. **Sign in with**: `kyoshikawa@electricwoods.com`
   (NOT kaz.yoshikawa@gmail.com)

4. **Navigate to OAuth credentials**:
   ```
   https://console.cloud.google.com/apis/credentials?project=photolala-android
   ```

## Create Android OAuth Client:

1. Click **"CREATE CREDENTIALS"** → **"OAuth client ID"**

2. Fill in:
   - **Application type**: Android
   - **Name**: Photolala Android Debug
   - **Package name**: `com.electricwoods.photolala.debug`
   - **SHA-1 certificate fingerprint**: `9B:E2:5F:F5:0A:1D:B9:3F:18:99:D0:FF:E2:3A:80:EF:5A:A7:FB:89`

3. Click **"CREATE"**

## Download Configuration:

1. After creating the OAuth client, go to:
   ```
   https://console.cloud.google.com/apis/credentials/oauthclient?project=photolala-android
   ```

2. Download the `google-services.json` file

3. Place it in: `android/app/google-services.json`

## Verify Setup:

Run the verification script:
```bash
cd /Users/kyoshikawa/Projects/Photolala/android
./verify-oauth-setup.sh
```

## Alternative: Use Firebase Console

If you prefer, you can also use Firebase Console:
1. Go to https://console.firebase.google.com/
2. Sign in with kyoshikawa@electricwoods.com
3. Select or create the photolala-android project
4. Add Android app with debug package name
5. Download google-services.json