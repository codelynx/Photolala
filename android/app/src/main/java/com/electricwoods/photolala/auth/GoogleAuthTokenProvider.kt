package com.electricwoods.photolala.auth

import android.accounts.Account
import android.content.Context
import android.util.Log
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.common.api.Scope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Helper class to obtain OAuth2 access tokens for Google Photos API
 */
class GoogleAuthTokenProvider(private val context: Context) {
	
	companion object {
		private const val TAG = "GoogleAuthTokenProvider"
		private const val GOOGLE_PHOTOS_SCOPE = "oauth2:https://www.googleapis.com/auth/photoslibrary.readonly"
	}
	
	/**
	 * Get a fresh access token for Google Photos API
	 * This method handles token refresh automatically
	 */
	suspend fun getAccessToken(): String? = withContext(Dispatchers.IO) {
		try {
			// Get the signed-in account
			val googleAccount = GoogleSignIn.getLastSignedInAccount(context)
			if (googleAccount == null) {
				Log.e(TAG, "No signed-in Google account found")
				return@withContext null
			}
			
			// Create Android Account object
			val account = Account(googleAccount.email, "com.google")
			
			// Get access token using GoogleAuthUtil
			// This will automatically refresh the token if needed
			val token = GoogleAuthUtil.getToken(context, account, GOOGLE_PHOTOS_SCOPE)
			
			Log.d(TAG, "Successfully obtained access token")
			token
		} catch (e: Exception) {
			Log.e(TAG, "Failed to get access token", e)
			
			// Clear cached token if it's invalid
			if (e.message?.contains("Invalid") == true) {
				try {
					val googleAccount = GoogleSignIn.getLastSignedInAccount(context)
					googleAccount?.email?.let { email ->
						val account = Account(email, "com.google")
						GoogleAuthUtil.clearToken(context, GOOGLE_PHOTOS_SCOPE)
					}
				} catch (clearError: Exception) {
					Log.e(TAG, "Failed to clear invalid token", clearError)
				}
			}
			
			null
		}
	}
	
	/**
	 * Clear the cached access token
	 * Call this when you receive 401 Unauthorized from the API
	 */
	suspend fun clearCachedToken() = withContext(Dispatchers.IO) {
		try {
			GoogleAuthUtil.clearToken(context, GOOGLE_PHOTOS_SCOPE)
			Log.d(TAG, "Cleared cached token")
		} catch (e: Exception) {
			Log.e(TAG, "Failed to clear token", e)
		}
	}
}