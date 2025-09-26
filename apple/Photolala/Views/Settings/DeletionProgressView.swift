//
//  DeletionProgressView.swift
//  Photolala
//
//  Shows real-time progress during account deletion
//

import SwiftUI

struct DeletionProgressView: View {
	@State private var model = Model()
	@Binding var isPresented: Bool
	let onCompletion: (Bool) -> Void

	var body: some View {
		VStack(spacing: 24) {
			// Header
			VStack(spacing: 12) {
				Image(systemName: model.currentState.icon)
					.font(.system(size: 60))
					.foregroundStyle(model.currentState.iconColor)
					.symbolEffect(.bounce, value: model.currentState)

				Text(model.currentState.title)
					.font(.title2)
					.fontWeight(.semibold)

				Text(model.currentState.subtitle)
					.font(.callout)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}

			// Progress Section
			if model.isDeleting {
				VStack(spacing: 16) {
					// Overall Progress
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Overall Progress")
								.font(.headline)
							Spacer()
							Text("\(model.completedSteps)/\(model.totalSteps)")
								.font(.caption)
								.foregroundStyle(.secondary)
						}

						ProgressView(value: model.overallProgress)
							.progressViewStyle(.linear)
					}

					// Namespace Progress
					ForEach(model.namespaces) { namespace in
						NamespaceProgressRow(namespace: namespace)
					}

					// Current Operation
					if let currentOperation = model.currentOperation {
						HStack {
							ProgressView()
								.controlSize(.small)
							Text(currentOperation)
								.font(.caption)
								.foregroundStyle(.secondary)
							Spacer()
						}
						.padding(.top, 8)
					}
				}
				.padding()
				.background(Color.secondary.opacity(0.1))
				.cornerRadius(8)
			}

			// Error Section
			if let error = model.errorMessage {
				VStack(alignment: .leading, spacing: 8) {
					Label(error, systemImage: "exclamationmark.triangle")
						.foregroundStyle(.red)
						.font(.callout)

					if model.canRetry {
						Button("Retry") {
							Task {
								await model.retryDeletion()
							}
						}
						.buttonStyle(.borderedProminent)
						.controlSize(.small)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding()
				.background(Color.red.opacity(0.1))
				.cornerRadius(8)
			}

			// Action Buttons
			HStack(spacing: 12) {
				if model.canCancel {
					Button("Cancel") {
						model.cancelDeletion()
						isPresented = false
						onCompletion(false)
					}
					.buttonStyle(.bordered)
				}

				if model.currentState == .completed {
					Button("Done") {
						isPresented = false
						onCompletion(true)
					}
					.buttonStyle(.borderedProminent)
				}

				if model.currentState == .failed {
					Button("Close") {
						isPresented = false
						onCompletion(false)
					}
					.buttonStyle(.bordered)
				}
			}
			.controlSize(.large)
		}
		.padding(32)
		.frame(minWidth: 400, maxWidth: 500)
		.task {
			await model.startDeletion()
		}
	}
}

// MARK: - Namespace Progress Row

struct NamespaceProgressRow: View {
	let namespace: DeletionProgressView.NamespaceProgress

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Label(namespace.name, systemImage: namespace.icon)
					.font(.caption)
					.foregroundStyle(namespace.status.color)

				Spacer()

				if namespace.status == .inProgress {
					ProgressView()
						.controlSize(.mini)
				} else {
					Image(systemName: namespace.status.statusIcon)
						.font(.caption)
						.foregroundStyle(namespace.status.color)
				}

				Text(namespace.statusText)
					.font(.caption2)
					.foregroundStyle(.secondary)
			}

			if namespace.status == .inProgress {
				ProgressView(value: namespace.progress)
					.progressViewStyle(.linear)
					.controlSize(.mini)
			}
		}
	}
}

// MARK: - View Model

extension DeletionProgressView {
	@MainActor
	@Observable
	final class Model: DeletionProgressDelegate {
		// State
		var currentState: DeletionState = .preparing
		var isDeleting = false
		var canCancel = true
		var canRetry = false

		// Progress
		var namespaces: [NamespaceProgress] = []
		var overallProgress: Double = 0
		var completedSteps = 0
		var totalSteps = 5 // photos, thumbnails, catalogs, users, identities

		// Current operation
		var currentOperation: String?
		var errorMessage: String?

		// Task management
		private var deletionTask: Task<Void, Error>?
		private var retryCount = 0
		private let maxRetries = 3

		init() {
			// Initialize namespaces
			namespaces = [
				NamespaceProgress(id: "photos", name: "Photos", icon: "photo"),
				NamespaceProgress(id: "thumbnails", name: "Thumbnails", icon: "photo.fill"),
				NamespaceProgress(id: "catalogs", name: "Catalogs", icon: "folder"),
				NamespaceProgress(id: "users", name: "User Data", icon: "person"),
				NamespaceProgress(id: "identities", name: "Identity Mappings", icon: "link")
			]
		}

		func startDeletion() async {
			isDeleting = true
			currentState = .deleting

			deletionTask = Task {
				do {
					// Start real account deletion with self as progress delegate
					try await AccountManager.shared.deleteAccount(progressDelegate: self)

					// Success
					currentState = .completed
					canCancel = false
					canRetry = false
					completedSteps = totalSteps
					overallProgress = 1.0

				} catch {
					// Handle errors
					handleDeletionError(error)
				}

				isDeleting = false
				currentOperation = nil
			}
		}

