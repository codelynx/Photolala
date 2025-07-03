package com.electricwoods.photolala.ui.viewmodels

import androidx.lifecycle.ViewModel
import com.electricwoods.photolala.services.IdentityManager
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class WelcomeViewModel @Inject constructor(
	private val identityManager: IdentityManager
) : ViewModel() {
	
	val currentUser = identityManager.currentUser
	val isSignedIn = identityManager.isSignedIn
	
	fun signOut() {
		identityManager.signOut()
	}
}