//
//  AccountSettingsView.swift
//  Photolala
//
//  Created by Claude on 7/3/25.
//

import SwiftUI

struct AccountSettingsView: View {
	@EnvironmentObject private var identityManager: IdentityManager
	@StateObject private var s3BackupManager = S3BackupManager.shared
	@Environment(\.dismiss) private var dismiss
	
	private var user: PhotolalaUser? {
		identityManager.currentUser
	}
	
	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Account")
				#if os(iOS)
				.navigationBarTitleDisplayMode(.inline)
				#endif
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") {
							dismiss()
						}
					}
				}
		}
		.task {
			await s3BackupManager.updateStorageInfo()
		}
	}
	
	@ViewBuilder
	private var content: some View {
		if let user = user {
			Form {
				userInfoSection(user: user)
				linkedProvidersSection
				storageSection
				subscriptionSection(user: user)
				actionsSection
			}
		} else {
			Text("Not signed in")
				.foregroundStyle(.secondary)
		}
	}
	
	private func userInfoSection(user: PhotolalaUser) -> some View {
		Section {
			HStack {
				userAvatar(photoURL: user.photoURL)
				userInfo(user: user)
				Spacer()
			}
			.padding(.vertical, 8)
		}
	}
	
	@ViewBuilder
	private func userAvatar(photoURL: String?) -> some View {
		if let photoURL = photoURL,
		   let url = URL(string: photoURL) {
			AsyncImage(url: url) { image in
				image
					.resizable()
					.aspectRatio(contentMode: .fill)
			} placeholder: {
				defaultAvatar
			}
			.frame(width: 60, height: 60)
			.clipShape(Circle())
		} else {
			defaultAvatar
		}
	}
	
	private var defaultAvatar: some View {
		Image(systemName: "person.circle.fill")
			.font(.system(size: 60))
			.foregroundColor(.accentColor)
	}
	
	private func userInfo(user: PhotolalaUser) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(user.fullName ?? "Photolala User")
				.font(.title3)
				.fontWeight(.semibold)
			if let email = user.email {
				Text(email)
					.font(.caption)
					.foregroundColor(.secondary)
			}
			Text("Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
				.font(.caption2)
				.foregroundColor(.secondary)
		}
	}
	
	private var linkedProvidersSection: some View {
		Section {
			LinkedProvidersView()
		}
	}
	
	private var storageSection: some View {
		Section("Storage") {
			HStack {
				Label("Cloud Storage", systemImage: "icloud")
				Spacer()
				Text(storageInfo)
					.foregroundColor(.secondary)
			}
		}
	}
	
	private func subscriptionSection(user: PhotolalaUser) -> some View {
		Section("Subscription") {
			subscriptionContent(user: user)
		}
	}
	
	@ViewBuilder
	private func subscriptionContent(user: PhotolalaUser) -> some View {
		if let subscription = user.subscription {
			subscriptionStatus(subscription: subscription)
			if subscription.tier == .free {
				freeTrialInfo(subscription: subscription)
			}
		} else {
			Text("No active subscription")
				.foregroundColor(.secondary)
		}
	}
	
	private func subscriptionStatus(subscription: Subscription) -> some View {
		HStack {
			Label(subscription.displayName, systemImage: "crown")
			Spacer()
			subscriptionBadge(subscription: subscription)
		}
	}
	
	private func subscriptionBadge(subscription: Subscription) -> some View {
		Text(subscription.isActive ? "Active" : "Expired")
			.foregroundColor(subscription.isActive ? .green : .red)
			.font(.caption)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(subscription.isActive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
			.cornerRadius(4)
	}
	
	private func freeTrialInfo(subscription: Subscription) -> some View {
		HStack {
			Image(systemName: "info.circle")
				.foregroundColor(.blue)
			Text("Free trial ends \(subscription.expiryDate.formatted(date: .abbreviated, time: .omitted))")
				.font(.caption)
		}
	}
	
	private var actionsSection: some View {
		Section {
			Button(role: .destructive) {
				signOut()
			} label: {
				Label("Sign Out", systemImage: "arrow.right.square")
					.foregroundColor(.red)
			}
		}
	}
	
	private func signOut() {
		identityManager.signOut()
		dismiss()
	}
	
	private var storageInfo: String {
		let used = formatBytes(s3BackupManager.currentUsage)
		let total = formatBytes(s3BackupManager.storageLimit)
		return "\(used) / \(total)"
	}
	
	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
}

// MARK: - Preview

#Preview {
	AccountSettingsView()
		.environmentObject(IdentityManager.shared)
}