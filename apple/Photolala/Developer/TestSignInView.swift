//
//  TestSignInView.swift
//  Photolala
//

#if os(macOS) && DEVELOPER
import SwiftUI
import AuthenticationServices
import AppKit
import Combine

@MainActor
final class TestSignInViewModel: ObservableObject {
	enum Flow {
		case apple
		case google
	}

	@Published private(set) var logEntries: [String] = []
	@Published private(set) var isRunning = false
	@Published private(set) var activeFlow: Flow?

	private lazy var timestampFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm:ss"
		return formatter
	}()

	func clearLog() {
		guard !isRunning else { return }
		logEntries.removeAll()
	}

	func runAppleSignIn() {
		start(flow: .apple)
	}

	func runGoogleSignIn() {
		start(flow: .google)
	}

	private func start(flow: Flow) {
		guard !isRunning else { return }
		logEntries.removeAll()
		isRunning = true
		activeFlow = flow

		Task(priority: .userInitiated) {
			switch flow {
			case .apple:
				await executeAppleSignIn()
			case .google:
				await executeGoogleSignIn()
			}

			finishRun()
		}
	}

	private func finishRun() {
		isRunning = false
		activeFlow = nil
	}

	private func executeAppleSignIn() async {
		do {
			log("=== Starting Apple Sign-In Test ===")

			let accountManager = AccountManager.shared
			let (credential, nonce) = try await accountManager.performTestAppleSignIn()
			log("✓ Received Apple credential")
			let nonceHash = String(accountManager.sha256(nonce).prefix(8))
			log("  - Nonce used: yes (SHA256: \(nonceHash)...)")

			if let identityToken = credential.identityToken,
			   let tokenString = String(data: identityToken, encoding: .utf8) {
				log("✓ Identity token received:")
				log("  - User: [REDACTED]")
				log("  - Token length: \(tokenString.count) characters")
				let parts = tokenString.split(separator: ".")
				if parts.count == 3 {
					log("✓ Valid JWT structure (3 parts)")
				} else {
					log("✗ Invalid JWT structure")
				}
			}

			if credential.email != nil {
				log("  - Email provided: yes (value: [REDACTED])")
			} else {
				log("  - Email provided: no")
			}

			if let fullName = credential.fullName {
				let hasFirstName = fullName.givenName != nil
				let hasLastName = fullName.familyName != nil
				log("  - Full name provided: first=\(hasFirstName), last=\(hasLastName)")
			} else {
				log("  - Full name provided: no")
			}

			log("  - Real user status: \(credential.realUserStatus.rawValue)")
			log("=== Test Complete ===")
		} catch {
			log("✗ Test failed: \(error)")
		}
	}

	private func executeGoogleSignIn() async {
		do {
			log("=== Starting Google Sign-In Test ===")

			let coordinator = GoogleSignInCoordinator()
			let credential = try await coordinator.performSignIn()
			log("✓ Received Google credential")

			log("✓ Identity token received:")
			log("  - User ID: [REDACTED]")
			let emailStatus = credential.claims.email != nil ? "[REDACTED]" : "not provided"
			log("  - Email: \(emailStatus)")
			log("  - Token length: \(credential.idToken.count) characters")

			let parts = credential.idToken.split(separator: ".")
			if parts.count == 3 {
				log("✓ Valid JWT structure (3 parts)")
			} else {
				log("✗ Invalid JWT structure")
			}

			log("✓ Token claims:")
			log("  - Issuer: \(credential.claims.issuer)")
			let audiencePreview = String(credential.claims.audience.prefix(20))
			log("  - Audience: \(audiencePreview)...")
			let emailVerified = credential.claims.emailVerified ?? false
			log("  - Email verified: \(emailVerified)")
			log("  - Has name: \(credential.claims.name != nil)")
			log("  - Has picture: \(credential.claims.picture != nil)")
			log("  - Nonce verified: yes")
			log("=== Test Complete ===")
		} catch let error as GoogleSignInError {
			switch error {
			case .userCancelled:
				log("✗ User cancelled the sign-in flow")
			case .stateMismatch:
				log("✗ Security error: State mismatch (possible CSRF)")
			case .nonceMismatch:
				log("✗ Security error: Nonce mismatch (possible replay attack)")
			case .tokenExpired:
				log("✗ Token validation failed: expired")
			case .invalidSignature:
				log("✗ Token validation failed: invalid signature")
			default:
				log("✗ Test failed: \(error)")
			}
		} catch {
			log("✗ Test failed: \(error)")
		}
	}

	private func log(_ message: String) {
		let timestamp = timestampFormatter.string(from: Date())
		logEntries.append("[\(timestamp)] \(message)")
	}
}

