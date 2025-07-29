# Apple Sign-In Android Implementation Guide

## Overview

This document consolidates the complete implementation details, known issues, and solutions for Apple Sign-In on Android in the Photolala app. The implementation enables cross-platform authentication compatibility, allowing users to sign in with the same Apple account across iOS, macOS, and Android platforms.

## Core Problem and Solution

### The Challenge

Apple's web-based OAuth flow (required for Android) has a critical limitation:
- **First authorization**: Returns both authorization code AND identity token (JWT)
- **Subsequent authorizations**: Only returns authorization code, NO identity token

This caused Android users to be unable to sign in with Apple accounts created on iOS/macOS because:
1. Android was using authorization codes as user IDs instead of the actual Apple user ID
2. S3 identity mappings were inconsistent across platforms
3. No token exchange was implemented to retrieve ID tokens on subsequent sign-ins

### The Solution

Implemented server-side token exchange using Apple's REST API to always obtain the ID token and extract the correct Apple user ID.

## Technical Implementation

### 1. JWT Token Exchange

The core solution involves exchanging authorization codes for tokens when Apple doesn't provide an ID token directly.

**Key Implementation (AppleAuthService.kt)**:
```kotlin
private suspend fun exchangeCodeForTokens(code: String): AppleTokenResponse {
    val clientSecret = generateClientSecret()
    val formBody = FormBody.Builder()
        .add("client_id", SERVICE_ID)
        .add("client_secret", clientSecret)
        .add("code", code)
        .add("grant_type", "authorization_code")
        .add("redirect_uri", REDIRECT_URI)
        .build()
    // POST to https://appleid.apple.com/auth/token
}
```

### 2. Client Secret Generation

Apple requires ES256 JWT signing for authentication:
```kotlin
private fun generateClientSecret(): String {
    val privateKey = // Load from credential-code
    val jwt = Jwts.builder()
        .setHeaderParam("kid", KEY_ID)
        .setHeaderParam("alg", "ES256")
        .setIssuer(TEAM_ID)
        .setAudience("https://appleid.apple.com")
        .setSubject(SERVICE_ID)
        .signWith(privateKey, SignatureAlgorithm.ES256)
        .compact()
}
```

### 3. Web-to-App Bridge

Since Apple requires `response_mode=form_post` for email/name scopes, a web bridge is needed to redirect the POST response to the Android app.

**Web Bridge Flow**:
1. Apple POSTs to `https://photolala.eastlynx.com/auth/apple/callback`
2. Web page extracts POST parameters
3. Redirects to Android deep link: `photolala://auth/apple?{params}`

**Bridge Implementation (HTML/JavaScript)**:
```javascript
function handleAppleCallback() {
    const urlParams = new URLSearchParams();
    const formData = new FormData(document.getElementById('appleForm'));
    
    for (const [key, value] of formData) {
        urlParams.append(key, value);
    }
    
    const appUrl = `photolala://auth/apple?${urlParams.toString()}`;
    window.location.href = appUrl;
}
```

### 4. Secure Credential Management

Apple private key is managed through the credential-code system:

**Updated .credential-code/credentials.json**:
```json
{
  "credentials": {
    "AWS_ACCESS_KEY_ID": "...",
    "AWS_SECRET_ACCESS_KEY": "...",
    "AWS_DEFAULT_REGION": "us-east-1",
    "APPLE_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
  }
}
```

### 5. S3 Identity Mapping

Standardized identity key format across all platforms:
```
identities/{provider}:{providerID}
```

Examples:
- Apple: `identities/apple:001196.9c1591b8ce9246eeb78b745667d8d7b6.0842`
- Google: `identities/google:1234567890`

## Apple Developer Configuration

Required Apple Developer settings:
- **Team ID**: `2P97EM4L4N`
- **Service ID**: `com.electricwoods.photolala.android`
- **Key ID**: `FPZRF65BMT`
- **Private Key**: ES256 key for JWT signing
- **Redirect URI**: `https://photolala.eastlynx.com/auth/apple/callback`

## Authentication Flow

### Complete Sign-In Process:

