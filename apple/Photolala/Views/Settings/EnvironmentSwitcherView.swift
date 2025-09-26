//
//  EnvironmentSwitcherView.swift
//  Photolala
//
//  Environment switcher accessible from environment badge
//

import SwiftUI

struct EnvironmentSwitcherView: View {
	@State private var model = Model()
	@Environment(\.dismiss) private var dismiss
	@Binding var isPresented: Bool

	var body: some View {
		NavigationStack {
			VStack(spacing: 24) {
				// Header
				VStack(spacing: 8) {
					Image(systemName: "server.rack")
						.font(.largeTitle)
						.foregroundStyle(.tint)

					Text("Switch Environment")
						.font(.title2.bold())

					Text("Select the environment you want to use")
						.font(.callout)
						.foregroundStyle(.secondary)
				}
				.padding(.top)

				// Current environment indicator
				HStack {
					Text("Currently:")
						.foregroundStyle(.secondary)
					Text(model.currentEnvironment.rawValue.capitalized)
						.fontWeight(.semibold)
						.foregroundStyle(environmentColor(for: model.currentEnvironment))
				}
				.font(.callout)

				// Environment options
				VStack(spacing: 12) {
					ForEach([AWSEnvironment.development, .staging, .production], id: \.self) { env in
						Button {
							model.selectedEnvironment = env
						} label: {
							HStack {
								// Radio button
								Image(systemName: model.selectedEnvironment == env ? "circle.inset.filled" : "circle")
									.font(.title3)
									.foregroundStyle(model.selectedEnvironment == env ? environmentColor(for: env) : .secondary)

								VStack(alignment: .leading, spacing: 2) {
									Text(env.rawValue.capitalized)
										.font(.headline)
										.foregroundStyle(.primary)

									Text(env.awsBucket)
										.font(.caption)
										.foregroundStyle(.secondary)
								}

								Spacer()

								// Current indicator
								if env == model.currentEnvironment {
									Text("CURRENT")
										.font(.caption2)
										.fontWeight(.semibold)
										.padding(.horizontal, 8)
										.padding(.vertical, 4)
										.background(Color.blue.opacity(0.2))
										.foregroundStyle(.blue)
										.clipShape(Capsule())
								}

								// Warning for production
								if env == .production && env != model.currentEnvironment {
									Image(systemName: "exclamationmark.triangle.fill")
										.font(.callout)
										.foregroundStyle(.orange)
								}
							}
							.padding()
							.background(
								RoundedRectangle(cornerRadius: 12)
									.fill(model.selectedEnvironment == env ?
										environmentColor(for: env).opacity(0.1) :
										Color(XColor.secondarySystemBackground))
							)
							.overlay(
								RoundedRectangle(cornerRadius: 12)
									.stroke(model.selectedEnvironment == env ?
										environmentColor(for: env).opacity(0.5) :
										Color.clear, lineWidth: 2)
							)
						}
						.buttonStyle(.plain)
					}
				}
				.padding(.horizontal)

				// Warning message if signed in
				if model.isSignedIn {
					HStack {
						Image(systemName: "info.circle.fill")
							.foregroundStyle(.orange)
						Text("Switching environments will sign you out")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					.padding(.horizontal)
				}

				Spacer()

				// Action buttons
				HStack(spacing: 12) {
					Button("Cancel") {
						dismiss()
					}
					.buttonStyle(.bordered)
					.controlSize(.large)

					Button("Switch") {
						model.switchEnvironment()
					}
					.buttonStyle(.borderedProminent)
					.controlSize(.large)
					.disabled(model.selectedEnvironment == model.currentEnvironment)
				}
				.padding(.horizontal)
				.padding(.bottom)
			}
			.frame(maxWidth: 500)
			.navigationTitle("Environment")
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.confirmationDialog(
				"Switch Environment?",
				isPresented: $model.showingConfirmation
			) {
				Button("Switch & Sign Out", role: .destructive) {
					Task {
						await model.performSwitch()
						isPresented = false
					}
				}
				Button("Cancel", role: .cancel) {}
			} message: {
				Text("Switching from \(model.currentEnvironment.rawValue.capitalized) to \(model.selectedEnvironment.rawValue.capitalized) will sign you out. You'll need to sign in again in the new environment.")
			}
			.alert("Environment Switched", isPresented: $model.showingSuccess) {
				Button("OK") {
					isPresented = false
				}
			} message: {
				Text("Successfully switched to \(model.selectedEnvironment.rawValue.capitalized) environment.")
			}
		}
		.task {
			await model.loadCurrentState()
		}
	}

	private func environmentColor(for environment: AWSEnvironment) -> Color {
		switch environment {
		case .development:
			return .blue
		case .staging:
			return .orange
		case .production:
			return .green
		}
	}
}

// MARK: - View Model

extension EnvironmentSwitcherView {
	@MainActor
	@Observable
	final class Model {
		var currentEnvironment: AWSEnvironment = .development
		var selectedEnvironment: AWSEnvironment = .development
		var isSignedIn = false
		var showingConfirmation = false
		var showingSuccess = false

		func loadCurrentState() async {
			// Get current environment
			let environmentPreference = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
			switch environmentPreference {
			case "production":
				currentEnvironment = .production
			case "staging":
				currentEnvironment = .staging
			default:
				currentEnvironment = .development
			}

			// Set initial selection to current
			selectedEnvironment = currentEnvironment

			// Check if signed in
			isSignedIn = AccountManager.shared.isSignedIn
		}

		func switchEnvironment() {
			// Don't switch if same environment selected
			guard selectedEnvironment != currentEnvironment else { return }

			if isSignedIn {
				// Show confirmation if signed in
				showingConfirmation = true
			} else {
				// Switch immediately if not signed in
				Task {
					await performSwitch()
				}
			}
		}

		func performSwitch() async {
			// Sign out if needed
			if isSignedIn {
				await AccountManager.shared.signOut()
			}

			// Update environment preference
			UserDefaults.standard.set(selectedEnvironment.rawValue, forKey: "environment_preference")

			// Update CredentialManager
			CredentialManager.shared.updateEnvironment(to: selectedEnvironment)
			CredentialManager.shared.invalidateCache()

			// Update current environment
			currentEnvironment = selectedEnvironment

			print("[EnvironmentSwitcher] Switched to \(selectedEnvironment.rawValue) environment")

			// Show success (optional)
			showingSuccess = true
		}
	}
}

// MARK: - Preview

#Preview {
	@Previewable @State var isPresented = true
	return EnvironmentSwitcherView(isPresented: $isPresented)
}