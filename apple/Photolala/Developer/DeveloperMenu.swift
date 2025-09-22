//
//  DeveloperMenu.swift
//  Photolala
//

#if os(macOS) && DEBUG
import SwiftUI

struct DeveloperMenuCommands: Commands {
	var body: some Commands {
		CommandMenu("Developer") {
			Button("Test Sign-In with Apple") {
				Task {
					await TestSignInHandler.testAppleSignIn()
				}
			}
			.keyboardShortcut("T", modifiers: [.command, .shift])

			Button("Test Sign-In with Google") {
				Task {
					await TestSignInHandler.testGoogleSignIn()
				}
			}
			.keyboardShortcut("G", modifiers: [.command, .shift])
		}
	}
}
#endif