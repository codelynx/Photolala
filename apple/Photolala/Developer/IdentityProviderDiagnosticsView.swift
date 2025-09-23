//
//  IdentityProviderDiagnosticsView.swift
//  Photolala
//

#if os(macOS) && DEVELOPER
import SwiftUI
import AuthenticationServices
import AppKit
import Combine

// Types moved to DiagnosticTypes.swift to avoid duplication

// MARK: - OAuth Test State
enum AuthenticationStep: Equatable {
	case idle
	case oauthInProgress
	case oauthComplete
	case complete(userId: String)
	case failed(error: String)

	var description: String {
		switch self {
		case .idle: return "Ready"
		case .oauthInProgress: return "OAuth Provider Authentication"
		case .oauthComplete: return "OAuth Token Received"
		case .complete(let userId): return "OAuth Test Complete: \(userId)"
		case .failed(let error): return "OAuth Failed: \(error)"
		}
	}

	var icon: String {
		switch self {
		case .idle: return "circle"
		case .oauthInProgress: return "arrow.triangle.2.circlepath"
		case .oauthComplete: return "checkmark.circle.fill"
		case .complete: return "checkmark.seal.fill"
		case .failed: return "xmark.circle.fill"
		}
	}

	var iconColor: Color {
		switch self {
		case .idle: return .secondary
		case .oauthInProgress: return .blue
		case .oauthComplete, .complete: return .green
		case .failed: return .red
		}
	}
}

// MARK: - Network Log Entry
struct NetworkLogEntry: Identifiable {
	let id = UUID()
	let timestamp: Date
	let type: LogType
	let message: String
	let details: [String: String]?

	enum LogType {
		case request
		case response
		case error
		case info

		var icon: String {
			switch self {
			case .request: return "arrow.up.circle"
			case .response: return "arrow.down.circle"
			case .error: return "exclamationmark.triangle"
			case .info: return "info.circle"
			}
		}

		var color: Color {
			switch self {
			case .request: return .blue
			case .response: return .green
			case .error: return .red
			case .info: return .secondary
			}
		}
	}

	/// Convenience initializer that automatically sets the current timestamp
	init(type: LogType, message: String, details: [String: String]? = nil) {
		self.timestamp = Date()
		self.type = type
		self.message = message
		self.details = details
	}
}

// MARK: - View Model
@MainActor
@Observable
final class IdentityProviderDiagnosticsModel {
	// Provider
	var selectedProvider: AuthProvider = .apple

	// OAuth Test Options
	var showDetailedLogs = false

	// State
	var isTestRunning = false
	var currentStep: AuthenticationStep = .idle
	var stepHistory: [(Date, AuthenticationStep)] = []

	// Results
	var lastAuthResult: AuthResult?
	var errorMessage: String?

	// Logs
	var networkLogs: [NetworkLogEntry] = []
	var debugMessages: [String] = []


	private let timestampFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm:ss.SSS"
		return formatter
	}()

	init() {
		// No environment setup needed for OAuth-only testing
	}

	func startTest() {
		guard !isTestRunning else { return }

		// Clear previous results
		clearResults()
		isTestRunning = true

		// OAuth testing is independent of environment

		Task {
			await performAuthentication()
		}
	}

	func clearResults() {
		currentStep = .idle
		stepHistory.removeAll()
		lastAuthResult = nil
		errorMessage = nil
		networkLogs.removeAll()
		debugMessages.removeAll()
	}

	private func performAuthentication() async {
		do {
			// Start OAuth test
			updateStep(.oauthInProgress)
			log(.info, "Starting \(selectedProvider.rawValue) OAuth test")

			switch selectedProvider {
			case .apple:
				// Test Apple OAuth only - no Lambda calls
				let (credential, nonce) = try await AccountManager.shared.performTestAppleSignIn()

				// Log OAuth success
				updateStep(.oauthComplete)
				log(.info, "Apple OAuth successful")

				// Extract and log token info (without sending to backend)
				if let identityToken = credential.identityToken,
				   let tokenString = String(data: identityToken, encoding: .utf8) {
					log(.info, "OAuth token received (length: \(tokenString.count) bytes)")
					log(.info, "User ID: \(credential.user)")
					if let email = credential.email {
						log(.info, "Email: \(email)")
					}
					if let fullName = credential.fullName {
						let name = [fullName.givenName, fullName.familyName]
							.compactMap { $0 }
							.joined(separator: " ")
						if !name.isEmpty {
							log(.info, "Name: \(name)")
						}
					}
					log(.info, "Nonce used: \(nonce)")
				}

				// Mark test complete - OAuth successful
				updateStep(.complete(userId: credential.user))
				isTestRunning = false

			case .google:
				// Test Google OAuth only - no Lambda calls
				log(.info, "Initiating Google OAuth flow...")
				log(.info, "Browser should open for authentication")

				let credential = try await AccountManager.shared.performTestGoogleSignIn()

				// Log OAuth success
				updateStep(.oauthComplete)
				log(.info, "Google OAuth successful")

				// Extract and log token info (without sending to backend)
				log(.info, "OAuth token received (ID token length: \(credential.idToken.count) bytes)")
				log(.info, "Access token length: \(credential.accessToken.count) bytes")
				log(.info, "User ID: \(credential.claims.subject)")
				log(.info, "Email: \(credential.claims.email ?? "N/A")")
				if let name = credential.claims.name {
					log(.info, "Name: \(name)")
				}

				// Mark test complete - OAuth successful
				updateStep(.complete(userId: credential.claims.subject))
				isTestRunning = false
			}

		} catch {
			updateStep(.failed(error: error.localizedDescription))
			log(.error, "OAuth test failed: \(error)")
			errorMessage = error.localizedDescription
			isTestRunning = false
		}
	}

	// Removed handleStepChange and handleAuthResult - not needed for OAuth-only testing

	private func updateStep(_ step: AuthenticationStep) {
		currentStep = step
		stepHistory.append((Date(), step))

		// Add to debug log
		let timestamp = timestampFormatter.string(from: Date())
		debugMessages.append("[\(timestamp)] \(step.description)")
	}

	private func log(_ type: NetworkLogEntry.LogType, _ message: String, details: [String: String]? = nil) {
		let entry = NetworkLogEntry(
			type: type,
			message: message,
			details: details
		)
		networkLogs.append(entry)

		// Also add to debug messages
		let timestamp = timestampFormatter.string(from: Date())
		let prefix = switch type {
		case .request: "→"
		case .response: "←"
		case .error: "✗"
		case .info: "ℹ"
		}
		debugMessages.append("[\(timestamp)] \(prefix) \(message)")
	}
}

