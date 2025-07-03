# Apple Sign-In Troubleshooting Guide

## If Browser Doesn't Open

### 1. Check Android Logs
```bash
adb logcat | grep -E "AppleAuth|Photolala|Chrome"
```

Look for:
- "Initiating Apple Sign-In"
- "Failed to launch Sign in with Apple"
- Any Chrome Custom Tabs errors

### 2. Verify Chrome is Installed
Chrome Custom Tabs requires Chrome browser. Make sure:
- Chrome is installed on the device
- Chrome is up to date
- Not using an emulator (use physical device)

### 3. Check Context Issues
The error might be because the context isn't an Activity context. 

Try this manual test:
1. Add a temporary button in your app
2. Make it directly call:
```kotlin
val intent = CustomTabsIntent.Builder().build()
intent.launchUrl(requireActivity(), Uri.parse("https://google.com"))
```

### 4. Test the Callback URL
Open this in your phone's browser:
```
https://photolala.electricwoods.com/auth/apple/callback/?test=1
```

It should try to open `photolala://auth/apple?test=1`

### 5. Check App State
Make sure:
- App is in foreground when clicking Apple Sign-In
- No other dialogs or activities are blocking
- Permissions are granted (INTERNET permission)

## Debug Steps

### Add Logging to AppleAuthService
In `signIn()` method, add:
```kotlin
Log.d("AppleAuth", "signIn() called")
Log.d("AppleAuth", "Auth URL: $authUrl")
Log.d("AppleAuth", "Context: ${context.javaClass.simpleName}")
```

### Add Logging to IdentityManager
In `prepareAppleSignIn()`:
```kotlin
Log.d("IdentityManager", "prepareAppleSignIn called with intent: $authIntent")
```

### Check ViewModel Callback
In AuthenticationViewModel, add:
```kotlin
onAppleSignInRequired = {
    Log.d("AuthViewModel", "onAppleSignInRequired invoked")
}
```

## Common Issues

### "Context is not an Activity"
If you see this, the AppleAuthService might be getting an Application context instead of Activity context.

### "No app found to handle Intent"
Chrome might not be installed or the Custom Tabs service is disabled.

### Silent Failure
Check if any try-catch blocks are swallowing exceptions.

## Alternative Test

Try opening the Apple Sign-In URL directly in Chrome:
```
https://appleid.apple.com/auth/authorize?response_type=code&client_id=com.electricwoods.photolala.android&redirect_uri=https://photolala.electricwoods.com/auth/apple/callback&scope=email%20name&response_mode=form_post
```

This should show Apple's sign-in page.