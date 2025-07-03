# Apple Sign-In Android Integration Guide

Last Updated: January 3, 2025

## Your Lambda Endpoint
```kotlin
const val APPLE_AUTH_ENDPOINT = "https://tygm499koc.execute-api.us-east-1.amazonaws.com"
```

## Step 1: Update Dependencies

Add to `app/build.gradle.kts`:

```kotlin
dependencies {
    // Chrome Custom Tabs for OAuth flow
    implementation("androidx.browser:browser:1.7.0")
    
    // HTTP client for Lambda calls
    implementation("io.ktor:ktor-client-core:2.3.7")
    implementation("io.ktor:ktor-client-cio:2.3.7")
    implementation("io.ktor:ktor-client-content-negotiation:2.3.7")
    implementation("io.ktor:ktor-serialization-kotlinx-json:2.3.7")
}
```

## Step 2: Update IdentityManager

Add these changes to `IdentityManager.kt`:

### Add Apple Auth Service Injection
```kotlin
@Singleton
class IdentityManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val s3Service: S3Service,
    private val preferencesManager: PreferencesManager,
    private val googleSignInLegacyService: GoogleSignInLegacyService,
    private val appleAuthService: AppleAuthService  // Add this
) {
```

### Update companion object
```kotlin
companion object {
    const val APPLE_AUTH_ENDPOINT = "https://tygm499koc.execute-api.us-east-1.amazonaws.com"
}
```

### Update authenticate method
```kotlin
private suspend fun authenticate(provider: AuthProvider): Result<AuthCredential> {
    return when (provider) {
        AuthProvider.GOOGLE -> authenticateWithGoogle()
        AuthProvider.APPLE -> authenticateWithApple()  // Change this
    }
}
```

### Add Apple authentication methods
```kotlin
// Add similar structure to Google for Apple
data class PendingAppleAuth(
    val authIntent: AuthIntent
)

var pendingAppleAuth: PendingAppleAuth? = null
    private set

// Apple authentication
private suspend fun authenticateWithApple(): Result<AuthCredential> {
    // Similar to Google, we return a special error to trigger the flow
    return Result.failure(AuthException.AppleSignInPending)
}

// Prepare Apple Sign-In
fun prepareAppleSignIn(authIntent: AuthIntent) {
    pendingAppleAuth = PendingAppleAuth(authIntent)
    appleAuthService.signIn()
}

// Handle Apple Sign-In callback
suspend fun handleAppleSignInCallback(uri: Uri): Result<PhotolalaUser> {
    val authIntent = pendingAppleAuth?.authIntent ?: AuthIntent.SIGN_IN
    pendingAppleAuth = null
    
    _isLoading.value = true
    _errorMessage.value = null
    
    return try {
        // Let AppleAuthService handle the callback
        if (!appleAuthService.handleCallback(uri)) {
            return Result.failure(AuthException.AuthenticationFailed("Invalid callback"))
        }
        
        // Wait for the auth state to update
        val authState = appleAuthService.authState.value
        when (authState) {
            is AppleAuthState.Success -> {
                val credential = authState.credential
                
                // Verify with Lambda and get user info
                val lambdaResponse = verifyAppleTokenWithLambda(credential.idToken!!)
                
                // Create AuthCredential with service user ID from Lambda
                val verifiedCredential = credential.copy(
                    serviceUserId = lambdaResponse.userId
                )
                
                // Continue with existing flow
                processAuthCredential(verifiedCredential, authIntent)
            }
            is AppleAuthState.Cancelled -> {
                _isLoading.value = false
                Result.failure(AuthException.UserCancelled)
            }
            is AppleAuthState.Error -> {
                _isLoading.value = false
                _errorMessage.value = authState.error.message
                Result.failure(AuthException.AuthenticationFailed(authState.error.message))
            }
            else -> {
                _isLoading.value = false
                Result.failure(AuthException.UnknownError)
            }
        }
    } catch (e: Exception) {
        _isLoading.value = false
        _errorMessage.value = e.message
        Result.failure(e)
    }
}

// Call Lambda to verify token
private suspend fun verifyAppleTokenWithLambda(idToken: String): AppleAuthResponse {
    return withContext(Dispatchers.IO) {
        val client = HttpClient(CIO) {
            install(ContentNegotiation) {
                json()
            }
        }
        
        try {
            val response: AppleAuthResponse = client.post(APPLE_AUTH_ENDPOINT) {
                contentType(ContentType.Application.Json)
                setBody(AppleAuthRequest(idToken = idToken))
            }.body()
            
            client.close()
            response
        } catch (e: Exception) {
            client.close()
            throw AuthException.NetworkError
        }
    }
}

// Data classes for Lambda communication
@Serializable
data class AppleAuthRequest(
    val idToken: String
)

@Serializable
data class AppleAuthResponse(
    val success: Boolean,
    val isNewUser: Boolean,
    val userId: String,
    val providerId: String,
    val email: String? = null
)
```

### Update AuthException
```kotlin
sealed class AuthException(message: String) : Exception(message) {
    // ... existing exceptions ...
    object AppleSignInPending : AuthException("Apple Sign-In pending")
}
```

