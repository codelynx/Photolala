//
//  PhotoBrowserViewLegacy.swift
//  Photolala
//
//  Legacy photo browser view (deprecated - use PhotoBrowserHostView + PhotoBrowserView instead)
//

import SwiftUI
import Combine

struct PhotoBrowserViewLegacy: View {
	// Injected environment
	@State var environment: PhotoBrowserEnvironment

	// View model
	@State private var model: Model

	// Display settings
	@State private var settings = PhotoBrowserSettings()

	// Error handling
	@State private var showError = false
	@State private var errorMessage = ""
	@State private var showAuthenticationView = false

	// Source management moved to PhotoBrowserHostView
	let onSourceChange: ((any PhotoSourceProtocol) -> Void)?

	// Navigation title
	let title: String

	init(environment: PhotoBrowserEnvironment,
	     title: String = "Photos",
	     onSourceChange: ((any PhotoSourceProtocol) -> Void)? = nil) {
		self._environment = State(initialValue: environment)
		self.title = title
		self.onSourceChange = onSourceChange
		self._model = State(initialValue: Model())

		// Source management handled by PhotoBrowserHostView
	}

	var body: some View {
		ZStack {
			PhotoCollectionViewRepresentable(
				photos: model.photos,
				selection: $model.selection,
				environment: environment,
				settings: settings,
				onItemTapped: { item in
					// Handle single tap - could show detail view
					print("[PhotoBrowser] Tapped item: \(item.displayName)")
				}
			)

			// Loading overlay for cloud source
			if model.isLoading && environment.source is S3PhotoSource && model.photos.isEmpty {
				VStack(spacing: 20) {
					ProgressView()
						.scaleEffect(1.5)
					Text("Loading cloud photos...")
						.font(.headline)
						.foregroundColor(.secondary)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				#if os(macOS)
				.background(Color(NSColor.windowBackgroundColor).opacity(0.95))
				#else
				.background(Color(UIColor.systemBackground).opacity(0.95))
				#endif
			}

			// Empty state for cloud when not signed in
			if let cloudSource = environment.source as? S3PhotoSource,
			   cloudSource.authenticationState == .notSignedIn,
			   !model.isLoading {
				VStack(spacing: 20) {
					Image(systemName: "icloud.slash")
						.font(.system(size: 60))
						.foregroundColor(.secondary)
					Text("Not Signed In")
						.font(.title2)
						.bold()
					Text("Sign in to access your cloud photos")
						.foregroundColor(.secondary)
					Button("Sign In...") {
						showAuthenticationView = true
					}
					.buttonStyle(.borderedProminent)
				}
				.frame(maxWidth: .infinity, maxHeight: .infinity)
				#if os(macOS)
				.background(Color(NSColor.windowBackgroundColor).opacity(0.95))
				#else
				.background(Color(UIColor.systemBackground).opacity(0.95))
				#endif
			}
		}
		.navigationTitle(title)
		#if os(macOS)
		.navigationSubtitle("\(model.photos.count) photos")
		#endif
		.toolbar {
			#if os(macOS)
			ToolbarItem(placement: .navigation) {
				Button(action: toggleSidebar) {
					Image(systemName: "sidebar.left")
				}
			}
			#endif

			// Source selector removed - handled by PhotoBrowserHostView

			// Group items on the right side
			ToolbarItemGroup(placement: .primaryAction) {
				// Thumbnail size control
				Picker("", selection: $settings.thumbnailSize) {
					ForEach(ThumbnailSize.allCases, id: \.self) { size in
						Text(size.rawValue)
							.tag(size)
					}
				}
				.pickerStyle(.segmented)
				.fixedSize()
				#if os(iOS)
				.scaleEffect(0.9) // Slightly smaller on iOS
				#endif

				// Fit/Fill toggle button
				Button(action: {
					settings.displayMode = settings.displayMode == .fit ? .fill : .fit
				}) {
					Image(systemName: settings.displayMode == .fit
						? "rectangle.arrowtriangle.2.inward"
						: "rectangle.arrowtriangle.2.outward")
						.help(settings.displayMode == .fit ? "Switch to Fill" : "Switch to Fit")
				}
				.buttonStyle(.plain)
				#if os(iOS)
				.padding(.leading, 4)
				#endif

				// Info bar toggle button
				Button(action: {
					settings.showInfoBar.toggle()
				}) {
					Image(systemName: settings.showInfoBar ? "square" : "inset.filled.bottomthird.square")
						.help(settings.showInfoBar ? "Hide Info Bar" : "Show Info Bar")
				}
				.buttonStyle(.plain)
				#if os(iOS)
				.padding(.leading, 4)
				#endif

				if model.isLoading {
					ProgressView()
						.scaleEffect(0.8)
				}
			}

			ToolbarItem(placement: .primaryAction) {
				Menu {
					Button(action: selectAll) {
						Label("Select All", systemImage: "checkmark.circle")
					}
					.disabled(model.photos.isEmpty)

					Button(action: deselectAll) {
						Label("Deselect All", systemImage: "circle")
					}
					.disabled(model.selection.isEmpty)

					Divider()

					Button(action: refresh) {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
				} label: {
					Image(systemName: "ellipsis.circle")
				}
			}
		}
		.task {
			await loadPhotos()
		}
		.onDisappear {
			// View cleanup if needed
		}
		.onReceive(environment.source.photosPublisher) { newPhotos in
			withAnimation(.easeInOut(duration: 0.2)) {
				model.photos = newPhotos
			}
		}
		.onReceive(environment.source.isLoadingPublisher) { isLoading in
			model.isLoading = isLoading
		}
		.alert("Error", isPresented: $showError) {
			Button("OK") {
				errorMessage = ""
			}
			Button("Retry") {
				Task {
					await loadPhotos()
				}
			}
		} message: {
			Text(errorMessage)
		}
		.sheet(isPresented: $showAuthenticationView) {
			CloudAuthenticationView(isPresented: $showAuthenticationView)
				.onDisappear {
					// Reload photos after sign-in
					Task {
						await loadPhotos()
					}
				}
		}
	}

	// MARK: - Actions

	private func loadPhotos() async {
		model.isLoading = true
		defer {
			model.isLoading = false
		}

		do {
			let photos = try await environment.source.loadPhotos()
			withAnimation {
				model.photos = photos
			}
		} catch PhotoSourceError.notAuthorized {
			errorMessage = "Please sign in to access cloud photos"
			showError = true
		} catch PhotoSourceError.sourceUnavailable {
			errorMessage = "Photo source is unavailable. Please try again."
			showError = true
		} catch PhotoSourceError.loadFailed(let underlyingError) {
			errorMessage = "Failed to load photos: \(underlyingError.localizedDescription)"
			showError = true
		} catch {
			print("[PhotoBrowser] Failed to load photos: \(error)")
			errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
			showError = true
		}
	}

	private func refresh() {
		Task {
			await loadPhotos()
		}
	}

	// Source switching removed - handled by PhotoBrowserHostView

	private func selectAll() {
		model.selection = Set(model.photos)
	}

	private func deselectAll() {
		model.selection.removeAll()
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

// MARK: - View Model

extension PhotoBrowserViewLegacy {
	@Observable
	final class Model {
		var photos: [PhotoBrowserItem] = []
		var selection = Set<PhotoBrowserItem>()
		var isLoading = false
		var error: Error?

		var hasSelection: Bool {
			!selection.isEmpty
		}

		var selectedCount: Int {
			selection.count
		}
	}
}
