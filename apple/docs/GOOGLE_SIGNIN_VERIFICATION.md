# Google Sign-In Configuration Verification

## Quick Checklist

### 1. Package Dependencies
- [ ] GoogleSignIn package appears in Xcode's Package Dependencies
- [ ] Package resolved successfully (no red errors)
- [ ] GoogleSignIn linked to Photolala target

### 2. OAuth Configuration
- [ ] iOS OAuth client created in Google Cloud Console
- [ ] Client ID copied (format: 105828093997-abc123.apps.googleusercontent.com)

### 3. Info.plist Configuration
Check that Info.plist contains:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Your reversed client ID here -->
            <string>com.googleusercontent.apps.105828093997-XXXXXXXXXX</string>
        </array>
    </dict>
</array>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>googlechrome</string>
    <string>googlechrome-x-callback</string>
</array>
```

### 4. Build Test
1. Clean build folder: **Shift+Cmd+K**
2. Build project: **Cmd+B**
3. Should build without errors

### 5. Runtime Test
1. Run on iOS Simulator
2. Tap "Create Account" or "Sign In"
3. Tap "Continue with Google"
4. Should show Google sign-in screen (not error)

## Common Issues

### "No such module 'GoogleSignIn'"
- Package not added to correct target
- Try: Clean build folder and rebuild

### "Invalid client ID"
- URL scheme doesn't match OAuth client
- Verify reversed client ID is exact

### App crashes on Google button tap
- Missing URL scheme in Info.plist
- GoogleSignIn not initialized

## Test Code
Add this temporary test to verify configuration:

```swift
// In PhotolalaApp.swift, after configureGoogleSignIn()
#if DEBUG
print("[GoogleSignIn] Configuration check:")
print("- SDK Available: \(GIDSignIn.sharedInstance != nil)")
print("- Configuration Set: \(GIDSignIn.sharedInstance.configuration != nil)")
if let config = GIDSignIn.sharedInstance.configuration {
    print("- Client ID: \(config.clientID)")
    print("- Server Client ID: \(config.serverClientID ?? "none")")
}
#endif
```

## Expected Client IDs

- **iOS Client ID**: `105828093997-[YOUR_SPECIFIC_ID].apps.googleusercontent.com`
- **Web Client ID**: `105828093997-qmr9jdj3h4ia0tt2772cnrejh4k0p609.apps.googleusercontent.com`
- **Reversed for URL**: `com.googleusercontent.apps.105828093997-[YOUR_SPECIFIC_ID]`

Replace [YOUR_SPECIFIC_ID] with the actual ID from Google Cloud Console.