# Apple Sign-In Android Implementation

## Overview

This document details the complete implementation of Apple Sign-In on Android for the Photolala app, enabling cross-platform authentication compatibility with iOS/macOS users.

## Problem Statement

### Original Issue
Android users could not sign in with Apple accounts created on iOS/macOS because:

1. **User ID Format Mismatch**: Android was using authorization codes as user IDs instead of extracting the actual Apple user ID from JWT tokens
2. **S3 Identity Mapping Inconsistency**: Different platforms were storing different identifiers in S3
3. **Token Exchange Missing**: Android wasn't performing token exchange to get ID tokens when Apple doesn't provide them directly

### Cross-Platform Requirement
Users should be able to:
- Create an Apple account on macOS/iOS
- Sign in with the same Apple account on Android
- Access the same cloud photos and backup data across all platforms

## Technical Solution

### 1. JWT Token Exchange Implementation

**Problem**: Apple's web OAuth flow only provides ID tokens on first authorization. Subsequent sign-ins only provide authorization codes.

**Solution**: Implemented server-side token exchange using Apple's REST API.

#### Key Components:

**AppleAuthService.kt** - Core token exchange logic:
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

**Client Secret Generation** - ES256 JWT signing:
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

### 2. Secure Credential Management

**Integration with credential-code system**:

Updated `.credential-code/credentials.json`:
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

**Credentials.kt** - Added Apple credential key:
```kotlin
enum class CredentialKey(val key: String) {
    AWS_ACCESS_KEY_ID("AWS_ACCESS_KEY_ID"),
    AWS_SECRET_ACCESS_KEY("AWS_SECRET_ACCESS_KEY"),
    AWS_DEFAULT_REGION("AWS_DEFAULT_REGION"),
    APPLE_PRIVATE_KEY("APPLE_PRIVATE_KEY")
}
```

### 3. Apple Developer Configuration

**Required Apple Developer Setup**:
- **Team ID**: `2P97EM4L4N`
- **Service ID**: `com.electricwoods.photolala.android`
- **Key ID**: `FPZRF65BMT`
- **Private Key**: ES256 key for JWT signing
- **Redirect URI**: `https://photolala.eastlynx.com/auth/apple/callback`

### 4. S3 Identity Mapping Format

**Standardized Identity Key Format**:
```
identities/{provider}:{providerID}
```

**Examples**:
- Apple: `identities/apple:001196.9c1591b8ce9246eeb78b745667d8d7b6.0842`
- Google: `identities/google:1234567890`

**Content**: Service User ID (UUID) as file content

### 5. Async Processing and Navigation

**Race Condition Fix**:

**Problem**: `AppleAuthService.handleCallback()` returned immediately but processed authentication asynchronously.

**Solution**: `IdentityManager` waits for auth state update:
```kotlin
val authState = appleAuthService.authState
    .first { state -> 
        state !is AppleAuthState.Loading && state !is AppleAuthState.Idle 
    }
```

**Event Bus Pattern**:
```kotlin
// AuthenticationEventBus.kt
suspend fun emitAppleSignInCompleted() {
    _events.emit(AuthEvent.AppleSignInCompleted)
}

// AuthenticationViewModel.kt
authEventBus.events.onEach { event ->
    when (event) {
        is AuthEvent.AppleSignInCompleted -> {
            pendingAppleSignInSuccessCallback?.invoke()
        }
    }
}
```

### 6. UI State Management

**Welcome Screen Signed-In State**:
```kotlin
// WelcomeScreen.kt
if (isSignedIn && currentUser != null) {
    SignedInCard(user = currentUser!!, onSignOut = viewModel::signOut)
}

// Hide sign-in buttons when signed in
if (!isSignedIn) {
    // Show sign-in/create account buttons
}
```

**SignedInCard Component** - Matches iOS implementation:
- Profile icon (50dp)
- "Signed in as" label
- User display name
- User email (if available)
- Red sign-out button

## Implementation Files

### Core Authentication Files

1. **AppleAuthService.kt** - Complete rewrite
   - JWT token exchange
   - Client secret generation
   - OAuth flow handling
   - Async state management

2. **IdentityManager.kt** - Major updates
   - Apple Sign-In callback handling
   - Async processing coordination
   - Event bus integration
   - S3 identity mapping

