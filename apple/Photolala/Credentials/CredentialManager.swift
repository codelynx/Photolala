//
//  CredentialManager.swift
//  Photolala
//
//  Convenient wrapper for credential access
//

import Foundation

// MARK: - Data Types

public struct AWSCredentials {
	public let accessKey: String
	public let secretKey: String
	public let region: String
}

public struct AppleSignInConfig {
	public let keyId: String
	public let teamId: String
	public let clientId: String
	public let bundleId: String
	public let privateKey: String
}

public enum AWSEnvironment: String {
	case development = "development"
	case staging = "staging"
	case production = "production"

	var awsBucket: String {
		switch self {
		case .development: return "photolala-dev"
		case .staging: return "photolala-stage"
		case .production: return "photolala-prod"
		}
	}
}

// MARK: - Protocol for Testing

public protocol CredentialProviding {
	func awsCredentials(for environment: AWSEnvironment) -> AWSCredentials?
	var appleSignInConfig: AppleSignInConfig? { get }
	var currentEnvironment: AWSEnvironment { get }
}

// MARK: - Main Implementation

public class CredentialManager: CredentialProviding {
	public static let shared = CredentialManager()

	private init() {}

	// MARK: - Current Environment

	public var currentEnvironment: AWSEnvironment {
		#if DEBUG || DEVELOPER
		let envString = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
		return AWSEnvironment(rawValue: envString) ?? .development
		#else
		// Production builds always use production
		return .production
		#endif
	}

	// MARK: - AWS Credentials

	public func awsCredentials(for environment: AWSEnvironment) -> AWSCredentials? {
		let accessKey: CredentialKey
		let secretKey: CredentialKey

		switch environment {
		case .development:
			accessKey = .AWS_ACCESS_KEY_ID_DEV
			secretKey = .AWS_SECRET_ACCESS_KEY_DEV
		case .staging:
			accessKey = .AWS_ACCESS_KEY_ID_STAGE
			secretKey = .AWS_SECRET_ACCESS_KEY_STAGE
		case .production:
			accessKey = .AWS_ACCESS_KEY_ID_PROD
			secretKey = .AWS_SECRET_ACCESS_KEY_PROD
		}

		guard let access = Credentials.decryptCached(accessKey),
			  let secret = Credentials.decryptCached(secretKey),
			  let region = Credentials.decryptCached(.AWS_REGION) else {
			return nil
		}

		return AWSCredentials(
			accessKey: access,
			secretKey: secret,
			region: region
		)
	}

	/// Get AWS credentials for current environment
	public var currentAWSCredentials: AWSCredentials? {
		return awsCredentials(for: currentEnvironment)
	}

	/// Get AWS bucket for current environment
	public var currentAWSBucket: String {
		return currentEnvironment.awsBucket
	}

	// MARK: - Apple Sign-In

	public var appleSignInConfig: AppleSignInConfig? {
		guard let keyId = Credentials.decryptCached(.APPLE_KEY_ID),
			  let teamId = Credentials.decryptCached(.APPLE_TEAM_ID),
			  let clientId = Credentials.decryptCached(.APPLE_CLIENT_ID),
			  let bundleId = Credentials.decryptCached(.APPLE_BUNDLE_ID),
			  let privateKey = Credentials.decryptCached(.APPLE_PRIVATE_KEY) else {
			return nil
		}

		return AppleSignInConfig(
			keyId: keyId,
			teamId: teamId,
			clientId: clientId,
			bundleId: bundleId,
			privateKey: privateKey
		)
	}

	// MARK: - Utility Methods

	/// Clear credential cache (useful after environment switch)
	public func clearCache() {
		Credentials.clearCache()
	}

	/// Update environment preference (for environment switching)
	public func updateEnvironment(to environment: AWSEnvironment) {
		#if DEBUG || DEVELOPER
		UserDefaults.standard.set(environment.rawValue, forKey: "environment_preference")
		print("[CredentialManager] Environment updated to: \(environment.rawValue)")
		#endif
	}

	/// Invalidate credential cache to force reload
	public func invalidateCache() {
		clearCache()
		print("[CredentialManager] Credential cache invalidated")
	}

	/// Check if all required credentials are available
	public func validateCredentials() -> Bool {
		// Check AWS credentials
		guard let aws = currentAWSCredentials else {
			print("❌ AWS credentials missing for \(currentEnvironment)")
			return false
		}

		// Validate AWS credential format
		guard aws.accessKey.starts(with: "AKIA"),
			  !aws.secretKey.isEmpty,
			  !aws.region.isEmpty else {
			print("❌ Invalid AWS credential format")
			return false
		}

		// Check Apple Sign-In (optional but log if missing)
		if appleSignInConfig == nil {
			print("⚠️ Apple Sign-In credentials missing")
		}

		return true
	}
}

// MARK: - Convenience Extensions

extension CredentialManager {
	/// Quick access to dev credentials (for testing)
	public var devAWSCredentials: AWSCredentials? {
		return awsCredentials(for: .development)
	}

	/// Quick access to production credentials
	public var prodAWSCredentials: AWSCredentials? {
		return awsCredentials(for: .production)
	}

	/// Environment display name
	public var environmentDisplayName: String {
		switch currentEnvironment {
		case .development: return "Development"
		case .staging: return "Staging"
		case .production: return "Production"
		}
	}

	/// Environment badge for UI
	public var environmentBadge: String? {
		#if DEBUG || DEVELOPER
		switch currentEnvironment {
		case .development: return "DEV"
		case .staging: return "STAGE"
		case .production: return nil // Don't show badge for prod
		}
		#else
		return nil // Never show badge in release builds
		#endif
	}
}

// MARK: - Mock Implementation for Testing

#if DEBUG
public class MockCredentialManager: CredentialProviding {
	public var mockEnvironment: AWSEnvironment = .development
	public var mockAWSCredentials: AWSCredentials?
	public var mockAppleConfig: AppleSignInConfig?

	public init() {
		// Set up default mock credentials
		mockAWSCredentials = AWSCredentials(
			accessKey: "AKIAMOCKTEST123456",
			secretKey: "mockSecretKey123456789",
			region: "us-east-1"
		)

		mockAppleConfig = AppleSignInConfig(
			keyId: "MOCKKEY123",
			teamId: "MOCKTEAM",
			clientId: "com.test.mock",
			bundleId: "com.test.mock",
			privateKey: "mock-private-key"
		)
	}

	public var currentEnvironment: AWSEnvironment {
		return mockEnvironment
	}

	public func awsCredentials(for environment: AWSEnvironment) -> AWSCredentials? {
		return mockAWSCredentials
	}

	public var appleSignInConfig: AppleSignInConfig? {
		return mockAppleConfig
	}
}
#endif