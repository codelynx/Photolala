import SwiftUI
#if os(macOS)
	import AppKit
#endif

struct HelpView: View {
	@State private var currentURL: URL?
	@State private var canGoBack = false
	@State private var canGoForward = false
	@State private var searchText = ""

	#if os(macOS)
		@Environment(\.dismiss) private var dismiss
	#else
		@Environment(\.presentationMode) var presentationMode
	#endif

	var body: some View {
		#if os(macOS)
			VStack(spacing: 0) {
				// Toolbar
				HStack {
					Button(action: self.goBack) {
						Image(systemName: "chevron.left")
					}
					.disabled(!self.canGoBack)
					.help("Go Back")

					Button(action: self.goForward) {
						Image(systemName: "chevron.right")
					}
					.disabled(!self.canGoForward)
					.help("Go Forward")

					Button(action: self.goHome) {
						Image(systemName: "house")
					}
					.help("Help Home")

					Spacer()

					TextField("Search Help", text: self.$searchText)
						.textFieldStyle(.roundedBorder)
						.frame(width: 200)
						.onSubmit {
							// TODO: Implement search
						}

					Spacer()

					Button("Done") {
						self.dismiss()
					}
					.keyboardShortcut(.escape, modifiers: [])
				}
				.padding()
				.background(Color(NSColor.controlBackgroundColor))

				Divider()

				// Web content
				HelpWebView(htmlFileName: "index", currentURL: self.$currentURL)
			}
			.frame(width: 800, height: 600)
			.background(Color(NSColor.windowBackgroundColor))
		#else
			NavigationView {
				VStack {
					HelpWebView(htmlFileName: "index", currentURL: self.$currentURL)
				}
				.navigationTitle("Help")
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .navigationBarLeading) {
						HStack {
							Button(action: self.goBack) {
								Image(systemName: "chevron.left")
							}
							.disabled(!self.canGoBack)

							Button(action: self.goForward) {
								Image(systemName: "chevron.right")
							}
							.disabled(!self.canGoForward)

							Button(action: self.goHome) {
								Image(systemName: "house")
							}
						}
					}

					ToolbarItem(placement: .navigationBarTrailing) {
						Button("Done") {
							self.presentationMode.wrappedValue.dismiss()
						}
					}
				}
			}
			.navigationViewStyle(StackNavigationViewStyle())
		#endif
	}

	private func goBack() {
		// TODO: Implement navigation via WKWebView
	}

	private func goForward() {
		// TODO: Implement navigation via WKWebView
	}

	private func goHome() {
		// TODO: Navigate to index.html
	}
}

#if os(macOS)
	// Help window controller for macOS
	class HelpWindowController: NSWindowController {
		convenience init() {
			let helpView = HelpView()
			let hostingController = NSHostingController(rootView: helpView)

			let window = NSWindow(contentViewController: hostingController)
			window.title = "Photolala Help"
			window.setContentSize(NSSize(width: 800, height: 600))
			window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
			window.minSize = NSSize(width: 600, height: 400)
			window.center()

			self.init(window: window)
		}

		func showHelp() {
			window?.makeKeyAndOrderFront(nil)
		}
	}
#endif
