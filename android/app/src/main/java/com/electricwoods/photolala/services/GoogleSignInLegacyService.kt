package com.electricwoods.photolala.services

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import com.electricwoods.photolala.models.AuthCredential
import com.electricwoods.photolala.models.AuthProvider
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.Scope
import com.google.android.gms.tasks.Task
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Legacy Google Sign-In implementation as fallback
 */
@Singleton
class GoogleSignInLegacyService @Inject constructor(
	@ApplicationContext private val context: Context
) {
	companion object {
		private const val TAG = "GoogleSignInLegacy"
		// Web Client ID from photolala project (Project ID: photolala)
		private const val WEB_CLIENT_ID = "105828093997-qmr9jdj3h4ia0tt2772cnrejh4k0p609.apps.googleusercontent.com"
		// Google Photos Library scope
		private val GOOGLE_PHOTOS_SCOPE = Scope("https://www.googleapis.com/auth/photoslibrary.readonly")
	}
	
	private val googleSignInClient: GoogleSignInClient by lazy {
		val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
			.requestIdToken(WEB_CLIENT_ID)
			.requestEmail()
			.requestProfile()
			.requestScopes(GOOGLE_PHOTOS_SCOPE)
			.build()
		
		GoogleSignIn.getClient(context, gso)
	}
	
	/**
	 * Get sign-in intent to launch
	 */
	fun getSignInIntent(): Intent {
		Log.d(TAG, "Creating sign-in intent with Web Client ID: $WEB_CLIENT_ID")
		return googleSignInClient.signInIntent
	}
	
	/**
	 * Handle sign-in result
	 */
	fun handleSignInResult(data: Intent?): Result<AuthCredential> {
		val task: Task<GoogleSignInAccount> = GoogleSignIn.getSignedInAccountFromIntent(data)
		return try {
			val account = task.getResult(ApiException::class.java)
			Log.d(TAG, "Sign-in successful: ${account.email}")
			Log.d(TAG, "Google User ID: ${account.id}")
			
			val credential = AuthCredential(
				provider = AuthProvider.GOOGLE,
				providerID = account.id ?: "",
				email = account.email,
				fullName = account.displayName,
				photoURL = account.photoUrl?.toString(),
				idToken = account.idToken,
				accessToken = null
			)
			
			Result.success(credential)
		} catch (e: ApiException) {
			Log.e(TAG, "Sign-in failed with code: ${e.statusCode}", e)
			when (e.statusCode) {
				12500 -> Result.failure(GoogleAuthException.ConfigurationError("Configuration error (12500)"))
				12501 -> Result.failure(GoogleAuthException.UserCancelled)
				12502 -> Result.failure(GoogleAuthException.NetworkError)
				else -> Result.failure(GoogleAuthException.AuthenticationFailed("Error code: ${e.statusCode}"))
			}
		}
	}
	
	/**
	 * Sign out
	 */
	fun signOut() {
		googleSignInClient.signOut()
	}
	
	/**
	 * Check if already signed in
	 */
	fun getLastSignedInAccount(): GoogleSignInAccount? {
		return GoogleSignIn.getLastSignedInAccount(context)
	}
	
	/**
	 * Check if Google Photos scope is granted
	 */
	fun hasGooglePhotosScope(): Boolean {
		val account = getLastSignedInAccount()
		return account?.grantedScopes?.contains(GOOGLE_PHOTOS_SCOPE) ?: false
	}
	
	/**
	 * Request additional scope if needed
	 */
	fun requestGooglePhotosScope(): Intent? {
		val account = getLastSignedInAccount() ?: return null
		
		if (!hasGooglePhotosScope()) {
			// Request additional scope
			val signInOptions = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
				.requestEmail()
				.requestScopes(GOOGLE_PHOTOS_SCOPE)
				.build()
			
			val client = GoogleSignIn.getClient(context, signInOptions)
			return client.signInIntent
		}
		
		return null
	}
}