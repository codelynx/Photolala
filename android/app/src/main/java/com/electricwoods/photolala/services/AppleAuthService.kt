package com.electricwoods.photolala.services

import android.content.Context
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsClient
import com.electricwoods.photolala.models.AuthCredential
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.utils.SecurityUtils
import com.electricwoods.photolala.utils.Credentials
import com.electricwoods.photolala.utils.CredentialKey
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import java.security.MessageDigest
import java.util.Base64
import javax.inject.Inject
import javax.inject.Singleton
import okhttp3.OkHttpClient
import okhttp3.FormBody
import okhttp3.Request
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.SignatureAlgorithm
import io.jsonwebtoken.security.Keys
import java.security.KeyFactory
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Date

/**
 * Service for handling Sign in with Apple on Android using web-based OAuth flow.
 * 
 * This is significantly more complex than iOS because:
 * 1. No native SDK - must use web OAuth
 * 2. Requires Chrome Custom Tabs or WebView
 * 3. Needs deep link handling for callbacks
 * 4. Token validation is more complex
 */
@Singleton
class AppleAuthService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        // Apple Developer Configuration
        const val TEAM_ID = "2P97EM4L4N"  // From CLAUDE.md
        const val SERVICE_ID = "com.electricwoods.photolala.android"
        const val KEY_ID = "FPZRF65BMT"
        
        const val AUTH_ENDPOINT = "https://appleid.apple.com/auth/authorize"
        const val TOKEN_ENDPOINT = "https://appleid.apple.com/auth/token"
        // Note: This redirect URI must be configured in Apple Developer Portal
        // For Android, we need a web URL that Apple can POST to
        const val REDIRECT_URI = "https://photolala.eastlynx.com/auth/apple/callback"
        
        // Scopes
        const val SCOPE_EMAIL = "email"
        const val SCOPE_NAME = "name"
    }
    
    // Track current auth session
    private var currentState: String? = null
    private var currentNonce: String? = null
    private var codeVerifier: String? = null
    
    // Observable auth state
    private val _authState = MutableStateFlow<AppleAuthState>(AppleAuthState.Idle)
    val authState: StateFlow<AppleAuthState> = _authState
    
    /**
     * Initiates Sign in with Apple flow using Chrome Custom Tabs
     */
    fun signIn() {
        try {
            // Generate security parameters
            currentState = generateRandomString()
            currentNonce = generateRandomString()
            codeVerifier = generateCodeVerifier()
            val codeChallenge = generateCodeChallenge(codeVerifier!!)
            
            // Build authorization URL with all required parameters
            val authUrl = Uri.parse(AUTH_ENDPOINT).buildUpon().apply {
                appendQueryParameter("client_id", SERVICE_ID)
                appendQueryParameter("redirect_uri", REDIRECT_URI)
                appendQueryParameter("response_type", "code")
                // TEMPORARY: Skip scopes to test token exchange
                // TODO: Implement web bridge for full scope support
                // appendQueryParameter("scope", "$SCOPE_EMAIL $SCOPE_NAME")
                // appendQueryParameter("response_mode", "form_post")
                appendQueryParameter("response_mode", "query")
                appendQueryParameter("state", currentState)
                appendQueryParameter("nonce", currentNonce)
            }.build()
            
            // Update state
            _authState.value = AppleAuthState.Loading
            
            val customTabsIntent = CustomTabsIntent.Builder()
                .setShowTitle(true)
                .setUrlBarHidingEnabled(true)
                .build()
                
            // Check if we can use Custom Tabs
            val packageName = CustomTabsClient.getPackageName(context, null)
            if (packageName != null) {
                customTabsIntent.launchUrl(context, authUrl)
            } else {
                // Fallback to regular browser
                val browserIntent = android.content.Intent(android.content.Intent.ACTION_VIEW, authUrl)
                browserIntent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(browserIntent)
            }
            
        } catch (e: Exception) {
            _authState.value = AppleAuthState.Error(
                AppleAuthError.LaunchFailed(e.message ?: "Failed to launch Sign in with Apple")
            )
        }
    }
    
    // Add property for coroutine scope
    private val scope = CoroutineScope(Dispatchers.Main)
    
    /**
     * Handles the OAuth callback from Apple
     * This should be called from the deep link handler activity
     */
    fun handleCallback(uri: Uri): Boolean {
        
        // Extract parameters from callback
        val state = uri.getQueryParameter("state")
        val code = uri.getQueryParameter("code")
        val idToken = uri.getQueryParameter("id_token")
        val error = uri.getQueryParameter("error")
        
        
        // Handle errors
        if (error != null) {
            _authState.value = when (error) {
                "user_cancelled_authorize" -> AppleAuthState.Cancelled
                else -> AppleAuthState.Error(AppleAuthError.AuthFailed(error))
            }
            cleanup()
            return true
        }
        
        // Validate state to prevent CSRF attacks
        if (state != currentState) {
            _authState.value = AppleAuthState.Error(
                AppleAuthError.InvalidState("State mismatch - possible security issue")
            )
            cleanup()
            return false
        }
        
        // Ensure we have required data
        if (code == null) {
            _authState.value = AppleAuthState.Error(
                AppleAuthError.MissingData("Missing authorization code")
            )
            cleanup()
            return false
        }
        
        // Handle token extraction with exchange if needed
        scope.launch {
            try {
                var tokenResponse: AppleTokenResponse? = null
                val tokenData = when {
                    idToken != null -> {
                        // First-time sign in - token provided directly
                        parseIdToken(idToken)
                    }
                    code != null -> {
                        // Subsequent sign in - need to exchange
                        _authState.value = AppleAuthState.Loading
                        tokenResponse = exchangeCodeForTokens(code)
                        parseIdToken(tokenResponse.idToken)
                    }
                    else -> {
                        throw Exception("No code or token received")
                    }
                }
                
                // Validate nonce if present
                if (tokenData.nonce != null && tokenData.nonce != currentNonce) {
                    _authState.value = AppleAuthState.Error(
                        AppleAuthError.InvalidNonce("Nonce mismatch - possible replay attack")
                    )
                    cleanup()
                    return@launch
                }
                
                // Create credential with proper Apple user ID from JWT
                val credential = AuthCredential(
                    provider = AuthProvider.APPLE,
                    providerID = tokenData.sub, // Always use sub from JWT
                    email = tokenData.email,
                    fullName = tokenData.fullName,
                    photoURL = null,
                    idToken = idToken ?: tokenResponse?.idToken,
                    accessToken = tokenResponse?.accessToken
                )
                
                
                
                _authState.value = AppleAuthState.Success(credential)
                cleanup()
                
            } catch (e: Exception) {
                android.util.Log.e("AppleAuthService", "Auth failed", e)
                _authState.value = AppleAuthState.Error(
                    AppleAuthError.TokenParseFailed(e.message ?: "Failed to process tokens")
                )
                cleanup()
            }
        }
        
        return true
    }
    
    /**
     * Parses the ID token JWT to extract user information
     * Note: This is basic parsing - production should use proper JWT library
     */
    private fun parseIdToken(token: String): AppleIdTokenData {
        // Split JWT into parts
        val parts = token.split(".")
        if (parts.size != 3) {
            throw IllegalArgumentException("Invalid JWT format")
        }
        
        // Decode payload (middle part)
        val payload = String(Base64.getUrlDecoder().decode(parts[1]))
        
        // Parse JSON (simplified - use proper JSON parser in production)
        val sub = extractJsonValue(payload, "sub") 
            ?: throw IllegalArgumentException("Missing user ID")
        val email = extractJsonValue(payload, "email")
        val nonce = extractJsonValue(payload, "nonce")
        val isPrivateEmail = extractJsonValue(payload, "is_private_email")?.toBoolean() ?: false
        
        // Extract name if provided
        val fullName = if (payload.contains("\"name\"")) {
            "${extractJsonValue(payload, "given_name") ?: ""} ${extractJsonValue(payload, "family_name") ?: ""}".trim()
        } else null
        
        val tokenData = AppleIdTokenData(
            sub = sub,
            email = email,
            fullName = fullName,
            nonce = nonce,
            isPrivateEmail = isPrivateEmail
        )
        
        android.util.Log.d("AppleAuthService", "Parsed Apple JWT - sub: $sub, email: $email, fullName: $fullName")
        return tokenData
    }
    
    /**
     * Simple JSON value extractor (replace with proper JSON parsing)
     */
    private fun extractJsonValue(json: String, key: String): String? {
        val pattern = "\"$key\"\\s*:\\s*\"([^\"]+)\"".toRegex()
        return pattern.find(json)?.groupValues?.get(1)
    }
    
    /**
     * Generates cryptographically secure random string
     */
    private fun generateRandomString(length: Int = 32): String {
        val bytes = ByteArray(length)
        java.security.SecureRandom().nextBytes(bytes)
        return android.util.Base64.encodeToString(bytes, android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP)
    }
    
    /**
     * Generates PKCE code verifier
     */
    private fun generateCodeVerifier(): String {
        return generateRandomString(32)
    }
    
    /**
     * Generates PKCE code challenge from verifier
     */
    private fun generateCodeChallenge(verifier: String): String {
        val bytes = verifier.toByteArray()
        val digest = MessageDigest.getInstance("SHA-256").digest(bytes)
        return android.util.Base64.encodeToString(digest, android.util.Base64.URL_SAFE or android.util.Base64.NO_PADDING or android.util.Base64.NO_WRAP)
    }
    
    /**
     * Cleanup auth session data
     */
    private fun cleanup() {
        currentState = null
        currentNonce = null
        codeVerifier = null
    }
    
    /**
     * Reset auth state to idle
     */
    fun resetState() {
        _authState.value = AppleAuthState.Idle
        cleanup()
    }
    
    /**
     * Token exchange response from Apple
     */
    data class AppleTokenResponse(
        @SerializedName("access_token")
        val accessToken: String,
        @SerializedName("token_type")
        val tokenType: String,
        @SerializedName("expires_in")
        val expiresIn: Int,
        @SerializedName("refresh_token")
        val refreshToken: String,
        @SerializedName("id_token")
        val idToken: String
    )
    
    /**
     * Generate client secret JWT for token exchange
     */
    private fun generateClientSecret(): String {
        // Get the private key from encrypted credentials
        val privateKeyPEM = Credentials.decrypt(CredentialKey.APPLE_PRIVATE_KEY)
            ?: throw Exception("Failed to decrypt Apple private key")
        
        android.util.Log.d("AppleAuthService", "Generating client secret with:")
        android.util.Log.d("AppleAuthService", "  Team ID: $TEAM_ID")
        android.util.Log.d("AppleAuthService", "  Service ID: $SERVICE_ID")
        android.util.Log.d("AppleAuthService", "  Key ID: $KEY_ID")
        
        // Parse the private key
        val privateKeyContent = privateKeyPEM
            .replace("-----BEGIN PRIVATE KEY-----", "")
            .replace("-----END PRIVATE KEY-----", "")
            .replace("\n", "")
            .trim()
        
        val keyBytes = Base64.getDecoder().decode(privateKeyContent)
        val keySpec = PKCS8EncodedKeySpec(keyBytes)
        val keyFactory = KeyFactory.getInstance("EC")
        val privateKey = keyFactory.generatePrivate(keySpec)
        
        // Create JWT
        val now = Date()
        val expiration = Date(now.time + 86400 * 180 * 1000L) // 180 days
        
        val jwt = Jwts.builder()
            .setHeaderParam("kid", KEY_ID)
            .setHeaderParam("alg", "ES256")
            .setIssuer(TEAM_ID)
            .setAudience("https://appleid.apple.com")
            .setSubject(SERVICE_ID)
            .setIssuedAt(now)
            .setExpiration(expiration)
            .signWith(privateKey, SignatureAlgorithm.ES256)
            .compact()
            
        android.util.Log.d("AppleAuthService", "Generated client secret JWT (first 50 chars): ${jwt.take(50)}...")
        return jwt
    }
    
    /**
     * Exchange authorization code for tokens
     */
    private suspend fun exchangeCodeForTokens(code: String): AppleTokenResponse {
        return withContext(Dispatchers.IO) {
            try {
                val client = OkHttpClient()
                val gson = Gson()
                
                // Generate client secret
                val clientSecret = generateClientSecret()
                
                // Build form body
                val formBody = FormBody.Builder()
                    .add("client_id", SERVICE_ID)
                    .add("client_secret", clientSecret)
                    .add("code", code)
                    .add("grant_type", "authorization_code")
                    .add("redirect_uri", REDIRECT_URI)
                    .build()
                
                // Log request details
                android.util.Log.d("AppleAuthService", "Token exchange request:")
                android.util.Log.d("AppleAuthService", "  URL: $TOKEN_ENDPOINT")
                android.util.Log.d("AppleAuthService", "  client_id: $SERVICE_ID")
                android.util.Log.d("AppleAuthService", "  code: ${code.take(20)}...")
                android.util.Log.d("AppleAuthService", "  redirect_uri: $REDIRECT_URI")
                
                // Create request
                val request = Request.Builder()
                    .url(TOKEN_ENDPOINT)
                    .post(formBody)
                    .header("Content-Type", "application/x-www-form-urlencoded")
                    .build()
                
                android.util.Log.d("AppleAuthService", "Exchanging code for tokens...")
                
                // Execute request
                val response = client.newCall(request).execute()
                val responseBody = response.body?.string()
                
                if (response.isSuccessful && responseBody != null) {
                    android.util.Log.d("AppleAuthService", "Token exchange successful")
                    gson.fromJson(responseBody, AppleTokenResponse::class.java)
                } else {
                    android.util.Log.e("AppleAuthService", "Token exchange failed: ${response.code} - $responseBody")
                    throw Exception("Token exchange failed: ${response.code} - $responseBody")
                }
            } catch (e: Exception) {
                android.util.Log.e("AppleAuthService", "Token exchange error", e)
                throw e
            }
        }
    }
}

/**
 * Represents the current state of Apple authentication
 */
sealed class AppleAuthState {
    object Idle : AppleAuthState()
    object Loading : AppleAuthState()
    object Cancelled : AppleAuthState()
    data class Success(val credential: AuthCredential) : AppleAuthState()
    data class Error(val error: AppleAuthError) : AppleAuthState()
}

/**
 * Apple authentication specific errors
 */
sealed class AppleAuthError(val message: String) {
    class LaunchFailed(message: String) : AppleAuthError(message)
    class AuthFailed(message: String) : AppleAuthError(message)
    class InvalidState(message: String) : AppleAuthError(message)
    class InvalidNonce(message: String) : AppleAuthError(message)
    class MissingData(message: String) : AppleAuthError(message)
    class TokenParseFailed(message: String) : AppleAuthError(message)
    class NetworkError(message: String) : AppleAuthError(message)
}

/**
 * Data extracted from Apple ID token
 */
data class AppleIdTokenData(
    val sub: String,           // User ID
    val email: String?,        // Email (may be private relay)
    val fullName: String?,     // Full name (only on first auth)
    val nonce: String?,        // Security nonce
    val isPrivateEmail: Boolean // Whether email is private relay
)