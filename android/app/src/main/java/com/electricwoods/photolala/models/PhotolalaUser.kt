package com.electricwoods.photolala.models

import kotlinx.serialization.Serializable
import kotlinx.serialization.Contextual
import java.util.Date

@Serializable
data class PhotolalaUser(
	val serviceUserID: String,          // UUID for S3 storage
	val primaryProvider: AuthProvider,  // First provider used
	val primaryProviderID: String,      // ID from primary provider
	var email: String?,                 // Primary email (may be masked)
	var fullName: String?,
	var photoURL: String?,              // Profile photo URL
	@Serializable(with = DateSerializer::class)
	val createdAt: Date,
	@Serializable(with = DateSerializer::class)
	var lastUpdated: Date,
	val linkedProviders: List<ProviderLink> = emptyList(),
	val subscription: Subscription? = null,
	val preferences: UserPreferences? = null
) {
	val displayName: String
		get() = fullName ?: email ?: "Photolala User"
}

@Serializable
data class ProviderLink(
	val provider: AuthProvider,
	val providerID: String,
	val email: String?,
	@Serializable(with = DateSerializer::class)
	val linkedAt: Date,
	val linkMethod: LinkMethod
)

@Serializable
enum class LinkMethod {
	USER_INITIATED,
	AUTOMATIC
}

@Serializable
data class Subscription(
	val tier: SubscriptionTier,
	val status: SubscriptionStatus,
	@Serializable(with = DateSerializer::class)
	val startDate: Date,
	@Serializable(with = DateSerializer::class)
	val endDate: Date?,
	val autoRenew: Boolean
) {
	companion object {
		fun freeTrial(): Subscription {
			return Subscription(
				tier = SubscriptionTier.FREE,
				status = SubscriptionStatus.ACTIVE,
				startDate = Date(),
				endDate = null,
				autoRenew = false
			)
		}
	}
}

@Serializable
enum class SubscriptionTier {
	FREE,
	STARTER,
	PRO,
	BUSINESS;
	
	val displayName: String
		get() = when (this) {
			FREE -> "Free"
			STARTER -> "Starter"
			PRO -> "Pro"
			BUSINESS -> "Business"
		}
	
	val storageLimit: Long
		get() = when (this) {
			FREE -> 5L * 1024 * 1024 * 1024      // 5 GB
			STARTER -> 100L * 1024 * 1024 * 1024  // 100 GB
			PRO -> 1024L * 1024 * 1024 * 1024     // 1 TB
			BUSINESS -> 10L * 1024 * 1024 * 1024 * 1024  // 10 TB
		}
}

@Serializable
enum class SubscriptionStatus {
	ACTIVE,
	EXPIRED,
	CANCELLED,
	PENDING
}

@Serializable
data class UserPreferences(
	val autoBackup: Boolean = true,
	val wifiOnlyBackup: Boolean = true,
	val notifications: Boolean = true
)