# Apple Sign In Implementation

Complete guide for Apple Sign In across all platforms.

## Platform Support

### iOS/macOS (Native)
- Direct integration with AuthenticationServices framework
- Native UI with system-provided buttons
- Automatic credential management
- Biometric authentication support

### Android (Web Bridge)
- OAuth2 web flow with custom bridge
- JWT token exchange for compatibility
- WebView integration with interceptor
- Secure credential handling

## iOS/macOS Implementation

### Setup
```swift
import AuthenticationServices

// Configure button
SignInWithAppleButton(.signIn) { request in
    request.requestedScopes = [.email, .fullName]
    request.nonce = sha256(nonce)
}
.onCompletion { result in
    // Handle authentication
}
```

### Key Features
- Automatic account creation
- Keychain integration
- Sign in with Apple ID saved passwords
- Platform-native experience

## Android Implementation

### Overview
Android requires a web-based OAuth flow since Apple doesn't provide a native Android SDK. The implementation uses a WebView bridge to handle Apple's form_post response.

### Core Components

#### 1. JWT Token Exchange
Apple's web OAuth returns an authorization code that must be exchanged for tokens. This requires a JWT client secret signed with ES256.

```kotlin
// Backend generates JWT client secret
val clientSecret = JWT.create()
    .withKeyId(keyId)
    .withIssuer(teamId)
    .withSubject(clientId)
    .withAudience("https://appleid.apple.com")
    .withIssuedAt(Date())
    .withExpiresAt(Date(System.currentTimeMillis() + 15778476000))
    .sign(Algorithm.ECDSA256(privateKey))
```

#### 2. WebView Bridge
Intercepts Apple's form_post response and extracts the authorization code:

```kotlin
webView.webViewClient = object : WebViewClient() {
    override fun shouldInterceptRequest(
        view: WebView?,
        request: WebResourceRequest?
    ): WebResourceResponse? {
        if (request?.url?.toString() == redirectUri) {
            // Extract code from form_post
            return createInterceptorResponse()
        }
        return super.shouldInterceptRequest(view, request)
    }
}
```

#### 3. Authentication Flow
1. User taps "Sign in with Apple"
2. WebView loads Apple OAuth URL
3. User authenticates with Apple
4. Bridge intercepts form_post response
5. Authorization code sent to backend
6. Backend exchanges code for tokens using JWT
7. User profile created/retrieved
8. Credentials stored securely

### Known Issues and Solutions

#### Authorization Code Exchange
**Problem**: Standard authorization_code exchange fails with "invalid_grant"
**Solution**: Generate JWT client secret with proper ES256 signing

#### User ID Format
**Problem**: Mismatch between Apple user ID formats
**Solution**: Consistent formatting as `appleid:{sub}` across platforms

#### Navigation Timing
**Problem**: WebView closes before response processing
**Solution**: Delayed navigation with proper state management

## Backend Integration

### Token Validation
```javascript
// Verify Apple ID token
const decodedToken = jwt.decode(idToken, { complete: true });
const { kid, alg } = decodedToken.header;

// Fetch Apple's public keys
const keys = await fetchApplePublicKeys();
const key = keys.find(k => k.kid === kid);

// Verify token signature
jwt.verify(idToken, key, { algorithms: ['RS256'] });
```

### User Profile Management
- Extract user info from ID token
- Create/update user profile
- Map Apple ID to internal UUID
- Handle account linking

## Security Considerations

1. **Nonce Validation**: Prevent replay attacks
2. **State Parameter**: CSRF protection
3. **Secure Storage**: Keychain/Encrypted preferences
4. **HTTPS Only**: All API communications
5. **Token Expiration**: Proper refresh handling

## Testing

### Test Accounts
- Use real Apple IDs (test accounts don't work)
- Test account creation and sign in
- Verify cross-platform compatibility
- Test account linking scenarios

### Debug Commands
```bash
# Decode Apple JWT
scripts/decode-apple-jwt.sh <jwt_token>

# Check S3 identity
scripts/check-s3-identities.sh
```

## Troubleshooting

### Common Issues

1. **"Invalid grant" error**
   - Verify JWT signing algorithm (ES256)
   - Check client secret expiration
   - Ensure proper key format

2. **WebView not loading**
   - Check network connectivity
   - Verify redirect URI configuration
   - Ensure JavaScript is enabled

3. **Token validation failures**
   - Verify Apple public keys are current
   - Check token expiration
   - Validate nonce matches

## Implementation Files

### iOS/macOS
- `AuthenticationService.swift` - Core authentication
- `SignInView.swift` - UI components
- `KeychainManager.swift` - Credential storage

### Android
- `AppleSignInActivity.kt` - WebView implementation
- `AppleAuthInterceptor.kt` - Response handling
- `AuthenticationViewModel.kt` - Business logic
- `TokenManager.kt` - Credential management

### Backend
- `auth/apple.js` - Token validation
- `auth/jwt.js` - JWT generation
- `models/User.js` - User management