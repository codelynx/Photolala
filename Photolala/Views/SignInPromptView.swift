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
				SignInFeatureRow(
					icon: "icloud",
					title: "Free Trial - 200MB",
					description: "Try our service with 200MB free"
				)

				SignInFeatureRow(
					icon: "iphone",
					title: "Access Anywhere",
					description: "View your photos on all your devices"
				)

				SignInFeatureRow(
					icon: "lock.shield",
					title: "Secure & Private",
					description: "Your photos are encrypted and private"
				)

				SignInFeatureRow(
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
				self.dismiss()
			}
			.foregroundColor(.secondary)
			.padding(.bottom, 40)
		}
		.frame(width: 500, height: 600)
		.background(Color(XPlatform.secondaryBackgroundColor))
			.onChange(of: self.identityManager.isSignedIn) { oldValue, newValue in
				if newValue {
					self.dismiss()
				}
			}
	}
}

struct SignInFeatureRow: View {
	let icon: String
	let title: String
	let description: String

	var body: some View {
		HStack(alignment: .top, spacing: 16) {
			Image(systemName: self.icon)
				.font(.title2)
				.foregroundColor(.accentColor)
				.frame(width: 30)

			VStack(alignment: .leading, spacing: 4) {
				Text(self.title)
					.font(.headline)
				Text(self.description)
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
		Double(self.currentUsage) / Double(self.storageLimit)
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

				Text(
					"You've used \(self.formatBytes(self.currentUsage)) of your \(self.formatBytes(self.storageLimit)) free storage."
				)
				.font(.body)
				.foregroundColor(.secondary)
			}
			.padding(.top, 40)

			// Usage indicator
			VStack(alignment: .leading, spacing: 8) {
				ProgressView(value: self.usagePercentage)
					.tint(.orange)

				HStack {
					Text(self.formatBytes(self.currentUsage))
						.font(.caption)
					Spacer()
					Text(self.formatBytes(self.storageLimit))
						.font(.caption)
				}
				.foregroundColor(.secondary)
			}
			.frame(maxWidth: 300)
			.padding()

			// Subscription tiers
			VStack(spacing: 12) {
				SubscriptionTierRow(tier: .starter, isRecommended: true)
				SubscriptionTierRow(tier: .essential, isRecommended: false)
				SubscriptionTierRow(tier: .plus, isRecommended: false)
			}
			.padding(.horizontal)

			// Actions
			HStack(spacing: 16) {
				Button("Maybe Later") {
					self.dismiss()
				}
				.buttonStyle(.plain)

				Button("View All Plans") {
					// Show full subscription view
				}
				.primaryButtonStyle()
			}
			.padding(.bottom, 40)
		}
		.frame(width: 500, height: 600)
		.background(Color(XPlatform.secondaryBackgroundColor))
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
					Text(self.tier.displayName)
						.font(.headline)
					if self.isRecommended {
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

				Text("\(self.formatBytes(self.tier.storageLimit)) storage")
					.font(.caption)
					.foregroundColor(.secondary)
			}

			Spacer()

			Text(self.tier.monthlyPrice)
				.font(.title3)
				.fontWeight(.semibold)
		}
		.padding()
		.background(self.isRecommended ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.1))
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
		currentUsage: 5 * 1_024 * 1_024 * 1_024,
		storageLimit: 5 * 1_024 * 1_024 * 1_024
	)
}