// MARK: - Main View
struct IdentityProviderDiagnosticsView: View {
	@State private var model = IdentityProviderDiagnosticsModel()

	var body: some View {
		VStack(spacing: 0) {
			// Header
			headerSection

			Divider()

			// Main Content
			ScrollView {
				VStack(spacing: 20) {
					providerSection
					optionsSection
					actionSection

					if model.isTestRunning || model.lastAuthResult != nil {
						Divider()
						processFlowSection
					}

					if let result = model.lastAuthResult {
						Divider()
						accountInfoSection(result: result)
					}

					if !model.debugMessages.isEmpty {
						Divider()
						debugLogSection
					}
				}
				.padding(20)
			}
		}
		.frame(minWidth: 600, minHeight: 700)
		.background(Color(nsColor: .controlBackgroundColor))
	}

	// MARK: - Header Section
	private var headerSection: some View {
		VStack(spacing: 8) {
			HStack {
				Image(systemName: "person.badge.shield.checkmark.fill")
					.font(.largeTitle)
					.foregroundStyle(.blue.gradient)

				VStack(alignment: .leading) {
					Text("OAuth Provider Diagnostics")
						.font(.title.bold())
					Text("Test Apple ID & Google Sign-In OAuth flows only")
						.font(.callout)
						.foregroundStyle(.secondary)
				}

				Spacer()

				if model.isTestRunning {
					ProgressView()
						.controlSize(.small)
				}
			}
			.padding()
		}
		.background(Color(nsColor: .windowBackgroundColor))
	}

	// Environment section removed - OAuth testing is independent of Photolala environments

	// MARK: - Provider Section
	private var providerSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Authentication Provider", systemImage: "person.badge.key")
				.font(.headline)

