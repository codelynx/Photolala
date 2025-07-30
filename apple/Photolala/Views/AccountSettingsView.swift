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
	@Environment(\.colorScheme) private var colorScheme
	
	private var user: PhotolalaUser? {
		identityManager.currentUser
	}
	
	var body: some View {
		NavigationStack {
			content
				.navigationTitle("Account")
				#if os(iOS)
				.navigationBarTitleDisplayMode(.large)
				#endif
				.toolbar {
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") {
							dismiss()
						}
						.buttonStyle(.bordered)
						.controlSize(.regular)
					}
				}
		}
		#if os(macOS)
		.frame(minWidth: 500, idealWidth: 600, minHeight: 600)
		#endif
		.task {
			await s3BackupManager.updateStorageInfo()
		}
	}
	
	@ViewBuilder
	private var content: some View {
		if let user = user {
			ScrollView {
				VStack(spacing: 24) {
					// Header with user info
					userHeaderView(user: user)
						.padding(.top, 20)
					
					// Main content sections
					VStack(spacing: 16) {
						linkedProvidersCard
						storageCard
						subscriptionCard(user: user)
						dangerZoneCard
					}
					.padding(.horizontal)
					.padding(.bottom, 30)
				}
			}
			.background(Color(NSColor.controlBackgroundColor).opacity(0.3))
		} else {
			VStack(spacing: 20) {
				Image(systemName: "person.slash")
					.font(.system(size: 60))
					.foregroundStyle(.tertiary)
				Text("Not signed in")
					.font(.title2)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}
	
	// MARK: - Header View
	
	private func userHeaderView(user: PhotolalaUser) -> some View {
		VStack(spacing: 16) {
			// Avatar
			ZStack {
				Circle()
					.fill(LinearGradient(
						colors: [Color.accentColor.opacity(0.8), Color.accentColor],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					))
					.frame(width: 100, height: 100)
				
				if let photoURL = user.photoURL, let url = URL(string: photoURL) {
					AsyncImage(url: url) { image in
						image
							.resizable()
							.aspectRatio(contentMode: .fill)
					} placeholder: {
						Image(systemName: "person.fill")
							.font(.system(size: 50))
							.foregroundColor(.white)
					}
					.frame(width: 96, height: 96)
					.clipShape(Circle())
				} else {
					Image(systemName: "person.fill")
						.font(.system(size: 50))
						.foregroundColor(.white)
				}
			}
			.shadow(color: Color.accentColor.opacity(0.3), radius: 10, x: 0, y: 5)
			
			// User Info
			VStack(spacing: 8) {
				Text(user.fullName ?? "Photolala User")
					.font(.title2)
					.fontWeight(.semibold)
				
				if let email = user.email {
					Text(email)
						.font(.callout)
						.foregroundColor(.secondary)
				}
				
				HStack(spacing: 4) {
					Image(systemName: "calendar")
						.font(.caption)
					Text("Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
						.font(.caption)
				}
				.foregroundColor(Color.secondary.opacity(0.7))
			}
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
	
	// MARK: - Card Components
	
	private var linkedProvidersCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("Sign-in Methods", systemImage: "person.badge.key")
				.font(.headline)
			
			LinkedProvidersView()
		}
		.padding()
		.background(Color(NSColor.controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
	}
	
	private var storageCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("Storage", systemImage: "externaldrive")
				.font(.headline)
			
			VStack(spacing: 12) {
				// Storage usage bar
				VStack(alignment: .leading, spacing: 8) {
					HStack {
						Text("Cloud Storage")
							.font(.subheadline)
						Spacer()
						Text(storageInfo)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					
					// Progress bar
					GeometryReader { geometry in
						ZStack(alignment: .leading) {
							RoundedRectangle(cornerRadius: 4)
								.fill(Color.gray.opacity(0.2))
								.frame(height: 8)
							
							RoundedRectangle(cornerRadius: 4)
								.fill(storageProgressColor)
								.frame(width: geometry.size.width * storagePercentage, height: 8)
						}
					}
					.frame(height: 8)
					
					Text("\(Int(storagePercentage * 100))% used")
						.font(.caption2)
						.foregroundColor(.secondary)
				}
				
				Divider()
				
				// Storage details
				HStack {
					VStack(alignment: .leading, spacing: 4) {
						Text("Photos Backed Up")
							.font(.caption)
							.foregroundColor(.secondary)
						Text("—")  // TODO: Add backed up photo count
							.font(.headline)
					}
					
					Spacer()
					
					VStack(alignment: .trailing, spacing: 4) {
						Text("Last Backup")
							.font(.caption)
							.foregroundColor(.secondary)
						Text(lastBackupTime)
							.font(.caption)
							.fontWeight(.medium)
					}
				}
			}
		}
		.padding()
		.background(Color(NSColor.controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
	}
	
	private func subscriptionCard(user: PhotolalaUser) -> some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("Subscription", systemImage: "crown")
				.font(.headline)
			
			if let subscription = user.subscription {
				VStack(spacing: 12) {
					// Subscription tier
					HStack {
						VStack(alignment: .leading, spacing: 4) {
							Text(subscription.displayName)
								.font(.title3)
								.fontWeight(.medium)
							
							HStack(spacing: 8) {
								StatusBadge(
									text: subscription.isActive ? "Active" : "Expired",
									color: subscription.isActive ? .green : .red
								)
								
								if subscription.tier == .free {
									Text("Expires \(subscription.expiryDate.formatted(date: .abbreviated, time: .omitted))")
										.font(.caption)
										.foregroundColor(.secondary)
								}
							}
						}
						
						Spacer()
						
						Button("Upgrade") {
							// Show upgrade options
						}
						.buttonStyle(.borderedProminent)
						.controlSize(.regular)
					}
					
					// Features
					if subscription.tier == .free {
						VStack(alignment: .leading, spacing: 8) {
							Divider()
							
							Label("Free trial includes:", systemImage: "info.circle")
								.font(.caption)
								.foregroundColor(.secondary)
							
							VStack(alignment: .leading, spacing: 4) {
								FeatureCheckRow(icon: "checkmark.circle.fill", text: "200 MB storage", included: true)
								FeatureCheckRow(icon: "checkmark.circle.fill", text: "Basic features", included: true)
								FeatureCheckRow(icon: "xmark.circle", text: "Priority support", included: false)
							}
						}
					}
				}
			} else {
				Text("No active subscription")
					.foregroundColor(.secondary)
			}
		}
		.padding()
		.background(Color(NSColor.controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
	
	private var dangerZoneCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("Danger Zone", systemImage: "exclamationmark.triangle")
				.font(.headline)
				.foregroundColor(.red)
			
			VStack(spacing: 12) {
				Button(action: { signOut() }) {
					HStack {
						Image(systemName: "arrow.right.square")
						Text("Sign Out")
						Spacer()
					}
					.foregroundColor(.red)
					.padding()
					.background(Color.red.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 8))
				}
				.buttonStyle(.plain)
				
				Text("You'll need to sign in again to access your backed up photos")
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
		.padding()
		.background(Color(NSColor.controlBackgroundColor))
		.overlay(
			RoundedRectangle(cornerRadius: 12)
				.stroke(Color.red.opacity(0.3), lineWidth: 1)
		)
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
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
	
	// MARK: - Computed Properties
	
	private var storagePercentage: Double {
		guard s3BackupManager.storageLimit > 0 else { return 0 }
		return min(Double(s3BackupManager.currentUsage) / Double(s3BackupManager.storageLimit), 1.0)
	}
	
	private var storageProgressColor: Color {
		switch storagePercentage {
		case 0..<0.7:
			return .green
		case 0.7..<0.9:
			return .orange
		default:
			return .red
		}
	}
	
	private var lastBackupTime: String {
		// TODO: Get actual last backup time from BackupQueueManager
		return "Today, 2:30 PM"
	}
}

// MARK: - Helper Views

struct StatusBadge: View {
	let text: String
	let color: Color
	
	var body: some View {
		Text(text)
			.font(.caption)
			.fontWeight(.medium)
			.foregroundColor(color)
			.padding(.horizontal, 8)
			.padding(.vertical, 2)
			.background(color.opacity(0.15))
			.clipShape(Capsule())
	}
}

struct FeatureCheckRow: View {
	let icon: String
	let text: String
	let included: Bool
	
	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: icon)
				.font(.caption)
				.foregroundColor(included ? .green : .gray)
			
			Text(text)
				.font(.caption)
				.foregroundColor(included ? .primary : .secondary)
		}
	}
}

// MARK: - Preview

#Preview {
	AccountSettingsView()
		.environmentObject(IdentityManager.shared)
}