package com.electricwoods.photolala.models

import kotlinx.serialization.Serializable

@Serializable
enum class AuthProvider(val value: String) {
	GOOGLE("google"),
	APPLE("apple");
	
	companion object {
		fun fromValue(value: String): AuthProvider? {
			return values().find { it.value == value }
		}
	}
	
	val displayName: String
		get() = when (this) {
			GOOGLE -> "Google"
			APPLE -> "Apple"
		}
}