struct TestSignInView: View {
	@ObservedObject private var viewModel: TestSignInViewModel

	init(viewModel: TestSignInViewModel = TestSignInViewModel()) {
		self._viewModel = ObservedObject(wrappedValue: viewModel)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			header
			Divider()
			logOutput
		}
		.padding(20)
		.frame(minWidth: 520, minHeight: 380)
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Sign-In Diagnostics")
				.font(.title2.bold())

			HStack(spacing: 12) {
				Button {
					viewModel.runAppleSignIn()
				} label: {
					Label("Test Sign in with Apple", systemImage: "apple.logo")
				}
				.disabled(viewModel.isRunning)

				Button {
					viewModel.runGoogleSignIn()
				} label: {
					Label("Test Sign in with Google", systemImage: "g.circle")
				}
				.disabled(viewModel.isRunning)

				if viewModel.isRunning {
					ProgressView()
						.controlSize(.small)
				}

				Spacer()

				Button("Clear Log") {
					viewModel.clearLog()
				}
				.disabled(viewModel.logEntries.isEmpty || viewModel.isRunning)
			}

			if let flow = viewModel.activeFlow {
				Text(statusMessage(for: flow))
					.font(.callout)
					.foregroundStyle(.secondary)
			}
		}
	}

	private var logOutput: some View {
		ScrollViewReader { proxy in
			let logView = ScrollView {
				LazyVStack(alignment: .leading, spacing: 6) {
					ForEach(Array(viewModel.logEntries.enumerated()), id: \.offset) { index, entry in
						Text(entry)
							.font(.system(.body, design: .monospaced))
							.frame(maxWidth: .infinity, alignment: .leading)
							.textSelection(.enabled)
							.id(index)
					}
				}
				.padding(12)
			}
			.background(Color(nsColor: .textBackgroundColor))
			.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 12, style: .continuous)
					.strokeBorder(Color.secondary.opacity(0.25))
			)

			Group {
				if #available(macOS 14.0, *) {
					logView
						.onChange(of: viewModel.logEntries.count) { _, newCount in
							scrollToBottomIfNeeded(count: newCount, proxy: proxy)
						}
				} else {
					logView
						.onChange(of: viewModel.logEntries.count) { count in
							scrollToBottomIfNeeded(count: count, proxy: proxy)
						}
				}
			}
		}
	}

	private func scrollToBottomIfNeeded(count: Int, proxy: ScrollViewProxy) {
		guard count > 0,
		      let last = viewModel.logEntries.indices.last else { return }
		withAnimation(.easeInOut(duration: 0.2)) {
			proxy.scrollTo(last, anchor: .bottom)
		}
	}

	private func statusMessage(for flow: TestSignInViewModel.Flow) -> String {
		switch flow {
		case .apple:
			return "Running Apple sign-in test…"
		case .google:
			return "Running Google sign-in test…"
		}
	}
}

@MainActor
final class TestSignInWindowController {
	static let shared = TestSignInWindowController()

	private let viewModel = TestSignInViewModel()
	private lazy var hostingController = NSHostingController(rootView: TestSignInView(viewModel: viewModel))
	private lazy var window: NSWindow = {
		let window = NSWindow(contentViewController: hostingController)
		window.title = "Test Sign-In"
		window.setContentSize(NSSize(width: 540, height: 420))
		window.styleMask.insert(.closable)
		window.isReleasedWhenClosed = false
		window.center()
		return window
	}()

	func show(startingFlow: TestSignInViewModel.Flow? = nil) {
		window.makeKeyAndOrderFront(nil)
		NSApp.activate(ignoringOtherApps: true)

		if let flow = startingFlow {
			switch flow {
			case .apple:
				viewModel.runAppleSignIn()
			case .google:
				viewModel.runGoogleSignIn()
			}
		}
	}
}

struct TestSignInView_Previews: PreviewProvider {
	static var previews: some View {
		TestSignInView()
			.frame(width: 540, height: 420)
	}
}
#endif
