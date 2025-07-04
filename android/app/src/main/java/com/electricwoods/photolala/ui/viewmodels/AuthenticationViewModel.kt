package com.electricwoods.photolala.ui.viewmodels

import android.content.Intent
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.models.AuthCredential
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.services.AuthException
import com.electricwoods.photolala.services.AuthenticationEventBus
import com.electricwoods.photolala.services.IdentityManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthenticationViewModel @Inject constructor(
	val identityManager: IdentityManager,
	private val authEventBus: AuthenticationEventBus
) : ViewModel() {
	
	// Callback for launching Google Sign-In
	var onGoogleSignInRequired: ((Intent) -> Unit)? = null
	
	// Callback for launching Apple Sign-In
	var onAppleSignInRequired: (() -> Unit)? = null
	
	// Callback for handling no account found error
	var onNoAccountFound: ((AuthProvider, AuthCredential?) -> Unit)? = null
	
	// Store the pending success callback for Apple Sign-In
	private var pendingAppleSignInSuccessCallback: (() -> Unit)? = null
	
	// Store the current authentication intent (sign in vs create account)
	private var currentAuthIntent: IdentityManager.AuthIntent? = null
	
	init {
		// Listen for Apple Sign-In completion events
		authEventBus.events
			.onEach { event ->
				when (event) {
					is AuthenticationEventBus.AuthEvent.AppleSignInCompleted -> {
						android.util.Log.d("AuthViewModel", "=== APPLE SIGN-IN EVENT RECEIVED ===")
						android.util.Log.d("AuthViewModel", "Pending callback available: ${pendingAppleSignInSuccessCallback != null}")
						// Call the pending success callback if available
						pendingAppleSignInSuccessCallback?.let { callback ->
							android.util.Log.d("AuthViewModel", "Invoking success callback for navigation")
							// Add small delay to ensure user state is fully updated
							kotlinx.coroutines.delay(100)
							callback()
							android.util.Log.d("AuthViewModel", "Success callback invoked")
						} ?: android.util.Log.d("AuthViewModel", "No pending callback to invoke")
						pendingAppleSignInSuccessCallback = null
					}
					is AuthenticationEventBus.AuthEvent.AppleSignInNoAccountFound -> {
						android.util.Log.d("AuthViewModel", "=== APPLE SIGN-IN NO ACCOUNT FOUND ===")
						// Invoke the no account found callback
						onNoAccountFound?.invoke(event.provider, event.credential)
						pendingAppleSignInSuccessCallback = null
					}
					else -> {}
				}
			}
			.launchIn(viewModelScope)
	}
	
	fun authenticate(
		provider: AuthProvider,
		isSignUp: Boolean,
		onSuccess: () -> Unit
	) {
		viewModelScope.launch {
			val result = if (isSignUp) {
				identityManager.createAccount(provider)
			} else {
				identityManager.signIn(provider)
			}
			
			result.onSuccess {
				onSuccess()
			}.onFailure { error ->
				when (error) {
					is AuthException.GoogleSignInPending -> {
						// We need to launch Google Sign-In activity
						val authIntent = if (isSignUp) {
							IdentityManager.AuthIntent.CREATE_ACCOUNT
						} else {
							IdentityManager.AuthIntent.SIGN_IN
						}
						val intent = identityManager.prepareGoogleSignIn(authIntent)
						onGoogleSignInRequired?.invoke(intent)
					}
					is AuthException.AppleSignInPending -> {
						// We need to launch Apple Sign-In in browser
						val authIntent = if (isSignUp) {
							IdentityManager.AuthIntent.CREATE_ACCOUNT
						} else {
							IdentityManager.AuthIntent.SIGN_IN
						}
						// Store the current intent and success callback
						currentAuthIntent = authIntent
						pendingAppleSignInSuccessCallback = onSuccess
						identityManager.prepareAppleSignIn(authIntent)
						onAppleSignInRequired?.invoke()
					}
					is AuthException.UserCancelled -> {
						// Handle user cancellation silently
						Log.d("AuthViewModel", "User cancelled authentication")
					}
					is AuthException.NoAccountFound -> {
						// Invoke the callback to show create account dialog
						// Pass the credential if available to avoid re-authentication
						onNoAccountFound?.invoke(provider, error.credential)
					}
					else -> {
						// Error is already set in identityManager.errorMessage
						Log.e("AuthViewModel", "Authentication failed", error)
					}
				}
			}
		}
	}
	
	fun createAccountWithCredential(
		credential: AuthCredential,
		onSuccess: () -> Unit
	) {
		viewModelScope.launch {
			val result = identityManager.createAccount(credential)
			result.onSuccess {
				onSuccess()
			}.onFailure { error ->
				// Error is already set in identityManager.errorMessage
				Log.e("AuthViewModel", "Account creation failed", error)
			}
		}
	}
	
	fun handleGoogleSignInResult(data: Intent?, onSuccess: () -> Unit) {
		viewModelScope.launch {
			val result = identityManager.handleGoogleSignInResult(data)
			result.onSuccess {
				onSuccess()
			}.onFailure { error ->
				when (error) {
					is AuthException.NoAccountFound -> {
						// Invoke the callback to show create account dialog
						// Pass the credential if available to avoid re-authentication
						onNoAccountFound?.invoke(error.provider, error.credential)
					}
					is AuthException.UserCancelled -> {
						// Handle user cancellation silently
						Log.d("AuthViewModel", "User cancelled Google Sign-In")
					}
					else -> {
						// Error is already set in identityManager.errorMessage
						Log.e("AuthViewModel", "Google Sign-In failed", error)
					}
				}
			}
		}
	}
	
	// Get the current authentication intent
	fun getCurrentAuthIntent(): IdentityManager.AuthIntent? {
		return currentAuthIntent
	}
	
	// Clear the current authentication intent
	fun clearAuthIntent() {
		currentAuthIntent = null
		pendingAppleSignInSuccessCallback = null
	}
}