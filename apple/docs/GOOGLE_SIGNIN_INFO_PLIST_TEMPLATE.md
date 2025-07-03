# Info.plist Configuration for Google Sign-In

Add the following to your `apple/Photolala/Info.plist` file:

## URL Schemes Configuration

```xml
<!-- Add this to the existing Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Replace with your reversed iOS client ID -->
            <!-- Format: com.googleusercontent.apps.YOUR_IOS_CLIENT_ID -->
            <string>com.googleusercontent.apps.105828093997-XXXXXXXXXXXXXXXXXXXXXXXXXX</string>
        </array>
    </dict>
</array>

<!-- For iOS 9+ to query Google app -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>googlechrome</string>
    <string>googlechrome-x-callback</string>
</array>
```

## How to Get Your iOS Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `photolala`
3. Go to APIs & Services → Credentials
4. Create OAuth client:
   - Type: iOS
   - Bundle ID: `com.electricwoods.photolala`
5. Copy the generated Client ID
6. Reverse it for the URL scheme:
   - Original: `105828093997-abc123.apps.googleusercontent.com`
   - Reversed: `com.googleusercontent.apps.105828093997-abc123`

## Important Notes

- The URL scheme must match your iOS OAuth client ID exactly
- The bundle ID in the OAuth client must match your app's bundle ID
- You need different OAuth clients for iOS and Android
- The Web Client ID (for server verification) is shared across platforms