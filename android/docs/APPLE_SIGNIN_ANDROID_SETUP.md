# Apple Sign-In for Android - Developer Setup Guide

## Overview

This guide covers the complete setup and implementation of Apple Sign-In for Android developers. Apple doesn't provide a native Android SDK, so we implement it using web-based OAuth with token exchange.

## Prerequisites

### Apple Developer Account Requirements
- Active Apple Developer Program membership ($99/year)
- Access to Apple Developer Portal
- Team ID and Bundle IDs configured

### Android Development Setup
- Android Studio with Kotlin support
- Min SDK 24+ (recommended 33+)
- Chrome Custom Tabs support
- Network permissions

## Apple Developer Portal Configuration

### 1. Create App ID
1. Go to Apple Developer Portal → Certificates, Identifiers & Profiles
2. Create new App ID for your iOS app (if not existing)
3. Enable "Sign in with Apple" capability
4. Note your Team ID (found in membership details)

### 2. Create Service ID
This is the crucial step for Android integration:

1. Go to Identifiers → Register a new identifier
2. Select "Services IDs"
3. Create Service ID (e.g., `com.yourapp.android`)
4. Description: "YourApp Android Sign-In"
5. **Enable "Sign in with Apple"**
6. Configure domains and redirect URLs:
   - Domain: `yourdomain.com` (must be a real domain you control)
   - Redirect URL: `https://yourdomain.com/auth/apple/callback`

**Important:** The redirect URL must be HTTPS and publicly accessible.

### 3. Create Private Key
1. Go to Keys → Register a new key
2. Key Name: "Apple Sign-In Key"
3. **Enable "Sign in with Apple"**
4. Register and download the `.p8` file
5. **Note the Key ID** (10-character string)
6. **Save the private key securely** - you can't download it again

### 4. Configure Service ID
1. Return to your Service ID
2. Click "Configure" next to Sign in with Apple
3. Select your App ID as the Primary App ID
4. Add your domain and redirect URL
5. Save configuration

## Android Project Setup

### 1. Add Dependencies

Add to `app/build.gradle.kts`:

```kotlin
dependencies {
    // JWT handling for Apple token exchange
    implementation("io.jsonwebtoken:jjwt-api:0.11.5")
    implementation("io.jsonwebtoken:jjwt-impl:0.11.5") 
    implementation("io.jsonwebtoken:jjwt-jackson:0.11.5")
    
    // HTTP client for token exchange
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    
    // JSON parsing
    implementation("com.google.code.gson:gson:2.8.9")
    
    // Chrome Custom Tabs
    implementation("androidx.browser:browser:1.7.0")
}
```

### 2. Configure Deep Links

Add to `AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true">
    
    <!-- Your existing intent filters -->
    
    <!-- Apple Sign-In deep link -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="yourapp" 
              android:host="auth" 
              android:path="/apple" />
    </intent-filter>
</activity>
```

**Note:** Replace `yourapp` with your app's custom scheme.

### 3. Secure Credential Storage

Use encrypted storage for Apple private key:

```kotlin
// Store Apple configuration
object AppleConfig {
    const val TEAM_ID = "YOUR_TEAM_ID"          // 10 characters
    const val SERVICE_ID = "com.yourapp.android" // Your Service ID
    const val KEY_ID = "YOUR_KEY_ID"            // 10 characters
    const val REDIRECT_URI = "https://yourdomain.com/auth/apple/callback"
    
    // Private key stored securely (use credential-code or similar)
    fun getPrivateKey(): String {
        // Return encrypted/secure private key
        return CredentialManager.getApplePrivateKey()
    }
}
```

## Implementation Architecture

### 1. AppleAuthService

Main service handling OAuth flow:

```kotlin
@Singleton
class AppleAuthService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val _authState = MutableStateFlow<AppleAuthState>(AppleAuthState.Idle)
    val authState: StateFlow<AppleAuthState> = _authState
    
    fun signIn() {
        // 1. Generate security parameters (state, nonce, PKCE)
        // 2. Build authorization URL
        // 3. Launch Chrome Custom Tabs
    }
    
    fun handleCallback(uri: Uri): Boolean {
        // 1. Validate state parameter
        // 2. Extract authorization code
        // 3. Exchange code for tokens (async)
        // 4. Parse JWT and extract user info
        // 5. Update auth state
    }
}
```

