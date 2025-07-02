import Foundation

// MARK: - Enhanced User Model

struct PhotolalaUser: Codable {
	// Primary identity
	let serviceUserID: String          // UUID for S3 storage
	let primaryProvider: AuthProvider  // First provider used
	let primaryProviderID: String      // ID from primary provider
	
	// User information
	let email: String?                 // Primary email (may be masked)
	let fullName: String?
	let photoURL: String?              // Profile photo URL
	let createdAt: Date
	var lastUpdated: Date
	
	// Linked accounts
	var linkedProviders: [ProviderLink] = []
	
	// Account settings
	var subscription: Subscription?
	var preferences: UserPreferences?
	
	// Computed properties
	var displayName: String {
		fullName ?? email ?? "Photolala User"
	}
	
	// Legacy support for existing users
	var appleUserID: String? {
		if primaryProvider == .apple {
			return primaryProviderID
		}
		return linkedProviders.first(where: { $0.provider == .apple })?.providerID
	}
	
	// Initialize from legacy model
	init(legacy: LegacyPhotolalaUser) {
		self.serviceUserID = legacy.serviceUserID
		self.primaryProvider = .apple
		self.primaryProviderID = legacy.appleUserID
		self.email = legacy.email
		self.fullName = legacy.fullName
		self.photoURL = nil
		self.createdAt = legacy.createdAt
		self.lastUpdated = Date()
		self.linkedProviders = []
		self.subscription = legacy.subscription
		self.preferences = UserPreferences()
	}
	
	// Initialize new user
	init(
		serviceUserID: String,
		provider: AuthProvider,
		providerID: String,
		email: String? = nil,
		fullName: String? = nil,
		photoURL: String? = nil,
		subscription: Subscription? = nil
	) {
		self.serviceUserID = serviceUserID
		self.primaryProvider = provider
		self.primaryProviderID = providerID
		self.email = email
		self.fullName = fullName
		self.photoURL = photoURL
		self.createdAt = Date()
		self.lastUpdated = Date()
		self.linkedProviders = []
		self.subscription = subscription ?? Subscription.freeTrial()
		self.preferences = UserPreferences()
	}
}

// MARK: - Provider Link

struct ProviderLink: Codable {
	let provider: AuthProvider
	let providerID: String
	let email: String?            // Provider-specific email
	let linkedAt: Date
	let linkMethod: LinkMethod    // How it was linked
}

enum LinkMethod: String, Codable {
	case emailMatch = "email_match"      // Automatic via email
	case userInitiated = "user_initiated" // Manual linking
	case support = "support"              // Support intervention
}

// MARK: - User Preferences

struct UserPreferences: Codable {
	var uploadQuality: UploadQuality = .high
	var autoBackup: Bool = true
	var wifiOnlyBackup: Bool = true
	var notifications: NotificationPreferences = NotificationPreferences()
}

enum UploadQuality: String, Codable {
	case original = "original"
	case high = "high"
	case medium = "medium"
}

struct NotificationPreferences: Codable {
	var backupComplete: Bool = true
	var quotaWarnings: Bool = true
	var newFeatures: Bool = true
}

// MARK: - Subscription Model

struct Subscription: Codable {
	let tier: SubscriptionTier
	let startDate: Date
	var expiryDate: Date
	let storageLimit: Int64  // in bytes
	var storageUsed: Int64 = 0
	var originalTransactionId: String?
	
	var isActive: Bool {
		Date() < expiryDate
	}
	
	var displayName: String {
		tier.displayName
	}
	
	var quotaBytes: Int64 {
		storageLimit
	}
	
	var storageUsedGB: Double {
		Double(storageUsed) / 1_073_741_824
	}
	
	var storageLimitGB: Double {
		Double(storageLimit) / 1_073_741_824
	}
	
	var percentageUsed: Double {
		guard storageLimit > 0 else { return 0 }
		return Double(storageUsed) / Double(storageLimit) * 100
	}
	
	static func freeTrial() -> Subscription {
		Subscription(
			tier: .free,
			startDate: Date(),
			expiryDate: Date().addingTimeInterval(30 * 24 * 60 * 60), // 30 days
			storageLimit: 200 * 1024 * 1024, // 200MB
			storageUsed: 0
		)
	}
}

enum SubscriptionTier: String, Codable, CaseIterable {
	case free
	case starter = "com.electricwoods.photolala.starter"
	case essential = "com.electricwoods.photolala.essential"
	case plus = "com.electricwoods.photolala.plus"
	case family = "com.electricwoods.photolala.family"
	
	var displayName: String {
		switch self {
		case .free: return "Free Trial"
		case .starter: return "Starter"
		case .essential: return "Essential"
		case .plus: return "Plus"
		case .family: return "Family"
		}
	}
	
	var price: String {
		switch self {
		case .free: return "Free"
		case .starter: return "$0.99/month"
		case .essential: return "$2.99/month"
		case .plus: return "$5.99/month"
		case .family: return "$9.99/month"
		}
	}
	
	var storageLimit: Int64 {
		switch self {
		case .free: return 200 * 1024 * 1024 // 200MB
		case .starter: return 10 * 1024 * 1024 * 1024 // 10GB
		case .essential: return 200 * 1024 * 1024 * 1024 // 200GB
		case .plus: return 2 * 1024 * 1024 * 1024 * 1024 // 2TB
		case .family: return 4 * 1024 * 1024 * 1024 * 1024 // 4TB
		}
	}
}

// MARK: - Legacy Model (for migration)

struct LegacyPhotolalaUser: Codable {
	let serviceUserID: String
	let appleUserID: String
	let email: String?
	let fullName: String?
	let createdAt: Date
	var subscription: Subscription?
}