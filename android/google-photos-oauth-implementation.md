# Google Photos OAuth2 Implementation Guide

## Current Status

The Google Photos browser implementation is complete except for OAuth2 token exchange. The API client and all features are ready, but we need to obtain an OAuth2 access token to make API calls.

## The Challenge

Google Sign-In provides:
- ID Token (for identity verification)
- Server Auth Code (one-time use)

Google Photos API requires:
- OAuth2 Access Token

## Implementation Options

### Option 1: Server-Side Token Exchange (Recommended for Production)

1. Send the server auth code to your backend
2. Backend exchanges it for access/refresh tokens
3. Backend returns access token to the app
4. App uses access token for API calls

**Pros:**
- Most secure approach
- Refresh token stays on server
- Can implement token rotation

**Cons:**
- Requires backend implementation
- More complex setup

### Option 2: Direct Token Request with GoogleAuthUtil (Testing Only)

```kotlin
// In GoogleAuthTokenProvider.kt
val account = Account(googleAccount.email, "com.google")
val token = GoogleAuthUtil.getToken(
    context, 
    account, 
    "oauth2:https://www.googleapis.com/auth/photoslibrary.readonly"
)
```

**Pros:**
- Works immediately for testing
- No backend required

**Cons:**
- Requires GET_ACCOUNTS permission
- May not work on all devices
- Not recommended for production

### Option 3: Use Google Identity Services (Web-based flow)

1. Open a web view with OAuth2 consent flow
2. Capture the authorization code
3. Exchange for tokens directly

**Pros:**
- Works without backend
- Standard OAuth2 flow

**Cons:**
- More complex UX
- Requires careful security handling

## Quick Testing Solution

For immediate testing, update `GooglePhotosServiceImpl.getApiClient()`:

```kotlin
private suspend fun getApiClient(): GooglePhotosApiClient = withContext(ioDispatcher) {
    val account = GoogleSignIn.getLastSignedInAccount(context)
        ?: throw GooglePhotosException.NotSignedIn
    
    if (!googleSignInLegacyService.hasGooglePhotosScope()) {
        throw GooglePhotosException.AuthorizationRequired
    }
    
    // For testing only - requires GET_ACCOUNTS permission
    try {
        val androidAccount = Account(account.email, "com.google")
        val token = GoogleAuthUtil.getToken(
            context,
            androidAccount,
            "oauth2:https://www.googleapis.com/auth/photoslibrary.readonly"
        )
        
        if (cachedToken != token) {
            cachedToken = token
            apiClient = GooglePhotosApiClient(token)
        }
        
        return apiClient!!
    } catch (e: Exception) {
        Log.e(TAG, "Failed to get token", e)
        throw GooglePhotosException.InvalidToken
    }
}
```

## Required AndroidManifest.xml Permissions

```xml
<!-- Required for GoogleAuthUtil -->
<uses-permission android:name="android.permission.GET_ACCOUNTS" />
<uses-permission android:name="android.permission.USE_CREDENTIALS" />
```

## Testing Steps

1. Add the permissions to AndroidManifest.xml
2. Update GooglePhotosServiceImpl with the testing code
3. Run the app and sign in with Google Photos scope
4. The Google Photos browser should now work

## Production Implementation

For production, implement a backend endpoint:

```
POST /api/auth/google/token
Body: { "authCode": "..." }
Response: { "accessToken": "...", "expiresIn": 3600 }
```

Then update the app to call this endpoint instead of using GoogleAuthUtil.

## Current Implementation Status

✅ Google Photos API client
✅ Photo listing and pagination
✅ Album support
✅ URL caching with expiration
✅ UI components
✅ Selection and starring
❌ OAuth2 token exchange

The only missing piece is obtaining the OAuth2 access token. Once that's resolved, the Google Photos browser will be fully functional.