### 2. Token Exchange Process

The critical difference from iOS implementation:

```kotlin
private suspend fun exchangeCodeForTokens(code: String): AppleTokenResponse {
    // 1. Generate client secret (ES256 JWT)
    val clientSecret = generateClientSecret()
    
    // 2. POST to Apple's token endpoint
    val response = httpClient.post("https://appleid.apple.com/auth/token") {
        setBody(FormDataContent(Parameters.build {
            append("client_id", SERVICE_ID)
            append("client_secret", clientSecret)
            append("code", code)
            append("grant_type", "authorization_code")
            append("redirect_uri", REDIRECT_URI)
        }))
    }
    
    // 3. Parse response and return tokens
    return gson.fromJson(response.body, AppleTokenResponse::class.java)
}
```

### 3. Client Secret Generation

Apple requires ES256-signed JWT for authentication:

```kotlin
private fun generateClientSecret(): String {
    val privateKey = loadPrivateKey() // Your .p8 key content
    
    val jwt = Jwts.builder()
        .setHeaderParam("kid", KEY_ID)
        .setHeaderParam("alg", "ES256")
        .setIssuer(TEAM_ID)
        .setAudience("https://appleid.apple.com")
        .setSubject(SERVICE_ID)
        .setIssuedAt(Date())
        .setExpiration(Date(System.currentTimeMillis() + 180 * 24 * 60 * 60 * 1000L)) // 180 days
        .signWith(privateKey, SignatureAlgorithm.ES256)
        .compact()
        
    return jwt
}
```

## User Identity Handling

### Extract Apple User ID

Critical for cross-platform compatibility:

```kotlin
private fun parseIdToken(token: String): AppleUserData {
    val parts = token.split(".")
    val payload = String(Base64.getUrlDecoder().decode(parts[1]))
    
    // Parse JWT payload
    val gson = Gson()
    val claims = gson.fromJson(payload, JsonObject::class.java)
    
    return AppleUserData(
        userID = claims.get("sub").asString,  // CRITICAL: Use 'sub' field
        email = claims.get("email")?.asString,
        isPrivateEmail = claims.get("is_private_email")?.asBoolean ?: false
    )
}
```

**Important:** Always use the `sub` field as the user identifier, not the email.

## Integration with Authentication System

### 1. Identity Manager Integration

```kotlin
suspend fun signInWithApple(): Result<User> {
    return try {
        // Start Apple Sign-In flow
        appleAuthService.signIn()
        
        // Wait for completion
        val authState = appleAuthService.authState.first { 
            it !is AppleAuthState.Loading 
        }
        
        when (authState) {
            is AppleAuthState.Success -> {
                val credential = authState.credential
                // Create user account or sign in existing user
                processAppleCredential(credential)
            }
            is AppleAuthState.Error -> Result.failure(authState.error)
            is AppleAuthState.Cancelled -> Result.failure(UserCancelledException())
            else -> Result.failure(UnknownException())
        }
    } catch (e: Exception) {
        Result.failure(e)
    }
}
```

### 2. Cross-Platform User Mapping

For apps with iOS/macOS versions:

```kotlin
// Store user mapping in backend/S3
private suspend fun createUserMapping(appleUserID: String, serviceUserID: String) {
    val identityKey = "apple:$appleUserID"
    val identityPath = "identities/$identityKey"
    
    // Store mapping: Apple User ID -> Your Service User ID
    s3Service.uploadData(
        data = serviceUserID.toByteArray(),
        key = identityPath
    )
}

// Lookup existing user
private suspend fun findExistingUser(appleUserID: String): String? {
    val identityKey = "apple:$appleUserID"
    val identityPath = "identities/$identityKey"
    
    return try {
        val data = s3Service.downloadData(identityPath).getOrNull()
        data?.let { String(it) }
    } catch (e: Exception) {
        null // User doesn't exist
    }
}
```

## Error Handling

### Common Issues and Solutions

1. **"invalid_grant" Error**
   - Check client secret generation
   - Verify Service ID configuration
   - Ensure redirect URI matches exactly

2. **Deep Link Not Working**
   - Verify intent filter configuration
   - Test with ADB: `adb shell am start -W -a android.intent.action.VIEW -d "yourapp://auth/apple?code=test"`
   - Check domain verification

