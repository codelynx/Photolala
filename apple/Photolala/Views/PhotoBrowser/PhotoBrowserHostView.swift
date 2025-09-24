//
//  PhotoBrowserHostView.swift
//  Photolala
//
//  Coordinator view that manages source switching and environment updates
//

import SwiftUI

struct PhotoBrowserHostView: View {
	@State private var environment: PhotoBrowserEnvironment
	@State private var currentSourceType: PhotoSourceSelector.PhotoSourceType
	@State private var isLoading = false
	@State private var errorMessage: String?
	@State private var showError = false
	@State private var showAuthSheet = false
	@StateObject private var accountManager = AccountManager.shared

	private let title: String
	private let factory: PhotoSourceFactory
	private let onSourceChange: ((any PhotoSourceProtocol) -> Void)?

	init(initialEnvironment: PhotoBrowserEnvironment,
	     title: String = "Photos",
	     factory: PhotoSourceFactory = DefaultPhotoSourceFactory.shared,
	     onSourceChange: ((any PhotoSourceProtocol) -> Void)? = nil) {
		self._environment = State(initialValue: initialEnvironment)
		self.title = title
		self.factory = factory
		self.onSourceChange = onSourceChange

		// Determine initial source type
		let source = initialEnvironment.source
		if source is S3PhotoSource {
			self._currentSourceType = State(initialValue: .cloud)
		} else if source is ApplePhotosSource {
			self._currentSourceType = State(initialValue: .applePhotos)
		} else {
			self._currentSourceType = State(initialValue: .local)
		}
	}

	var body: some View {
		ZStack {
			// Pure rendering view - just displays what it's given
			PhotoBrowserView(
				environment: environment,
				title: title
			)
			.toolbar {
				#if os(macOS)
				ToolbarItem(placement: .navigation) {
					Button(action: toggleSidebar) {
						Image(systemName: "sidebar.left")
					}
				}
				#endif

				// Source selector that delegates back to host
				ToolbarItem(placement: .navigation) {
					PhotoSourceSelector(
						currentSource: $currentSourceType,
						onSourceChanged: { newType in
							switchToSource(newType)
						}
					)
				}
			}

			// Loading overlay
			if isLoading {
				loadingOverlay
			}
		}
		.alert("Error", isPresented: $showError) {
			Button("OK") {
				errorMessage = nil
			}
		} message: {
			Text(errorMessage ?? "An error occurred")
		}
		.sheet(isPresented: $showAuthSheet) {
			CloudAuthenticationView(isPresented: $showAuthSheet)
				.onDisappear {
					// After auth, try switching to cloud again if needed
					if currentSourceType == .cloud && !(environment.source is S3PhotoSource) {
						switchToSource(.cloud)
					}
				}
		}
	}

	@ViewBuilder
	private var loadingOverlay: some View {
		VStack(spacing: 20) {
			ProgressView()
				.scaleEffect(1.5)
			Text("Loading...")
				.font(.headline)
				.foregroundColor(.secondary)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Color.black.opacity(0.3))
	}

	private func switchToSource(_ type: PhotoSourceSelector.PhotoSourceType) {
		Task { @MainActor in
			// Capture current state in case we need to revert
			let previousType = currentSourceType
			let previousEnvironment = environment

			isLoading = true
			defer { isLoading = false }

			let newSource: any PhotoSourceProtocol

			switch type {
			case .local:
				#if os(iOS)
				// On iOS, check if we have a saved local source
				if factory.getLastLocalSourceURL() != nil {
					newSource = await factory.makeLocalSource(url: nil)
				} else {
					// No saved source on iOS - show error
					errorMessage = "Please select a folder using 'Select Folder' from the home screen"
					showError = true
					currentSourceType = previousType
					return
				}
				#else
				// macOS can always create a local source
				newSource = await factory.makeLocalSource(url: nil)
				#endif

			case .applePhotos:
				newSource = factory.makeApplePhotosSource()

			case .cloud:
				// Check authentication first
				if !accountManager.isSignedIn {
					showAuthSheet = true
					currentSourceType = previousType
					return
				}

				do {
					newSource = try await factory.makeCloudSource()
				} catch {
					// Failed to create cloud source
					print("[PhotoBrowserHost] Failed to create cloud source: \(error)")
					errorMessage = "Failed to connect to cloud: \(error.localizedDescription)"
					showError = true

					// Revert both UI and environment state
					currentSourceType = previousType
					environment = previousEnvironment
					return
				}
			}

			// Successfully created new source - update environment
			environment = PhotoBrowserEnvironment(
				source: newSource,
				configuration: environment.configuration,
				cacheManager: environment.cacheManager
			)

			// Notify callback if provided
			onSourceChange?(newSource)
		}
	}

	#if os(macOS)
	private func toggleSidebar() {
		NSApp.keyWindow?.firstResponder?.tryToPerform(
			#selector(NSSplitViewController.toggleSidebar(_:)),
			with: nil
		)
	}
	#endif
}