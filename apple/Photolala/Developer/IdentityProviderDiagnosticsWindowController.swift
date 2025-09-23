//
//  IdentityProviderDiagnosticsWindowController.swift
//  Photolala
//

#if os(macOS) && DEVELOPER
import AppKit
import SwiftUI

final class IdentityProviderDiagnosticsWindowController: NSWindowController {
	static let shared = IdentityProviderDiagnosticsWindowController()

	private init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.title = "OAuth Provider Diagnostics"
		window.center()
		window.contentView = NSHostingView(rootView: IdentityProviderDiagnosticsView())

		super.init(window: window)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func show() {
		window?.makeKeyAndOrderFront(nil)
		window?.center()
	}
}
#endif