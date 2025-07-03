package com.electricwoods.photolala.services

import android.content.Context
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.browser.customtabs.CustomTabsClient
import com.electricwoods.photolala.models.AuthCredential
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.utils.SecurityUtils
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.security.MessageDigest
import java.util.Base64
import javax.inject.Inject
import javax.inject.Singleton

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
        // Service ID from Apple Developer Portal
        const val SERVICE_ID = "com.electricwoods.photolala.android"
        const val AUTH_ENDPOINT = "https://appleid.apple.com/auth/authorize"
        const val TOKEN_ENDPOINT = "https://appleid.apple.com/auth/token"
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
                appendQueryParameter("scope", "$SCOPE_EMAIL $SCOPE_NAME")
                appendQueryParameter("response_mode", "form_post")
                appendQueryParameter("state", currentState)
                appendQueryParameter("nonce", currentNonce)
                appendQueryParameter("code_challenge", codeChallenge)
                appendQueryParameter("code_challenge_method", "S256")
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
        
        try {
            // Parse ID token to extract user info (if available)
            val tokenData = if (idToken != null) parseIdToken(idToken) else null
            
            // If we have token data, validate nonce
            if (tokenData != null && tokenData.nonce != currentNonce) {
                _authState.value = AppleAuthState.Error(
                    AppleAuthError.InvalidNonce("Nonce mismatch - possible replay attack")
                )
                cleanup()
                return false
            }
            
            // For now, we'll create a minimal credential with just the code
            // The actual user info will be fetched by the Lambda
            val credential = AuthCredential(
                provider = AuthProvider.APPLE,
                providerID = code, // Using code as temporary ID
                email = tokenData?.email,
                fullName = tokenData?.fullName,
                photoURL = null,
                idToken = idToken,
                accessToken = null
            )
            
            _authState.value = AppleAuthState.Success(credential)
            cleanup()
            return true
            
        } catch (e: Exception) {
            _authState.value = AppleAuthState.Error(
                AppleAuthError.TokenParseFailed(e.message ?: "Failed to parse ID token")
            )
            cleanup()
            return false
        }
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
        
        return AppleIdTokenData(
            sub = sub,
            email = email,
            fullName = fullName,
            nonce = nonce,
            isPrivateEmail = isPrivateEmail
        )
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