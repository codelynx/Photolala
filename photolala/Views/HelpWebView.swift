import SwiftUI
import WebKit

#if os(macOS)
import AppKit

struct HelpWebView: NSViewRepresentable {
	let htmlFileName: String
	@Binding var currentURL: URL?
	
	func makeNSView(context: Context) -> WKWebView {
		let configuration = WKWebViewConfiguration()
		configuration.preferences.isTextInteractionEnabled = true
		
		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = context.coordinator
		webView.allowsBackForwardNavigationGestures = true
		
		// Enable zoom
		webView.allowsMagnification = true
		webView.magnification = 1.0
		
		return webView
	}
	
	func updateNSView(_ webView: WKWebView, context: Context) {
		loadHTMLFile(in: webView)
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	private func loadHTMLFile(in webView: WKWebView) {
		guard let helpURL = Bundle.main.url(forResource: htmlFileName, withExtension: "html", subdirectory: "Help") else {
			print("Could not find help file: \(htmlFileName).html")
			return
		}
		
		// Get the base URL for resources
		let baseURL = helpURL.deletingLastPathComponent()
		
		do {
			let htmlString = try String(contentsOf: helpURL)
			webView.loadHTMLString(htmlString, baseURL: baseURL)
			currentURL = helpURL
		} catch {
			print("Error loading help file: \(error)")
			webView.loadHTMLString("<h1>Error</h1><p>Could not load help content.</p>", baseURL: nil)
		}
	}
	
	class Coordinator: NSObject, WKNavigationDelegate {
		var parent: HelpWebView
		
		init(_ parent: HelpWebView) {
			self.parent = parent
		}
		
		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
			if let url = navigationAction.request.url {
				// Handle internal navigation
				if url.scheme == "file" {
					parent.currentURL = url
					decisionHandler(.allow)
				} else if url.scheme == "http" || url.scheme == "https" {
					// Open external links in default browser
					NSWorkspace.shared.open(url)
					decisionHandler(.cancel)
				} else {
					decisionHandler(.allow)
				}
			} else {
				decisionHandler(.allow)
			}
		}
		
		func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
			// Inject CSS for dark mode support
			let script = """
			if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
				document.documentElement.setAttribute('data-theme', 'dark');
			}
			"""
			webView.evaluateJavaScript(script)
		}
	}
}

#else
import UIKit

struct HelpWebView: UIViewRepresentable {
	let htmlFileName: String
	@Binding var currentURL: URL?
	
	func makeUIView(context: Context) -> WKWebView {
		let configuration = WKWebViewConfiguration()
		configuration.preferences.isTextInteractionEnabled = true
		
		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.navigationDelegate = context.coordinator
		webView.allowsBackForwardNavigationGestures = true
		
		// Adjust for iOS
		webView.scrollView.contentInsetAdjustmentBehavior = .automatic
		
		return webView
	}
	
	func updateUIView(_ webView: WKWebView, context: Context) {
		loadHTMLFile(in: webView)
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	private func loadHTMLFile(in webView: WKWebView) {
		guard let helpURL = Bundle.main.url(forResource: htmlFileName, withExtension: "html", subdirectory: "Help") else {
			print("Could not find help file: \(htmlFileName).html")
			return
		}
		
		// Get the base URL for resources
		let baseURL = helpURL.deletingLastPathComponent()
		
		do {
			let htmlString = try String(contentsOf: helpURL)
			webView.loadHTMLString(htmlString, baseURL: baseURL)
			currentURL = helpURL
		} catch {
			print("Error loading help file: \(error)")
			webView.loadHTMLString("<h1>Error</h1><p>Could not load help content.</p>", baseURL: nil)
		}
	}
	
	class Coordinator: NSObject, WKNavigationDelegate {
		var parent: HelpWebView
		
		init(_ parent: HelpWebView) {
			self.parent = parent
		}
		
		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
			if let url = navigationAction.request.url {
				// Handle internal navigation
				if url.scheme == "file" {
					parent.currentURL = url
					decisionHandler(.allow)
				} else if url.scheme == "http" || url.scheme == "https" {
					// Open external links in default browser
					UIApplication.shared.open(url)
					decisionHandler(.cancel)
				} else {
					decisionHandler(.allow)
				}
			} else {
				decisionHandler(.allow)
			}
		}
		
		func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
			// Inject CSS for dark mode support
			let script = """
			if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
				document.documentElement.setAttribute('data-theme', 'dark');
			}
			"""
			webView.evaluateJavaScript(script)
		}
	}
}
#endif