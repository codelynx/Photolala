//
//  photolalaApp.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/09.
//

import SwiftUI

@main
struct photolalaApp: App {
	var body: some Scene {
		#if os(macOS)
		WindowGroup("Welcome") {
			WelcomeView()
		}
		.windowResizability(.contentSize)
		
		WindowGroup("Photo Browser", for: URL.self) { $folderURL in
			if let folderURL {
				PhotoBrowserView(folderURL: folderURL)
			} else {
				Text("No folder selected")
					.foregroundStyle(.secondary)
					.frame(minWidth: 400, minHeight: 300)
			}
		}
		#else
		WindowGroup {
			NavigationStack {
				WelcomeView()
			}
		}
		#endif
	}
}
