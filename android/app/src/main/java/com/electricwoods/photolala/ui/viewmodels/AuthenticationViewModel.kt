package com.electricwoods.photolala.ui.viewmodels

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.electricwoods.photolala.models.AuthProvider
import com.electricwoods.photolala.services.IdentityManager
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthenticationViewModel @Inject constructor(
	val identityManager: IdentityManager
) : ViewModel() {
	
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
			}
		}
	}
}