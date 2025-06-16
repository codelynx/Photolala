import SwiftUI

struct SignInPromptView: View {
	@Environment(\.dismiss) private var dismiss
	@StateObject private var identityManager = IdentityManager.shared
	
	var body: some View {
		VStack(spacing: 32) {
			// Header
			VStack(spacing: 16) {
				Image(systemName: "icloud.and.arrow.up")
					.font(.system(size: 60))
					.foregroundColor(.accentColor)
				
				Text("Sign In to Back Up Photos")
					.font(.largeTitle)
					.fontWeight(.bold)
				
				Text("Create a free account to back up your photos to the cloud and access them from any device.")
					.font(.body)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.frame(maxWidth: 400)
			}
			.padding(.top, 40)
			
			// Benefits
			VStack(alignment: .leading, spacing: 16) {
				FeatureRow(
					icon: "icloud",
					title: "5 GB Free Storage",
					description: "Start with 5 GB of free cloud storage"
				)
				
				FeatureRow(
					icon: "devices.phone.and.tablet",
					title: "Access Anywhere",
					description: "View your photos on all your devices"
				)
				
				FeatureRow(
					icon: "lock.shield",
					title: "Secure & Private",
					description: "Your photos are encrypted and private"
				)
				
				FeatureRow(
					icon: "arrow.up.circle",
					title: "Automatic Backup",
					description: "Never lose your precious memories"
				)
			}
			.frame(maxWidth: 400)
			.padding(.vertical)
			
			// Sign In Button
			SignInWithAppleButton()
				.padding(.bottom, 20)
			
			// Skip for now
			Button("Browse Locally Only") {
				dismiss()
			}
			.foregroundColor(.secondary)
			.padding(.bottom, 40)
		}
		.frame(width: 500, height: 600)
		.background(Color(NSColor.windowBackgroundColor))
		.onChange(of: identityManager.isSignedIn) { _, isSignedIn in
			if isSignedIn {
				dismiss()
			}
		}
	}
}

struct FeatureRow: View {
	let icon: String
	let title: String
	let description: String
	
	var body: some View {
		HStack(alignment: .top, spacing: 16) {
			Image(systemName: icon)
				.font(.title2)
				.foregroundColor(.accentColor)
				.frame(width: 30)
			
			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.headline)
				Text(description)
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
	}
}

// MARK: - Subscription Upgrade View

struct SubscriptionUpgradeView: View {
	@Environment(\.dismiss) private var dismiss
	@StateObject private var identityManager = IdentityManager.shared
	
	let currentUsage: Int64
	let storageLimit: Int64
	
	var usagePercentage: Double {
		Double(currentUsage) / Double(storageLimit)
	}
	
	var body: some View {
		VStack(spacing: 24) {
			// Header
			VStack(spacing: 16) {
				Image(systemName: "exclamationmark.icloud")
					.font(.system(size: 50))
					.foregroundColor(.orange)
				
				Text("Storage Limit Reached")
					.font(.largeTitle)
					.fontWeight(.bold)
				
				Text("You've used \(formatBytes(currentUsage)) of your \(formatBytes(storageLimit)) free storage.")
					.font(.body)
					.foregroundColor(.secondary)
			}
			.padding(.top, 40)
			
			// Usage indicator
			VStack(alignment: .leading, spacing: 8) {
				ProgressView(value: usagePercentage)
					.tint(.orange)
				
				HStack {
					Text(formatBytes(currentUsage))
						.font(.caption)
					Spacer()
					Text(formatBytes(storageLimit))
						.font(.caption)
				}
				.foregroundColor(.secondary)
			}
			.frame(maxWidth: 300)
			.padding()
			
			// Subscription tiers
			VStack(spacing: 12) {
				SubscriptionTierRow(tier: .basic, isRecommended: true)
				SubscriptionTierRow(tier: .standard, isRecommended: false)
				SubscriptionTierRow(tier: .pro, isRecommended: false)
			}
			.padding(.horizontal)
			
			// Actions
			HStack(spacing: 16) {
				Button("Maybe Later") {
					dismiss()
				}
				.buttonStyle(.plain)
				
				Button("View All Plans") {
					// Show full subscription view
				}
				.buttonStyle(.borderedProminent)
			}
			.padding(.bottom, 40)
		}
		.frame(width: 500, height: 600)
		.background(Color(NSColor.windowBackgroundColor))
	}
	
	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
}

struct SubscriptionTierRow: View {
	let tier: SubscriptionTier
	let isRecommended: Bool
	
	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				HStack {
					Text(tier.displayName)
						.font(.headline)
					if isRecommended {
						Text("RECOMMENDED")
							.font(.caption2)
							.fontWeight(.bold)
							.foregroundColor(.white)
							.padding(.horizontal, 6)
							.padding(.vertical, 2)
							.background(Color.accentColor)
							.cornerRadius(4)
					}
				}
				
				Text("\(formatBytes(tier.storageLimit)) storage")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			
			Spacer()
			
			Text(tier.monthlyPrice)
				.font(.title3)
				.fontWeight(.semibold)
		}
		.padding()
		.background(isRecommended ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
		.cornerRadius(8)
		
	}
	
	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
}

#Preview("Sign In") {
	SignInPromptView()
}

#Preview("Upgrade") {
	SubscriptionUpgradeView(
		currentUsage: 5 * 1024 * 1024 * 1024,
		storageLimit: 5 * 1024 * 1024 * 1024
	)
}