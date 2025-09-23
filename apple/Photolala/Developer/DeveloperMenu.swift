//
//  DeveloperMenu.swift
//  Photolala
//

#if os(macOS) && DEVELOPER
import SwiftUI

struct DeveloperMenuCommands: Commands {
	var body: some Commands {
		CommandMenu("Developer") {
			Menu("Diagnostics") {
				Button("OAuth Provider Diagnostics...") {
					Task { @MainActor in
						IdentityProviderDiagnosticsWindowController.shared.show()
					}
				}
				.keyboardShortcut("I", modifiers: [.command, .shift])
				.help("Test OAuth providers only (Apple ID, Google Sign-In)")

				Button("Photolala Account Diagnostics...") {
					Task { @MainActor in
						PhotolalaAccountDiagnosticsWindowController.shared.show()
					}
				}
				.keyboardShortcut("P", modifiers: [.command, .shift])
				.help("Test full account lifecycle and Lambda functions")
			}
		}
	}
}
#endif
