//
//  PhotolalaAccountDiagnosticsWindowController.swift
//  Photolala
//

#if os(macOS) && DEVELOPER
import AppKit
import SwiftUI

final class PhotolalaAccountDiagnosticsWindowController: NSWindowController {
	static let shared = PhotolalaAccountDiagnosticsWindowController()

	private init() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800),
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		window.title = "Photolala Account Diagnostics"
		window.center()
		window.contentView = NSHostingView(rootView: PhotolalaAccountDiagnosticsView())

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