//
//  DeveloperMenu.swift
//  Photolala
//

#if os(macOS) && DEVELOPER
import SwiftUI

struct DeveloperMenuCommands: Commands {
	var body: some Commands {
		CommandMenu("Developer") {
			Button("Identity Provider Diagnostics") {
				Task { @MainActor in
					IdentityProviderDiagnosticsController.shared.show()
				}
			}
			.keyboardShortcut("I", modifiers: [.command, .shift])

			Divider()

			Button("Test Sign-In with Apple") {
				Task { @MainActor in
					TestSignInWindowController.shared.show(startingFlow: .apple)
				}
			}
			.keyboardShortcut("T", modifiers: [.command, .shift])

			Button("Test Sign-In with Google") {
				Task { @MainActor in
					TestSignInWindowController.shared.show(startingFlow: .google)
				}
			}
			.keyboardShortcut("G", modifiers: [.command, .shift])

			Divider()

			Menu("Diagnostics") {
				Button("OAuth Provider Diagnostics...") {
					Task { @MainActor in
						IdentityProviderDiagnosticsWindowController.shared.show()
					}
				}
				.help("Test OAuth providers only (Apple ID, Google Sign-In)")

				Button("Photolala Account Diagnostics...") {
					Task { @MainActor in
						PhotolalaAccountDiagnosticsWindowController.shared.show()
					}
				}
				.help("Test full account lifecycle and Lambda functions")
			}

			Divider()

			Button("Open Sign-In Test Panel") {
				Task { @MainActor in
					TestSignInWindowController.shared.show()
				}
			}
		}
	}
}
#endif