3. **AuthenticationViewModel.kt** - Enhanced
   - Event bus listener
   - Navigation coordination
   - Callback management

### UI Components

4. **WelcomeScreen.kt** - Enhanced debugging
   - State logging
   - iOS-like signed-in display

5. **AuthenticationScreen.kt** - Navigation fix
   - Separated Google/Apple callback handling
   - Prevented duplicate navigation

6. **PhotolalaNavigation.kt** - Enhanced logging
   - Navigation tracking
   - State management

### Infrastructure

7. **MainActivity.kt** - Deep link handling
   - Apple callback processing
   - Enhanced logging

8. **Credentials.kt** - Apple key support
   - New credential key enum

9. **build.gradle.kts** - Dependencies
   - JWT library integration

## Authentication Flow

### Complete Apple Sign-In Flow:

1. **Initiation**: User taps "Sign in with Apple"
2. **Browser Launch**: Chrome Custom Tabs opens Apple OAuth
3. **User Authentication**: User authenticates with Apple
4. **Deep Link Callback**: Browser redirects to `photolala://auth/apple`
5. **MainActivity Processing**: Deep link handler processes callback
6. **Token Exchange**: Authorization code exchanged for ID token
7. **JWT Parsing**: Extract user ID and email from ID token
8. **S3 Lookup**: Check for existing user with `identities/apple:{userID}`
9. **User State Update**: Update IdentityManager state
10. **Event Bus Emission**: Emit Apple Sign-In completion event
11. **Navigation**: AuthenticationViewModel receives event and navigates
12. **Welcome Screen**: Shows signed-in state with user profile

## Security Considerations

### Secure Key Management
- Apple private key encrypted using credential-code
- Keys never stored in plain text
- Automatic key rotation supported

### OAuth Security
- PKCE (Proof Key for Code Exchange) implementation
- State parameter validation
- Nonce validation for replay attack prevention
- HTTPS-only redirect URIs

### JWT Validation
- Proper signature verification
- Audience validation
- Expiry time checking
- Issuer validation

## Testing and Debugging

### Debug Logging
Comprehensive logging throughout the flow:
- Deep link processing
- Token exchange requests/responses
- JWT parsing details
- State transitions
- Navigation events

### Test Scenarios
1. **Cross-Platform Sign-In**: Create account on iOS, sign in on Android
2. **Subsequent Sign-Ins**: Multiple sign-ins after initial setup
3. **Error Handling**: Network failures, invalid tokens, user cancellation
4. **Navigation Flow**: Proper return to welcome screen
5. **State Persistence**: App restart with existing user

## Troubleshooting

### Common Issues

1. **"NoSuchKey" in S3**
   - Check identity mapping format
   - Verify user ID extraction from JWT
   - Confirm S3 bucket permissions

2. **"invalid_grant" during token exchange**
   - Verify client secret generation
   - Check Apple Developer configuration
   - Confirm redirect URI matches

3. **Navigation not working**
   - Check event bus emission
   - Verify callback timing
   - Review async processing logs

### Debug Commands
```bash
# Check S3 identity mappings
aws s3 ls s3://photolala-main/identities/ --recursive

# Decode Apple JWT locally
./scripts/decode-apple-jwt.sh <jwt_token>

# Clear test data
./scripts/clear-s3-test-data.sh
```

## Performance Considerations

### Async Processing
- Non-blocking token exchange using coroutines
- Proper UI state management during loading
- Timeout handling for network requests

### Caching
- Auth state caching in IdentityManager
- Credential validation on app startup
- S3 identity mapping verification

## Future Enhancements

1. **Token Refresh**: Implement refresh token handling
2. **Biometric Auth**: Add biometric authentication for subsequent sign-ins
3. **Migration Tools**: User migration utilities for platform switches
4. **Analytics**: Authentication flow analytics and error tracking
5. **Testing**: Automated testing for authentication flows

## Dependencies Added

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

## Conclusion

The Apple Sign-In implementation provides seamless cross-platform authentication, allowing users to sign in with the same Apple account across iOS, macOS, and Android platforms. The implementation follows security best practices and maintains consistency with the existing authentication architecture.

The solution properly handles the complexities of Apple's OAuth flow on Android, including token exchange, JWT parsing, and async state management, while providing a user experience that matches the iOS implementation.