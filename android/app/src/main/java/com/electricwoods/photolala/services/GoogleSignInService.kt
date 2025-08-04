package com.electricwoods.photolala.services

import android.content.Context
import android.content.Intent
import android.util.Log
import com.electricwoods.photolala.models.AuthCredential
import com.electricwoods.photolala.models.AuthProvider
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

sealed class GoogleSignInException : Exception() {
	object UserCancelled : GoogleSignInException() {
		override val message = "User cancelled sign in"
	}
	
	data class SignInFailed(override val message: String) : GoogleSignInException()
	
	data class UnknownError(override val message: String) : GoogleSignInException()
}

/**
 * Service for Google Sign-In (authentication only)
 */
@Singleton
class GoogleSignInService @Inject constructor(
	@ApplicationContext private val context: Context
) {
	companion object {
		private const val TAG = "GoogleSignInService"
		// Web Client ID for Google Sign-In (from unified Photolala project)
		private const val WEB_CLIENT_ID = "75309194504-p2sfktq2ju97ataogb1e5fkl70cj2jg3.apps.googleusercontent.com"
	}
	
	private val googleSignInClient: GoogleSignInClient by lazy {
		val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
			.requestIdToken(WEB_CLIENT_ID)
			.requestEmail()
			.requestProfile()
			.build()
		
		GoogleSignIn.getClient(context, gso)
	}
	
	/**
	 * Get the sign-in intent to launch the Google Sign-In flow
	 */
	fun getSignInIntent(): Intent {
		return googleSignInClient.signInIntent
	}
	
	/**
	 * Handle the sign-in result and extract user credentials
	 */
	fun handleSignInResult(data: Intent?): Result<AuthCredential> {
		return try {
			val task = GoogleSignIn.getSignedInAccountFromIntent(data)
			val account = task.getResult(ApiException::class.java)
			
			if (account != null) {
				val credential = createAuthCredential(account)
				Result.success(credential)
			} else {
				Result.failure(GoogleSignInException.SignInFailed("Invalid account received from sign in"))
			}
		} catch (e: ApiException) {
			Log.e(TAG, "Sign-in failed with code: ${e.statusCode}", e)
			when (e.statusCode) {
				12501 -> Result.failure(GoogleSignInException.UserCancelled)
				else -> Result.failure(GoogleSignInException.SignInFailed(e.message ?: "Unknown error"))
			}
		} catch (e: Exception) {
			Log.e(TAG, "Unexpected error during sign-in", e)
			Result.failure(GoogleSignInException.UnknownError(e.message ?: "Unknown error"))
		}
	}
	
	/**
	 * Sign out the current user
	 */
	fun signOut() {
		googleSignInClient.signOut()
	}
	
	/**
	 * Create AuthCredential from GoogleSignInAccount
	 */
	private fun createAuthCredential(account: GoogleSignInAccount): AuthCredential {
		return AuthCredential(
			provider = AuthProvider.GOOGLE,
			providerID = account.id ?: "",
			email = account.email,
			fullName = account.displayName,
			photoURL = account.photoUrl?.toString(),
			idToken = account.idToken,
			accessToken = null // We don't need access token for basic auth
		)
	}
}