## Step 3: Update MainActivity

Add Apple Sign-In callback handling:

```kotlin
class MainActivity : ComponentActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if this is an Apple Sign-In callback
        handleAppleSignInCallbackIfNeeded(intent)
        
        // ... rest of onCreate
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAppleSignInCallbackIfNeeded(intent)
    }
    
    private fun handleAppleSignInCallbackIfNeeded(intent: Intent) {
        intent.data?.let { uri ->
            if (uri.scheme == "photolala" && uri.host == "auth" && uri.path == "/apple") {
                // This is an Apple Sign-In callback
                lifecycleScope.launch {
                    identityManager.handleAppleSignInCallback(uri)
                }
            }
        }
    }
}
```

## Step 4: Update AuthenticationViewModel

Add Apple Sign-In handling:

```kotlin
fun handleAuthAction(action: AuthAction) {
    when (action) {
        is AuthAction.SignIn -> signIn(action.provider)
        is AuthAction.CreateAccount -> createAccount(action.provider)
    }
}

private fun signIn(provider: AuthProvider) {
    viewModelScope.launch {
        when (provider) {
            AuthProvider.GOOGLE -> {
                val result = identityManager.signIn(provider)
                if (result.isFailure && result.exceptionOrNull() is AuthException.GoogleSignInPending) {
                    val intent = identityManager.prepareGoogleSignIn(IdentityManager.AuthIntent.SIGN_IN)
                    launcher?.launch(intent)
                }
            }
            AuthProvider.APPLE -> {
                val result = identityManager.signIn(provider)
                if (result.isFailure && result.exceptionOrNull() is AuthException.AppleSignInPending) {
                    identityManager.prepareAppleSignIn(IdentityManager.AuthIntent.SIGN_IN)
                    // Apple Sign-In will open browser, no launcher needed
                }
            }
        }
    }
}
```

## Step 5: Update AuthenticationScreen UI

Make sure the Apple button is visible:

```kotlin
// In AuthenticationScreen.kt
if (authIntent == AuthIntent.SIGN_IN || authIntent == AuthIntent.CREATE_ACCOUNT) {
    // Google Sign-In Button
    OutlinedButton(
        onClick = { 
            viewModel.handleAuthAction(
                if (authIntent == AuthIntent.SIGN_IN) 
                    AuthAction.SignIn(AuthProvider.GOOGLE)
                else 
                    AuthAction.CreateAccount(AuthProvider.GOOGLE)
            )
        },
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.outlinedButtonColors()
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_google_logo),
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = Color.Unspecified
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = if (authIntent == AuthIntent.SIGN_IN) 
                "Sign in with Google" 
            else 
                "Sign up with Google"
        )
    }
    
    Spacer(modifier = Modifier.height(12.dp))
    
    // Apple Sign-In Button
    OutlinedButton(
        onClick = { 
            viewModel.handleAuthAction(
                if (authIntent == AuthIntent.SIGN_IN) 
                    AuthAction.SignIn(AuthProvider.APPLE)
                else 
                    AuthAction.CreateAccount(AuthProvider.APPLE)
            )
        },
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.outlinedButtonColors(
            containerColor = Color.Black,
            contentColor = Color.White
        ),
        border = BorderStroke(1.dp, Color.Black)
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_apple_logo),
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = Color.White
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = if (authIntent == AuthIntent.SIGN_IN) 
                "Sign in with Apple" 
            else 
                "Sign up with Apple",
            color = Color.White
        )
    }
}
```

## Step 6: Add Apple Logo

Create `ic_apple_logo.xml` in `res/drawable/`:

```xml
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

## Step 7: Test It!

1. Build and run the app
2. Go to Authentication screen
3. Click "Sign in with Apple"
4. Browser should open to Apple's auth page
5. Complete sign-in
6. App should handle the callback and sign you in

## Troubleshooting

### Browser doesn't open
- Check AppleAuthService is properly injected
- Verify AndroidManifest has the deep link configured

### Callback not received
- Verify AndroidManifest.xml has the AppleSignInCallbackActivity
- Check the deep link scheme matches

### Lambda errors
- Check logs: `aws logs tail /aws/logs/lambda/photolala-apple-auth --follow`
- Verify Apple Service ID is created and matches Lambda config

### "Invalid token format"
- Make sure you're testing with a real Apple ID
- Service ID must be properly configured

## Complete Flow

1. User clicks "Sign in with Apple"
2. `IdentityManager.authenticate(APPLE)` returns `AppleSignInPending`
3. `prepareAppleSignIn()` calls `appleAuthService.signIn()`
4. Chrome Custom Tab opens Apple auth page
5. User signs in with Apple ID
6. Apple redirects to `photolala://auth/apple`
7. `AppleSignInCallbackActivity` receives deep link
8. `handleAppleSignInCallback()` processes the result
9. Lambda verifies token and returns user info
10. User is signed in!

## Next Steps

1. Test with a real Apple ID
2. Monitor Lambda logs during testing
3. Add proper error handling for edge cases
4. Consider adding loading states in UI