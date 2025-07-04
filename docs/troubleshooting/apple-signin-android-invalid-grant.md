# Troubleshooting: Apple Sign-In "invalid_grant" Error on Android

## Error Description

When attempting token exchange, Apple returns:
```json
{"error":"invalid_grant"}
```

## Common Causes and Solutions

### 1. Response Mode Mismatch

**Issue**: The authorization request uses `response_mode=form_post` but Android expects query parameters.

**Solution**: Changed to `response_mode=query` in the authorization request.

### 2. Authorization Code Already Used

**Issue**: Apple authorization codes are single-use only. If you've attempted token exchange before, the code is invalid.

**Solution**: 
- Sign out and sign in again to get a fresh code
- Ensure token exchange only happens once per authorization

### 3. Code Expiration

**Issue**: Authorization codes expire after 5 minutes.

**Solution**: 
- Ensure token exchange happens immediately after receiving the code
- Check if there are delays in the callback handling

### 4. Redirect URI Mismatch

**Issue**: The redirect_uri in token exchange must exactly match the one used in authorization.

**Current Configuration**:
- Redirect URI: `https://photolala.eastlynx.com/auth/apple/callback`
- Must be configured in Apple Developer Portal under Service ID

### 5. Service ID Configuration

**Check in Apple Developer Portal**:

1. Go to Certificates, Identifiers & Profiles → Identifiers
2. Find Service ID: `com.electricwoods.photolala.android`
3. Click "Sign in with Apple" → Configure
4. Verify:
   - Primary App ID is set
   - Domain: `photolala.eastlynx.com`
   - Return URL: `https://photolala.eastlynx.com/auth/apple/callback`

### 6. Deep Link Configuration

**Check Android Manifest**:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="photolala.eastlynx.com"
        android:pathPrefix="/auth/apple/callback" />
</intent-filter>
```

## Debugging Steps

1. **Check Logs** for:
   - Team ID, Service ID, Key ID values
   - Authorization code format
   - Client secret generation

2. **Verify Timeline**:
   - Note when authorization code is received
   - Check how long before token exchange attempt
   - Ensure < 5 minutes elapsed

3. **Test Fresh Sign-In**:
   - Clear app data
   - Sign in with Apple again
   - Watch for immediate token exchange

4. **Verify Callback Handling**:
   - Check if deep link is properly intercepted
   - Ensure query parameters are parsed correctly
   - Verify state parameter matches

## Alternative: Test with Shorter Client Secret Expiry

Try generating client secret with shorter expiry to test:
```kotlin
val expiration = Date(now.time + 3600 * 1000L) // 1 hour instead of 180 days
```

## If All Else Fails

1. **Create New Service ID**: Sometimes Apple's configuration gets stuck
2. **Regenerate Private Key**: Create new key in Apple Developer Portal
3. **Check Apple System Status**: https://developer.apple.com/system-status/