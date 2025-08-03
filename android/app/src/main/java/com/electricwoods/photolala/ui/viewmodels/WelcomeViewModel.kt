package com.electricwoods.photolala.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.services.IdentityManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject

@HiltViewModel
class WelcomeViewModel @Inject constructor(
	private val identityManager: IdentityManager
) : ViewModel() {
	
	val currentUser = identityManager.currentUser
	val isSignedIn = identityManager.isSignedIn
	
	// Check if user has Google account linked
	val hasGoogleAccount: StateFlow<Boolean> = identityManager.currentUser
		.map { user ->
			user?.linkedProviders?.any { it.provider == AuthProvider.GOOGLE } == true ||
			user?.primaryProvider == AuthProvider.GOOGLE
		}
		.stateIn(
			scope = viewModelScope,
			started = SharingStarted.WhileSubscribed(5000),
			initialValue = false
		)
	
	fun signOut() {
		identityManager.signOut()
	}
}