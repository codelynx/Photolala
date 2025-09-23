//
//  HomeView.swift
//  Photolala
//
//  Created by Claude on 2025/09/23.
//

import SwiftUI
import Photos
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Navigation destinations
enum PhotoBrowserDestination: Hashable {
	case localFolder(URL, Bool) // URL and securityScopeStarted
	case applePhotos
	case cloudPhotos
}

struct HomeView: View {
	@State private var navigationPath = NavigationPath()
	@State private var model = Model()

	private var welcomeMessage: String {
		#if os(macOS)
		if model.isSignedIn {
			"Welcome back! Choose how to browse your photos"
		} else {
			"Welcome! Sign in to access cloud features or browse locally"
		}
		#else
		"Choose a source to browse photos"
		#endif
	}

	var body: some View {
		#if os(iOS)
		NavigationStack(path: $navigationPath) {
			homeContent
				.navigationDestination(for: PhotoBrowserDestination.self) { destination in
					photoBrowserView(for: destination)
				}
		}
		.onChange(of: model.pendingDestination) { _, newDestination in
			if let destination = newDestination {
				navigationPath.append(destination)
				model.pendingDestination = nil
			}
		}
		#else
		homeContent
		#endif
	}

	var homeContent: some View {
		VStack(spacing: 30) {
			// App icon and name
			VStack(spacing: 16) {
				#if os(iOS)
				// Note: AppIcon from bundle may not be available as a named image
				// Using fallback system image for now
				Image(systemName: "photo.stack")
					.font(.system(size: 80))
					.foregroundStyle(.tint)
				#else
				if let appIcon = NSImage(named: "AppIcon") {
					Image(nsImage: appIcon)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 80, height: 80)
						.cornerRadius(16)
				} else {
					Image(systemName: "photo.stack")
						.font(.system(size: 80))
						.foregroundStyle(.tint)
				}
				#endif

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
				Button(action: model.selectFolder) {
					Label("Browse Local Folder", systemImage: "folder")
						.frame(minWidth: 280)
				}
				.controlSize(.large)
				.buttonStyle(.borderedProminent)

				// Apple Photos button
				Button(action: model.openPhotoLibrary) {
					Label("Apple Photos Library", systemImage: "photo.on.rectangle")
						.frame(minWidth: 280)
						.foregroundStyle(.tint)
				}
				.controlSize(.large)

				// Cloud browser button - only show if signed in
				if model.isSignedIn {
					Button(action: model.openCloudPhotos) {
						Label("Cloud Photos", systemImage: "cloud")
							.frame(minWidth: 280)
					}
					.controlSize(.large)
				}
			}
			#else
			// On iOS, show both buttons since there's no menu bar
			VStack(spacing: 12) {
				// Select folder button
				Button(action: model.selectFolder) {
					Label("Browse Folder", systemImage: "folder")
						.frame(minWidth: 200)
				}
				.controlSize(.large)

				// Photos Library button
				Button(action: model.openPhotoLibrary) {
					Label("Photos Library", systemImage: "photo.on.rectangle")
						.frame(minWidth: 200)
				}
				.controlSize(.large)

				// Cloud browser button - only show if signed in
				if model.isSignedIn {
					Button(action: model.openCloudPhotos) {
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

			// Account section - show Sign In or Account Settings based on auth state
			if !model.isSignedIn {
				// Not signed in - show sign in prompt
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

					// Sign In button with prominent styling
					Button(action: model.signIn) {
						Label("Sign In", systemImage: "person.circle")
							.frame(minWidth: 180)
					}
					.controlSize(.large)
					.buttonStyle(.borderedProminent)

					// Create Account option for new users
					Spacer()
						.frame(height: 8)

					HStack(spacing: 4) {
						Text("Don't have an account?")
							.font(.caption)
							.foregroundStyle(.secondary)

						Button(action: model.signIn) {
							Text("Sign Up")
								.font(.caption)
								.fontWeight(.medium)
								.foregroundStyle(.tint)
						}
						.buttonStyle(.plain)
					}
				}
			} else {
				// Show signed in status with enhanced display
				VStack(spacing: 20) {
					VStack(spacing: 12) {
						// User avatar with checkmark
						ZStack(alignment: .bottomTrailing) {
							Image(systemName: "person.circle.fill")
								.font(.system(size: 50))
								.foregroundColor(.accentColor)

							// Green checkmark to indicate signed in
							Image(systemName: "checkmark.circle.fill")
								.font(.system(size: 18))
								.foregroundColor(.green)
								#if os(iOS)
								.background(Circle().fill(Color(UIColor.systemBackground)))
								#else
								.background(Circle().fill(Color(NSColor.windowBackgroundColor)))
								#endif
								.offset(x: 5, y: 5)
						}

						VStack(spacing: 4) {
							Text("Signed in as")
								.font(.caption)
								.foregroundStyle(.secondary)

							let displayName = model.currentUser?.displayName ?? "User"
							Text(displayName)
								.font(.headline)
								.foregroundStyle(.primary)

							// Show email if different from display name
							if let email = model.currentUser?.email,
							   email != displayName {
								Text(email)
									.font(.caption)
									.foregroundStyle(.secondary)
							}
						}
					}

					// Account Settings button with prominent styling
					VStack(spacing: 8) {
						Button(action: model.openAccountSettings) {
							Label("Account Settings", systemImage: "gearshape.fill")
								.frame(minWidth: 180)
						}
						.controlSize(.large)
						.buttonStyle(.borderedProminent)

						Text("Manage subscription, storage, and sign out")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			}
		}
		.padding(40)
		#if os(macOS)
		.frame(minWidth: 600, minHeight: 700)
		#else
		.frame(minWidth: 400, minHeight: 300)
		#endif
		.onChange(of: model.isSignedIn) { _, isSignedIn in
			// Show success message when user signs in
			if isSignedIn && !model.showSignInSuccess {
				if let user = model.currentUser {
					model.signInSuccessMessage = "Welcome, \(user.displayName)!"
					model.showSignInSuccess = true

					// Hide success message after 3 seconds
					DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
						withAnimation {
							model.showSignInSuccess = false
						}
					}
				}
			}
		}
		.overlay(alignment: .top) {
			// Success message overlay
			if model.showSignInSuccess {
				VStack {
					HStack {
						Image(systemName: "checkmark.circle.fill")
							.foregroundColor(.green)
						Text(model.signInSuccessMessage)
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
				.animation(.easeInOut(duration: 0.3), value: model.showSignInSuccess)
			}
		}
		#if os(iOS)
		// Add environment badge only on iOS
		.overlay(alignment: .topTrailing) {
			EnvironmentBadgeView()
		}
		.portraitOnlyForiPhone() // Lock to portrait on iPhone only
		#endif
		.task {
			await model.checkSignInStatus()
		}
		#if os(iOS)
		.sheet(isPresented: $model.showingFolderPicker) {
			DocumentPickerView(
				isPresented: $model.showingFolderPicker,
				contentTypes: [.folder],
				onPick: { url, started in
					model.handleFolderSelection(url, securityScopeStarted: started)
				}
			)
		}
		#else
		.fileImporter(
			isPresented: $model.showingFolderPicker,
			allowedContentTypes: [.folder],
			allowsMultipleSelection: false
		) { result in
			switch result {
			case .success(let urls):
				if let url = urls.first {
					model.handleFolderSelection(url, securityScopeStarted: false)
				}
			case .failure(let error):
				print("[HomeView] Folder selection failed: \(error)")
			}
		}
		#endif
	}

	@ViewBuilder
	private func photoBrowserView(for destination: PhotoBrowserDestination) -> some View {
		switch destination {
		case .localFolder(let url, let scopeStarted):
			#if os(iOS)
			let source = LocalPhotoSource(directoryURL: url, requiresSecurityScope: true, securityScopeAlreadyStarted: scopeStarted)
			#else
			let source = LocalPhotoSource(directoryURL: url)
			#endif
			let environment = PhotoBrowserEnvironment(source: source)
			PhotoBrowserView(environment: environment, title: url.lastPathComponent)
				#if os(macOS)
				.frame(minWidth: 800, minHeight: 600)
				#endif

		case .applePhotos:
			let source = ApplePhotosSource()
			let environment = PhotoBrowserEnvironment(source: source)
			PhotoBrowserView(environment: environment, title: "Photos Library")
				#if os(macOS)
				.frame(minWidth: 800, minHeight: 600)
				#endif

		case .cloudPhotos:
			// TODO: Implement S3PhotoSource
			Text("Cloud Photos - Coming Soon")
				.font(.title)
				.foregroundStyle(.secondary)
		}
	}
}

// MARK: - View Model
extension HomeView {
	@Observable
	final class Model {
		// State properties
		var showingFolderPicker = false
		var showingSignIn = false
		var showSignInSuccess = false
		var signInSuccessMessage = ""
		var showingAccountSettings = false

		// Navigation state
		#if os(iOS)
		// iOS navigation
		var pendingDestination: PhotoBrowserDestination?
		#endif

		// User state
		var isSignedIn = false
		var currentUser: PhotolalaUser?

		// MARK: - Actions (Placeholder implementations)

		@MainActor
		func checkSignInStatus() async {
			// Check if user is signed in
			currentUser = AccountManager.shared.getCurrentUser()
			isSignedIn = currentUser != nil
			print("[HomeView] Sign-in status checked: \(isSignedIn ? "Signed in" : "Not signed in")")
		}

		@MainActor
		func selectFolder() {
			print("[HomeView] Select folder tapped")
			showingFolderPicker = true
		}


		@MainActor
		func openPhotoLibrary() {
			print("[HomeView] Photo library tapped")
			#if os(macOS)
			// Open in new window
			PhotoWindowManager.shared.openApplePhotosWindow()
			#else
			// On iOS, use navigation
			pendingDestination = .applePhotos
			#endif
		}

		@MainActor
		func openCloudPhotos() {
			print("[HomeView] Cloud photos tapped")
			#if os(macOS)
			// TODO: Show cloud photos in sheet
			#else
			// On iOS, use navigation
			pendingDestination = .cloudPhotos
			#endif
		}

		@MainActor
		func handleFolderSelection(_ url: URL, securityScopeStarted: Bool) {
			print("[HomeView] Folder selected: \(url.path), scope started: \(securityScopeStarted)")

			#if os(iOS)
			// Set navigation immediately while picker is still visible
			// This ensures SwiftUI processes the navigation correctly
			self.pendingDestination = .localFolder(url, securityScopeStarted)
			#else
			// On macOS, open in new window
			PhotoWindowManager.shared.openWindow(for: url)
			#endif
		}

		@MainActor
		func signIn() {
			print("[HomeView] Sign in tapped")
			showingSignIn = true
		}

		@MainActor
		func openAccountSettings() {
			print("[HomeView] Account settings tapped")
			showingAccountSettings = true
		}
	}
}

#Preview {
	HomeView()
}
