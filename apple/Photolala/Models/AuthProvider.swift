import Foundation

enum AuthProvider: String, Codable, CaseIterable {
	case apple = "apple"
	case google = "google"
	
	var displayName: String {
		switch self {
		case .apple: return "Apple"
		case .google: return "Google"
		}
	}
	
	var iconName: String {
		switch self {
		case .apple: return "apple.logo"
		case .google: return "globe"
		}
	}
}

enum AuthError: LocalizedError {
	case providerNotImplemented
	case noAccountFound(provider: AuthProvider, credential: AuthCredential? = nil)
	case accountAlreadyExists(provider: AuthProvider)
	case authenticationFailed(reason: String)
	case invalidCredentials
	case networkError
	case keychainError
	case userCancelled
	case noStoredCredentials
	case unknownError(String)
	
	// Account linking errors
	case emailAlreadyInUse(existingUser: PhotolalaUser, newCredential: AuthCredential)
	case providerAlreadyLinked
	case providerInUseByAnotherAccount
	case cannotUnlinkLastProvider
	case emailMismatch
	
	// Custom error with code and message
	case custom(code: String, message: String)
	
	init(code: String, message: String) {
		self = .custom(code: code, message: message)
	}
	
	var errorDescription: String? {
		switch self {
		case .providerNotImplemented:
			return "This sign-in method is not yet available"
		case .noAccountFound(let provider, _):
			return "No account found with \(provider.displayName). Please create an account first."
		case .accountAlreadyExists(let provider):
			return "An account already exists with \(provider.displayName). Please sign in instead."
		case .authenticationFailed(let reason):
			return "Authentication failed: \(reason)"
		case .invalidCredentials:
			return "Invalid credentials received from provider"
		case .networkError:
			return "Network error. Please check your connection."
		case .keychainError:
			return "Failed to save account information"
		case .userCancelled:
			return "Sign in was cancelled"
		case .noStoredCredentials:
			return "No stored credentials found"
		case .unknownError(let message):
			return message
			
		// Account linking errors
		case .emailAlreadyInUse:
			return "An account with this email already exists"
		case .providerAlreadyLinked:
			return "This sign-in method is already linked to your account"
		case .providerInUseByAnotherAccount:
			return "This sign-in method is already used by another account"
		case .cannotUnlinkLastProvider:
			return "Cannot remove your only sign-in method"
		case .emailMismatch:
			return "The email addresses don't match"
			
		case .custom(_, let message):
			return message
		}
	}
}