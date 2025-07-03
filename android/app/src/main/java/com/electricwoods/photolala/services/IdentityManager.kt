package com.electricwoods.photolala.services

import android.content.Context
import android.content.Intent
import com.electricwoods.photolala.data.PreferencesManager
import com.electricwoods.photolala.models.*
import com.electricwoods.photolala.utils.SecurityUtils
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class IdentityManager @Inject constructor(
	@ApplicationContext private val context: Context,
	private val s3Service: S3Service,
	private val preferencesManager: PreferencesManager,
	private val googleSignInLegacyService: GoogleSignInLegacyService
) {
	private val json = Json { 
		ignoreUnknownKeys = true
		coerceInputValues = true
	}
	
	private val _currentUser = MutableStateFlow<PhotolalaUser?>(null)
	val currentUser: StateFlow<PhotolalaUser?> = _currentUser.asStateFlow()
	
	private val _isSignedIn = MutableStateFlow(false)
	val isSignedIn: StateFlow<Boolean> = _isSignedIn.asStateFlow()
	
	private val _isLoading = MutableStateFlow(false)
	val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
	
	private val _errorMessage = MutableStateFlow<String?>(null)
	val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()
	
	init {
		loadStoredUser()
	}
	
	enum class AuthIntent {
		SIGN_IN,
		CREATE_ACCOUNT
	}
	
	// Sign in with an existing account
	suspend fun signIn(provider: AuthProvider): Result<PhotolalaUser> {
		return authenticateAndProcess(provider, AuthIntent.SIGN_IN)
	}
	
	// Create a new account
	suspend fun createAccount(provider: AuthProvider): Result<PhotolalaUser> {
		return authenticateAndProcess(provider, AuthIntent.CREATE_ACCOUNT)
	}
	
	// Unified authentication flow
	private suspend fun authenticateAndProcess(
		provider: AuthProvider,
		intent: AuthIntent
	): Result<PhotolalaUser> {
		_isLoading.value = true
		_errorMessage.value = null
		
		try {
			// Step 1: Authenticate with provider
			val credential = authenticate(provider).getOrThrow()
			
			// Step 2: Check if user exists with this provider ID
			val existingUser = findUserByProviderID(provider, credential.providerID)
			
			// Step 3: Handle based on intent and existence
			return when {
				intent == AuthIntent.SIGN_IN && existingUser != null -> {
					// Sign in successful - user exists
					val updatedUser = existingUser.copy(
						email = credential.email ?: existingUser.email,
						fullName = credential.fullName ?: existingUser.fullName,
						photoURL = credential.photoURL ?: existingUser.photoURL,
						lastUpdated = Date()
					)
					saveUser(updatedUser)
					_currentUser.value = updatedUser
					_isSignedIn.value = true
					Result.success(updatedUser)
				}
				
				intent == AuthIntent.SIGN_IN && existingUser == null -> {
					// Sign in failed - no account exists
					Result.failure(AuthException.NoAccountFound(provider))
				}
				
				intent == AuthIntent.CREATE_ACCOUNT && existingUser != null -> {
					// Create account failed - user already exists
					Result.failure(AuthException.AccountAlreadyExists(provider))
				}
				
				intent == AuthIntent.CREATE_ACCOUNT && existingUser == null -> {
					// Create account successful - create new user
					val serviceUserID = UUID.randomUUID().toString().lowercase()
					val newUser = PhotolalaUser(
						serviceUserID = serviceUserID,
						primaryProvider = provider,
						primaryProviderID = credential.providerID,
						email = credential.email,
						fullName = credential.fullName,
						photoURL = credential.photoURL,
						createdAt = Date(),
						lastUpdated = Date(),
						subscription = Subscription.freeTrial()
					)
					
					saveUser(newUser)
					createS3UserFolders(newUser)
					
					_currentUser.value = newUser
					_isSignedIn.value = true
					Result.success(newUser)
				}
				
				else -> Result.failure(AuthException.UnknownError)
			}
		} catch (e: Exception) {
			// Don't show error for user cancellation or pending sign-in
			if (e !is AuthException.UserCancelled && e !is AuthException.GoogleSignInPending) {
				_errorMessage.value = e.message
			}
			// For GoogleSignInPending, we don't set loading to false yet
			if (e !is AuthException.GoogleSignInPending) {
				_isLoading.value = false
			}
			return Result.failure(e)
		}
	}
	
	// Authenticate with provider
	private suspend fun authenticate(provider: AuthProvider): Result<AuthCredential> {
		return when (provider) {
			AuthProvider.GOOGLE -> authenticateWithGoogle()
			AuthProvider.APPLE -> Result.failure(AuthException.ProviderNotImplemented)
		}
	}
	
	// Store the pending auth info for Google Sign-In
	data class PendingGoogleAuth(
		val intent: Intent,
		val authIntent: AuthIntent
	)
	
	var pendingGoogleAuth: PendingGoogleAuth? = null
		private set
	
	// Google authentication using GoogleSignInLegacyService
	private suspend fun authenticateWithGoogle(): Result<AuthCredential> {
		// For Google Sign-In, we need to return a special error that triggers the activity
		// The actual authentication will happen when handleGoogleSignInResult is called
		return Result.failure(AuthException.GoogleSignInPending)
	}
	
	// Create Google Sign-In intent and store auth intent
	fun prepareGoogleSignIn(authIntent: AuthIntent): Intent {
		val signInIntent = googleSignInLegacyService.getSignInIntent()
		pendingGoogleAuth = PendingGoogleAuth(signInIntent, authIntent)
		return signInIntent
	}
	
	// Handle Google Sign-In result from activity
	suspend fun handleGoogleSignInResult(data: Intent?): Result<PhotolalaUser> {
		val authIntent = pendingGoogleAuth?.authIntent ?: AuthIntent.SIGN_IN
		pendingGoogleAuth = null
		
		_isLoading.value = true
		_errorMessage.value = null
		
		return try {
			// Get the credential from the sign-in result
			val credentialResult = googleSignInLegacyService.handleSignInResult(data)
			
			if (credentialResult.isFailure) {
				val error = credentialResult.exceptionOrNull()
				val authException = when (error) {
					is GoogleAuthException.UserCancelled -> AuthException.UserCancelled
					is GoogleAuthException.ConfigurationError -> AuthException.ConfigurationError(error.message)
					is GoogleAuthException.NetworkError -> AuthException.NetworkError
					else -> AuthException.AuthenticationFailed(error?.message ?: "Google Sign-In failed")
				}
				
				if (authException !is AuthException.UserCancelled) {
					_errorMessage.value = authException.message
				}
				return Result.failure(authException)
			}
			
			val credential = credentialResult.getOrThrow()
			
			// Now process the credential based on the auth intent
			val existingUser = findUserByProviderID(AuthProvider.GOOGLE, credential.providerID)
			
			when {
				authIntent == AuthIntent.SIGN_IN && existingUser != null -> {
					// Sign in successful - user exists
					val updatedUser = existingUser.copy(
						email = credential.email ?: existingUser.email,
						fullName = credential.fullName ?: existingUser.fullName,
						photoURL = credential.photoURL ?: existingUser.photoURL,
						lastUpdated = Date()
					)
					saveUser(updatedUser)
					_currentUser.value = updatedUser
					_isSignedIn.value = true
					Result.success(updatedUser)
				}
				
				authIntent == AuthIntent.SIGN_IN && existingUser == null -> {
					// Sign in failed - no account exists
					val error = AuthException.NoAccountFound(AuthProvider.GOOGLE)
					_errorMessage.value = error.message
					Result.failure(error)
				}
				
				authIntent == AuthIntent.CREATE_ACCOUNT && existingUser != null -> {
					// Create account failed - user already exists
					val error = AuthException.AccountAlreadyExists(AuthProvider.GOOGLE)
					_errorMessage.value = error.message
					Result.failure(error)
				}
				
				authIntent == AuthIntent.CREATE_ACCOUNT && existingUser == null -> {
					// Create account successful - create new user
					val serviceUserID = UUID.randomUUID().toString().lowercase()
					val newUser = PhotolalaUser(
						serviceUserID = serviceUserID,
						primaryProvider = AuthProvider.GOOGLE,
						primaryProviderID = credential.providerID,
						email = credential.email,
						fullName = credential.fullName,
						photoURL = credential.photoURL,
						createdAt = Date(),
						lastUpdated = Date(),
						subscription = Subscription.freeTrial()
					)
					
					saveUser(newUser)
					createS3UserFolders(newUser)
					
					_currentUser.value = newUser
					_isSignedIn.value = true
					Result.success(newUser)
				}
				
				else -> {
					val error = AuthException.UnknownError
					_errorMessage.value = error.message
					Result.failure(error)
				}
			}
		} catch (e: Exception) {
			val authError = if (e is AuthException) e else AuthException.AuthenticationFailed(e.message ?: "Unknown error")
			if (authError !is AuthException.UserCancelled) {
				_errorMessage.value = authError.message
			}
			Result.failure(authError)
		} finally {
			_isLoading.value = false
		}
	}
	
	// Find user by provider ID
	private suspend fun findUserByProviderID(
		provider: AuthProvider,
		providerID: String
	): PhotolalaUser? {
		// First, check local storage
		val localUser = loadStoredUser()
		if (localUser != null) {
			if (localUser.primaryProvider == provider && 
				localUser.primaryProviderID == providerID) {
				return localUser
			}
			
			// Check linked providers
			if (localUser.linkedProviders.any { 
				it.provider == provider && it.providerID == providerID 
			}) {
				return localUser
			}
		}
		
		// If not found locally, check S3 identity mapping
		try {
			val identityKey = "${provider.value}:$providerID"
			val identityPath = "identities/$identityKey"
			
			val uuidData = s3Service.downloadData(identityPath).getOrNull()
			if (uuidData != null) {
				val serviceUserID = String(uuidData)
				println("Found identity mapping: $identityPath -> $serviceUserID")
				
				// Reconstruct basic user (will be updated with fresh JWT data)
				return PhotolalaUser(
					serviceUserID = serviceUserID,
					primaryProvider = provider,
					primaryProviderID = providerID,
					email = null,
					fullName = null,
					photoURL = null,
					createdAt = Date(),
					lastUpdated = Date(),
					subscription = Subscription.freeTrial()
				)
			}
		} catch (e: Exception) {
			println("No identity mapping found: ${e.message}")
		}
		
		return null
	}
	
	// Create S3 folders for new user
	private suspend fun createS3UserFolders(user: PhotolalaUser) {
		println("Creating S3 folders for user: ${user.serviceUserID}")
		
		// Create user directory
		val userPath = "users/${user.serviceUserID}/"
		s3Service.createFolder(userPath)
		
		// Create provider ID mapping
		val identityKey = "${user.primaryProvider.value}:${user.primaryProviderID}"
		val identityPath = "identities/$identityKey"
		
		// Store the UUID as content of the identity file
		val uuidData = user.serviceUserID.toByteArray()
		s3Service.uploadData(uuidData, identityPath)
		
		println("Created identity mapping: $identityPath -> ${user.serviceUserID}")
	}
	
	// Save user to secure storage
	private suspend fun saveUser(user: PhotolalaUser) {
		try {
			val userData = json.encodeToString(user)
			val encryptedData = SecurityUtils.encrypt(context, userData)
			preferencesManager.setEncryptedUserData(encryptedData)
		} catch (e: Exception) {
			println("Failed to save user: ${e.message}")
		}
	}
	
	// Load user from secure storage
	private fun loadStoredUser(): PhotolalaUser? {
		return try {
			val encryptedData = preferencesManager.getEncryptedUserData()
			if (encryptedData != null) {
				val userData = SecurityUtils.decrypt(context, encryptedData)
				val user = json.decodeFromString<PhotolalaUser>(userData)
				_currentUser.value = user
				_isSignedIn.value = true
				user
			} else {
				null
			}
		} catch (e: Exception) {
			println("Failed to load stored user: ${e.message}")
			null
		}
	}
	
	// Sign out
	fun signOut() {
		_currentUser.value = null
		_isSignedIn.value = false
		kotlinx.coroutines.runBlocking {
			preferencesManager.clearUserData()
		}
		// Clear any cached data if needed
	}
}

