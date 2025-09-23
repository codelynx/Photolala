//
//  EnvironmentBadgeView.swift
//  Photolala
//
//  Shows current environment badge when enabled in Settings
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EnvironmentBadgeView: View {
	@AppStorage("environment_preference") private var environmentPreference: String?
	@State private var isHovering = false

	private var currentEnvironment: String {
		// Use the environment preference directly for reactivity
		let env = environmentPreference ?? "development"
		switch env {
		case "development":
			return "DEV"
		case "staging":
			return "STAGE"
		case "production":
			return "PROD"
		default:
			return env.uppercased()
		}
	}

	private var badgeColor: Color {
		let env = environmentPreference ?? "development"
		switch env {
		case "development":
			return .orange
		case "staging":
			return .yellow
		case "production":
			return .blue
		default:
			return .gray
		}
	}

	private var shouldShowBadge: Bool {
		#if DEBUG || DEVELOPER
		// Show badge in debug and developer builds
		return true
		#else
		// Hide badge in AppStore builds
		return false
		#endif
	}

	var body: some View {
		if shouldShowBadge {
			VStack {
				HStack {
					Spacer()
					#if os(macOS)
					Button(action: openSettings) {
						Text(currentEnvironment)
							.font(.caption2)
							.fontWeight(.bold)
							.foregroundColor(.white)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(badgeColor.opacity(isHovering ? 0.8 : 1.0))
							.cornerRadius(4)
							.scaleEffect(isHovering ? 1.05 : 1.0)
							.animation(.easeInOut(duration: 0.1), value: isHovering)
					}
					.buttonStyle(.plain)
					.help("Click to open Developer Settings")
					.onHover { hovering in
						isHovering = hovering
					}
					.padding(.trailing, 8)
					.padding(.top, 8)
					#else
					Button(action: openSettings) {
						Text(currentEnvironment)
							.font(.caption2)
							.fontWeight(.bold)
							.foregroundColor(.white)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(badgeColor)
							.cornerRadius(4)
					}
					.buttonStyle(.plain)
					.padding(.trailing, 8)
					.padding(.top, 8)
					#endif
				}
				Spacer()
			}
		}
	}

	private func openSettings() {
		#if os(iOS)
		if let url = URL(string: UIApplication.openSettingsURLString) {
			UIApplication.shared.open(url)
		}
		#elseif os(macOS)
		// Set flag to show developer tab when settings open
		UserDefaults.standard.set(true, forKey: "ShowDeveloperTabOnOpen")
		// Open preferences window
		NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
		#endif
	}
}

#Preview {
	EnvironmentBadgeView()
}