//
//  PhotoBrowserView.swift
//  Photolala
//
//  Main photo browser view with dependency injection
//

import SwiftUI
import Combine

struct PhotoBrowserView: View {
	// Injected environment
	let environment: PhotoBrowserEnvironment

	// View model
	@State private var model: Model

	// Navigation title
	let title: String

	init(environment: PhotoBrowserEnvironment, title: String = "Photos") {
		self.environment = environment
		self.title = title
		self._model = State(initialValue: Model())
	}

	var body: some View {
		PhotoCollectionViewRepresentable(
			photos: model.photos,
			selection: $model.selection,
			environment: environment,
			onItemTapped: { item in
				// Handle single tap - could show detail view
				print("[PhotoBrowser] Tapped item: \(item.displayName)")
			}
		)
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

			ToolbarItem(placement: .primaryAction) {
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
		} catch {
			print("[PhotoBrowser] Failed to load photos: \(error)")
			// TODO: Show error alert
		}
	}

	private func refresh() {
		Task {
			await loadPhotos()
		}
	}

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

extension PhotoBrowserView {
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