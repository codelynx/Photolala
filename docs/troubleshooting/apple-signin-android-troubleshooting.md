# Apple Sign-In Android Troubleshooting Guide

## Common Issues and Solutions

### 1. "NoSuchKey" Error in S3 Identity Lookup

**Symptoms:**
- User can authenticate with Apple but app shows "No account found"
- Logs show S3 download failure for identity mapping
- Cross-platform sign-in fails

**Causes:**
- Incorrect user ID extraction from JWT token
- Wrong S3 identity mapping format
- User created account on different platform with different ID format

**Debug Steps:**
1. Check the logs for JWT parsing:
   ```
   AppleAuthService: JWT sub (providerID): 001196.9c1591b8ce9246eeb78b745667d8d7b6.0842
   ```

2. Verify S3 identity mapping format:
   ```
   aws s3 ls s3://photolala-main/identities/ --recursive
   ```

3. Look for the correct identity key:
   ```
   identities/apple:001196.9c1591b8ce9246eeb78b745667d8d7b6.0842
   ```

**Solutions:**
- Ensure JWT parsing extracts the `sub` field correctly
- Verify Apple Developer configuration matches between platforms
- Check that both iOS and Android use the same Service ID

### 2. "invalid_grant" Error During Token Exchange

**Symptoms:**
- Apple authentication starts but fails during token exchange
- Logs show HTTP 400 error from Apple token endpoint
- User sees generic authentication error

**Causes:**
- Incorrect client secret generation
- Wrong Apple Developer configuration
- Mismatched redirect URI
- Expired or invalid authorization code

**Debug Steps:**
1. Check client secret generation logs:
   ```
   AppleAuthService: Generating client secret with:
     Team ID: 2P97EM4L4N
     Service ID: com.electricwoods.photolala.android
     Key ID: FPZRF65BMT
   ```

2. Verify token exchange request:
   ```
   AppleAuthService: Token exchange request:
     URL: https://appleid.apple.com/auth/token
     client_id: com.electricwoods.photolala.android
     redirect_uri: https://photolala.eastlynx.com/auth/apple/callback
   ```

3. Check Apple Developer Portal configuration:
   - Service ID matches exactly
   - Redirect URI is registered
   - Private key is active

**Solutions:**
- Verify Apple Developer Portal configuration
- Regenerate private key if needed
- Update Service ID configuration in Apple Developer Portal
- Ensure redirect URI matches exactly (including HTTPS)

### 3. Navigation Stuck on Sign-In Screen

**Symptoms:**
- User completes Apple authentication
- App shows success notification/toast
- Screen stays on authentication instead of returning to welcome
- No navigation occurs

**Causes:**
- Race condition in async callback processing
- Event bus not properly connected
- Navigation callback not being invoked
- Duplicate navigation attempts

**Debug Steps:**
1. Check event bus logs:
   ```
   AuthViewModel: === APPLE SIGN-IN EVENT RECEIVED ===
   AuthViewModel: Pending callback available: true
   AuthViewModel: Invoking success callback for navigation
   ```

2. Look for navigation completion:
   ```
   PhotolalaNav: === SIGN-IN AUTH SUCCESS ===
   PhotolalaNav: Navigation completed
   ```

3. Verify auth state updates:
   ```
   IdentityManager: Final auth state: Success
   IdentityManager: Apple auth successful, processing credential
   ```

**Solutions:**
- Ensure IdentityManager waits for auth state with `Flow.first()`
- Check that event bus emission happens after user state update
- Verify AuthenticationViewModel has pending callback stored
- Add delay before navigation if race condition persists

### 4. Welcome Screen Still Shows Sign-In Buttons

**Symptoms:**
- User successfully signs in
- Navigation returns to welcome screen
- Welcome screen still shows "Sign In" and "Create Account" buttons
- User profile not displayed

**Causes:**
- User state not properly updated in IdentityManager
- Welcome screen not observing state changes
- State flow not emitting updates
- Race condition in state synchronization

**Debug Steps:**
1. Check welcome screen state logs:
   ```
   WelcomeScreen: === WELCOME SCREEN STATE ===
   WelcomeScreen: isSignedIn: true
   WelcomeScreen: currentUser: John Doe
   ```

2. Verify IdentityManager state:
   ```
   IdentityManager: _currentUser.value = [user details]
   IdentityManager: _isSignedIn.value = true
   ```

3. Check StateFlow updates:
   ```
   WelcomeViewModel: currentUser flow updated
   WelcomeViewModel: isSignedIn flow updated
   ```

**Solutions:**
- Ensure IdentityManager sets both `_currentUser` and `_isSignedIn`
- Verify state flows are properly exposed in WelcomeViewModel
- Check that WelcomeScreen observes state with `collectAsStateWithLifecycle()`
- Add debugging to verify state propagation

### 5. Deep Link Not Being Processed

**Symptoms:**
- User completes Apple authentication in browser
- Browser redirects but app doesn't respond
- No deep link processing logs
- User stuck in browser

