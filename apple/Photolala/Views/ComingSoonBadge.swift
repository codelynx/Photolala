//
//  ComingSoonBadge.swift
//  Photolala
//
//  Created by Photolala on 6/17/25.
//

import SwiftUI

struct ComingSoonBadge: View {
	var body: some View {
		Text("Coming Soon")
			.font(.caption2)
			.fontWeight(.medium)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(Color.orange)
			.foregroundColor(.white)
			.cornerRadius(12)
	}
}

struct ComingSoonOverlay: ViewModifier {
	let show: Bool
	
	func body(content: Content) -> some View {
		content
			.overlay(alignment: .topTrailing) {
				if show && FeatureFlags.showComingSoonBadges {
					ComingSoonBadge()
						.padding(8)
				}
			}
	}
}

extension View {
	func comingSoon(_ show: Bool = true) -> some View {
		modifier(ComingSoonOverlay(show: show))
	}
}

#Preview {
	VStack(spacing: 20) {
		// Example card with coming soon badge
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Image(systemName: "icloud.and.arrow.up")
					.font(.largeTitle)
					.foregroundColor(.blue)
				Spacer()
			}
			
			Text("Cloud Backup")
				.font(.headline)
			
			Text("Automatically backup your photos to secure cloud storage")
				.font(.caption)
				.foregroundColor(.secondary)
		}
		.padding()
		.frame(width: 250)
		.background(Color(XPlatform.secondaryBackgroundColor))
		.cornerRadius(12)
		.comingSoon()
		
		// Regular view without badge
		Text("Available Feature")
			.padding()
			.background(Color.blue)
			.foregroundColor(.white)
			.cornerRadius(8)
			.comingSoon(false)
	}
	.padding()
}