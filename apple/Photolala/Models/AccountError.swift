import Foundation

enum AccountError: LocalizedError {
	case notSignedIn
	case invalidCredential
	case lambdaError(String)
	case networkError(Error)
	case decodingError(Error)
	case providerAlreadyLinked
	case termsNotAccepted
	case unknown

	var errorDescription: String? {
		switch self {
		case .notSignedIn:
			return "You are not signed in. Please sign in to continue."
		case .invalidCredential:
			return "Invalid credential received from authentication provider."
		case .lambdaError(let message):
			return "Server error: \(message)"
		case .networkError(let error):
			return "Network error: \(error.localizedDescription)"
		case .decodingError(let error):
			return "Failed to process response: \(error.localizedDescription)"
		case .providerAlreadyLinked:
			return "This provider is already linked to another account."
		case .termsNotAccepted:
			return "You must accept the Terms of Service to create an account."
		case .unknown:
			return "An unknown error occurred."
		}
	}
}