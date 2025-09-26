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
	@State private var showingSwitcher = false

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
		#if DEVELOPER
		// Show badge in developer builds (including TestFlight)
		return true
		#else
		// Hide badge in AppStore builds
		return false
		#endif
	}

	var body: some View {
		if shouldShowBadge {
			ZStack {
				// Invisible background to not interfere with other UI
				Color.clear

				VStack {
					HStack {
						Spacer()
						#if os(macOS)
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
							.onTapGesture {
								showingSwitcher = true
							}
							.onHover { hovering in
								isHovering = hovering
							}
							.help("Click to switch environment")
						#else
						Text(currentEnvironment)
							.font(.caption2)
							.fontWeight(.bold)
							.foregroundColor(.white)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(badgeColor)
							.cornerRadius(4)
							.onTapGesture {
								showingSwitcher = true
							}
						#endif
						Spacer()
							.frame(width: 8)
					}
					.padding(.top, 8)
					Spacer()
				}
			}
			.sheet(isPresented: $showingSwitcher) {
				EnvironmentSwitcherView(isPresented: $showingSwitcher)
			}
		}
	}
}

#Preview {
	EnvironmentBadgeView()
}