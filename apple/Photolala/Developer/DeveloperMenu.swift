//
//  DeveloperMenu.swift
//  Photolala
//

#if os(macOS) && DEVELOPER
import SwiftUI

struct DeveloperMenuCommands: Commands {
	var body: some Commands {
		CommandMenu("Developer") {
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

			Button("Open Sign-In Test Panel") {
				Task { @MainActor in
					TestSignInWindowController.shared.show()
				}
			}
		}
	}
}
#endif
