# Google OAuth Setup for Photolala

## Error: "Access blocked: Photolala has not completed the Google verification process"

This error occurs because the OAuth consent screen is in "Testing" mode. During testing, only explicitly authorized test users can sign in.

## Solution: Add Test Users

1. **Go to Google Cloud Console**
   - Visit: https://console.cloud.google.com/
   - Select your Photolala project

2. **Navigate to OAuth consent screen**
   - In the left menu: APIs & Services → OAuth consent screen
   - You should see your app is in "Testing" status

3. **Add test users**
   - Scroll down to "Test users" section
   - Click "+ ADD USERS"
   - Add your email: kaz.yoshikawa@gmail.com
   - Add any other emails you want to test with
   - Click "SAVE"

4. **Wait a few minutes**
   - Changes may take a few minutes to propagate

5. **Try signing in again**
   - The error should now be resolved

## Alternative: Enable Google Photos API

Also ensure the Google Photos Library API is enabled:

1. In Google Cloud Console
2. APIs & Services → Library
3. Search for "Photos Library API"
4. Click on it and press "ENABLE" if not already enabled

## For Production Release

When ready to release to production:

1. Complete the OAuth consent screen configuration
2. Submit for Google verification
3. This process can take several weeks
4. Until verified, the app remains in testing mode

## OAuth Scopes Required

Make sure these scopes are configured in your OAuth consent screen:
- `email`
- `profile`
- `openid`
- `https://www.googleapis.com/auth/photoslibrary.readonly`

## Troubleshooting

If still having issues after adding test users:

1. Clear app data/cache
2. Sign out completely from the app
3. Make sure you're using the correct Google account
4. Check that the email exactly matches (including domain)
5. Verify the project ID matches between your app and Google Cloud Console