			Picker("", selection: $model.selectedProvider) {
				ForEach(AuthProvider.allCases, id: \.self) { provider in
					Label(provider.rawValue, systemImage: provider.icon)
						.tag(provider)
				}
			}
			.pickerStyle(.segmented)
			.disabled(model.isTestRunning)
		}
		.padding()
		.background(Color(nsColor: .controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 8))
	}

	// MARK: - Options Section
	private var optionsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("OAuth Debug Options", systemImage: "gearshape")
				.font(.headline)

			Toggle("Show detailed OAuth flow logs", isOn: $model.showDetailedLogs)
				.toggleStyle(.checkbox)
				.help("Display detailed OAuth token exchange and validation logs")
		}
		.padding()
		.background(Color(nsColor: .controlBackgroundColor))
		.clipShape(RoundedRectangle(cornerRadius: 8))
		.disabled(model.isTestRunning)
	}

	// MARK: - Action Section
	private var actionSection: some View {
		HStack {
			Button(action: model.startTest) {
				Label("Begin Authentication Test", systemImage: "play.fill")
					.frame(maxWidth: .infinity)
			}
			.controlSize(.large)
			.buttonStyle(.borderedProminent)
			.disabled(model.isTestRunning)

			if !model.debugMessages.isEmpty {
				Button(action: model.clearResults) {
					Label("Clear", systemImage: "trash")
				}
				.controlSize(.large)
				.disabled(model.isTestRunning)
			}
		}
	}

	// MARK: - Process Flow Section
	private var processFlowSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Authentication Flow", systemImage: "arrow.triangle.swap")
				.font(.headline)

			VStack(alignment: .leading, spacing: 8) {
				ForEach(model.stepHistory, id: \.0) { date, step in
					HStack {
						Image(systemName: step.icon)
							.foregroundStyle(step.iconColor)
							.frame(width: 20)

						Text(step.description)
							.font(.system(.body, design: .monospaced))

						Spacer()

						Text(date.formatted(date: .omitted, time: .standard))
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
			.padding()
			.background(Color(nsColor: .textBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 8))
		}
	}

	// MARK: - Account Info Section
	private func accountInfoSection(result: AuthResult) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Account Information", systemImage: "person.text.rectangle")
				.font(.headline)

			VStack(alignment: .leading, spacing: 8) {
				// User ID
				HStack {
					Text("User UUID:")
						.foregroundStyle(.secondary)
					Text(result.user.id.uuidString)
						.font(.system(.body, design: .monospaced))
						.textSelection(.enabled)
				}

				// Email
				HStack {
					Text("Email:")
						.foregroundStyle(.secondary)
					Text(result.user.email ?? "Not provided")
						.textSelection(.enabled)
				}

				// Display Name
				HStack {
					Text("Display Name:")
						.foregroundStyle(.secondary)
					Text(result.user.displayName)
						.textSelection(.enabled)
				}

				// Provider IDs
				if result.user.hasAppleProvider {
					HStack {
						Label("Apple ID:", systemImage: "apple.logo")
							.foregroundStyle(.secondary)
						Text(result.user.appleUserID ?? "N/A")
							.font(.system(.caption, design: .monospaced))
							.textSelection(.enabled)
					}
				}

				if result.user.hasGoogleProvider {
					HStack {
						Label("Google ID:", systemImage: "g.circle")
							.foregroundStyle(.secondary)
						Text(result.user.googleUserID ?? "N/A")
							.font(.system(.caption, design: .monospaced))
							.textSelection(.enabled)
					}
				}

				Divider()

				// Account Status
				HStack {
					Label(
						result.isNewUser ? "New User" : "Existing User",
						systemImage: result.isNewUser ? "person.badge.plus" : "person.fill"
					)
					.foregroundStyle(result.isNewUser ? .green : .blue)

					Spacer()

					VStack(alignment: .trailing, spacing: 4) {
						Text("Created: \(result.user.createdAt.formatted(date: .abbreviated, time: .shortened))")
						Text("Updated: \(result.user.updatedAt.formatted(date: .abbreviated, time: .shortened))")
					}
					.font(.caption)
					.foregroundStyle(.secondary)
				}

				// STS Credentials
				HStack {
					Label("Credentials Expire:", systemImage: "clock")
						.foregroundStyle(.orange)
					Text(result.credentials.expiration.formatted(date: .abbreviated, time: .standard))
						.font(.caption)
				}
			}
			.padding()
			.background(Color(nsColor: .textBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 8))
		}
	}

	// MARK: - Debug Log Section
	private var debugLogSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Label("Debug Log", systemImage: "doc.text.magnifyingglass")
					.font(.headline)

				Spacer()

				Button(action: copyDebugLog) {
					Label("Copy", systemImage: "doc.on.doc")
				}
				.controlSize(.mini)
			}

			ScrollView {
				VStack(alignment: .leading, spacing: 2) {
					ForEach(Array(model.debugMessages.enumerated()), id: \.offset) { _, message in
						Text(message)
							.font(.system(.caption, design: .monospaced))
							.textSelection(.enabled)
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(8)
			}
			.frame(height: 200)
			.background(Color(nsColor: .textBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 8))
		}
	}

	private func copyDebugLog() {
		let log = model.debugMessages.joined(separator: "\n")
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(log, forType: .string)
	}
}

// MARK: - Window Controller
@MainActor
final class IdentityProviderDiagnosticsController {
	static let shared = IdentityProviderDiagnosticsController()

	private lazy var hostingController = NSHostingController(
		rootView: IdentityProviderDiagnosticsView()
	)

	private lazy var window: NSWindow = {
		let window = NSWindow(contentViewController: hostingController)
		window.title = "Identity Provider Diagnostics"
		window.setContentSize(NSSize(width: 650, height: 800))
		window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
		window.isReleasedWhenClosed = false
		window.center()
		return window
	}()

	func show() {
		window.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)
	}
}

// MARK: - Preview
struct IdentityProviderDiagnosticsView_Previews: PreviewProvider {
	static var previews: some View {
		IdentityProviderDiagnosticsView()
			.frame(width: 650, height: 800)
	}
}
#endif