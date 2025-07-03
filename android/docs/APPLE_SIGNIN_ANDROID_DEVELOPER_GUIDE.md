# Complete Guide: Implementing Sign in with Apple on Android

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Apple Developer Setup](#apple-developer-setup)
4. [Android Project Setup](#android-project-setup)
5. [Implementation](#implementation)
6. [Common Issues and Solutions](#common-issues-and-solutions)
7. [Security Considerations](#security-considerations)
8. [Testing](#testing)
9. [Production Checklist](#production-checklist)

## Overview

Unlike iOS, Android doesn't have a native Sign in with Apple SDK. This guide provides a complete implementation using web-based OAuth 2.0 flow with Chrome Custom Tabs.

### Key Differences from iOS
- No native SDK - must use web OAuth flow
- Requires Service ID (not just App ID)
- Need to handle browser-to-app navigation
- More complex callback handling

## Prerequisites

### Apple Developer Account
- Enrolled in Apple Developer Program ($99/year)
- Access to Certificates, Identifiers & Profiles

### Android Requirements
- Android 5.0 (API 21) or higher
- Chrome Custom Tabs support
- Deep link handling capability

### Backend Requirements
- Server to host callback endpoint
- Ability to verify Apple tokens (optional but recommended)

## Apple Developer Setup

### 1. Create App ID (if not exists)
1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles → Identifiers
3. Click + and select "App IDs"
4. Choose "App" type
5. Fill in:
   - Description: `Your App Name`
   - Bundle ID: `com.yourcompany.yourapp` (explicit)
   - Enable "Sign in with Apple" capability

### 2. Create Service ID (Required for Android)
1. In Identifiers, click + and select "Services IDs"
2. Fill in:
   - Description: `Your App Name - Android`
   - Identifier: `com.yourcompany.yourapp.android`
3. Enable "Sign in with Apple"
4. Click Configure:
   - Primary App ID: Select your App ID
   - Register Website URLs:
     - Domain: `yourapp.com`
     - Return URL: `https://yourapp.com/auth/apple/callback`

### 3. Create and Configure Key
1. Navigate to Keys section
2. Create a new key with "Sign in with Apple" enabled
3. Configure the key:
   - Select your App ID
   - Download the .p8 file (keep it secure!)
   - Note the Key ID

## Android Project Setup

### 1. Add Dependencies

```kotlin
// app/build.gradle.kts
dependencies {
    // Chrome Custom Tabs for OAuth flow
    implementation("androidx.browser:browser:1.7.0")
    
    // Optional: For server communication
    implementation("io.ktor:ktor-client-core:2.3.7")
    implementation("io.ktor:ktor-client-cio:2.3.7")
    implementation("io.ktor:ktor-client-content-negotiation:2.3.7")
    implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.7")
    
    // Coroutines for async operations
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

### 2. Configure AndroidManifest.xml

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Internet permission -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application>
        <!-- Main Activity with deep link support -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop">
            
            <!-- Standard launch intent -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
            
            <!-- Deep link for Apple Sign In callback -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                
                <data
                    android:scheme="yourapp"
                    android:host="auth"
                    android:pathPrefix="/apple" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### 3. Create Apple Sign In Button Asset

```xml
<!-- res/drawable/ic_apple_logo.xml -->
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="@android:color/black"
        android:pathData="M18.71,19.5C17.88,20.74 17,21.95 15.66,21.97C14.32,22 13.89,21.18 12.37,21.18C10.84,21.18 10.37,21.95 9.09,22C7.78,22.05 6.8,20.68 5.96,19.47C4.25,17 2.94,12.45 4.7,9.39C5.57,7.87 7.13,6.91 8.82,6.88C10.1,6.86 11.32,7.75 12.11,7.75C12.89,7.75 14.37,6.68 15.92,6.84C16.57,6.87 18.39,7.1 19.56,8.82C19.47,8.88 17.39,10.1 17.41,12.63C17.44,15.65 20.06,16.66 20.09,16.67C20.06,16.74 19.67,18.11 18.71,19.5M13,3.5C13.73,2.67 14.94,2.04 15.94,2C16.07,3.17 15.6,4.35 14.9,5.19C14.21,6.04 13.07,6.7 11.95,6.61C11.8,5.46 12.36,4.26 13,3.5Z"/>
</vector>
```

## Implementation

### 1. Apple Auth Service

```kotlin
// AppleAuthService.kt
import android.content.Context
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AppleAuthService @Inject constructor(
    private val context: Context
) {
    companion object {
        const val SERVICE_ID = "com.yourcompany.yourapp.android"
        const val AUTH_ENDPOINT = "https://appleid.apple.com/auth/authorize"
        const val REDIRECT_URI = "https://yourapp.com/auth/apple/callback"
        const val SCOPE = "email name"
    }
    
    private var currentState: String? = null
    private var currentNonce: String? = null
    private var codeVerifier: String? = null
    
    private val _authState = MutableStateFlow<AppleAuthState>(AppleAuthState.Idle)
    val authState: StateFlow<AppleAuthState> = _authState
    
    fun signIn() {
        try {
            // Generate security parameters
            currentState = generateRandomString()
            currentNonce = generateRandomString()
            codeVerifier = generateCodeVerifier()
            val codeChallenge = generateCodeChallenge(codeVerifier!!)
            
            // Build authorization URL
            val authUrl = Uri.parse(AUTH_ENDPOINT).buildUpon().apply {
                appendQueryParameter("client_id", SERVICE_ID)
                appendQueryParameter("redirect_uri", REDIRECT_URI)
                appendQueryParameter("response_type", "code id_token")
                appendQueryParameter("scope", SCOPE)
                appendQueryParameter("response_mode", "form_post")
                appendQueryParameter("state", currentState)
                appendQueryParameter("nonce", currentNonce)
                appendQueryParameter("code_challenge", codeChallenge)
                appendQueryParameter("code_challenge_method", "S256")
            }.build()
            
            _authState.value = AppleAuthState.Loading
            
            // Launch Chrome Custom Tab
            val customTabsIntent = CustomTabsIntent.Builder()
                .setShowTitle(true)
                .setUrlBarHidingEnabled(true)
                .build()
                
            val packageName = CustomTabsClient.getPackageName(context, null)
            if (packageName != null) {
                customTabsIntent.launchUrl(context, authUrl)
            } else {
                // Fallback to default browser
                val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, authUrl)
                intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
            }
            
        } catch (e: Exception) {
            _authState.value = AppleAuthState.Error(e.message ?: "Failed to launch")
        }
    }
    
    fun handleCallback(uri: Uri): Boolean {
        val state = uri.getQueryParameter("state")
        val code = uri.getQueryParameter("code")
        val idToken = uri.getQueryParameter("id_token")
        val error = uri.getQueryParameter("error")
        
        // Handle errors
        if (error != null) {
            _authState.value = when (error) {
                "user_cancelled_authorize" -> AppleAuthState.Cancelled
                else -> AppleAuthState.Error(error)
            }
            cleanup()
            return true
        }
        
        // Validate state
        if (state != currentState) {
            _authState.value = AppleAuthState.Error("Invalid state - possible security issue")
            cleanup()
            return false
        }
        
        // Process successful authentication
        if (code != null) {
            val credential = AppleCredential(
                authorizationCode = code,
                identityToken = idToken,
                state = state
            )
            _authState.value = AppleAuthState.Success(credential)
            cleanup()
            return true
        }
        
        _authState.value = AppleAuthState.Error("Missing authorization code")
        cleanup()
        return false
    }
    
    private fun generateRandomString(length: Int = 32): String {
        val bytes = ByteArray(length)
        SecureRandom().nextBytes(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }
    
    private fun generateCodeVerifier(): String = generateRandomString(32)
    
    private fun generateCodeChallenge(verifier: String): String {
        val bytes = verifier.toByteArray()
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return Base64.getUrlEncoder().withoutPadding().encodeToString(digest)
    }
    
    private fun cleanup() {
        currentState = null
        currentNonce = null
        codeVerifier = null
    }
}

// State classes
sealed class AppleAuthState {
    object Idle : AppleAuthState()
    object Loading : AppleAuthState()
    object Cancelled : AppleAuthState()
    data class Success(val credential: AppleCredential) : AppleAuthState()
    data class Error(val message: String) : AppleAuthState()
}

data class AppleCredential(
    val authorizationCode: String,
    val identityToken: String?,
    val state: String?
)
```

### 2. MainActivity Setup

```kotlin
// MainActivity.kt
class MainActivity : AppCompatActivity() {
    
    private lateinit var appleAuthService: AppleAuthService
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize service
        appleAuthService = AppleAuthService(this)
        
        // Handle deep link if launched with one
        handleDeepLink(intent)
        
        // Your UI setup...
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleDeepLink(intent)
    }
    
    private fun handleDeepLink(intent: Intent?) {
        intent?.data?.let { uri ->
            if (uri.scheme == "yourapp" && uri.host == "auth" && uri.path == "/apple") {
                lifecycleScope.launch {
                    appleAuthService.handleCallback(uri)
                }
            }
        }
    }
}
```

### 3. UI Implementation (Compose)

```kotlin
// AppleSignInButton.kt
@Composable
fun AppleSignInButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true
) {
    Button(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(50.dp),
        enabled = enabled,
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Black,
            contentColor = Color.White
        ),
        shape = RoundedCornerShape(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center
        ) {
            Icon(
                painter = painterResource(id = R.drawable.ic_apple_logo),
                contentDescription = "Apple Logo",
                modifier = Modifier.size(20.dp),
                tint = Color.White
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "Sign in with Apple",
                fontSize = 17.sp,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

// Usage in your screen
@Composable
fun LoginScreen() {
    val appleAuthService = remember { AppleAuthService(LocalContext.current) }
    val authState by appleAuthService.authState.collectAsState()
    
    Column(
        modifier = Modifier.padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        AppleSignInButton(
            onClick = { appleAuthService.signIn() },
            enabled = authState !is AppleAuthState.Loading
        )
        
        // Handle auth state
        when (authState) {
            is AppleAuthState.Success -> {
                // Send credential to your backend
                LaunchedEffect(authState) {
                    sendToBackend((authState as AppleAuthState.Success).credential)
                }
            }
            is AppleAuthState.Error -> {
                Text(
                    text = "Error: ${(authState as AppleAuthState.Error).message}",
                    color = MaterialTheme.colorScheme.error
                )
            }
            else -> { /* Handle other states */ }
        }
    }
}
```

### 4. Backend Callback Handler

Your server needs to handle the callback from Apple. Here's a simple example:

```html
<!-- https://yourapp.com/auth/apple/callback -->
<!DOCTYPE html>
<html>
<head>
    <title>Signing in...</title>
    <script>
        // Parse form data posted by Apple
        const params = new URLSearchParams(window.location.search);
        const code = document.querySelector('input[name="code"]')?.value || params.get('code');
        const state = document.querySelector('input[name="state"]')?.value || params.get('state');
        const idToken = document.querySelector('input[name="id_token"]')?.value || params.get('id_token');
        
        // Redirect to app with parameters
        const appUrl = `yourapp://auth/apple?code=${code}&state=${state}&id_token=${idToken || ''}`;
        window.location.href = appUrl;
        
        // Fallback for older browsers
        setTimeout(() => {
            document.body.innerHTML = '<p>Please return to the app</p>';
        }, 1000);
    </script>
</head>
<body>
    <p>Redirecting to app...</p>
</body>
</html>
```

## Common Issues and Solutions

### 1. Navigation State Loss
**Problem**: App returns to wrong screen after authentication.

**Solution**: Use `singleTop` launch mode and save navigation state:
```kotlin
// Save state before launching browser
object NavigationState {
    var returnToScreen: String? = null
}

// Restore after auth
if (NavigationState.returnToScreen != null) {
    navController.navigate(NavigationState.returnToScreen!!)
    NavigationState.returnToScreen = null
}
```

### 2. App Gets Killed During Auth
**Problem**: Android kills app while in background.

**Solution**: Use persistent storage for auth parameters:
```kotlin
// Save to SharedPreferences before auth
prefs.edit()
    .putString("apple_auth_state", state)
    .putString("apple_auth_nonce", nonce)
    .apply()

// Restore when handling callback
val savedState = prefs.getString("apple_auth_state", null)
```

### 3. Callback URL Not Working
**Problem**: Deep link doesn't trigger app.

**Solutions**:
- Verify intent filter matches exactly
- Test with adb: `adb shell am start -W -a android.intent.action.VIEW -d "yourapp://auth/apple" com.yourapp`
- Check if another app is intercepting the URL

### 4. Invalid Client Error
**Problem**: Apple returns "invalid_client" error.

**Solutions**:
- Verify Service ID matches exactly
- Ensure redirect URI is registered in Apple Developer
- Check domain verification is complete

## Security Considerations

### 1. State Parameter
Always validate to prevent CSRF attacks:
```kotlin
if (receivedState != savedState) {
    throw SecurityException("State mismatch - possible CSRF attack")
}
```

### 2. Nonce Validation
Verify nonce in ID token:
```kotlin
val idTokenPayload = parseJWT(idToken)
if (idTokenPayload.nonce != savedNonce) {
    throw SecurityException("Nonce mismatch - possible replay attack")
}
```

### 3. Token Verification
Always verify tokens server-side:
- Validate JWT signature with Apple's public keys
- Check issuer is "https://appleid.apple.com"
- Verify audience matches your Service ID
- Check expiration time

### 4. Secure Storage
Never store sensitive data in:
- SharedPreferences (without encryption)
- Static variables
- Intent extras

Use Android Keystore for sensitive data.

## Testing

### 1. Test Scenarios
- [ ] Happy path: Complete sign in
- [ ] User cancels at Apple login
- [ ] User uses back button
- [ ] Network error during auth
- [ ] App killed during auth
- [ ] Invalid/expired tokens
- [ ] Deep link interception

### 2. Test Different Environments
- [ ] Different Android versions (5.0+)
- [ ] With/without Chrome installed
- [ ] Different default browsers
- [ ] Tablet vs phone
- [ ] Work profiles

### 3. Debugging Tips
```kotlin
// Enable Chrome Custom Tabs debugging
if (BuildConfig.DEBUG) {
    CustomTabsIntent.Builder()
        .setStartAnimations(this, android.R.anim.fade_in, android.R.anim.fade_out)
        .setExitAnimations(this, android.R.anim.fade_in, android.R.anim.fade_out)
        .enableUrlBarHiding()
        .setShowTitle(true)
        .build()
}

// Log all callback parameters
Log.d("AppleAuth", "Callback URI: $uri")
uri.queryParameterNames.forEach { param ->
    Log.d("AppleAuth", "$param = ${uri.getQueryParameter(param)}")
}
```

## Production Checklist

- [ ] Service ID configured correctly in Apple Developer
- [ ] Redirect URLs whitelisted
- [ ] Deep links tested on all target devices
- [ ] Error handling for all edge cases
- [ ] Analytics tracking for funnel analysis
- [ ] Secure token storage implementation
- [ ] Server-side token validation
- [ ] Privacy policy includes Apple Sign In
- [ ] App Store metadata mentions Apple Sign In
- [ ] Fallback for users without compatible browsers
- [ ] Proper loading states during auth
- [ ] Clear error messages for users
- [ ] Logout functionality implemented
- [ ] Account deletion compliance (Apple requirement)

## Additional Resources

- [Sign in with Apple Documentation](https://developer.apple.com/documentation/sign_in_with_apple)
- [Sign in with Apple REST API](https://developer.apple.com/documentation/sign_in_with_apple/sign_in_with_apple_rest_api)
- [Chrome Custom Tabs Documentation](https://developer.chrome.com/docs/android/custom-tabs)
- [Android App Links](https://developer.android.com/training/app-links)
- [JWT.io](https://jwt.io/) - For debugging tokens

## Sample Project Structure
```
app/
├── src/main/
│   ├── java/com/yourapp/
│   │   ├── auth/
│   │   │   ├── AppleAuthService.kt
│   │   │   ├── AppleAuthState.kt
│   │   │   └── AppleCredential.kt
│   │   ├── ui/
│   │   │   ├── components/
│   │   │   │   └── AppleSignInButton.kt
│   │   │   └── screens/
│   │   │       └── LoginScreen.kt
│   │   └── MainActivity.kt
│   └── res/
│       ├── drawable/
│       │   └── ic_apple_logo.xml
│       └── values/
│           └── strings.xml
└── build.gradle.kts
```

This implementation provides a robust foundation for Sign in with Apple on Android. Remember to adapt it to your specific architecture and requirements.