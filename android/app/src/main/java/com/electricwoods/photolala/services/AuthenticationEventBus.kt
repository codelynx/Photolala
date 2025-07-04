package com.electricwoods.photolala.services

import com.electricwoods.photolala.models.AuthCredential
import com.electricwoods.photolala.models.AuthProvider
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Event bus for authentication events to coordinate between
 * deep link callbacks and the UI
 */
@Singleton
class AuthenticationEventBus @Inject constructor() {
	sealed class AuthEvent {
		object AppleSignInCompleted : AuthEvent()
		object GoogleSignInCompleted : AuthEvent()
		data class AppleSignInNoAccountFound(
			val provider: AuthProvider,
			val credential: AuthCredential
		) : AuthEvent()
	}
	
	private val _events = MutableSharedFlow<AuthEvent>()
	val events: SharedFlow<AuthEvent> = _events.asSharedFlow()
	
	suspend fun emitAppleSignInCompleted() {
		_events.emit(AuthEvent.AppleSignInCompleted)
	}
	
	suspend fun emitGoogleSignInCompleted() {
		_events.emit(AuthEvent.GoogleSignInCompleted)
	}
	
	suspend fun emitAppleSignInNoAccountFound(provider: AuthProvider, credential: AuthCredential) {
		_events.emit(AuthEvent.AppleSignInNoAccountFound(provider, credential))
	}
}