1. **Initiation**: User taps "Sign in with Apple"
2. **Browser Launch**: Chrome Custom Tabs opens Apple OAuth
3. **User Authentication**: User authenticates with Apple
4. **Web Bridge**: Apple POSTs to web callback URL
5. **Deep Link**: Web page redirects to `photolala://auth/apple`
6. **MainActivity**: Processes deep link callback
7. **Token Exchange**: If no ID token, exchange authorization code
8. **JWT Parsing**: Extract actual Apple user ID from token
9. **S3 Lookup**: Check `identities/apple:{userID}` for existing user
10. **State Update**: Update IdentityManager with user info
11. **Event Bus**: Emit sign-in completion event
12. **Navigation**: Return to welcome screen showing signed-in state

## Known Issues and Solutions

### Issue 1: Async Processing Race Condition

**Problem**: `handleCallback()` returned immediately but processed auth asynchronously, causing navigation to fail.

**Solution**: Wait for auth state update in IdentityManager:
```kotlin
val authState = appleAuthService.authState
    .first { state -> 
        state !is AppleAuthState.Loading && state !is AppleAuthState.Idle 
    }
```

### Issue 2: User ID Format Mismatch

**Problem**: Android used authorization codes instead of Apple user IDs.

**Solution**: Always perform token exchange to get the ID token and extract the correct user ID.

### Issue 3: Navigation Timing

**Solution**: Event bus pattern for proper async coordination:
```kotlin
// Emit event after auth completes
authEventBus.emitAppleSignInCompleted()

// Listen and navigate in ViewModel
authEventBus.events.onEach { event ->
    when (event) {
        is AuthEvent.AppleSignInCompleted -> {
            pendingAppleSignInSuccessCallback?.invoke()
        }
    }
}
```

## Security Considerations

1. **Encrypted Credentials**: Apple private key encrypted using credential-code
2. **PKCE Implementation**: Proof Key for Code Exchange for OAuth security
3. **JWT Validation**: Proper signature, audience, expiry, and issuer validation
4. **HTTPS Only**: All redirect URIs must use HTTPS
5. **State Parameter**: Validation to prevent CSRF attacks

## Testing and Debugging

### Debug Commands
```bash
# Check S3 identity mappings
aws s3 ls s3://photolala-main/identities/ --recursive

# Decode Apple JWT locally
./scripts/decode-apple-jwt.sh <jwt_token>

# Clear test data
./scripts/clear-s3-test-data.sh
```

### Test Scenarios
1. Cross-platform sign-in (create on iOS, sign in on Android)
2. Subsequent sign-ins (no JWT scenario)
3. Error handling (network failures, invalid tokens)
4. Navigation flow completion
5. State persistence across app restarts

## Common Troubleshooting

### "NoSuchKey" S3 Error
- Verify identity mapping format matches
- Check JWT parsing extracts correct user ID
- Confirm S3 bucket permissions

### "invalid_grant" Token Exchange Error
- Verify client secret generation
- Check Apple Developer configuration matches
- Confirm redirect URI is exact match

### Navigation Not Working
- Check event bus emission timing
- Verify async callback handling
- Review state transition logs

## Dependencies

```kotlin
// JWT handling
implementation("io.jsonwebtoken:jjwt-api:0.11.5")
implementation("io.jsonwebtoken:jjwt-impl:0.11.5")
implementation("io.jsonwebtoken:jjwt-jackson:0.11.5")

// HTTP client for token exchange
implementation("com.squareup.okhttp3:okhttp:4.12.0")

// JSON parsing
implementation("com.google.code.gson:gson:2.8.9")
```

## Key Implementation Files

1. **AppleAuthService.kt** - Core authentication logic, token exchange
2. **IdentityManager.kt** - User state management, S3 operations
3. **AuthenticationViewModel.kt** - UI coordination, event handling
4. **MainActivity.kt** - Deep link processing
5. **WelcomeScreen.kt** - Signed-in state display
6. **Credentials.kt** - Apple key support in credential system

## Future Enhancements

1. **Token Refresh**: Implement refresh token handling for long sessions
2. **Biometric Auth**: Add fingerprint/face authentication
3. **Server-Side Exchange**: Move token exchange to backend for enhanced security
4. **Analytics**: Track authentication flow metrics
5. **Automated Testing**: Add integration tests for auth flows

## Summary

The Apple Sign-In implementation on Android successfully enables cross-platform authentication through:
- Proper JWT token exchange to obtain Apple user IDs
- Web bridge to handle Apple's form_post requirement
- Secure credential management with credential-code
- Event-driven async processing for reliable navigation
- Consistent S3 identity mapping across all platforms

This solution maintains security best practices while providing a seamless user experience that matches the iOS/macOS implementation.