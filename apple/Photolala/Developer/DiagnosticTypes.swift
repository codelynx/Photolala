//
//  DiagnosticTypes.swift
//  Photolala
//
//  Shared types for diagnostic views
//

#if os(macOS) && DEVELOPER
import SwiftUI

// MARK: - Shared Enums

enum TestEnvironment: String, CaseIterable {
	case development = "Development"
	case staging = "Staging"
	case production = "Production"

	var userDefaultsValue: String {
		switch self {
		case .development: return "development"
		case .staging: return "staging"
		case .production: return "production"
		}
	}

	var color: Color {
		switch self {
		case .development: return .blue
		case .staging: return .orange
		case .production: return .red
		}
	}
}

enum AuthProvider: String, CaseIterable {
	case apple = "Apple"
	case google = "Google"

	var icon: String {
		switch self {
		case .apple: return "apple.logo"
		case .google: return "g.circle"
		}
	}
}

#endif