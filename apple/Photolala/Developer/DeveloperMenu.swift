//
//  DeveloperMenu.swift
//  Photolala
//

#if os(macOS) && DEBUG
import SwiftUI

struct DeveloperMenuCommands: Commands {
	var body: some Commands {
		CommandMenu("Developer") {
			Button("Test Sign-In") {
				Task { @MainActor in
					TestSignInWindowController.shared.show()
				}
			}
			.keyboardShortcut("T", modifiers: [.command, .shift])
		}
	}
}
#endif
