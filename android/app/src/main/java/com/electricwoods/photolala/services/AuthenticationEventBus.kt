package com.electricwoods.photolala.services

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
	}
	
	private val _events = MutableSharedFlow<AuthEvent>()
	val events: SharedFlow<AuthEvent> = _events.asSharedFlow()
	
	suspend fun emitAppleSignInCompleted() {
		_events.emit(AuthEvent.AppleSignInCompleted)
	}
	
	suspend fun emitGoogleSignInCompleted() {
		_events.emit(AuthEvent.GoogleSignInCompleted)
	}
}