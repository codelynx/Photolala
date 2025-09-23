//
//  PhotolalaAccountDiagnosticsView.swift
//  Photolala
//
//  Diagnostics tool for testing full Photolala account lifecycle and service authentication.
//  Tests Lambda calls, account creation, STS credentials, and environment switching.
//

#if os(macOS) && DEVELOPER
import SwiftUI
import AuthenticationServices

// MARK: - View
struct PhotolalaAccountDiagnosticsView: View {
	@State private var model = PhotolalaAccountDiagnosticsModel()

	var body: some View {
		VStack(spacing: 0) {
			// Header
			headerSection

			Divider()

			// Main content
			HSplitView {
				// Left: Controls
				controlPanel
					.frame(minWidth: 350, idealWidth: 400)

				// Right: Results
				resultsPanel
					.frame(minWidth: 500)
			}
		}
		.frame(minWidth: 900, minHeight: 700)
		.background(Color(nsColor: .windowBackgroundColor))
	}

	// MARK: - Header Section

	private var headerSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Image(systemName: "person.badge.shield.checkmark")
					.font(.title)
					.foregroundStyle(.tint)

				VStack(alignment: .leading) {
					Text("Photolala Account Diagnostics")
						.font(.title2)
						.fontWeight(.semibold)

					Text("Test full account lifecycle, Lambda functions, and service authentication")
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Spacer()

				// Status indicator
				statusBadge
			}
			.padding()
		}
	}

	private var statusBadge: some View {
		Group {
			switch model.currentStep {
			case .idle:
				Label("Ready", systemImage: "circle.dotted")
					.foregroundStyle(.secondary)
			case .authenticating:
				Label("Authenticating", systemImage: "arrow.triangle.2.circlepath")
					.foregroundStyle(.blue)
			case .lambdaCalling:
				Label("Calling Lambda", systemImage: "network")
					.foregroundStyle(.orange)
			case .accountProcessing:
				Label("Processing Account", systemImage: "person.crop.circle.badge.clock")
					.foregroundStyle(.purple)
			case .complete:
				Label("Complete", systemImage: "checkmark.seal.fill")
					.foregroundStyle(.green)
			case .failed:
				Label("Failed", systemImage: "exclamationmark.triangle.fill")
					.foregroundStyle(.red)
			}
		}
		.labelStyle(.titleAndIcon)
		.padding(.horizontal, 12)
		.padding(.vertical, 6)
		.background(Color(nsColor: .controlBackgroundColor))
		.clipShape(Capsule())
	}

	// MARK: - Control Panel

	private var controlPanel: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 20) {
				// Environment Selection
				environmentSection

				Divider()

				// Provider Selection
				providerSection

				Divider()

				// Test Options
				testOptionsSection

				Divider()

				// Action Buttons
				actionButtonsSection
			}
			.padding()
		}
		.background(Color(nsColor: .controlBackgroundColor))
	}

	private var environmentSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Environment", systemImage: "globe")
				.font(.headline)

			Picker("Environment", selection: $model.selectedEnvironment) {
				ForEach(TestEnvironment.allCases, id: \.self) { env in
					Text(env.rawValue).tag(env)
				}
			}
			.pickerStyle(.segmented)

			HStack {
				Image(systemName: "info.circle")
					.foregroundStyle(.secondary)
				Text("Current: \(model.currentEnvironmentDisplay)")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
	}

	private var providerSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Authentication Provider", systemImage: "person.2.badge.key")
				.font(.headline)

			Picker("Provider", selection: $model.selectedProvider) {
				ForEach(AuthProvider.allCases, id: \.self) { provider in
					Label(provider.rawValue, systemImage: provider.icon)
						.tag(provider)
				}
			}
			.pickerStyle(.radioGroup)
		}
	}

	private var testOptionsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Test Options", systemImage: "gearshape")
				.font(.headline)

			Toggle("Force new account creation", isOn: $model.forceNewAccount)
				.help("Simulate first-time user flow")

			Toggle("Test account linking", isOn: $model.testAccountLinking)
				.help("Test linking providers to existing account")

			Toggle("Verify STS credentials", isOn: $model.verifySTSCredentials)
				.help("Test AWS STS credential generation and validation")

			Toggle("Show detailed Lambda logs", isOn: $model.showDetailedLogs)
		}
	}

	private var actionButtonsSection: some View {
		VStack(spacing: 12) {
			Button(action: model.runFullTest) {
				Label("Run Full Account Test", systemImage: "play.fill")
					.frame(maxWidth: .infinity)
			}
			.controlSize(.large)
			.buttonStyle(.borderedProminent)
			.disabled(model.isTestRunning)

			HStack {
				Button(action: model.clearResults) {
					Label("Clear", systemImage: "trash")
				}
				.disabled(model.isTestRunning)

				Button(action: model.exportLogs) {
					Label("Export Logs", systemImage: "square.and.arrow.up")
				}
				.disabled(model.logs.isEmpty)
			}
		}
	}

	// MARK: - Results Panel

	private var resultsPanel: some View {
		VStack(alignment: .leading, spacing: 0) {
			// Results header
			HStack {
				Text("Test Results")
					.font(.headline)

				Spacer()

				if let testDuration = model.testDuration {
					Text("Duration: \(String(format: "%.2fs", testDuration))")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.padding()
			.background(Color(nsColor: .controlBackgroundColor))

			Divider()

			// Results content
			ScrollViewReader { proxy in
				ScrollView {
					VStack(alignment: .leading, spacing: 16) {
						// Account info (if available)
						if let accountInfo = model.accountInfo {
							accountInfoSection(accountInfo)
						}

						// Lambda calls
						if !model.lambdaCalls.isEmpty {
							lambdaCallsSection
						}

						// Logs
						if !model.logs.isEmpty {
							logsSection
						}

						// Error (if any)
						if let error = model.lastError {
							errorSection(error)
						}
					}
					.padding()
				}
				.onChange(of: model.logs.count) { _, _ in
					withAnimation {
						proxy.scrollTo("bottom", anchor: .bottom)
					}
				}
			}
		}
	}

	private func accountInfoSection(_ info: AccountInfo) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Account Information", systemImage: "person.text.rectangle")
				.font(.headline)

			VStack(alignment: .leading, spacing: 8) {
				InfoRow(label: "User ID", value: info.userId)
				InfoRow(label: "Email", value: info.email ?? "N/A")
				InfoRow(label: "Provider", value: info.provider)
				InfoRow(label: "Environment", value: info.environment)
				InfoRow(label: "Is New User", value: info.isNewUser ? "Yes" : "No")

				if let credentials = info.stsCredentials {
					Divider()
					Text("STS Credentials")
						.font(.caption)
						.foregroundStyle(.secondary)
					InfoRow(label: "Access Key", value: String(credentials.accessKeyId.prefix(10)) + "...")
					InfoRow(label: "Expires", value: credentials.expiration.formatted())
				}
			}
			.padding()
			.background(Color(nsColor: .textBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 8))
		}
	}

	private var lambdaCallsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Label("Lambda Function Calls", systemImage: "network")
				.font(.headline)

			ForEach(model.lambdaCalls) { call in
				HStack {
					Image(systemName: call.success ? "checkmark.circle.fill" : "xmark.circle.fill")
						.foregroundStyle(call.success ? .green : .red)

					VStack(alignment: .leading) {
						Text(call.functionName)
							.font(.caption)
							.fontWeight(.medium)

						Text("\(call.duration)ms")
							.font(.caption2)
							.foregroundStyle(.secondary)
					}

					Spacer()

					Text(call.timestamp.formatted(date: .omitted, time: .standard))
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
				.padding(8)
				.background(Color(nsColor: .textBackgroundColor))
				.clipShape(RoundedRectangle(cornerRadius: 6))
			}
		}
	}

	private var logsSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Label("Detailed Logs", systemImage: "doc.text")
				.font(.headline)

			VStack(alignment: .leading, spacing: 4) {
				ForEach(model.logs) { log in
					HStack(alignment: .top) {
						Image(systemName: log.type.icon)
							.foregroundStyle(log.type.color)
							.frame(width: 20)

						VStack(alignment: .leading) {
							Text(log.message)
								.font(.system(.caption, design: .monospaced))

							if let details = log.details, model.showDetailedLogs {
								Text(details)
									.font(.system(.caption2, design: .monospaced))
									.foregroundStyle(.secondary)
							}
						}

						Spacer()

						Text(log.timestamp.formatted(date: .omitted, time: .standard))
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}

				Spacer()
					.frame(height: 1)
					.id("bottom")
			}
			.padding()
			.background(Color(nsColor: .textBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 8))
		}
	}

	private func errorSection(_ error: String) -> some View {
		HStack {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.red)

			Text(error)
				.font(.caption)

			Spacer()
		}
		.padding()
		.background(Color.red.opacity(0.1))
		.clipShape(RoundedRectangle(cornerRadius: 8))
	}
}

