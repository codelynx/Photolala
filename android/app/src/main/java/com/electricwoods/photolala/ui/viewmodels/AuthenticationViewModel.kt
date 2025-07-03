package com.electricwoods.photolala.ui.viewmodels

import android.content.Intent
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.services.AuthException
import com.electricwoods.photolala.services.IdentityManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthenticationViewModel @Inject constructor(
	val identityManager: IdentityManager
) : ViewModel() {
	
	// Callback for launching Google Sign-In
	var onGoogleSignInRequired: ((Intent) -> Unit)? = null
	
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
					is AuthException.UserCancelled -> {
						// Handle user cancellation silently
						Log.d("AuthViewModel", "User cancelled authentication")
					}
					else -> {
						// Error is already set in identityManager.errorMessage
						Log.e("AuthViewModel", "Authentication failed", error)
					}
				}
			}
		}
	}
	
	fun handleGoogleSignInResult(data: Intent?, onSuccess: () -> Unit) {
		viewModelScope.launch {
			val result = identityManager.handleGoogleSignInResult(data)
			result.onSuccess {
				onSuccess()
			}.onFailure { error ->
				// Handle errors (already set in identityManager.errorMessage)
				if (error !is AuthException.UserCancelled) {
					Log.e("AuthViewModel", "Google Sign-In failed", error)
				}
			}
		}
	}
}