sealed class AuthException : Exception() {
	object ProviderNotImplemented : AuthException() {
		override val message = "This sign-in method is not yet available"
	}
	
	data class NoAccountFound(val provider: AuthProvider) : AuthException() {
		override val message = "No account found with ${provider.displayName}. Please create an account first."
	}
	
	data class AccountAlreadyExists(val provider: AuthProvider) : AuthException() {
		override val message = "An account already exists with ${provider.displayName}. Please sign in instead."
	}
	
	data class AuthenticationFailed(val reason: String) : AuthException() {
		override val message = "Authentication failed: $reason"
	}
	
	object InvalidCredentials : AuthException() {
		override val message = "Invalid credentials received from provider"
	}
	
	object NetworkError : AuthException() {
		override val message = "Network error. Please check your connection."
	}
	
	object StorageError : AuthException() {
		override val message = "Failed to save account information"
	}
	
	object UnknownError : AuthException() {
		override val message = "An unknown error occurred"
	}
	
	object UserCancelled : AuthException() {
		override val message = "Sign in cancelled"
	}
	
	object NoGoogleAccount : AuthException() {
		override val message = "No Google account found. Please add a Google account to your device."
	}
	
	data class ConfigurationError(val details: String) : AuthException() {
		override val message = "Configuration error: $details"
	}
	
	object GoogleSignInPending : AuthException() {
		override val message = "Google Sign-In requires activity interaction"
	}
}

// Extension function to map Result errors
inline fun <T, E, F> Result<T>.mapError(transform: (E) -> F): Result<T> where E : Throwable, F : Throwable {
	return when {
		isSuccess -> this
		else -> Result.failure(transform(exceptionOrNull() as E))
	}
}