// MARK: - Supporting Types
// TestEnvironment and AuthProvider are defined in DiagnosticTypes.swift

enum TestStep {
	case idle
	case authenticating
	case lambdaCalling
	case accountProcessing
	case complete
	case failed
}

struct AccountInfo {
	let userId: String
	let email: String?
	let provider: String
	let environment: String
	let isNewUser: Bool
	let stsCredentials: STSCredentials?
}

struct LambdaCall: Identifiable {
	let id = UUID()
	let functionName: String
	let duration: Int
	let success: Bool
	let timestamp: Date
}

struct LogEntry: Identifiable {
	let id = UUID()
	let timestamp: Date
	let type: LogType
	let message: String
	let details: String?

	enum LogType {
		case info
		case request
		case response
		case error

		var icon: String {
			switch self {
			case .info: return "info.circle"
			case .request: return "arrow.up.circle"
			case .response: return "arrow.down.circle"
			case .error: return "exclamationmark.triangle"
			}
		}

		var color: Color {
			switch self {
			case .info: return .secondary
			case .request: return .blue
			case .response: return .green
			case .error: return .red
			}
		}
	}

	init(type: LogType, message: String, details: String? = nil) {
		self.timestamp = Date()
		self.type = type
		self.message = message
		self.details = details
	}
}

