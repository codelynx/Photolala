//
//  WelcomeView.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI
import XPlatform

struct WelcomeView: View {
	@State private var selectedFolder: URL?
	@State private var showingFolderPicker = false
	@State private var navigateToPhotoBrowser = false
	@State private var navigateToPhotoLibrary = false
	@State private var showingSignIn = false
	@State private var showSignInSuccess = false
	@State private var signInSuccessMessage = ""
	@EnvironmentObject var identityManager: IdentityManager
	#if os(macOS)
		@Environment(\.openWindow) private var openWindow
	#endif
	
	private var welcomeMessage: String {
		#if os(macOS)
			if identityManager.isSignedIn {
				"Welcome back! Choose how to browse your photos"
			} else {
				"Welcome! Sign in to access cloud features or browse locally"
			}
		#else
			"Choose a source to browse photos"
		#endif
	}

	var body: some View {
		VStack(spacing: 30) {
			// App icon and name
			VStack(spacing: 16) {
				if let appIcon = XImage(named: "AppIconImage") {
					Image(appIcon)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 80, height: 80)
						.cornerRadius(16)
				} else {
					Image(systemName: "photo.stack")
						.font(.system(size: 80))
						.foregroundStyle(.tint)
				}

				Text("Photolala")
					.font(.largeTitle)
					.fontWeight(.medium)
			}

			// Welcome message
			Text(welcomeMessage)
				.font(.headline)
				.foregroundStyle(.secondary)

			// Source selection buttons
			#if os(macOS)
			// On macOS, show main browsing options
			VStack(spacing: 12) {
				// Browse folder button
				Button(action: self.selectFolder) {
					Label("Browse Local Folder", systemImage: "folder")
						.frame(minWidth: 280)
				}
				.controlSize(.large)
				.buttonStyle(.borderedProminent)
				
				// Apple Photos button
				#if os(macOS)
				Button(action: {
					// Open Apple Photos window
					PhotoCommands.openApplePhotosLibrary()
				}) {
					Label("Apple Photos Library", systemImage: "photo.on.rectangle")
						.frame(minWidth: 280)
				}
				.controlSize(.large)
				#else
				NavigationLink(destination: ApplePhotosBrowserView()) {
					Label("Apple Photos Library", systemImage: "photo.on.rectangle")
						.frame(minWidth: 280)
				}
				.controlSize(.large)
				#endif
				
				// Cloud browser button - only show if signed in
				if identityManager.isSignedIn {
					#if os(macOS)
					Button(action: {
						// Open S3 browser window
						PhotoCommands.openS3Browser()
					}) {
						Label("Cloud Photos", systemImage: "cloud")
							.frame(minWidth: 280)
					}
					.controlSize(.large)
					#else
					NavigationLink(destination: S3PhotoBrowserView()) {
						Label("Cloud Photos", systemImage: "cloud")
							.frame(minWidth: 280)
					}
					.controlSize(.large)
					#endif
				}
			}
			#else
			// On iOS, show both buttons since there's no menu bar
			VStack(spacing: 12) {
				// Select folder button
				Button(action: self.selectFolder) {
					Label("Browse Folder", systemImage: "folder")
						.frame(minWidth: 200)
				}
				.controlSize(.large)
				
				// Photos Library button
				Button(action: self.openPhotoLibrary) {
					Label("Photos Library", systemImage: "photo.on.rectangle")
						.frame(minWidth: 200)
				}
				.controlSize(.large)
				
				// Cloud browser button - only show if signed in
				if identityManager.isSignedIn {
					NavigationLink(destination: S3PhotoBrowserView()) {
						Label("Cloud Photos", systemImage: "cloud")
							.frame(minWidth: 200)
					}
					.controlSize(.large)
				}
			}
			#endif
			
			Divider()
				.frame(maxWidth: 300)
				.padding(.vertical, 20)
			
			// Sign In section
			if !identityManager.isSignedIn {
				VStack(spacing: 16) {
					VStack(spacing: 8) {
						Text("Sign in for cloud features")
							.font(.headline)
							.foregroundStyle(.primary)
						
						Text("Backup photos • Access from anywhere • Sync across devices")
							.font(.caption)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
					}
					
					HStack(spacing: 12) {
						Button(action: {
							showingSignIn = true
						}) {
							Label("Sign In", systemImage: "person.circle")
								.frame(minWidth: 130)
						}
						.controlSize(.large)
						.buttonStyle(.borderedProminent)
						
						Button(action: {
							showingSignIn = true
						}) {
							Text("Create Account")
								.frame(minWidth: 130)
						}
						.controlSize(.large)
					}
				}
			} else {
				// Show signed in status with enhanced display
				VStack(spacing: 16) {
					VStack(spacing: 12) {
						Image(systemName: "person.circle.fill")
							.font(.system(size: 50))
							.foregroundColor(.accentColor)
						
						VStack(spacing: 4) {
							Text("Signed in as")
								.font(.caption)
								.foregroundStyle(.secondary)
							
							let displayName = identityManager.currentUser?.displayName ?? "User"
							Text(displayName)
								.font(.headline)
								.foregroundStyle(.primary)
							
							// Show email if different from display name
							if let email = identityManager.currentUser?.email,
							   email != displayName {
								Text(email)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							
							// If no name or email, show a button to add profile info
							if let user = identityManager.currentUser,
							   (user.fullName?.isEmpty ?? true) && (user.email?.isEmpty ?? true) {
								Button(action: {
									// TODO: Show profile edit sheet
									print("[WelcomeView] User needs to add profile information")
								}) {
									Label("Add Profile Info", systemImage: "pencil.circle")
										.font(.caption)
										.foregroundColor(.accentColor)
								}
								.buttonStyle(.plain)
								.padding(.top, 4)
							}
						}
					}
					
					HStack(spacing: 16) {
						#if os(macOS)
						Button(action: {
							// Open subscription management
							PhotoCommands.showSubscriptionView()
						}) {
							Text("Manage Subscription")
								.font(.callout)
						}
						#if os(macOS)
						.buttonStyle(.link)
						#else
						.buttonStyle(.plain)
						#endif
						
						Text("•")
							.foregroundStyle(.secondary)
						#endif
						
						Button(action: {
							identityManager.signOut()
						}) {
							Text("Sign Out")
								.font(.callout)
								.foregroundColor(.red)
						}
						#if os(macOS)
						.buttonStyle(.link)
						#else
						.buttonStyle(.plain)
						#endif
					}
				}
			}

			// Selected folder display
			if let folder = selectedFolder {
				VStack(spacing: 8) {
					Text("Selected:")
						.font(.caption)
						.foregroundStyle(.secondary)

					Text(folder.lastPathComponent)
						.font(.body)
						.fontWeight(.medium)

					Text(folder.path)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(1)
						.truncationMode(.middle)
						.frame(maxWidth: 300)
				}
				.padding()
				.background(Color.gray.opacity(0.1))
				.cornerRadius(8)
			}
		}
		.padding(40)
		#if os(macOS)
		.frame(minWidth: 600, minHeight: 700)
		#else
		.frame(minWidth: 400, minHeight: 300)
		#endif
		.onReceive(identityManager.$isSignedIn) { isSignedIn in
			// Show success message when user signs in
			if isSignedIn && !showSignInSuccess {
				if let user = identityManager.currentUser {
					signInSuccessMessage = "Welcome, \(user.displayName)!"
					showSignInSuccess = true
					
					// Hide success message after 3 seconds
					DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
						withAnimation {
							showSignInSuccess = false
						}
					}
				}
			}
		}
		.overlay(alignment: .top) {
			// Success message overlay
			if showSignInSuccess {
				VStack {
					HStack {
						Image(systemName: "checkmark.circle.fill")
							.foregroundColor(.green)
						Text(signInSuccessMessage)
							.fontWeight(.medium)
					}
					.padding(.horizontal, 20)
					.padding(.vertical, 12)
					.background(Color.green.opacity(0.1))
					.background(.regularMaterial)
					.cornerRadius(8)
					.overlay(
						RoundedRectangle(cornerRadius: 8)
							.stroke(Color.green.opacity(0.3), lineWidth: 1)
					)
				}
				.padding(.top, 20)
				.transition(.move(edge: .top).combined(with: .opacity))
				.animation(.easeInOut(duration: 0.3), value: showSignInSuccess)
			}
		}
		#if os(iOS)
			.navigationDestination(isPresented: self.$navigateToPhotoBrowser) {
				if let folder = selectedFolder {
					DirectoryPhotoBrowserView(directoryPath: folder.path as NSString)
				}
			}
			.navigationDestination(isPresented: self.$navigateToPhotoLibrary) {
				ApplePhotosBrowserView()
			}
		#endif
		#if os(macOS)
		.fileImporter(
			isPresented: self.$showingFolderPicker,
			allowedContentTypes: [.folder],
			allowsMultipleSelection: false
		) { result in
			switch result {
			case let .success(urls):
				if let url = urls.first {
					self.selectedFolder = url
					self.openPhotoBrowser(for: url)
				}
			case let .failure(error):
				print("Folder selection error: \(error)")
			}
		}
		#elseif os(iOS)
		.sheet(isPresented: self.$showingFolderPicker) {
			DocumentPickerView(selectedFolder: self.$selectedFolder) { url in
				self.openPhotoBrowser(for: url)
			}
		}
		#endif
		.sheet(isPresented: $showingSignIn) {
			AuthenticationChoiceView()
				.environmentObject(identityManager)
		}
		.portraitOnlyForiPhone() // Lock to portrait on iPhone only
	}

	private func selectFolder() {
		#if os(macOS)
			self.showingFolderPicker = true
		#elseif os(iOS)
			self.showingFolderPicker = true
		#endif
	}

	private func openPhotoBrowser(for url: URL) {
		#if os(macOS)
			// Open a new window with the folder browser
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
				styleMask: [.titled, .closable, .resizable, .miniaturizable],
				backing: .buffered,
				defer: false
			)
			
			window.title = url.lastPathComponent
			window.center()
			window.contentView = NSHostingView(
				rootView: DirectoryPhotoBrowserView(directoryPath: url.path as NSString)
					.environmentObject(IdentityManager.shared)
			)
			
			// Set minimum window size
			window.minSize = NSSize(width: 800, height: 600)
			
			window.makeKeyAndOrderFront(nil)
			
			// Keep window in front but not floating
			window.level = .normal
			window.isReleasedWhenClosed = false
		#else
			self.navigateToPhotoBrowser = true
		#endif
	}
	
	private func openPhotoLibrary() {
		#if os(macOS)
			// This method is not used on macOS anymore
			// Apple Photos Library is accessed from Window menu
		#else
			self.navigateToPhotoLibrary = true
		#endif
	}
}

#if os(iOS)
	import UIKit

	struct DocumentPickerView: UIViewControllerRepresentable {
		@Binding var selectedFolder: URL?
		@Environment(\.dismiss) private var dismiss
		let onSelectFolder: (URL) -> Void

		func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
			let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
			picker.delegate = context.coordinator
			picker.allowsMultipleSelection = false
			return picker
		}

		func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

		func makeCoordinator() -> Coordinator {
			Coordinator(self)
		}

		class Coordinator: NSObject, UIDocumentPickerDelegate {
			let parent: DocumentPickerView

			init(_ parent: DocumentPickerView) {
				self.parent = parent
			}

			func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
				if let url = urls.first {
					self.parent.selectedFolder = url
					// Start accessing the security-scoped resource
					// Note: We should NOT stop access here - the DirectoryPhotoBrowserView
					// needs to maintain access while browsing the folder
					_ = url.startAccessingSecurityScopedResource()
					self.parent.onSelectFolder(url)
				}
				self.parent.dismiss()
			}

			func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
				self.parent.dismiss()
			}
		}
	}
#endif

#Preview {
	WelcomeView()
}
