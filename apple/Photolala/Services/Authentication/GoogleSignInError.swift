//
//  GoogleSignInError.swift
//  Photolala
//
//  Error types for Google Sign-In
//

import Foundation

/// Errors that can occur during Google Sign-In
enum GoogleSignInError: LocalizedError {
	// OAuth errors
	case invalidAuthorizationResponse
	case stateMismatch           // CSRF protection
	case noAuthorizationCode
	case tokenExchangeFailed(String)
	case userCancelled
	case signInAlreadyInProgress
	case invalidConfiguration
	case authorizationFailed(String)
	case invalidState
	case invalidTokenResponse

	// JWT verification errors
	case invalidIDToken          // Structure invalid
	case missingKeyID           // No kid in header
	case unknownKeyID           // Key not in Google's set
	case invalidSignature       // Signature verification failed
	case invalidIssuer          // Wrong issuer
	case invalidAudience        // Wrong audience
	case tokenExpired           // Past expiration
	case invalidIssuedAt        // Future issued time
	case nonceMismatch          // Replay protection

	// Platform errors
	case webAuthenticationUnavailable
	case publicKeyFetchFailed

	var errorDescription: String? {
		switch self {
		case .invalidAuthorizationResponse:
			return "Invalid authorization response from Google"
		case .stateMismatch:
			return "Security error: State mismatch detected (possible CSRF attack)"
		case .noAuthorizationCode:
			return "No authorization code received from Google"
		case .tokenExchangeFailed(let error):
			return "Failed to exchange authorization code: \(error)"
		case .userCancelled:
			return "Sign-in was cancelled"
		case .signInAlreadyInProgress:
			return "Sign-in is already in progress"
		case .invalidConfiguration:
			return "Invalid OAuth configuration"
		case .authorizationFailed(let error):
			return "Authorization failed: \(error)"
		case .invalidState:
			return "Invalid OAuth state"
		case .invalidTokenResponse:
			return "Invalid token response from Google"
		case .invalidIDToken:
			return "Invalid ID token structure"
		case .missingKeyID:
			return "Missing key ID in token header"
		case .unknownKeyID:
			return "Unknown key ID - key not found in Google's public keys"
		case .invalidSignature:
			return "Invalid token signature"
		case .invalidIssuer:
			return "Invalid token issuer"
		case .invalidAudience:
			return "Invalid token audience"
		case .tokenExpired:
			return "Token has expired"
		case .invalidIssuedAt:
			return "Invalid token issue time"
		case .nonceMismatch:
			return "Security error: Nonce mismatch detected (possible replay attack)"
		case .webAuthenticationUnavailable:
			return "Web authentication is not available"
		case .publicKeyFetchFailed:
			return "Failed to fetch Google's public keys"
		}
	}

	var recoverySuggestion: String? {
		switch self {
		case .userCancelled:
			return "Please try signing in again"
		case .stateMismatch, .nonceMismatch:
			return "For security reasons, please try signing in again"
		case .tokenExpired:
			return "Your session has expired. Please sign in again"
		case .webAuthenticationUnavailable:
			return "Please check your internet connection and try again"
		case .publicKeyFetchFailed:
			return "Please check your internet connection and try again"
		default:
			return "Please try again or contact support if the problem persists"
		}
	}
}