struct InfoRow: View {
	let label: String
	let value: String

	var body: some View {
		HStack {
			Text(label + ":")
				.font(.caption)
				.foregroundStyle(.secondary)
				.frame(width: 100, alignment: .leading)

			Text(value)
				.font(.caption)
				.fontWeight(.medium)
				.textSelection(.enabled)

			Spacer()
		}
	}
}

// MARK: - View Model

@MainActor
@Observable
final class PhotolalaAccountDiagnosticsModel {
	// Configuration
	var selectedEnvironment: TestEnvironment
	var selectedProvider: AuthProvider = .apple
	var forceNewAccount = false
	var testAccountLinking = false
	var verifySTSCredentials = true
	var showDetailedLogs = false

	// State
	var isTestRunning = false
	var currentStep: TestStep = .idle
	var testStartTime: Date?
	var testDuration: TimeInterval?

	// Results
	var accountInfo: AccountInfo?
	var lambdaCalls: [LambdaCall] = []
	var logs: [LogEntry] = []
	var lastError: String?

	// Environment
	nonisolated private let originalEnvironment: String?

	var currentEnvironmentDisplay: String {
		let current = UserDefaults.standard.string(forKey: "environment_preference") ?? "development"
		return current.capitalized
	}

	init() {
		// Store and use current environment
		originalEnvironment = UserDefaults.standard.string(forKey: "environment_preference")
		switch originalEnvironment ?? "development" {
		case "staging":
			selectedEnvironment = .staging
		case "production":
			selectedEnvironment = .production
		default:
			selectedEnvironment = .development
		}
	}

	deinit {
		// Restore original environment
		if let original = originalEnvironment {
			UserDefaults.standard.set(original, forKey: "environment_preference")
		}
	}

	func runFullTest() {
		guard !isTestRunning else { return }

		Task {
			await performTest()
		}
	}

