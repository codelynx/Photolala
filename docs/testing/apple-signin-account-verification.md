# Apple Sign-In Account Verification Guide

## The Problem
Apple Sign-In on different devices may use different Apple IDs without clearly showing which one is being used. This causes authentication to fail across platforms because each Apple ID has a unique identifier.

## How to Check Which Apple ID You're Using

### On macOS
1. **System Settings**
   - Go to System Settings → Apple ID (top of sidebar)
   - Note the email address shown
   
2. **Before Sign-In**
   - When the Apple Sign-In dialog appears, it should show the Apple ID email at the top
   - If multiple Apple IDs are available, you can choose which one to use

### On Android
1. **No System-Level Apple ID**
   - Android doesn't have system-level Apple ID integration
   - Apple Sign-In uses the Apple ID you enter in the web form
   
2. **Check Browser State**
   - Open Chrome/default browser
   - Go to appleid.apple.com
   - See if you're already signed in
   - Sign out if needed to ensure you use the correct account

## Best Practices for Testing

### 1. Clear Browser State on Android
```bash
# Via ADB
adb shell pm clear com.android.chrome
# Or manually: Settings → Apps → Chrome → Clear Data
```

### 2. Use Same Apple ID Email
- Make note of the exact email used on Mac
- Manually enter the same email on Android
- Use the same password

### 3. Add Visual Debugging
Consider adding temporary UI to show which Apple ID is being used:

**For iOS/macOS:**
```swift
// In AuthCredential.swift after extracting JWT
print("🍎 Apple Sign-In Details:")
print("   Email: \(email ?? "not provided")")
print("   User ID: \(providerID)")
```

**For Android:**
```kotlin
// In AppleAuthService.kt
android.util.Log.i("AppleAuth", "🍎 Apple Sign-In Details:")
android.util.Log.i("AppleAuth", "   Email: ${credential.email ?: "not provided"}")
android.util.Log.i("AppleAuth", "   User ID: ${credential.providerID}")
```

### 4. Create Test Accounts
For easier testing, consider:
1. Create a dedicated test Apple ID
2. Sign out of all personal Apple IDs on test devices
3. Only sign in with the test Apple ID

## Verification Steps

1. **On Mac:**
   - Sign out from Photolala
   - Note your Apple ID email
   - Create new account
   - Check logs for the JWT sub value

2. **On Android:**
   - Clear app data
   - Clear browser data
   - Sign in with Apple
   - **Manually enter the same email used on Mac**
   - Check logs to confirm same JWT sub value

## Current Apple ID Formats Seen

From your logs, different Apple IDs are being used:
- Mac: `001196.9c1591b8ce9246eeb78b745667d8d7b6.0842`
- Android attempts:
  - `c506bf677c8494e30aefa1c8bd4b1d18c.0.rsqqw.iapdng0gEDhnyB2wDJ2mDQ`
  - `c8e7a19d0e49d4fec99dbb81ed7afc408.0.prrzw.DcHHw8tyGnWpUUi6GFJA8w`
  - And several others...

These are all different Apple accounts!