//
//  AccountSettingsView.swift
//  Photolala
//
//  Account settings and profile management
//

import SwiftUI
import AuthenticationServices

struct AccountSettingsView: View {
	@State private var model = Model()
	@Environment(\.dismiss) private var dismiss: DismissAction

	var body: some View {
		NavigationStack {
			Form {
				// Profile Section
				profileSection

				// Storage Section
				storageSection

				// Linked Accounts Section
				linkedAccountsSection

				// Danger Zone
				dangerZoneSection
			}
			.navigationTitle("Account Settings")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
			.alert("Sign Out", isPresented: $model.showingSignOutConfirmation) {
				Button("Cancel", role: .cancel) { }
				Button("Sign Out", role: .destructive) {
					Task {
						await model.signOut()
						dismiss()
					}
				}
			} message: {
				Text("Are you sure you want to sign out? Your local data will remain on this device.")
			}
			.alert("Delete Account", isPresented: $model.showingDeleteConfirmation) {
				Button("Cancel", role: .cancel) { }
				Button("Delete Account", role: .destructive) {
					model.showingReauthentication = true
				}
			} message: {
				Text("This will permanently delete your account and all cloud data. This action cannot be undone.")
			}
			.alert("Error", isPresented: $model.showingError) {
				Button("OK") { }
			} message: {
				Text(model.errorMessage)
			}
			.sheet(isPresented: $model.showingReauthentication) {
				ReauthenticationView { success in
					if success {
						Task {
							await model.deleteAccount()
							dismiss()
						}
					}
				}
			}
			.sheet(isPresented: $model.showingEditProfile) {
				EditProfileView(displayName: model.displayName) { newName in
					Task {
						await model.updateDisplayName(newName)
					}
				}
			}
		}
		.task {
			await model.loadUserData()
		}
	}

	// MARK: - Sections

	private var profileSection: some View {
		Section("Profile") {
			// User Avatar/Icon
			HStack {
				Image(systemName: "person.crop.circle.fill")
					.font(.system(size: 60))
					.foregroundStyle(.secondary)

				VStack(alignment: .leading, spacing: 4) {
					Text(model.displayName)
						.font(.headline)
					if let email = model.email {
						Text(email)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}

				Spacer()

				Button("Edit") {
					model.showingEditProfile = true
				}
				.buttonStyle(.bordered)
			}
			.padding(.vertical, 8)

			// User Details
			LabeledContent("User ID", value: model.userID)
				.font(.caption)
				.textSelection(.enabled)

			LabeledContent("Member Since", value: model.createdDate)
				.font(.caption)
		}
	}

	private var storageSection: some View {
		Section("Storage") {
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("Used")
					Spacer()
					Text("\(model.storageUsedText) of \(model.storageQuotaText)")
						.foregroundStyle(.secondary)
				}

				ProgressView(value: model.storageProgress)
					.tint(model.storageProgress > 0.9 ? .red : .accentColor)

				HStack {
					Label("\(model.photoCount) Photos", systemImage: "photo")
						.font(.caption)
						.foregroundStyle(.secondary)

					Spacer()

					if model.isLoadingStorage {
						ProgressView()
							.scaleEffect(0.8)
					} else {
						Button("Refresh") {
							Task {
								await model.calculateStorage()
							}
						}
						.font(.caption)
					}
				}
			}
			.padding(.vertical, 4)
		}
	}

	private var linkedAccountsSection: some View {
		Section("Linked Accounts") {
			if model.hasAppleProvider {
				Label("Apple", systemImage: "apple.logo")
					.badge("Primary")
			}

			if model.hasGoogleProvider {
				Label {
					Text("Google")
				} icon: {
					Image(systemName: "g.circle.fill")
						.foregroundStyle(.red)
				}
				.badge(model.hasAppleProvider ? "Linked" : "Primary")
			}

			if !model.hasAppleProvider || !model.hasGoogleProvider {
				Button {
					Task {
						await model.linkProvider(!model.hasAppleProvider ? .apple : .google)
					}
				} label: {
					Label("Link Another Account", systemImage: "link")
				}
			}
		}
	}

	private var dangerZoneSection: some View {
		Section {
			Button(role: .destructive) {
				model.showingSignOutConfirmation = true
			} label: {
				Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
			}

			Button(role: .destructive) {
				model.showingDeleteConfirmation = true
			} label: {
				Label("Delete Account", systemImage: "trash")
			}
		} header: {
			Text("Account Actions")
		} footer: {
			Text("Deleting your account will permanently remove all your photos and data from Photolala cloud storage.")
				.font(.caption)
		}
	}
}