3. **JWT Parsing Errors**
   - Verify Base64 URL decoding
   - Check JWT structure (3 parts separated by dots)
   - Validate JWT signature if needed

### Error Recovery

```kotlin
sealed class AppleAuthError(val message: String) {
    class InvalidGrant(message: String) : AppleAuthError(message)
    class NetworkError(message: String) : AppleAuthError(message)
    class InvalidState(message: String) : AppleAuthError(message)
    class UserCancelled : AppleAuthError("User cancelled")
    class ConfigurationError(message: String) : AppleAuthError(message)
}

// Handle errors gracefully
when (error) {
    is AppleAuthError.UserCancelled -> {
        // Don't show error - user intentionally cancelled
    }
    is AppleAuthError.NetworkError -> {
        showRetryDialog("Network error. Please try again.")
    }
    is AppleAuthError.ConfigurationError -> {
        // Log for developers, show generic error to users
        Log.e("AppleAuth", "Configuration error: ${error.message}")
        showError("Sign in temporarily unavailable")
    }
    else -> {
        showError("Sign in failed: ${error.message}")
    }
}
```

## Testing

### 1. Development Testing

```kotlin
// Test with real Apple ID in debug builds
#if DEBUG
private fun enableTestMode() {
    // Use sandbox environment if available
    // Add extra logging
    // Allow HTTP redirect URLs for local testing
}
#endif
```

### 2. Deep Link Testing

Test deep link handling:

```bash
# Test deep link processing
adb shell am start \
  -W -a android.intent.action.VIEW \
  -d "yourapp://auth/apple?code=test_code&state=test_state" \
  com.yourpackage.name
```

### 3. Production Testing

- Test with real Apple IDs
- Verify cross-platform compatibility
- Test error scenarios (network failures, user cancellation)
- Verify user identity consistency

## Security Considerations

### 1. Private Key Security
- Never store private key in plain text
- Use encrypted storage or credential management
- Rotate keys periodically
- Monitor for key exposure

### 2. OAuth Security
- Always validate state parameter (CSRF protection)
- Implement nonce validation for replay protection
- Use HTTPS for all redirect URLs
- Validate JWT signatures in production

### 3. User Data
- Handle private email addresses appropriately
- Respect user privacy preferences
- Implement proper data retention policies
- Follow Apple's guidelines for user data handling

## Best Practices

### 1. User Experience
- Show clear loading states during auth flow
- Handle errors gracefully
- Provide fallback authentication methods
- Match Apple's design guidelines for buttons

### 2. Performance
- Cache JWT parsing results
- Implement request timeouts
- Use background processing for token exchange
- Optimize deep link handling

### 3. Maintenance
- Monitor Apple Developer Portal for changes
- Update JWT libraries regularly
- Test with new Android versions
- Keep documentation updated

## Apple Design Guidelines

### Sign-In Button Requirements

Follow Apple's guidelines for button appearance:

```xml
<!-- Apple Sign-In Button -->
<Button
    android:layout_width="match_parent"
    android:layout_height="44dp"
    android:background="@color/black"
    android:text="Sign in with Apple"
    android:textColor="@color/white"
    android:drawableStart="@drawable/apple_logo"
    android:fontFamily="sans-serif-medium" />
```

### Button Text Guidelines
- "Sign in with Apple" (first time)
- "Continue with Apple" (returning users)
- Never "Login with Apple" or other variations

## Conclusion

Apple Sign-In on Android requires more setup than iOS but provides seamless cross-platform authentication. Key success factors:

1. **Proper Apple Developer Portal configuration**
2. **Secure credential management**
3. **Robust error handling**
4. **Cross-platform user identity consistency**
5. **Following Apple's design guidelines**

The implementation provides enterprise-grade security while maintaining excellent user experience across platforms.

## Additional Resources

- [Apple Sign-In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Apple REST API Documentation](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api)
- [JWT.io for token debugging](https://jwt.io/)
- [Chrome Custom Tabs Documentation](https://developer.chrome.com/docs/android/custom-tabs/)

## Support

For implementation issues:
1. Check Apple Developer Portal configuration
2. Verify deep link handling
3. Test token exchange manually
4. Review security credentials
5. Check network connectivity and firewall settings