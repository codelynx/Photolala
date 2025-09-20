//
//  EnvironmentHelper.swift
//  Photolala
//
//  Helper utilities for environment management
//

import Foundation

struct EnvironmentHelper {
	/// Check if the current build is a developer build
	/// - DEBUG or DEVELOPER builds: true
	/// - AppStore builds: false
	static var isDeveloperBuild: Bool {
		#if DEBUG || DEVELOPER
		return true
		#else
		return false
		#endif
	}
	
	/// Check if developer settings should be shown
	static var shouldShowDeveloperSettings: Bool {
		return isDeveloperBuild
	}
	
	/// Get the current environment name for display
	static var currentEnvironmentName: String {
		let bucket = getCurrentBucket()
		switch bucket {
		case "photolala-dev":
			return "Development"
		case "photolala-stage":
			return "Staging"
		case "photolala-test":
			return "Test"
		case "photolala-prod":
			return "Production"
		default:
			return "Unknown"
		}
	}
	
	/// Get the current bucket being used
	static func getCurrentBucket() -> String {
		#if DEBUG || DEVELOPER
		// Developer builds can switch between environments
		let environmentPreference = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
		
		switch environmentPreference {
		case "development":
			return "photolala-dev"
		case "staging":
			return "photolala-stage"
		case "production":
			return "photolala-prod"
		default:
			return "photolala-dev"
		}
		#else
		// AppStore builds always use production
		return "photolala-prod"
		#endif
	}
	
	/// Get environment badge text for developer builds
	static var environmentBadge: String? {
		guard isDeveloperBuild else { return nil }
		
		let bucket = getCurrentBucket()
		switch bucket {
		case "photolala-dev":
			return "DEV"
		case "photolala-stage":
			return "STAGE"
		case "photolala-test":
			return "TEST"
		default:
			return nil
		}
	}
	
	/// Get build type description
	static var buildTypeDescription: String {
		let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
		
		#if DEBUG
		return "Debug Build (\(buildNumber))"
		#elseif DEVELOPER
		return "Developer Build (\(buildNumber))"
		#else
		return "Production Build (\(buildNumber))"
		#endif
	}
}