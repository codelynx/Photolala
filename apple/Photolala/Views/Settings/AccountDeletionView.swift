import SwiftUI

struct AccountDeletionView: View {
	@State private var model = Model()
	@Environment(\.dismiss) var dismiss
	@Environment(\.colorScheme) var colorScheme

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 24) {
					// Warning header
					warningCard

					// Grace period info
					gracePeriodCard

					// What happens section
					whatHappensCard

					// Action buttons
					actionButtons
				}
				.padding()
			}
			.navigationTitle("Delete Account")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.large)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
			}
			.confirmationDialog(
				"Confirm Account Deletion",
				isPresented: $model.showingConfirmation
			) {
				Button(model.confirmButtonTitle, role: .destructive) {
					Task {
						await model.performDeletion()
					}
				}
				Button("Cancel", role: .cancel) { }
			} message: {
				Text(model.confirmationMessage)
			}
			.alert("Deletion Scheduled", isPresented: $model.showingSuccess) {
				Button("OK") {
					dismiss()
				}
			} message: {
				Text("Your account will be deleted on \(model.deletionDate.formatted()). Check your email for details.")
			}
			.alert("Error", isPresented: $model.showingError) {
				Button("OK") { }
			} message: {
				Text(model.errorMessage)
			}
			.overlay {
				if model.isProcessing {
					ProgressView("Scheduling deletion...")
						.padding()
						.background(.regularMaterial)
						.clipShape(RoundedRectangle(cornerRadius: 12))
				}
			}
		}
	}

	// MARK: - Components

	private var warningCard: some View {
		VStack(spacing: 16) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 50))
				.foregroundStyle(.red)

			Text("Account Deletion")
				.font(.title2.bold())

			Text("This action will schedule your account for permanent deletion")
				.multilineTextAlignment(.center)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity)
		.padding()
		.background(Color.red.opacity(0.1))
		.clipShape(RoundedRectangle(cornerRadius: 16))
	}

	private var gracePeriodCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Grace Period", systemImage: "clock.fill")
				.font(.headline)

			Text("Your account will be deleted after \(model.gracePeriodText)")
				.font(.callout)

			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Image(systemName: "checkmark.circle.fill")
						.foregroundStyle(.green)
					Text("You can cancel anytime during this period")
						.font(.caption)
				}

				HStack {
					Image(systemName: "checkmark.circle.fill")
						.foregroundStyle(.green)
					Text("You'll receive email reminders")
						.font(.caption)
				}

				if model.isDevelopment {
					HStack {
						Image(systemName: "bolt.circle.fill")
							.foregroundStyle(.orange)
						Text("Development: Immediate deletion available")
							.font(.caption)
							.foregroundStyle(.orange)
					}
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
		.background(Color(XColor.secondarySystemBackground))
		.clipShape(RoundedRectangle(cornerRadius: 16))
	}

	private var whatHappensCard: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("What Will Be Deleted", systemImage: "trash.fill")
				.font(.headline)

			VStack(alignment: .leading, spacing: 8) {
				bulletPoint("All photos and thumbnails")
				bulletPoint("Photo catalogs and metadata")
				bulletPoint("Account information")
				bulletPoint("Identity mappings")
			}

			Divider()

			Text("This action cannot be undone after the grace period")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
		.background(Color(XColor.secondarySystemBackground))
		.clipShape(RoundedRectangle(cornerRadius: 16))
	}

	private func bulletPoint(_ text: String) -> some View {
		HStack(alignment: .top, spacing: 8) {
			Text("•")
				.font(.callout)
			Text(text)
				.font(.callout)
		}
	}

	private var actionButtons: some View {
		VStack(spacing: 12) {
			// Schedule deletion button
			Button {
				model.showingConfirmation = true
			} label: {
				Label("Schedule Deletion", systemImage: "calendar.badge.clock")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
			.tint(.red)

			// Delete now button (dev only)
			if model.isDevelopment {
				Button {
					model.deletionOption = .immediate
					model.showingConfirmation = true
				} label: {
					Label("Delete Now (Dev Only)", systemImage: "trash.fill")
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.bordered)
				.controlSize(.large)
				.tint(.orange)
			}

			// Cancel button
			Button("Cancel") {
				dismiss()
			}
			.buttonStyle(.bordered)
			.controlSize(.large)
		}
		.padding(.top)
	}
}

// MARK: - View Model

extension AccountDeletionView {
	@MainActor
	@Observable
	final class Model {
		var deletionOption: DeletionOption = .scheduled
		var showingConfirmation = false
		var showingSuccess = false
		var showingError = false
		var errorMessage = ""
		var isProcessing = false

		enum DeletionOption {
			case scheduled
			case immediate
		}

		var isDevelopment: Bool {
			let environment = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
			return environment == "development"
		}

		var gracePeriodText: String {
			let environment = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
			switch environment {
			case "development":
				return "3 minutes"
			case "staging":
				return "3 days"
			case "production":
				return "30 days"
			default:
				return "30 days"
			}
		}

		var deletionDate: Date {
			let environment = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
			let seconds: TimeInterval
			switch environment {
			case "development":
				seconds = 180 // 3 minutes
			case "staging":
				seconds = 259200 // 3 days
			case "production":
				seconds = 2592000 // 30 days
			default:
				seconds = 2592000
			}
			return Date().addingTimeInterval(seconds)
		}

		var confirmButtonTitle: String {
			deletionOption == .immediate ? "Delete Immediately" : "Schedule Deletion"
		}

		var confirmationMessage: String {
			if deletionOption == .immediate {
				return "This will immediately and permanently delete your account. This cannot be undone."
			} else {
				return "Your account will be scheduled for deletion. You can cancel anytime during the grace period."
			}
		}

		func performDeletion() async {
			isProcessing = true
			defer { isProcessing = false }

			do {
				guard let user = AccountManager.shared.getCurrentUser() else {
					throw AccountError.notSignedIn
				}

				// Get current environment
				let environment = getCurrentAWSEnvironment()
				let s3Service = try await S3Service.forEnvironment(environment)
				let scheduler = DeletionScheduler(s3Service: s3Service, environment: environment)

				if deletionOption == .immediate && isDevelopment {
					// Development only: immediate deletion
					try await scheduler.expediteDeletion(user: user)

					// Sign out immediately
					await AccountManager.shared.signOut()
				} else {
					// Schedule deletion with grace period
					try await scheduler.scheduleAccountDeletion(user: user)
					showingSuccess = true
				}
			} catch {
				errorMessage = error.localizedDescription
				showingError = true
			}
		}

		private func getCurrentAWSEnvironment() -> AWSEnvironment {
			let environmentPreference = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
			switch environmentPreference {
			case "production":
				return .production
			case "staging":
				return .staging
			default:
				return .development
			}
		}
	}
}

// MARK: - Preview

#Preview {
	AccountDeletionView()
}