**Causes:**
- Intent filter not configured correctly
- Deep link scheme/host mismatch
- MainActivity not handling intent
- Android system not recognizing app for deep links

**Debug Steps:**
1. Check Android manifest intent filter:
   ```xml
   <intent-filter android:autoVerify="true">
       <action android:name="android.intent.action.VIEW" />
       <category android:name="android.intent.category.DEFAULT" />
       <category android:name="android.intent.category.BROWSABLE" />
       <data android:scheme="photolala" 
             android:host="auth" />
   </intent-filter>
   ```

2. Look for deep link logs:
   ```
   MainActivity: Received deep link: photolala://auth/apple?code=...
   MainActivity: === APPLE DEEP LINK DETECTED ===
   ```

3. Test deep link manually:
   ```bash
   adb shell am start \
     -W -a android.intent.action.VIEW \
     -d "photolala://auth/apple?code=test&state=test" \
     com.electricwoods.photolala
   ```

**Solutions:**
- Verify intent filter configuration in AndroidManifest.xml
- Check that scheme and host match Apple Developer Portal
- Test deep link handling with ADB
- Ensure MainActivity handles both onCreate and onNewIntent

## Debugging Tools

### 1. Enable Enhanced Logging

Add this to track the complete flow:
```kotlin
// In AppleAuthService
android.util.Log.d("AppleAuth", "Step: $description")

// In IdentityManager  
android.util.Log.d("IdentityManager", "State: $state")

// In WelcomeScreen
android.util.Log.d("WelcomeScreen", "UI State: isSignedIn=$isSignedIn")
```

### 2. Logcat Filtering

Use these filters to focus on relevant logs:
```bash
# Apple Sign-In specific
adb logcat | grep -E "(AppleAuth|Apple|IdentityManager)"

# Navigation flow
adb logcat | grep -E "(PhotolalaNav|AuthViewModel|WelcomeScreen)"

# Deep link processing
adb logcat | grep -E "(MainActivity|Intent|DeepLink)"
```

### 3. JWT Token Inspection

Decode JWT tokens to verify content:
```bash
# Use the provided script
./scripts/decode-apple-jwt.sh <jwt_token>

# Or manually
echo "<jwt_payload_base64>" | base64 -d | jq
```

### 4. S3 Identity Verification

Check S3 for identity mappings:
```bash
# List all identities
aws s3 ls s3://photolala-main/identities/ --recursive

# Download specific identity
aws s3 cp s3://photolala-main/identities/apple:USER_ID /tmp/identity

# View content (should be UUID)
cat /tmp/identity
```

## Testing Scenarios

### 1. Cross-Platform Sign-In Test

1. Create Apple account on iOS/macOS
2. Verify S3 identity mapping exists
3. Sign in with same Apple account on Android
4. Verify same serviceUserID is used
5. Check that cloud data is accessible

### 2. Error Recovery Test

1. Start Apple Sign-In on Android
2. Cancel authentication in browser
3. Verify app returns to auth screen gracefully
4. Try again and complete successfully
5. Verify navigation works correctly

### 3. State Persistence Test

1. Sign in with Apple on Android
2. Force-close app
3. Restart app
4. Verify user remains signed in
5. Verify welcome screen shows signed-in state

## Configuration Checklist

### Apple Developer Portal
- [ ] Service ID created and configured
- [ ] Redirect URI added: `https://photolala.eastlynx.com/auth/apple/callback`
- [ ] Private key generated and downloaded
- [ ] Sign in with Apple capability enabled

### Android Configuration
- [ ] Apple private key added to credential-code
- [ ] Deep link intent filter in AndroidManifest.xml
- [ ] Team ID, Service ID, Key ID constants correct
- [ ] Build dependencies include JWT libraries

### Runtime Verification
- [ ] Credential-code decryption working
- [ ] Deep link processing functional
- [ ] S3 access configured correctly
- [ ] Event bus listeners registered

## Performance Considerations

### 1. Token Exchange Timeout

- Default timeout: 30 seconds
- Network-dependent operation
- Consider retry logic for poor connections

### 2. JWT Parsing Performance

- Parsing happens on main thread
- Consider moving to background for large tokens
- Cache parsed results if needed

### 3. S3 Identity Lookup

- Network operation during authentication
- Can add perceived delay to sign-in flow
- Consider caching mechanism for frequent users

## Security Verification

### 1. Private Key Protection

- Verify key is encrypted in binary
- Check no plain text in source code
- Confirm secure storage in credential-code

### 2. OAuth Parameter Validation

- State parameter prevents CSRF
- Nonce prevents replay attacks
- Redirect URI must match exactly

### 3. JWT Signature Verification

- Apple signs ID tokens with their private key
- Consider adding signature verification
- Validate audience and issuer claims

## Future Improvements

1. **Retry Logic**: Add automatic retry for network failures
2. **Offline Support**: Cache authentication state for offline use
3. **Biometric Auth**: Add biometric authentication for subsequent sign-ins
4. **Analytics**: Track authentication flow success/failure rates
5. **Migration Tools**: Tools for moving between Apple IDs