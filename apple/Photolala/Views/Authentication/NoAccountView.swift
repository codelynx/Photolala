//
//  NoAccountView.swift
//  Photolala
//
//  Shows when user authenticates but doesn't have a Photolala account
//

import SwiftUI

struct NoAccountView: View {
	let providerName: String
	let onCreateAccount: () -> Void
	let onCancel: () -> Void

	var body: some View {
		VStack(spacing: 24) {
			// Icon
			Image(systemName: "person.crop.circle.badge.questionmark")
				.font(.system(size: 72))
				.foregroundStyle(.blue.gradient)
				.padding(.top, 40)

			// Title
			Text("No Photolala Account")
				.font(.largeTitle)
				.fontWeight(.bold)

			// Message
			VStack(spacing: 16) {
				Text("You signed in with \(providerName) but don't have a Photolala account yet.")
					.font(.headline)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)

				Text("Would you like to create a free account to sync and backup your photos across all your devices?")
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
			.padding(.horizontal, 32)

			// Features list
			VStack(alignment: .leading, spacing: 12) {
				FeatureRow(icon: "icloud", text: "Unlimited cloud storage")
				FeatureRow(icon: "devices", text: "Access from all your devices")
				FeatureRow(icon: "sparkles", text: "AI-powered organization")
				FeatureRow(icon: "lock.shield", text: "Secure and private")
			}
			.padding(.horizontal, 40)
			.padding(.vertical, 24)
			.background(Color.blue.opacity(0.05))
			.cornerRadius(12)

			Spacer()

			// Action buttons
			VStack(spacing: 12) {
				Button(action: onCreateAccount) {
					Text("Create Account")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.frame(height: 50)
						.background(Color.blue)
						.foregroundColor(.white)
						.cornerRadius(12)
				}
				.buttonStyle(.plain)

				Button(action: onCancel) {
					Text("Cancel")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.frame(height: 50)
						.background(Color.secondary.opacity(0.1))
						.foregroundColor(.primary)
						.cornerRadius(12)
				}
				.buttonStyle(.plain)
			}
			.padding(.horizontal, 40)
			.padding(.bottom, 40)
		}
		.frame(width: 500, height: 650)
	}
}

private struct FeatureRow: View {
	let icon: String
	let text: String

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: icon)
				.font(.body)
				.foregroundStyle(.blue)
				.frame(width: 24)

			Text(text)
				.font(.body)

			Spacer()
		}
	}
}

#Preview {
	NoAccountView(
		providerName: "Google",
		onCreateAccount: { print("Create account") },
		onCancel: { print("Cancel") }
	)
}