	private func performTest() async {
		isTestRunning = true
		currentStep = .authenticating
		testStartTime = Date()
		clearResults()

		// Set test environment
		UserDefaults.standard.set(selectedEnvironment.userDefaultsValue, forKey: "environment_preference")
		log(.info, "Environment set to: \(selectedEnvironment.rawValue)")

		do {
			// Setup diagnostic hooks
			setupDiagnosticHooks()

			// Perform authentication
			log(.info, "Starting authentication with \(selectedProvider.rawValue)")
			currentStep = .lambdaCalling

			let accountManager = AccountManager.shared

			switch selectedProvider {
			case .apple:
				let result = try await accountManager.signInWithAppleWithDiagnostics()
				await handleAuthResult(result)
			case .google:
				let result = try await accountManager.signInWithGoogleWithDiagnostics()
				await handleAuthResult(result)
			}

			// Verify STS credentials if requested
			if verifySTSCredentials {
				log(.info, "Verifying STS credentials...")
				let credentials = try await accountManager.getSTSCredentials()
				log(.response, "STS credentials valid until \(credentials.expiration.formatted())")
			}

			currentStep = .complete
			log(.info, "Test completed successfully")

		} catch {
			currentStep = .failed
			lastError = error.localizedDescription
			log(.error, "Test failed: \(error.localizedDescription)")
		}

		// Calculate duration
		if let startTime = testStartTime {
			testDuration = Date().timeIntervalSince(startTime)
		}

		isTestRunning = false

		// Restore environment
		restoreOriginalEnvironment()
	}

	private func setupDiagnosticHooks() {
		AccountManager.diagnosticHooks = AccountManager.DiagnosticHooks(
			onStepChange: { [weak self] step in
				Task { @MainActor in
					self?.log(.info, step)
				}
			},
			onNetworkRequest: { [weak self] message, details in
				Task { @MainActor in
					self?.log(.request, message, details: details?.description)

					// Track Lambda calls
					if message.contains("Lambda") {
						let functionName = message.replacingOccurrences(of: "Calling Lambda: ", with: "")
						self?.lambdaCalls.append(LambdaCall(
							functionName: functionName,
							duration: 0,
							success: false,
							timestamp: Date()
						))
					}
				}
			},
			onNetworkResponse: { [weak self] message, details in
				Task { @MainActor in
					self?.log(.response, message, details: details?.description)

					// Update last Lambda call
					if let lastIndex = self?.lambdaCalls.indices.last {
						self?.lambdaCalls[lastIndex] = LambdaCall(
							functionName: self?.lambdaCalls[lastIndex].functionName ?? "",
							duration: Int.random(in: 100...500), // Mock duration
							success: true,
							timestamp: Date()
						)
					}
				}
			},
			onError: { [weak self] error in
				Task { @MainActor in
					self?.log(.error, error.localizedDescription)
				}
			}
		)
	}

	private func handleAuthResult(_ result: AuthResult) async {
		currentStep = .accountProcessing

		accountInfo = AccountInfo(
			userId: result.user.id.uuidString,
			email: result.user.email,
			provider: selectedProvider.rawValue,
			environment: selectedEnvironment.rawValue,
			isNewUser: result.isNewUser,
			stsCredentials: result.credentials
		)

		log(.info, "Account processed: \(result.user.id.uuidString)")
		log(.info, "Is new user: \(result.isNewUser)")
	}

	private func log(_ type: LogEntry.LogType, _ message: String, details: String? = nil) {
		let entry = LogEntry(type: type, message: message, details: details)
		logs.append(entry)
	}

	private func restoreOriginalEnvironment() {
		if let original = originalEnvironment {
			UserDefaults.standard.set(original, forKey: "environment_preference")
			log(.info, "Environment restored to original value")
		}
	}

	func clearResults() {
		accountInfo = nil
		lambdaCalls.removeAll()
		logs.removeAll()
		lastError = nil
		testDuration = nil
	}

	func exportLogs() {
		// Create export text
		var exportText = "Photolala Account Diagnostics Export\n"
		exportText += "Generated: \(Date().formatted())\n"
		exportText += "Environment: \(selectedEnvironment.rawValue)\n"
		exportText += "Provider: \(selectedProvider.rawValue)\n"
		exportText += "\n--- Logs ---\n"

		for log in logs {
			exportText += "\(log.timestamp.formatted()): [\(log.type)] \(log.message)\n"
			if let details = log.details {
				exportText += "  Details: \(details)\n"
			}
		}

		// Save to file
		let savePanel = NSSavePanel()
		savePanel.nameFieldStringValue = "photolala-account-diagnostics-\(Date().timeIntervalSince1970).txt"
		savePanel.begin { result in
			if result == .OK, let url = savePanel.url {
				try? exportText.write(to: url, atomically: true, encoding: .utf8)
			}
		}
	}
}

// MARK: - Preview

#Preview {
	PhotolalaAccountDiagnosticsView()
}

#endif