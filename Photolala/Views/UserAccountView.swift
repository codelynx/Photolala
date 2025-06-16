import SwiftUI

struct UserAccountView: View {
	@StateObject private var identityManager = IdentityManager.shared
	@StateObject private var s3BackupManager = S3BackupManager.shared
	@State private var showingSignOut = false
	
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
						Label(storageInfo, systemImage: "internaldrive")
							.disabled(true)
						
						Label(user.subscription?.tier.displayName ?? "Free", systemImage: "creditcard")
							.disabled(true)
						
						Divider()
						
						// Actions
						Button("Manage Subscription") {
							// Show subscription view
						}
						
						Button("Sign Out") {
							showingSignOut = true
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
		.confirmationDialog("Sign Out", isPresented: $showingSignOut) {
			Button("Sign Out", role: .destructive) {
				identityManager.signOut()
			}
		} message: {
			Text("Are you sure you want to sign out? You'll need to sign in again to backup photos.")
		}
		.task {
			await s3BackupManager.updateStorageInfo()
		}
	}
	
	private var storageInfo: String {
		let used = formatBytes(s3BackupManager.currentUsage)
		let total = formatBytes(s3BackupManager.storageLimit)
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
			if identityManager.isSignedIn {
				if s3BackupManager.isUploading {
					ProgressView()
						.scaleEffect(0.7)
				} else {
					Image(systemName: "checkmark.icloud.fill")
						.foregroundColor(.green)
				}
				
				Text(statusText)
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
		.help(helpText)
	}
	
	private var statusText: String {
		if s3BackupManager.isUploading {
			return "Uploading..."
		} else {
			let percentage = Double(s3BackupManager.currentUsage) / Double(s3BackupManager.storageLimit) * 100
			return String(format: "%.0f%% used", percentage)
		}
	}
	
	private var helpText: String {
		if identityManager.isSignedIn {
			return "Cloud backup active"
		} else {
			return "Sign in to enable cloud backup"
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