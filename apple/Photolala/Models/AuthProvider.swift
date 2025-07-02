import Foundation

enum AuthProvider: String, Codable {
	case apple = "apple"
	case google = "google"
	
	var displayName: String {
		switch self {
		case .apple: return "Apple"
		case .google: return "Google"
		}
	}
}

enum AuthError: LocalizedError {
	case providerNotImplemented
	case noAccountFound(provider: AuthProvider)
	case accountAlreadyExists(provider: AuthProvider)
	case authenticationFailed(reason: String)
	case invalidCredentials
	case networkError
	case keychainError
	
	var errorDescription: String? {
		switch self {
		case .providerNotImplemented:
			return "This sign-in method is not yet available"
		case .noAccountFound(let provider):
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
		}
	}
}