		func retryDeletion() async {
			guard canRetry else { return }

			retryCount += 1
			errorMessage = nil
			canRetry = false

			await startDeletion()
		}

		func cancelDeletion() {
			deletionTask?.cancel()
			currentState = .cancelled
			isDeleting = false
			canCancel = false
		}

		// MARK: - DeletionProgressDelegate

		func updateProgress(namespace: String, progress: Double, itemsDeleted: Int) async {
			if let index = namespaces.firstIndex(where: { $0.id == namespace }) {
				namespaces[index].status = .inProgress
				namespaces[index].progress = progress
				namespaces[index].deletedCount = itemsDeleted
				updateOverallProgress()
			}
		}

		func namespaceCompleted(namespace: String, deletedCount: Int) async {
			if let index = namespaces.firstIndex(where: { $0.id == namespace }) {
				namespaces[index].status = .completed
				namespaces[index].progress = 1.0
				namespaces[index].deletedCount = deletedCount
				completedSteps += 1
				updateOverallProgress()
			}
		}

		func namespaceFailed(namespace: String, error: Error) async {
			if let index = namespaces.firstIndex(where: { $0.id == namespace }) {
				namespaces[index].status = .failed
			}
		}

		func updateOperation(_ operation: String) async {
			currentOperation = operation
		}

		private func handleDeletionError(_ error: Error) {
			currentState = .failed
			canCancel = false

			if let s3Error = error as? S3Error,
			   case .partialDeletionFailure(let errors, let deletedCount) = s3Error {
				// Handle partial failure
				errorMessage = "Partially deleted \(deletedCount) objects. Some items could not be removed."
				canRetry = retryCount < maxRetries

				// Update namespace statuses based on errors
				for errorMsg in errors {
					if errorMsg.contains("photos/") {
						updateNamespaceStatus("photos", to: .failed)
					} else if errorMsg.contains("thumbnails/") {
						updateNamespaceStatus("thumbnails", to: .failed)
					} else if errorMsg.contains("catalogs/") {
						updateNamespaceStatus("catalogs", to: .failed)
					} else if errorMsg.contains("users/") {
						updateNamespaceStatus("users", to: .failed)
					} else if errorMsg.contains("identities/") {
						updateNamespaceStatus("identities", to: .failed)
					}
				}
			} else {
				// Generic error
				errorMessage = error.localizedDescription
				canRetry = retryCount < maxRetries
			}
		}

		private func updateNamespaceStatus(_ id: String, to status: NamespaceStatus) {
			if let index = namespaces.firstIndex(where: { $0.id == id }) {
				namespaces[index].status = status
			}
		}

		private func updateOverallProgress() {
			let totalProgress = namespaces.reduce(0) { $0 + $1.progress }
			overallProgress = totalProgress / Double(namespaces.count)
		}
	}

	// MARK: - Supporting Types

	enum DeletionState {
		case preparing
		case deleting
		case completed
		case failed
		case cancelled

		var icon: String {
			switch self {
			case .preparing: return "hourglass"
			case .deleting: return "trash"
			case .completed: return "checkmark.circle.fill"
			case .failed: return "xmark.circle.fill"
			case .cancelled: return "xmark.circle"
			}
		}

		var iconColor: Color {
			switch self {
			case .preparing: return .secondary
			case .deleting: return .orange
			case .completed: return .green
			case .failed: return .red
			case .cancelled: return .secondary
			}
		}

		var title: String {
			switch self {
			case .preparing: return "Preparing..."
			case .deleting: return "Deleting Account"
			case .completed: return "Account Deleted"
			case .failed: return "Deletion Failed"
			case .cancelled: return "Deletion Cancelled"
			}
		}

		var subtitle: String {
			switch self {
			case .preparing:
				return "Getting ready to delete your account"
			case .deleting:
				return "This may take a few moments"
			case .completed:
				return "Your account and all data have been removed"
			case .failed:
				return "Some data could not be deleted"
			case .cancelled:
				return "Account deletion was cancelled"
			}
		}
	}

	struct NamespaceProgress: Identifiable {
		let id: String
		let name: String
		let icon: String
		var status: NamespaceStatus = .pending
		var progress: Double = 0
		var deletedCount: Int = 0

		var statusText: String {
			switch status {
			case .pending:
				return "Waiting"
			case .inProgress:
				if deletedCount > 0 {
					return "\(deletedCount) deleted"
				} else {
					return "\(Int(progress * 100))%"
				}
			case .completed:
				return "\(deletedCount) items"
			case .failed:
				return "Failed"
			}
		}
	}

	enum NamespaceStatus {
		case pending
		case inProgress
		case completed
		case failed

		var color: Color {
			switch self {
			case .pending: return .secondary
			case .inProgress: return .blue
			case .completed: return .green
			case .failed: return .red
			}
		}

		var statusIcon: String {
			switch self {
			case .pending: return "clock"
			case .inProgress: return "arrow.circlepath"
			case .completed: return "checkmark.circle.fill"
			case .failed: return "exclamationmark.circle.fill"
			}
		}
	}
}

// MARK: - Preview

#Preview("Deleting") {
	DeletionProgressView(isPresented: .constant(true)) { _ in }
}

#Preview("Completed") {
	DeletionProgressView(isPresented: .constant(true)) { _ in }
}

#Preview("Failed") {
	DeletionProgressView(isPresented: .constant(true)) { _ in }
}