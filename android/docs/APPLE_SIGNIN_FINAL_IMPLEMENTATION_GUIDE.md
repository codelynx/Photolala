# Apple Sign-In for Android - Final Implementation Guide

## Overview

This guide documents the final, working implementation of Apple Sign-In for Android in Photolala. All code has been tested and is production-ready.

## Architecture

### Authentication Flow
1. User taps "Sign in with Apple" button
2. App launches Chrome Custom Tabs with OAuth URL
3. User authenticates with Apple
4. Apple POSTs to callback server
5. Server redirects to app deep link
6. App processes authentication result
7. User is signed in/account created

### Key Components

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│                 │     │                  │     │                 │
│ Authentication  │────▶│ AppleAuthService │────▶│ Chrome Custom   │
│     Screen      │     │                  │     │     Tabs        │
└─────────────────┘     └──────────────────┘     └─────────────────┘
         ▲                       │                         │
         │                       │                         ▼
         │                       │                  ┌─────────────────┐
         │                       │                  │                 │
         │                       │                  │  Apple OAuth    │
         │                       │                  │     Server      │
         │                       │                  └─────────────────┘
         │                       │                         │
         │                       ▼                         ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│                 │     │                  │     │                 │
│  MainActivity   │◀────│ IdentityManager  │◀────│ Callback Server │
│   (Deep Link)   │     │                  │     │  (Redirect)     │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Implementation Details

### 1. AppleAuthService.kt
Handles the OAuth flow with security best practices:

```kotlin
companion object {
    const val SERVICE_ID = "com.electricwoods.photolala.android"
    const val AUTH_ENDPOINT = "https://appleid.apple.com/auth/authorize"
    const val REDIRECT_URI = "https://photolala.eastlynx.com/auth/apple/callback"
}

fun signIn() {
    // Generate security parameters
    currentState = generateRandomString()
    currentNonce = generateRandomString()
    codeVerifier = generateCodeVerifier()
    val codeChallenge = generateCodeChallenge(codeVerifier!!)
    
    // Build OAuth URL with PKCE
    val authUrl = Uri.parse(AUTH_ENDPOINT).buildUpon().apply {
        appendQueryParameter("client_id", SERVICE_ID)
        appendQueryParameter("redirect_uri", REDIRECT_URI)
        appendQueryParameter("response_type", "code id_token")
        appendQueryParameter("scope", "email name")
        appendQueryParameter("response_mode", "form_post")
        appendQueryParameter("state", currentState)
        appendQueryParameter("nonce", currentNonce)
        appendQueryParameter("code_challenge", codeChallenge)
        appendQueryParameter("code_challenge_method", "S256")
    }.build()
    
    // Launch in Chrome Custom Tabs
}
```

### 2. Deep Link Configuration (AndroidManifest.xml)

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop">  <!-- Important for state preservation -->
    
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        
        <data
            android:scheme="photolala"
            android:host="auth"
            android:pathPrefix="/apple" />
    </intent-filter>
</activity>
```

### 3. Navigation State Preservation

The key innovation is preserving navigation state when the app returns from browser:

```kotlin
// PhotolalaNavigation.kt
object PhotolalaNavigation {
    internal var wasInCreateAccountFlow: Boolean = false
}

// In Create Account route
authViewModel.onAppleSignInRequired = {
    PhotolalaNavigation.wasInCreateAccountFlow = true
    // Launch Apple Sign-In
}

// In Welcome screen
LaunchedEffect(Unit) {
    if (PhotolalaNavigation.wasInCreateAccountFlow) {
        PhotolalaNavigation.wasInCreateAccountFlow = false
        navController.navigate(PhotolalaRoute.CreateAccount.route)
    }
}
```

### 4. Event Bus for Async Coordination

```kotlin
// AuthenticationEventBus.kt
@Singleton
class AuthenticationEventBus @Inject constructor() {
    private val _events = MutableSharedFlow<AuthEvent>()
    val events: SharedFlow<AuthEvent> = _events.asSharedFlow()
    
    suspend fun emitAppleSignInCompleted() {
        _events.emit(AuthEvent.AppleSignInCompleted)
    }
}
```

### 5. Callback Server

The server at `https://photolala.eastlynx.com/auth/apple/callback` handles Apple's POST:

```javascript
// Simple redirect to app
const code = req.body.code;
const state = req.body.state;
const idToken = req.body.id_token;

const appUrl = `photolala://auth/apple?code=${code}&state=${state}&id_token=${idToken || ''}`;
res.redirect(appUrl);
```

## Security Features

1. **CSRF Protection**: State parameter validation
2. **Replay Attack Protection**: Nonce validation
3. **PKCE**: Code challenge/verifier for OAuth security
4. **HTTPS Only**: All communication over secure channels

## Error Handling

The implementation handles all error scenarios:
- User cancellation
- Network errors
- Invalid responses
- State mismatches
- Missing data

## Testing

### Manual Testing Steps
1. Tap "Continue with Apple" from Create Account
2. Authenticate in browser
3. Cancel and verify return to Create Account (not Sign In)
4. Complete authentication
5. Verify account creation

### Edge Cases Tested
- App backgrounding during auth
- No Chrome installed (fallback to default browser)
- Invalid callback data
- Network interruption

## Dependencies

```kotlin
// build.gradle.kts
implementation("androidx.browser:browser:1.7.0")  // Chrome Custom Tabs
```

## Configuration Summary

| Component | Value |
|-----------|-------|
| Service ID | `com.electricwoods.photolala.android` |
| Redirect URI | `https://photolala.eastlynx.com/auth/apple/callback` |
| Deep Link | `photolala://auth/apple` |
| Launch Mode | `singleTop` |
| Min SDK | API 21 (Android 5.0) |

## Common Issues and Solutions

### Issue: App returns to wrong screen after auth
**Solution**: Change launch mode from `singleTask` to `singleTop`

### Issue: Deep link not working
**Solution**: Ensure intent filter matches exactly and test with adb

### Issue: State validation failures
**Solution**: Use static storage that survives app backgrounding

## Conclusion

Apple Sign-In is now fully functional on Android with:
- ✅ Secure OAuth implementation
- ✅ Smooth user experience
- ✅ Proper error handling
- ✅ Navigation state preservation
- ✅ Platform parity with iOS

The implementation is production-ready and has been thoroughly tested.