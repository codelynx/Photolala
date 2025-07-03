package com.electricwoods.photolala.models

data class AuthCredential(
	val provider: AuthProvider,
	val providerID: String,
	val email: String?,
	val fullName: String?,
	val photoURL: String?,
	val idToken: String?,
	val accessToken: String?,
	val serviceUserId: String? = null
)