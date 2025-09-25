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
	@Environment(\.dismiss) var dismiss
	@Environment(\.colorScheme) var colorScheme

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 24) {
					// Profile Header Card
					profileHeaderCard
						.padding(.top)

					// Quick Stats
					statsGrid

					// Storage Card
					storageCard

					// Linked Accounts Card
					linkedAccountsCard

					// Danger Zone
					dangerZoneCard
				}
				.padding(.horizontal)
				.padding(.bottom)
			}
			.background(backgroundGradient)
			.navigationTitle("Account")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.large)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						dismiss()
					} label: {
						Image(systemName: "xmark.circle.fill")
							.symbolRenderingMode(.hierarchical)
							.font(.title2)
							.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
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
			.sheet(isPresented: $model.showingDeletionOptions) {
				AccountDeletionView()
			}
			.alert("Error", isPresented: $model.showingError) {
				Button("OK") { }
			} message: {
				Text(model.errorMessage)
			}
			.sheet(isPresented: $model.showingReauthentication) {
				ReauthenticationView { success in
					if success {
						model.showingDeletionProgress = true
					}
				}
			}
			.sheet(isPresented: $model.showingDeletionProgress) {
				DeletionProgressView(isPresented: $model.showingDeletionProgress) { success in
					if success {
						// Account deleted successfully, dismiss the settings view
						dismiss()
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

	// MARK: - Components

	private var backgroundGradient: some View {
		LinearGradient(
			colors: [
				Color(white: colorScheme == .dark ? 0.1 : 0.95),
				Color(white: colorScheme == .dark ? 0.05 : 0.98)
			],
			startPoint: .topLeading,
			endPoint: .bottomTrailing
		)
		.ignoresSafeArea()
	}

	private var profileHeaderCard: some View {
		VStack(spacing: 20) {
			// Avatar with gradient border
			ZStack {
				Circle()
					.fill(
						LinearGradient(
							colors: [Color.blue, Color.purple],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.frame(width: 96, height: 96)

				Circle()
					.fill(Color(XColor.systemBackground))
					.frame(width: 90, height: 90)

				Image(systemName: "person.fill")
					.font(.system(size: 40))
					.foregroundStyle(
						LinearGradient(
							colors: [Color.blue, Color.purple],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
			}
			.shadow(color: Color.blue.opacity(0.3), radius: 10, y: 5)

			VStack(spacing: 8) {
				Text(model.displayName)
					.font(.title2.bold())

				if let email = model.email {
					Text(email)
						.font(.callout)
						.foregroundStyle(.secondary)
				}

				// Member badge
				HStack(spacing: 4) {
					Image(systemName: "star.circle.fill")
						.font(.caption)
						.foregroundStyle(.yellow)
					Text("Member since \(model.createdDate)")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(.horizontal, 12)
				.padding(.vertical, 6)
				.background(Color(XColor.secondarySystemBackground))
				.clipShape(Capsule())
			}

			Button {
				model.showingEditProfile = true
			} label: {
				Label("Edit Profile", systemImage: "pencil")
					.font(.callout.weight(.medium))
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 24)
		.padding(.horizontal, 20)
		.background(cardBackground)
		.clipShape(RoundedRectangle(cornerRadius: 20))
		.shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
	}

	private var cardBackground: some View {
		RoundedRectangle(cornerRadius: 20)
			.fill(Color(XColor.secondarySystemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: 20)
					.stroke(Color(XColor.separator).opacity(0.2), lineWidth: 1)
			)
	}

	private var statsGrid: some View {
		LazyVGrid(columns: [
			GridItem(.flexible()),
			GridItem(.flexible())
		], spacing: 12) {
			// Photos count
			VStack(spacing: 8) {
				Image(systemName: "photo.stack")
					.font(.title2)
					.foregroundStyle(
						LinearGradient(
							colors: [Color.blue, Color.cyan],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)

				VStack(spacing: 2) {
					Text("\(model.photoCount)")
						.font(.title3.bold())
					Text("Photos")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 16)
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(Color(XColor.tertiarySystemBackground))
					.overlay(
						RoundedRectangle(cornerRadius: 16)
							.stroke(Color(XColor.separator).opacity(0.1), lineWidth: 1)
					)
			)

			// Storage used
			VStack(spacing: 8) {
				Image(systemName: "internaldrive")
					.font(.title2)
					.foregroundStyle(
						LinearGradient(
							colors: [Color.purple, Color.pink],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)

				VStack(spacing: 2) {
					Text(model.storageUsedText)
						.font(.title3.bold())
					Text("Used")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 16)
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(Color(XColor.tertiarySystemBackground))
					.overlay(
						RoundedRectangle(cornerRadius: 16)
							.stroke(Color(XColor.separator).opacity(0.1), lineWidth: 1)
					)
			)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 4)
	}

	private var storageCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Header with icon
			HStack {
				Image(systemName: "cloud.fill")
					.font(.title3)
					.foregroundStyle(
						LinearGradient(
							colors: [Color.blue, Color.cyan],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)

				Text("Cloud Storage")
					.font(.headline)

				Spacer()

				if model.isLoadingStorage {
					ProgressView()
						.scaleEffect(0.7)
				} else {
					Button {
						Task {
							await model.calculateStorage()
						}
					} label: {
						Image(systemName: "arrow.clockwise")
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
				}
			}

			// Storage bar
			VStack(alignment: .leading, spacing: 12) {
				// Progress bar with gradient
				ZStack(alignment: .leading) {
					RoundedRectangle(cornerRadius: 8)
						.fill(Color(XColor.tertiarySystemBackground))
						.frame(height: 24)

					GeometryReader { geometry in
						RoundedRectangle(cornerRadius: 8)
							.fill(
								LinearGradient(
									colors: model.storageProgress > 0.9 ? [.red, .orange] :
											model.storageProgress > 0.7 ? [.yellow, .orange] :
											[.blue, .cyan],
									startPoint: .leading,
									endPoint: .trailing
								)
							)
							.frame(width: geometry.size.width * model.storageProgress)
					}
					.frame(height: 24)

					// Percentage text
					Text("\(Int(model.storageProgress * 100))%")
						.font(.caption.bold())
						.foregroundStyle(.white)
						.padding(.horizontal, 8)
				}

				// Storage details
				HStack {
					VStack(alignment: .leading, spacing: 2) {
						Text("\(model.storageUsedText) used")
							.font(.callout)
							.foregroundStyle(.primary)
						Text("of \(model.storageQuotaText)")
							.font(.caption)
							.foregroundStyle(.secondary)
					}

					Spacer()

					if model.storageProgress > 0.9 {
						Label("Nearly Full", systemImage: "exclamationmark.triangle.fill")
							.font(.caption)
							.foregroundStyle(.red)
					}
				}
			}
		}
		.padding(20)
		.background(cardBackground)
		.clipShape(RoundedRectangle(cornerRadius: 20))
		.shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
	}

	private var linkedAccountsCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Header
			HStack {
				Image(systemName: "link.circle.fill")
					.font(.title3)
					.foregroundStyle(
						LinearGradient(
							colors: [Color.green, Color.mint],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)

				Text("Linked Accounts")
					.font(.headline)
			}

			// Account list
			VStack(spacing: 12) {
				if model.hasAppleProvider {
					HStack {
						Image(systemName: "apple.logo")
							.font(.title3)
							.frame(width: 30)

						VStack(alignment: .leading, spacing: 2) {
							Text("Apple ID")
								.font(.callout)
							Text("Sign in with Apple")
								.font(.caption)
								.foregroundStyle(.secondary)
						}

						Spacer()

						Text("Primary")
							.font(.caption)
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(Color.blue.opacity(0.2))
							.foregroundStyle(.blue)
							.clipShape(Capsule())
					}
					.padding(12)
					.background(Color(XColor.tertiarySystemBackground))
					.clipShape(RoundedRectangle(cornerRadius: 12))
				}

				if model.hasGoogleProvider {
					HStack {
						Image(systemName: "g.circle.fill")
							.font(.title3)
							.foregroundStyle(.red)
							.frame(width: 30)

						VStack(alignment: .leading, spacing: 2) {
							Text("Google")
								.font(.callout)
							if let email = model.email {
								Text(email)
									.font(.caption)
									.foregroundStyle(.secondary)
									.lineLimit(1)
							}
						}

						Spacer()

						if !model.hasAppleProvider {
							Text("Primary")
								.font(.caption)
								.padding(.horizontal, 8)
								.padding(.vertical, 4)
								.background(Color.blue.opacity(0.2))
								.foregroundStyle(.blue)
								.clipShape(Capsule())
						}
					}
					.padding(12)
					.background(Color(XColor.tertiarySystemBackground))
					.clipShape(RoundedRectangle(cornerRadius: 12))
				}

				// Add account button
				if !model.hasAppleProvider || !model.hasGoogleProvider {
					Button {
						Task {
							await model.linkProvider(!model.hasAppleProvider ? .apple : .google)
						}
					} label: {
						HStack {
							Image(systemName: "plus.circle.fill")
								.font(.title3)
								.foregroundStyle(.secondary)
							Text("Link Another Account")
								.font(.callout)
								.foregroundStyle(.primary)
							Spacer()
							Image(systemName: "chevron.right")
								.font(.caption)
								.foregroundStyle(.tertiary)
						}
					}
					.padding(12)
					.background(Color(XColor.tertiarySystemBackground))
					.clipShape(RoundedRectangle(cornerRadius: 12))
					.buttonStyle(.plain)
				}
			}
		}
		.padding(20)
		.background(cardBackground)
		.clipShape(RoundedRectangle(cornerRadius: 20))
		.shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
	}

	private var dangerZoneCard: some View {
		VStack(alignment: .leading, spacing: 16) {
			// Header with warning icon
			HStack {
				Image(systemName: "exclamationmark.triangle.fill")
					.font(.title3)
					.foregroundStyle(.red)

				Text("Account Actions")
					.font(.headline)
			}

			// Warning message
			Text("These actions affect your account and data")
				.font(.caption)
				.foregroundStyle(.secondary)

			// Action buttons
			VStack(spacing: 12) {
				// Sign Out button
				Button {
					model.showingSignOutConfirmation = true
				} label: {
					HStack {
						Image(systemName: "rectangle.portrait.and.arrow.right")
							.frame(width: 20)
						Text("Sign Out")
						Spacer()
						Image(systemName: "chevron.right")
							.font(.caption)
							.foregroundStyle(.tertiary)
					}
					.foregroundStyle(.orange)
					.padding(14)
					.frame(maxWidth: .infinity)
					.background(Color.orange.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 12))
					.overlay(
						RoundedRectangle(cornerRadius: 12)
							.stroke(Color.orange.opacity(0.3), lineWidth: 1)
					)
				}
				.buttonStyle(.plain)

				// Delete Account button
				Button {
					model.showingDeletionOptions = true
				} label: {
					HStack {
						Image(systemName: "trash.fill")
							.frame(width: 20)
						Text("Delete Account")
						Spacer()
						Image(systemName: "chevron.right")
							.font(.caption)
							.foregroundStyle(.tertiary)
					}
					.foregroundStyle(.red)
					.padding(14)
					.frame(maxWidth: .infinity)
					.background(Color.red.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 12))
					.overlay(
						RoundedRectangle(cornerRadius: 12)
							.stroke(Color.red.opacity(0.3), lineWidth: 1)
					)
				}
				.buttonStyle(.plain)
			}

			// Footer warning
			Text("Deleting your account permanently removes all photos and data from cloud storage")
				.font(.caption2)
				.foregroundStyle(.secondary)
				.padding(.top, 4)
		}
		.padding(20)
		.background(
			RoundedRectangle(cornerRadius: 20)
				.fill(Color(XColor.secondarySystemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: 20)
						.stroke(Color.red.opacity(0.2), lineWidth: 1)
				)
		)
		.clipShape(RoundedRectangle(cornerRadius: 20))
		.shadow(color: Color.red.opacity(0.1), radius: 10, y: 5)
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
		var showingDeletionOptions = false
		var showingReauthentication = false
		var showingDeletionProgress = false
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
				let s3Service = try await S3Service.forCurrentAWSEnvironment()

				// Calculate storage usage for current user
				guard let user = AccountManager.shared.getCurrentUser() else {
					print("[AccountSettings] No current user for storage calculation")
					return
				}
				let usage = try await s3Service.calculateStorageUsage(userID: user.id.uuidString)
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

				// Update local state first
				await AccountManager.shared.updateUser(updatedUser)
				displayName = newName

				// Save to S3
				let s3Service = try await S3Service.forCurrentAWSEnvironment()
				try await s3Service.updateUserProfile(updatedUser)
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
			// AccountManager.signOut() now handles all cleanup
			await AccountManager.shared.signOut()
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
	@Environment(\.dismiss) var dismiss

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
	@Environment(\.dismiss) var dismiss
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
	NavigationStack {
		AccountSettingsView()
	}
}