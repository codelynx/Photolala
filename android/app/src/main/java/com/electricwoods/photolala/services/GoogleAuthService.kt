package com.electricwoods.photolala.services

import android.content.Context
import android.util.Log
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.GetCredentialException
import com.electricwoods.photolala.models.AuthCredential
import com.electricwoods.photolala.models.AuthProvider
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.android.libraries.identity.googleid.GoogleIdTokenParsingException
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class GoogleAuthService @Inject constructor(
	@ApplicationContext private val context: Context
) {
	companion object {
		private const val TAG = "GoogleAuthService"
		// Web Application OAuth 2.0 Client ID from Google Cloud Console (photolala-android project)
		private const val WEB_CLIENT_ID = "521726419018-5229b406ioc7m1513kqrnosb67vnm2oo.apps.googleusercontent.com"
	}
	
	private val credentialManager = CredentialManager.create(context)
	
	/**
	 * Sign in with Google using Credential Manager API
	 * @return AuthCredential with user information or throws exception
	 */
	suspend fun signIn(): Result<AuthCredential> {
		return try {
			Log.d(TAG, "Starting Google Sign-In...")
			Log.d(TAG, "Web Client ID: $WEB_CLIENT_ID")
			Log.d(TAG, "Package name: ${context.packageName}")
			
			val googleIdOption = GetGoogleIdOption.Builder()
				.setFilterByAuthorizedAccounts(false) // Show all Google accounts
				.setServerClientId(WEB_CLIENT_ID)
				.setAutoSelectEnabled(false) // Don't auto-select account
				.build()
			
			Log.d(TAG, "Created GetGoogleIdOption")
			
			val request = GetCredentialRequest.Builder()
				.addCredentialOption(googleIdOption)
				.build()
			
			Log.d(TAG, "Created GetCredentialRequest, calling credentialManager.getCredential...")
			
			val result = credentialManager.getCredential(
				request = request,
				context = context
			)
			
			Log.d(TAG, "Got credential result")
			
			handleSignInResult(result)
		} catch (e: GetCredentialException) {
			Log.e(TAG, "GetCredentialException during sign in: ${e.type}, ${e.errorMessage}", e)
			Result.failure(mapCredentialException(e))
		} catch (e: Exception) {
			Log.e(TAG, "Unexpected error during sign in", e)
			Result.failure(GoogleAuthException.UnknownError(e.message ?: "Unknown error"))
		}
	}
	
	/**
	 * Sign in silently (for existing users)
	 * Attempts to sign in without showing account picker
	 */
	suspend fun signInSilently(): Result<AuthCredential> {
		return try {
			val googleIdOption = GetGoogleIdOption.Builder()
				.setFilterByAuthorizedAccounts(true) // Only show previously used accounts
				.setServerClientId(WEB_CLIENT_ID)
				.setAutoSelectEnabled(true) // Auto-select if only one account
				.build()
			
			val request = GetCredentialRequest.Builder()
				.addCredentialOption(googleIdOption)
				.build()
			
			val result = credentialManager.getCredential(
				request = request,
				context = context
			)
			
			handleSignInResult(result)
		} catch (e: GetCredentialException) {
			Log.d(TAG, "Silent sign in failed, user interaction required", e)
			Result.failure(GoogleAuthException.UserInteractionRequired)
		} catch (e: Exception) {
			Log.e(TAG, "Unexpected error during silent sign in", e)
			Result.failure(GoogleAuthException.UnknownError(e.message ?: "Unknown error"))
		}
	}
	
	/**
	 * Handle the credential response and extract user information
	 */
	private fun handleSignInResult(result: GetCredentialResponse): Result<AuthCredential> {
		return when (val credential = result.credential) {
			is CustomCredential -> {
				if (credential.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
					try {
						val googleIdTokenCredential = GoogleIdTokenCredential
							.createFrom(credential.data)
						
						val authCredential = AuthCredential(
							provider = AuthProvider.GOOGLE,
							providerID = googleIdTokenCredential.id,
							email = null, // Email not provided by GoogleIdTokenCredential
							fullName = googleIdTokenCredential.displayName,
							photoURL = googleIdTokenCredential.profilePictureUri?.toString(),
							idToken = googleIdTokenCredential.idToken,
							accessToken = null // Google Credential Manager doesn't provide access token
						)
						
						Log.d(TAG, "Successfully signed in: ${authCredential.email}")
						Result.success(authCredential)
					} catch (e: GoogleIdTokenParsingException) {
						Log.e(TAG, "Failed to parse Google ID token", e)
						Result.failure(GoogleAuthException.InvalidCredential)
					}
				} else {
					Log.e(TAG, "Unexpected credential type: ${credential.type}")
					Result.failure(GoogleAuthException.InvalidCredential)
				}
			}
			else -> {
				Log.e(TAG, "Unexpected credential type: ${credential.javaClass}")
				Result.failure(GoogleAuthException.InvalidCredential)
			}
		}
	}
	
	/**
	 * Map GetCredentialException to our custom exceptions
	 */
	private fun mapCredentialException(exception: GetCredentialException): GoogleAuthException {
		return when (exception) {
			is androidx.credentials.exceptions.NoCredentialException -> {
				GoogleAuthException.NoAccountFound
			}
			is androidx.credentials.exceptions.GetCredentialCancellationException -> {
				GoogleAuthException.UserCancelled
			}
			is androidx.credentials.exceptions.GetCredentialInterruptedException -> {
				GoogleAuthException.UserCancelled
			}
			else -> {
				GoogleAuthException.AuthenticationFailed(
					exception.message ?: "Authentication failed"
				)
			}
		}
	}
	
	/**
	 * Check if Web Client ID is configured
	 */
	fun isConfigured(): Boolean {
		return WEB_CLIENT_ID != "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
	}
}

/**
 * Custom exceptions for Google Sign-In
 */
sealed class GoogleAuthException : Exception() {
	object NoAccountFound : GoogleAuthException() {
		override val message = "No Google account found on device"
	}
	
	object UserCancelled : GoogleAuthException() {
		override val message = "User cancelled sign in"
	}
	
	object InvalidCredential : GoogleAuthException() {
		override val message = "Invalid credential received"
	}
	
	object UserInteractionRequired : GoogleAuthException() {
		override val message = "User interaction required for sign in"
	}
	
	data class ConfigurationError(override val message: String) : GoogleAuthException()
	
	data class AuthenticationFailed(override val message: String) : GoogleAuthException()
	
	data class UnknownError(override val message: String) : GoogleAuthException()
	
	object NetworkError : GoogleAuthException() {
		override val message = "Network error occurred"
	}
}