// MARK: - View Model

extension AccountSettingsView {
	@MainActor
	@Observable
	final class Model {
		// User data
		var displayName = "Loading..."
		var email: String?
		var userID = ""
		var createdDate = ""
		var hasAppleProvider = false
		var hasGoogleProvider = false

		// Storage
		var storageUsedBytes: Int64 = 0
		var storageQuotaBytes: Int64 = 5_000_000_000 // 5GB default
		var photoCount = 0
		var isLoadingStorage = false

		// UI State
		var showingSignOutConfirmation = false
		var showingDeleteConfirmation = false
		var showingReauthentication = false
		var showingEditProfile = false
		var showingError = false
		var errorMessage = ""

		// Computed properties
		var storageUsedText: String {
			ByteCountFormatter.string(fromByteCount: storageUsedBytes, countStyle: .file)
		}

		var storageQuotaText: String {
			ByteCountFormatter.string(fromByteCount: storageQuotaBytes, countStyle: .file)
		}

		var storageProgress: Double {
			guard storageQuotaBytes > 0 else { return 0 }
			return Double(storageUsedBytes) / Double(storageQuotaBytes)
		}

		// MARK: - Data Loading

		func loadUserData() async {
			guard let user = AccountManager.shared.getCurrentUser() else { return }

			displayName = user.displayName
			email = user.email
			userID = user.id.uuidString
			hasAppleProvider = user.hasAppleProvider
			hasGoogleProvider = user.hasGoogleProvider

			let formatter = DateFormatter()
			formatter.dateStyle = .medium
			createdDate = formatter.string(from: user.createdAt)

			await calculateStorage()
		}

		func calculateStorage() async {
			isLoadingStorage = true
			defer { isLoadingStorage = false }

			do {
				// Get S3 service
				let s3Service = try await S3Service.forCurrentEnvironment()

				// Calculate storage usage
				let usage = try await s3Service.calculateStorageUsage()
				storageUsedBytes = usage.totalBytes
				photoCount = usage.photoCount

				// TODO: Get actual quota from subscription tier
				// For now, use default 5GB for free tier
				storageQuotaBytes = 5_000_000_000
			} catch {
				print("[AccountSettings] Failed to calculate storage: \(error)")
			}
		}

		// MARK: - Actions

		func updateDisplayName(_ newName: String) async {
			guard !newName.isEmpty else { return }

			do {
				// Update local user
				guard var user = AccountManager.shared.getCurrentUser() else { return }

				// Create updated user with new display name
				let updatedUser = PhotolalaUser(
					id: user.id,
					appleUserID: user.appleUserID,
					googleUserID: user.googleUserID,
					email: user.email,
					displayName: newName,
					createdAt: user.createdAt,
					updatedAt: Date()
				)

				// Save to S3
				let s3Service = try await S3Service.forCurrentEnvironment()
				try await s3Service.updateUserProfile(updatedUser)

				// Update local state
				await AccountManager.shared.updateUser(updatedUser)
				displayName = newName
			} catch {
				errorMessage = "Failed to update profile: \(error.localizedDescription)"
				showingError = true
			}
		}

		func linkProvider(_ provider: AuthProvider) async {
			// TODO: Implement provider linking
			errorMessage = "Provider linking not yet implemented"
			showingError = true
		}

		func signOut() async {
			// Stop any ongoing operations
			await PhotoBasket.shared.cancelCurrentOperation()

			// Clear caches
			await clearAllCaches()

			// Sign out from AccountManager
			await AccountManager.shared.signOut()
		}

		func deleteAccount() async {
			do {
				guard let user = AccountManager.shared.getCurrentUser() else { return }

				// Get S3 service
				let s3Service = try await S3Service.forCurrentEnvironment()

				// Delete all user data from S3
				try await s3Service.deleteAllUserData(userID: user.id.uuidString)

				// TODO: Call Lambda to remove identity mappings
				// For now, just sign out locally

				// Clear all local data
				await clearAllCaches()
				PhotoBasket.shared.clear()

				// Sign out
				await AccountManager.shared.signOut()
			} catch {
				errorMessage = "Failed to delete account: \(error.localizedDescription)"
				showingError = true
			}
		}

