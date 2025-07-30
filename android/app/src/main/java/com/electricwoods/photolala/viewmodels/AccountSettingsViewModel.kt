package com.electricwoods.photolala.viewmodels

import android.app.Activity
import android.content.Intent
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.models.PhotolalaUser
import com.electricwoods.photolala.services.AuthException
import com.electricwoods.photolala.services.GoogleSignInLegacyService
import com.electricwoods.photolala.services.IdentityManager
import com.electricwoods.photolala.services.AppleAuthService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

data class AccountSettingsUiState(
	val user: PhotolalaUser? = null,
	val isLoading: Boolean = false,
	val errorMessage: String? = null,
	val isLinking: Boolean = false,
	val pendingLinkProvider: AuthProvider? = null
)

@HiltViewModel
class AccountSettingsViewModel @Inject constructor(
	private val identityManager: IdentityManager,
	private val googleSignInLegacyService: GoogleSignInLegacyService,
	private val appleAuthService: AppleAuthService
) : ViewModel() {
	
	private val _uiState = MutableStateFlow(AccountSettingsUiState())
	val uiState: StateFlow<AccountSettingsUiState> = _uiState.asStateFlow()
	
	init {
		// Observe the current user
		viewModelScope.launch {
			identityManager.currentUser.collect { user ->
				_uiState.value = _uiState.value.copy(user = user)
			}
		}
	}
	
	fun linkProvider(provider: AuthProvider) {
		viewModelScope.launch {
			_uiState.value = _uiState.value.copy(
				isLinking = true,
				pendingLinkProvider = provider,
				errorMessage = null
			)
			
			val result = identityManager.linkProvider(provider)
			
			result.fold(
				onSuccess = {
					// Success - provider linked
					_uiState.value = _uiState.value.copy(
						isLinking = false,
						pendingLinkProvider = null
					)
				},
				onFailure = { error ->
					when (error) {
						is AuthException.GoogleSignInPending -> {
							// Need to trigger Google Sign-In from Activity
							// The activity will handle this
						}
						is AuthException.AppleSignInPending -> {
							// Need to trigger Apple Sign-In
							appleAuthService.signIn()
						}
						else -> {
							_uiState.value = _uiState.value.copy(
								isLinking = false,
								pendingLinkProvider = null,
								errorMessage = error.message
							)
						}
					}
				}
			)
		}
	}
	
	fun unlinkProvider(provider: AuthProvider) {
		viewModelScope.launch {
			_uiState.value = _uiState.value.copy(isLoading = true, errorMessage = null)
			
			val result = identityManager.unlinkProvider(provider)
			
			result.fold(
				onSuccess = {
					_uiState.value = _uiState.value.copy(isLoading = false)
				},
				onFailure = { error ->
					_uiState.value = _uiState.value.copy(
						isLoading = false,
						errorMessage = error.message
					)
				}
			)
		}
	}
	
	fun clearError() {
		_uiState.value = _uiState.value.copy(errorMessage = null)
	}
	
	// For Google Sign-In
	fun getGoogleSignInIntent(): Intent? {
		return if (_uiState.value.pendingLinkProvider == AuthProvider.GOOGLE) {
			googleSignInLegacyService.getSignInIntent()
		} else {
			null
		}
	}
	
	// Handle Google Sign-In result
	fun handleGoogleSignInResult(data: Intent?) {
		viewModelScope.launch {
			if (_uiState.value.pendingLinkProvider == AuthProvider.GOOGLE) {
				val result = identityManager.handleGoogleLinkResult(data)
				
				result.fold(
					onSuccess = {
						_uiState.value = _uiState.value.copy(
							isLinking = false,
							pendingLinkProvider = null
						)
					},
					onFailure = { error ->
						_uiState.value = _uiState.value.copy(
							isLinking = false,
							pendingLinkProvider = null,
							errorMessage = if (error is AuthException.UserCancelled) null else error.message
						)
					}
				)
			}
		}
	}
	
	// Handle Apple Sign-In result (called from MainActivity deep link)
	fun handleAppleSignInCallback(uri: android.net.Uri) {
		viewModelScope.launch {
			if (_uiState.value.pendingLinkProvider == AuthProvider.APPLE) {
				val result = identityManager.handleAppleLinkCallback(uri)
				
				result.fold(
					onSuccess = {
						_uiState.value = _uiState.value.copy(
							isLinking = false,
							pendingLinkProvider = null
						)
					},
					onFailure = { error ->
						_uiState.value = _uiState.value.copy(
							isLinking = false,
							pendingLinkProvider = null,
							errorMessage = if (error is AuthException.UserCancelled) null else error.message
						)
					}
				)
			}
		}
	}
}