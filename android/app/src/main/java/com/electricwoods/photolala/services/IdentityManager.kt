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
import android.net.Uri
import kotlinx.coroutines.DelicateCoroutinesApi
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.first

@Singleton
class IdentityManager @Inject constructor(
	@ApplicationContext private val context: Context,
	private val s3Service: S3Service,
	private val preferencesManager: PreferencesManager,
	private val googleSignInLegacyService: GoogleSignInLegacyService,
	private val appleAuthService: AppleAuthService,
	private val authEventBus: AuthenticationEventBus,
	private val catalogService: CatalogService
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
		android.util.Log.d("IdentityManager", "Initializing IdentityManager")
		loadStoredUser()
		// Verify stored user exists in S3
		@OptIn(DelicateCoroutinesApi::class)
		GlobalScope.launch {
			android.util.Log.d("IdentityManager", "Starting S3 verification of stored user")
			verifyStoredUserWithS3()
		}
	}
	
	companion object {
		const val APPLE_AUTH_ENDPOINT = "https://tygm499koc.execute-api.us-east-1.amazonaws.com"
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
	
	// Create a new account with an existing credential (avoids re-authentication)
	suspend fun createAccount(credential: AuthCredential): Result<PhotolalaUser> {
		_isLoading.value = true
		_errorMessage.value = null
		
		try {
			// Check if user already exists with this provider ID
			val existingUser = findUserByProviderID(credential.provider, credential.providerID)
			
			if (existingUser != null) {
				// User already exists - this shouldn't happen in normal flow
				_errorMessage.value = "An account already exists with ${credential.provider.displayName}"
				return Result.failure(AuthException.AccountAlreadyExists(credential.provider))
			}
			
			// Create new account
			val serviceUserID = UUID.randomUUID().toString().lowercase()
			val newUser = PhotolalaUser(
				serviceUserID = serviceUserID,
				primaryProvider = credential.provider,
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
			return Result.success(newUser)
		} catch (e: Exception) {
			_errorMessage.value = e.message
			return Result.failure(e)
		} finally {
			_isLoading.value = false
		}
	}
	
	// Unified authentication flow
	private suspend fun authenticateAndProcess(
		provider: AuthProvider,
		intent: AuthIntent
	): Result<PhotolalaUser> {
		android.util.Log.d("IdentityManager", "=== authenticateAndProcess START ===")
		android.util.Log.d("IdentityManager", "Provider: ${provider.value}, Intent: $intent")
		println("[IdentityManager] === authenticateAndProcess START ===")
		println("[IdentityManager] Provider: ${provider.value}, Intent: $intent")
		
		_isLoading.value = true
		_errorMessage.value = null
		
		try {
			// Step 1: Authenticate with provider
			android.util.Log.d("IdentityManager", "Step 1: Authenticating with provider...")
			val credential = authenticate(provider).getOrThrow()
			android.util.Log.d("IdentityManager", "Authentication successful - Credential: provider=${credential.provider.value}, providerID=${credential.providerID}")
			
			// Step 2: Check if user exists with this provider ID
			android.util.Log.d("IdentityManager", "Step 2: Checking if user exists...")
			android.util.Log.d("IdentityManager", "Looking for: ${provider.value}:${credential.providerID}")
			val existingUser = findUserByProviderID(provider, credential.providerID)
			android.util.Log.d("IdentityManager", "Step 2 Result: ${if (existingUser != null) "Found user ${existingUser.serviceUserID}" else "No user found"}")
			
			// Step 3: Handle based on intent and existence
			android.util.Log.d("IdentityManager", "Step 3: Processing intent=$intent, existingUser=${existingUser?.serviceUserID}")
			
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
					// Include the credential so it can be reused for account creation
					android.util.Log.d("IdentityManager", "SIGN_IN failed: No account found for ${provider.value}:${credential.providerID}")
					Result.failure(AuthException.NoAccountFound(provider, credential))
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
			AuthProvider.APPLE -> authenticateWithApple()
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
			val existingUser = kotlinx.coroutines.runBlocking {
				findUserByProviderID(AuthProvider.GOOGLE, credential.providerID)
			}
			
			when {
				authIntent == AuthIntent.SIGN_IN && existingUser != null -> {
					// Sign in successful - user exists
					android.util.Log.d("IdentityManager", "Google Sign in successful - existing user found: ${existingUser.serviceUserID}")
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
					// Include the credential so it can be reused for account creation
					android.util.Log.d("IdentityManager", "Google Sign in failed - no account found for ${AuthProvider.GOOGLE.value}:${credential.providerID}")
					val error = AuthException.NoAccountFound(AuthProvider.GOOGLE, credential)
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
	
	// Apple Sign-In Support
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
		android.util.Log.d("IdentityManager", "=== APPLE SIGN-IN FLOW START ===")
		android.util.Log.d("IdentityManager", "Auth Intent: $authIntent")
		pendingAppleAuth = PendingAppleAuth(authIntent)
		appleAuthService.signIn()
	}
	
	// Handle Apple Sign-In callback
	suspend fun handleAppleSignInCallback(uri: Uri): Result<PhotolalaUser> {
		android.util.Log.d("IdentityManager", "=== APPLE CALLBACK START ===")
		val authIntent = pendingAppleAuth?.authIntent ?: AuthIntent.SIGN_IN
		android.util.Log.d("IdentityManager", "Auth intent: $authIntent")
		pendingAppleAuth = null
		
		_isLoading.value = true
		_errorMessage.value = null
		
		return try {
			// Let AppleAuthService handle the callback
			android.util.Log.d("IdentityManager", "Calling AppleAuthService.handleCallback")
			if (!appleAuthService.handleCallback(uri)) {
				android.util.Log.e("IdentityManager", "AppleAuthService.handleCallback returned false")
				return Result.failure(AuthException.AuthenticationFailed("Invalid callback"))
			}
			
			android.util.Log.d("IdentityManager", "AppleAuthService.handleCallback returned true, waiting for state update...")
			
			// Wait for the auth state to update (AppleAuthService processes async)
			// Use first() to wait for the first non-Loading state
			val authState = appleAuthService.authState
				.first { state -> 
					state !is AppleAuthState.Loading && state !is AppleAuthState.Idle 
				}
			
			android.util.Log.d("IdentityManager", "Final auth state: ${authState::class.simpleName}")
			when (authState) {
				is AppleAuthState.Success -> {
					android.util.Log.d("IdentityManager", "Apple auth successful, processing credential")
					val credential = authState.credential
					val verifiedCredential = credential.copy(
						serviceUserId = null // Will be assigned by processAuthCredential
					)
					processAuthCredential(verifiedCredential, authIntent)
				}
				is AppleAuthState.Cancelled -> {
					android.util.Log.d("IdentityManager", "Apple auth cancelled")
					_isLoading.value = false
					Result.failure(AuthException.UserCancelled)
				}
				is AppleAuthState.Error -> {
					android.util.Log.e("IdentityManager", "Apple auth error: ${authState.error.message}")
					_isLoading.value = false
					_errorMessage.value = authState.error.message
					Result.failure(AuthException.AuthenticationFailed(authState.error.message))
				}
				else -> {
					android.util.Log.e("IdentityManager", "Unexpected auth state: $authState")
					_isLoading.value = false
					Result.failure(AuthException.UnknownError)
				}
			}
		} catch (e: Exception) {
			android.util.Log.e("IdentityManager", "Exception in handleAppleSignInCallback", e)
			_isLoading.value = false
			_errorMessage.value = e.message
			Result.failure(e)
		}
	}
	
	// Process authenticated credential
	private suspend fun processAuthCredential(
		credential: AuthCredential,
		authIntent: AuthIntent
	): Result<PhotolalaUser> {
		val provider = credential.provider
		android.util.Log.d("IdentityManager", "Processing auth credential - Provider: ${provider.value}, ID: ${credential.providerID}, Intent: $authIntent")
		android.util.Log.d("IdentityManager", "JWT Data - Email: ${credential.email}, Name: ${credential.fullName}")
		val existingUser = kotlinx.coroutines.runBlocking {
			findUserByProviderID(provider, credential.providerID)
		}
		
		return when {
			authIntent == AuthIntent.SIGN_IN && existingUser != null -> {
				// Sign in successful - user exists
				android.util.Log.d("IdentityManager", "Sign in successful - existing user found: ${existingUser.serviceUserID}")
				val updatedUser = existingUser.copy(
					email = credential.email ?: existingUser.email,
					fullName = credential.fullName ?: existingUser.fullName,
					photoURL = credential.photoURL ?: existingUser.photoURL,
					lastUpdated = Date()
				)
				saveUser(updatedUser)
				_currentUser.value = updatedUser
				_isSignedIn.value = true
				_isLoading.value = false
				
				// Emit event for Apple Sign-In completion
				if (provider == AuthProvider.APPLE) {
					GlobalScope.launch {
						authEventBus.emitAppleSignInCompleted()
					}
				}
				
				Result.success(updatedUser)
			}
			
			authIntent == AuthIntent.SIGN_IN && existingUser == null -> {
				// Sign in failed - no account exists
				// Include the credential so it can be reused for account creation
				android.util.Log.d("IdentityManager", "Sign in failed - no account found for provider: ${provider.value}, ID: ${credential.providerID}")
				val error = AuthException.NoAccountFound(provider, credential)
				// Don't set error message for Apple Sign-In - let the UI handle it
				if (provider != AuthProvider.APPLE) {
					_errorMessage.value = error.message
				}
				_isLoading.value = false
				
				// Emit event for Apple Sign-In no account found
				if (provider == AuthProvider.APPLE) {
					GlobalScope.launch {
						authEventBus.emitAppleSignInNoAccountFound(provider, credential)
					}
				}
				
				Result.failure(error)
			}
			
			authIntent == AuthIntent.CREATE_ACCOUNT && existingUser != null -> {
				// Create account failed - user already exists
				val error = AuthException.AccountAlreadyExists(provider)
				_errorMessage.value = error.message
				_isLoading.value = false
				Result.failure(error)
			}
			
			authIntent == AuthIntent.CREATE_ACCOUNT && existingUser == null -> {
				// Create account successful - create new user
				val serviceUserID = credential.serviceUserId ?: UUID.randomUUID().toString().lowercase()
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
				_isLoading.value = false
				
				// Emit event for Apple Sign-In completion
				if (provider == AuthProvider.APPLE) {
					GlobalScope.launch {
						authEventBus.emitAppleSignInCompleted()
					}
				}
				
				Result.success(newUser)
			}
			
			else -> {
				val error = AuthException.UnknownError
				_errorMessage.value = error.message
				_isLoading.value = false
				Result.failure(error)
			}
		}
	}
	
	
	// Find user by provider ID
	private suspend fun findUserByProviderID(
		provider: AuthProvider,
		providerID: String
	): PhotolalaUser? {
		android.util.Log.d("IdentityManager", "findUserByProviderID called with ${provider.value}:$providerID")
		
		// Always check S3 as the single source of truth
		// We'll still check local storage but S3 takes precedence
		val localUser = loadStoredUser()
		if (localUser != null) {
			android.util.Log.d("IdentityManager", "Checking local user: ${localUser.primaryProvider.value}:${localUser.primaryProviderID} against ${provider.value}:$providerID")
			if (localUser.primaryProvider == provider && 
				localUser.primaryProviderID == providerID) {
				android.util.Log.d("IdentityManager", "Found matching local user")
				return localUser
			}
			
			// Check linked providers
			if (localUser.linkedProviders.any { 
				it.provider == provider && it.providerID == providerID 
			}) {
				android.util.Log.d("IdentityManager", "Found matching linked provider")
				return localUser
			}
			android.util.Log.d("IdentityManager", "Local user exists but no matching provider")
		} else {
			android.util.Log.d("IdentityManager", "No local user found")
		}
		
		// If not found locally, check S3 identity mapping
		val identityKey = "${provider.value}:$providerID"
		val identityPath = "identities/$identityKey"
		
		android.util.Log.d("IdentityManager", "=== S3 LOOKUP START ===")
		android.util.Log.d("IdentityManager", "Provider: ${provider.value}, ProviderID: $providerID")
		android.util.Log.d("IdentityManager", "Identity path: $identityPath")
		println("[IdentityManager] === S3 LOOKUP START ===")
		println("[IdentityManager] Looking for identity: $identityPath")
		
		try {
			android.util.Log.d("IdentityManager", "About to call s3Service.downloadData...")
			println("[IdentityManager] About to download from S3: $identityPath")
			
			val downloadResult = s3Service.downloadData(identityPath)
			android.util.Log.d("IdentityManager", "S3 download result: ${if (downloadResult.isSuccess) "Success" else "Failure: ${downloadResult.exceptionOrNull()?.message}"}")
			println("[IdentityManager] S3 download result: ${if (downloadResult.isSuccess) "Success" else "Failure: ${downloadResult.exceptionOrNull()?.message}"}")
			val uuidData = downloadResult.getOrNull()
			if (uuidData != null) {
				val serviceUserID = String(uuidData).trim()
				android.util.Log.d("IdentityManager", "Found identity mapping: $identityPath -> $serviceUserID")
				println("Found identity mapping: $identityPath -> $serviceUserID")
				
				// Reconstruct basic user (will be updated with fresh JWT data)
				val reconstructedUser = PhotolalaUser(
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
				android.util.Log.d("IdentityManager", "Returning reconstructed user from S3")
				return reconstructedUser
			} else {
				android.util.Log.d("IdentityManager", "No identity mapping found at: $identityPath")
			}
		} catch (e: Exception) {
			android.util.Log.e("IdentityManager", "Error checking identity mapping for $identityPath", e)
			println("Error checking identity mapping: ${e.message}")
			e.printStackTrace()
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
		s3Service.uploadData(uuidData, identityPath, "text/plain")
		
		println("Created identity mapping: $identityPath -> ${user.serviceUserID}")
		
		// Create empty catalog for new user
		catalogService.createEmptyCatalog(user.serviceUserID)
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
	
	// Verify stored user exists in S3
	private suspend fun verifyStoredUserWithS3() {
		val user = _currentUser.value ?: return
		
		try {
			// Check if user exists in S3 by verifying identity mapping
			val identityKey = "${user.primaryProvider.value}:${user.primaryProviderID}"
			val identityPath = "identities/$identityKey"
			
			android.util.Log.d("IdentityManager", "Verifying user in S3: $identityPath")
			
			// Try to download the identity mapping
			val result = s3Service.downloadData(identityPath)
			if (result.isSuccess) {
				android.util.Log.d("IdentityManager", "User verified in S3: ${user.displayName}")
				// User exists - keep signed in state
			} else {
				// User doesn't exist in S3 - clear local state
				android.util.Log.d("IdentityManager", "User not found in S3 ($identityPath), clearing local state")
				preferencesManager.clearUserData()
				_currentUser.value = null
				_isSignedIn.value = false
			}
		} catch (e: Exception) {
			// Error verifying - clear local state to be safe
			android.util.Log.e("IdentityManager", "Error verifying user in S3: ${e.message}. Clearing local state.")
			preferencesManager.clearUserData()
			_currentUser.value = null
			_isSignedIn.value = false
		}
	}
	
	// Link a new provider to the current user account
	suspend fun linkProvider(provider: AuthProvider): Result<PhotolalaUser> {
		// Must be signed in to link a provider
		val currentUser = _currentUser.value ?: return Result.failure(
			AuthException.AuthenticationFailed("Must be signed in to link a provider")
		)
		
		_isLoading.value = true
		_errorMessage.value = null
		
		try {
			// Check if provider is already linked
			if (currentUser.primaryProvider == provider || 
				currentUser.linkedProviders.any { it.provider == provider }) {
				return Result.failure(
					AuthException.ProviderAlreadyLinked(provider)
				)
			}
			
			// Authenticate with the provider
			val credential = when (provider) {
				AuthProvider.GOOGLE -> {
					// For Google, we need to trigger the sign-in flow
					// This will be handled by the UI layer
					return Result.failure(AuthException.GoogleSignInPending)
				}
				AuthProvider.APPLE -> {
					// For Apple, we need to trigger the sign-in flow
					return Result.failure(AuthException.AppleSignInPending)
				}
			}
		} catch (e: Exception) {
			_errorMessage.value = e.message
			return Result.failure(e)
		} finally {
			_isLoading.value = false
		}
	}
	
	// Complete the provider linking after authentication
	suspend fun completeLinkProvider(credential: AuthCredential): Result<PhotolalaUser> {
		val currentUser = _currentUser.value ?: return Result.failure(
			AuthException.AuthenticationFailed("Must be signed in to link a provider")
		)
		
		_isLoading.value = true
		_errorMessage.value = null
		
		try {
			// Check if this provider ID is already used by another account
			val existingUser = findUserByProviderID(credential.provider, credential.providerID)
			if (existingUser != null && existingUser.serviceUserID != currentUser.serviceUserID) {
				return Result.failure(
					AuthException.ProviderInUse(credential.provider)
				)
			}
			
			// Create the provider link
			val providerLink = ProviderLink(
				provider = credential.provider,
				providerID = credential.providerID,
				email = credential.email,
				linkedAt = Date(),
				linkMethod = LinkMethod.USER_INITIATED
			)
			
			// Update user with new provider
			val updatedUser = currentUser.copy(
				linkedProviders = currentUser.linkedProviders + providerLink,
				lastUpdated = Date()
			)
			
			// Create S3 identity mapping
			val identityKey = "${credential.provider.value}:${credential.providerID}"
			val identityPath = "identities/$identityKey"
			val uuidData = currentUser.serviceUserID.toByteArray()
			
			val uploadResult = s3Service.uploadData(uuidData, identityPath)
			if (uploadResult.isFailure) {
				return Result.failure(
					AuthException.StorageError
				)
			}
			
			// Save updated user
			saveUser(updatedUser)
			_currentUser.value = updatedUser
			
			return Result.success(updatedUser)
		} catch (e: Exception) {
			_errorMessage.value = e.message
			return Result.failure(e)
		} finally {
			_isLoading.value = false
		}
	}
	
	// Unlink a provider from the current user account
	suspend fun unlinkProvider(provider: AuthProvider): Result<PhotolalaUser> {
		val currentUser = _currentUser.value ?: return Result.failure(
			AuthException.AuthenticationFailed("Must be signed in to unlink a provider")
		)
		
		_isLoading.value = true
		_errorMessage.value = null
		
		try {
			// Find the provider to unlink
			val providerLink = currentUser.linkedProviders.find { it.provider == provider }
			if (providerLink == null) {
				// Check if it's the primary provider
				if (currentUser.primaryProvider != provider) {
					return Result.failure(
						AuthException.ProviderNotLinked(provider)
					)
				}
			}
			
			// Cannot unlink the last provider
			if (currentUser.linkedProviders.isEmpty() && currentUser.primaryProvider == provider) {
				return Result.failure(
					AuthException.CannotUnlinkLastProvider
				)
			}
			
			// Get the provider ID to delete
			val providerID = if (provider == currentUser.primaryProvider) {
				currentUser.primaryProviderID
			} else {
				providerLink?.providerID ?: return Result.failure(
					AuthException.UnknownError
				)
			}
			
			// Delete S3 identity mapping
			val identityKey = "${provider.value}:$providerID"
			val identityPath = "identities/$identityKey"
			
			val deleteResult = s3Service.deleteObject(identityPath)
			if (deleteResult.isFailure) {
				android.util.Log.e("IdentityManager", "Failed to delete S3 identity mapping: ${deleteResult.exceptionOrNull()?.message}")
				// Continue anyway - S3 deletion failure shouldn't prevent unlinking
			}
			
			// Update user by removing the provider
			val updatedUser = currentUser.copy(
				linkedProviders = currentUser.linkedProviders.filter { it.provider != provider },
				lastUpdated = Date()
			)
			
			// Save updated user
			saveUser(updatedUser)
			_currentUser.value = updatedUser
			
			return Result.success(updatedUser)
		} catch (e: Exception) {
			_errorMessage.value = e.message
			return Result.failure(e)
		} finally {
			_isLoading.value = false
		}
	}
	
	// Handle Google Sign-In result for linking
	suspend fun handleGoogleLinkResult(data: Intent?): Result<PhotolalaUser> {
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
			completeLinkProvider(credential)
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
	
	// Handle Apple Sign-In callback for linking
	suspend fun handleAppleLinkCallback(uri: Uri): Result<PhotolalaUser> {
		android.util.Log.d("IdentityManager", "=== APPLE LINK CALLBACK START ===")
		
		_isLoading.value = true
		_errorMessage.value = null
		
		return try {
			// Let AppleAuthService handle the callback
			if (!appleAuthService.handleCallback(uri)) {
				return Result.failure(AuthException.AuthenticationFailed("Invalid callback"))
			}
			
			// Wait for the auth state to update
			val authState = appleAuthService.authState
				.first { state -> 
					state !is AppleAuthState.Loading && state !is AppleAuthState.Idle 
				}
			
			when (authState) {
				is AppleAuthState.Success -> {
					val credential = authState.credential
					completeLinkProvider(credential)
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
	
	data class NoAccountFound(val provider: AuthProvider, val credential: AuthCredential? = null) : AuthException() {
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
	
	object AppleSignInPending : AuthException() {
		override val message = "Apple Sign-In requires browser interaction"
	}
	
	data class ProviderAlreadyLinked(val provider: AuthProvider) : AuthException() {
		override val message = "${provider.displayName} is already linked to your account"
	}
	
	data class ProviderInUse(val provider: AuthProvider) : AuthException() {
		override val message = "This ${provider.displayName} account is already linked to a different Photolala account"
	}
	
	data class ProviderNotLinked(val provider: AuthProvider) : AuthException() {
		override val message = "${provider.displayName} is not linked to your account"
	}
	
	object CannotUnlinkLastProvider : AuthException() {
		override val message = "Cannot remove your only sign-in method"
	}
}


// Extension function to map Result errors
inline fun <T, E, F> Result<T>.mapError(transform: (E) -> F): Result<T> where E : Throwable, F : Throwable {
	return when {
		isSuccess -> this
		else -> Result.failure(transform(exceptionOrNull() as E))
	}
}