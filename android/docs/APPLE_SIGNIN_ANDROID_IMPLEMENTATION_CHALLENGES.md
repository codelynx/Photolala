# Apple Sign-In Android Implementation: Challenges and Solutions

## Overview
This document details the challenges encountered while implementing Apple Sign-In on Android for the Photolala app, including the trial-and-error process and the final solutions.

## Key Challenges

### 1. Navigation State Loss After Browser Return

#### Problem
When users initiated Apple Sign-In from the "Create Account" screen and then navigated back from the browser (either by canceling or after authentication), the app would return to the "Sign In" screen instead of maintaining the "Create Account" screen state.

#### Root Cause
- Android's `launchMode="singleTask"` in the MainActivity was causing the activity to be recreated when returning from the browser
- This cleared the navigation back stack and reset the app to its default state
- The navigation state wasn't persisted across the browser context switch

#### Solutions Attempted
1. **Initial Attempt**: Tried to store authentication intent in ViewModel
   - Added `currentAuthIntent` to track whether user was signing in or creating account
   - This didn't work because the ViewModel was recreated when the activity restarted

2. **Second Attempt**: Changed launch mode to `singleTop`
   - This prevented the activity from being recreated
   - However, navigation state was still lost due to the navigation controller resetting

3. **Final Solution**: Combined approach
   - Changed `launchMode` from `singleTask` to `singleTop` in AndroidManifest.xml
   - Added a static flag `wasInCreateAccountFlow` in PhotolalaNavigation companion object
   - Set flag when Apple Sign-In is triggered from Create Account screen
   - Check and restore navigation state in the Welcome screen's LaunchedEffect

```kotlin
// In PhotolalaNavigation.kt
object PhotolalaNavigation {
    internal var wasInCreateAccountFlow: Boolean = false
}

// In Create Account route
authViewModel.onAppleSignInRequired = {
    PhotolalaNavigation.wasInCreateAccountFlow = true
    // ... launch Apple Sign-In
}

// In Welcome screen
LaunchedEffect(Unit) {
    if (PhotolalaNavigation.wasInCreateAccountFlow) {
        PhotolalaNavigation.wasInCreateAccountFlow = false
        navController.navigate(PhotolalaRoute.CreateAccount.route)
    }
}
```

### 2. Deep Link Handling for OAuth Callback

#### Problem
Apple Sign-In on Android requires a web-based OAuth flow with a callback URL, unlike iOS which has a native SDK.

#### Solution
- Configured deep link handling in AndroidManifest.xml
- Set up intent filter for `photolala://auth/apple` scheme
- Handled the callback in MainActivity's `onNewIntent` method

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="photolala"
        android:host="auth"
        android:pathPrefix="/apple" />
</intent-filter>
```

### 3. Asynchronous Authentication Flow Coordination

#### Problem
The authentication flow involves multiple asynchronous steps:
1. User clicks Apple Sign-In button
2. Browser opens for authentication
3. User completes/cancels in browser
4. Deep link returns to app
5. App processes the result
6. UI needs to update accordingly

#### Solution
- Implemented `AuthenticationEventBus` to coordinate between deep link callbacks and UI
- Used Kotlin Flow to emit events when authentication completes
- ViewModel listens to these events and triggers UI updates

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

// In ViewModel
authEventBus.events
    .onEach { event ->
        when (event) {
            is AuthEvent.AppleSignInCompleted -> {
                pendingAppleSignInSuccessCallback?.invoke()
            }
        }
    }
    .launchIn(viewModelScope)
```

### 4. Browser Context Switch Handling

#### Problem
When the browser opens for Apple Sign-In, the app goes to background and may be killed by the system, losing state.

#### Solutions
- Used `singleTop` launch mode to prevent activity recreation
- Stored critical state in static variables (not ideal but works)
- Implemented proper state restoration in `onNewIntent`

### 5. OAuth State and Nonce Validation

#### Problem
Apple requires state and nonce parameters for security, but these were lost during browser context switch.

#### Current State
- State and nonce validation is currently commented out for testing
- TODO: Implement proper secure storage for these values that survives app backgrounding

```kotlin
// In AppleAuthService.kt
// TODO: Re-enable after testing
// if (state != currentState) {
//     _authState.value = AppleAuthState.Error(
//         AppleAuthError.InvalidState("State mismatch - possible security issue")
//     )
//     return false
// }
```

## Best Practices Learned

1. **Always test the full flow**: Including app backgrounding, process death, and various cancellation points
2. **Use persistent storage for critical auth state**: Don't rely on in-memory storage
3. **Handle all edge cases**: User cancellation, network errors, invalid responses
4. **Provide clear error messages**: Help users understand what went wrong
5. **Test on real devices**: Emulator behavior may differ for browser interactions

## Implementation Checklist

- [x] Configure deep links in AndroidManifest.xml
- [x] Implement AppleAuthService for OAuth flow
- [x] Handle browser launch with Chrome Custom Tabs
- [x] Process OAuth callback in MainActivity
- [x] Coordinate async events with EventBus
- [x] Preserve navigation state across browser switch
- [x] Add Apple logo asset
- [x] Update UI to show Apple Sign-In button
- [ ] Implement secure state/nonce storage
- [ ] Add comprehensive error handling
- [ ] Test on various Android versions

## Testing Scenarios

1. **Happy Path**: Complete Apple Sign-In successfully
2. **Cancellation**: User cancels at Apple login screen
3. **Back Navigation**: User uses back button during auth
4. **App Backgrounding**: App goes to background during auth
5. **Process Death**: System kills app during auth
6. **Network Errors**: Handle connection issues
7. **Invalid Responses**: Handle malformed callbacks

## Future Improvements

1. Implement secure storage for OAuth state and nonce
2. Add analytics to track authentication flow completion rates
3. Implement automatic retry for network errors
4. Consider using AndroidX Activity Result API for better state management
5. Add unit tests for all authentication scenarios

## References

- [Sign in with Apple REST API](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api)
- [Android Deep Links Documentation](https://developer.android.com/training/app-links/deep-linking)
- [Chrome Custom Tabs Best Practices](https://developer.chrome.com/docs/android/custom-tabs/best-practices/)