		private func clearAllCaches() async {
			// Clear photo caches
			let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
			if let enumerator = FileManager.default.enumerator(at: cacheDir, includingPropertiesForKeys: nil) {
				for case let url as URL in enumerator {
					try? FileManager.default.removeItem(at: url)
				}
			}

			// Clear app support data (except essential files)
			let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
			let photolalaDir = appSupport.appendingPathComponent("Photolala")

			// Keep only essential directories, clear the rest
			let essentialDirs = ["GlobalCatalog", "Checkpoints"]
			if let enumerator = FileManager.default.enumerator(at: photolalaDir, includingPropertiesForKeys: nil) {
				for case let url as URL in enumerator {
					let lastComponent = url.lastPathComponent
					if !essentialDirs.contains(lastComponent) && url.deletingLastPathComponent() == photolalaDir {
						try? FileManager.default.removeItem(at: url)
					}
				}
			}
		}

		enum AuthProvider {
			case apple, google
		}
	}
}

// MARK: - Supporting Views

struct EditProfileView: View {
	@State private var displayName: String
	let onSave: (String) -> Void
	@Environment(\.dismiss) private var dismiss: DismissAction

	init(displayName: String, onSave: @escaping (String) -> Void) {
		_displayName = State(initialValue: displayName)
		self.onSave = onSave
	}

	var body: some View {
		NavigationStack {
			Form {
				Section("Display Name") {
					TextField("Name", text: $displayName)
						.textFieldStyle(.roundedBorder)
				}
			}
			.navigationTitle("Edit Profile")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Save") {
						onSave(displayName)
						dismiss()
					}
					.disabled(displayName.isEmpty)
				}
			}
		}
	}
}

struct ReauthenticationView: View {
	let onAuthenticated: (Bool) -> Void
	@Environment(\.dismiss) private var dismiss: DismissAction
	@State private var isAuthenticating = false

	var body: some View {
		VStack(spacing: 20) {
			Image(systemName: "exclamationmark.shield.fill")
				.font(.system(size: 60))
				.foregroundStyle(.red)

			Text("Confirm Account Deletion")
				.font(.title2)
				.fontWeight(.semibold)

			Text("Please re-authenticate to confirm you want to permanently delete your account.")
				.multilineTextAlignment(.center)
				.foregroundStyle(.secondary)

			VStack(spacing: 12) {
				if AccountManager.shared.getCurrentUser()?.hasAppleProvider == true {
					SignInWithAppleButton { request in
						// Configure request
					} onCompletion: { result in
						handleAuthentication(result: result)
					}
					.frame(height: 50)
					.signInWithAppleButtonStyle(.black)
				}

				if AccountManager.shared.getCurrentUser()?.hasGoogleProvider == true {
					Button {
						Task {
							await authenticateWithGoogle()
						}
					} label: {
						Label("Sign in with Google", systemImage: "g.circle.fill")
							.frame(maxWidth: .infinity)
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.large)
				}
			}

			Button("Cancel") {
				dismiss()
			}
			.buttonStyle(.bordered)
		}
		.padding()
		.frame(maxWidth: 400)
		.overlay {
			if isAuthenticating {
				ProgressView()
					.controlSize(.large)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.background(.regularMaterial)
			}
		}
	}

	private func handleAuthentication(result: Result<ASAuthorization, Error>) {
		switch result {
		case .success:
			onAuthenticated(true)
			dismiss()
		case .failure(let error):
			print("[Reauth] Authentication failed: \(error)")
			onAuthenticated(false)
		}
	}

	private func authenticateWithGoogle() async {
		isAuthenticating = true
		defer { isAuthenticating = false }

		do {
			_ = try await AccountManager.shared.signInWithGoogle()
			onAuthenticated(true)
			dismiss()
		} catch {
			print("[Reauth] Google authentication failed: \(error)")
			onAuthenticated(false)
		}
	}
}

// MARK: - Preview

#Preview {
	AccountSettingsView()
}