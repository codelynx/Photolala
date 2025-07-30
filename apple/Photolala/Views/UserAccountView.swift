import SwiftUI

struct UserAccountView: View {
	@StateObject private var identityManager = IdentityManager.shared
	@StateObject private var s3BackupManager = S3BackupManager.shared
	@State private var showingSignOut = false
	@State private var showingAccountSettings = false

	var body: some View {
		Group {
			if let user = identityManager.currentUser {
				Menu {
					VStack {
						// User info
						Label(user.displayName, systemImage: "person.circle")
							.disabled(true)

						if let email = user.email {
							Label(email, systemImage: "envelope")
								.disabled(true)
						}

						Divider()

						// Storage info
						Label(self.storageInfo, systemImage: "internaldrive")
							.disabled(true)

						Label(user.subscription?.tier.displayName ?? "Free", systemImage: "creditcard")
							.disabled(true)

						Divider()

						// Actions
						Button("Account Settings...") {
							showingAccountSettings = true
						}
						
						Button("Manage Subscription") {
							// Show subscription view
						}

						Button("Sign Out") {
							self.showingSignOut = true
						}
					}
				} label: {
					HStack(spacing: 4) {
						Image(systemName: "person.circle.fill")
						Text(user.displayName)
							.lineLimit(1)
					}
				}
				.menuStyle(.borderlessButton)
				.fixedSize()
				.help("Account: \(user.displayName)")
			} else {
				Button("Sign In") {
					// Show sign in
				}
				.help("Sign in to enable cloud backup")
			}
		}
		.confirmationDialog("Sign Out", isPresented: self.$showingSignOut) {
			Button("Sign Out", role: .destructive) {
				self.identityManager.signOut()
			}
		} message: {
			Text("Are you sure you want to sign out? You'll need to sign in again to backup photos.")
		}
		.sheet(isPresented: $showingAccountSettings) {
			AccountSettingsView()
				.environmentObject(identityManager)
		}
		.task {
			await self.s3BackupManager.updateStorageInfo()
		}
	}

	private var storageInfo: String {
		let used = self.formatBytes(self.s3BackupManager.currentUsage)
		let total = self.formatBytes(self.s3BackupManager.storageLimit)
		return "\(used) of \(total)"
	}

	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
}

// MARK: - Compact Status View

struct BackupStatusView: View {
	@StateObject private var identityManager = IdentityManager.shared
	@StateObject private var s3BackupManager = S3BackupManager.shared

	var body: some View {
		HStack(spacing: 8) {
			if self.identityManager.isSignedIn {
				if self.s3BackupManager.isUploading {
					ProgressView()
						.scaleEffect(0.7)
				} else {
					Image(systemName: "checkmark.icloud.fill")
						.foregroundColor(.green)
				}

				Text(self.statusText)
					.font(.caption)
					.foregroundColor(.secondary)
			} else {
				Image(systemName: "icloud.slash")
					.foregroundColor(.secondary)
				Text("Not signed in")
					.font(.caption)
					.foregroundColor(.secondary)
			}
		}
		.help(self.helpText)
	}

	private var statusText: String {
		if self.s3BackupManager.isUploading {
			return "Uploading..."
		} else {
			let percentage = Double(s3BackupManager.currentUsage) / Double(self.s3BackupManager.storageLimit) * 100
			return String(format: "%.0f%% used", percentage)
		}
	}

	private var helpText: String {
		if self.identityManager.isSignedIn {
			"Cloud backup active"
		} else {
			"Sign in to enable cloud backup"
		}
	}
}

#Preview {
	VStack {
		UserAccountView()
		Divider()
		BackupStatusView()
	}
	.padding()
}
