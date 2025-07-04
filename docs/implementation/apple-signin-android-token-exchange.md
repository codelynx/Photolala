# Apple Sign-In Android Token Exchange Implementation

## Overview

This document describes the implementation of Apple Sign-In token exchange on Android, which solves the cross-platform authentication issue where Android users couldn't sign in with Apple accounts created on iOS/macOS.

## Problem Solved

- **Issue**: Android was using authorization codes as user IDs instead of the actual Apple user ID
- **Root Cause**: Apple's web OAuth flow only provides ID tokens on first authorization
- **Solution**: Implement token exchange to get ID tokens on subsequent sign-ins

## Implementation Details

### 1. Credential Storage

The Apple private key is securely stored using credential-code:

```json
// .credential-code/credentials.json
{
  "credentials": {
    "APPLE_PRIVATE_KEY": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
  }
}
```

### 2. AppleAuthService Updates

#### Configuration Constants

```kotlin
companion object {
    const val TEAM_ID = "2P97EM4L4N"
    const val SERVICE_ID = "com.electricwoods.photolala.android"
    const val KEY_ID = "YOUR_KEY_ID"  // TODO: Replace with actual Key ID
}
```

#### Client Secret Generation

```kotlin
private fun generateClientSecret(): String {
    val privateKeyPEM = Credentials.decrypt(CredentialKey.APPLE_PRIVATE_KEY)
    // Parse and use private key to sign JWT
    return Jwts.builder()
        .setHeaderParam("kid", KEY_ID)
        .setIssuer(TEAM_ID)
        .setAudience("https://appleid.apple.com")
        .setSubject(SERVICE_ID)
        .signWith(privateKey, SignatureAlgorithm.ES256)
        .compact()
}
```

#### Token Exchange

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
    
    // POST to Apple's token endpoint
    // Parse response to get ID token
}
```

#### Updated Callback Handling

```kotlin
fun handleCallback(uri: Uri): Boolean {
    scope.launch {
        val tokenData = when {
            idToken != null -> parseIdToken(idToken)  // First sign-in
            code != null -> {
                val response = exchangeCodeForTokens(code)  // Subsequent sign-in
                parseIdToken(response.idToken)
            }
        }
        
        // Create credential with correct Apple user ID
        val credential = AuthCredential(
            providerID = tokenData.sub,  // Always use JWT sub field
            // ... other fields
        )
    }
}
```

### 3. Dependencies Added

```gradle
// Apple Sign-In dependencies
implementation("com.squareup.okhttp3:okhttp:4.11.0")
implementation("com.google.code.gson:gson:2.10.1")
implementation("io.jsonwebtoken:jjwt-api:0.11.5")
runtimeOnly("io.jsonwebtoken:jjwt-impl:0.11.5")
runtimeOnly("io.jsonwebtoken:jjwt-jackson:0.11.5")
```

## Setup Requirements

### 1. Apple Developer Portal

1. Create a Sign in with Apple key
2. Download the .p8 private key file
3. Note the Key ID (10-character string)
4. Create Service ID: `com.electricwoods.photolala.android`

### 2. Update Credentials

1. Add private key to `.credential-code/credentials.json`
2. Run `./scripts/generate-credentials.sh`
3. Update `KEY_ID` constant in AppleAuthService.kt

### 3. Configure Service ID

In Apple Developer Portal:
1. Enable Sign in with Apple for the Service ID
2. Configure domains and return URLs:
   - Domain: `photolala.eastlynx.com`
   - Return URL: `https://photolala.eastlynx.com/auth/apple/callback`

## Testing

1. **First-time sign in**: Should receive ID token directly
2. **Subsequent sign in**: Should exchange code for tokens
3. **Cross-platform**: Create account on iOS, sign in on Android
4. **Verify**: Check S3 identity mapping uses correct Apple user ID

## Security Considerations

1. **Private Key**: Encrypted using credential-code, never in source control
2. **Client Secret**: Generated on-demand with 6-month expiry
3. **Token Exchange**: Uses HTTPS for all communication
4. **Nonce Validation**: Prevents replay attacks

## Troubleshooting

### Common Issues

1. **"Failed to decrypt Apple private key"**
   - Ensure credentials.json has the private key
   - Run generate-credentials.sh
   - Check Credentials.kt exists

2. **"Token exchange failed: 400"**
   - Verify KEY_ID is correct
   - Check Service ID configuration
   - Ensure authorization code hasn't expired

3. **"Invalid client"**
   - Service ID must match exactly
   - Redirect URI must be configured in Apple Developer Portal

## Future Improvements

1. **Cache client secrets**: Reuse until near expiry
2. **Refresh token support**: Implement token refresh flow
3. **Server-side option**: Move token exchange to backend for enhanced security