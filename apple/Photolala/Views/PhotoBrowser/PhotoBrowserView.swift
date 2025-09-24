//
//  PhotoBrowserView.swift
//  Photolala
//
//  Pure view for displaying photos - no source management
//

import SwiftUI
import Combine

struct PhotoBrowserView: View {
	// Immutable environment passed in from parent
	let environment: PhotoBrowserEnvironment
	let title: String

	// View state
	@State private var model = Model()
	@State private var settings = PhotoBrowserSettings()
	#if os(iOS)
	@State private var showBasketView = false
	#endif

	// Optional callbacks
	let onItemTapped: ((PhotoBrowserItem) -> Void)?
	let onSelectionChanged: ((Set<PhotoBrowserItem>) -> Void)?

	init(environment: PhotoBrowserEnvironment,
	     title: String = "Photos",
	     onItemTapped: ((PhotoBrowserItem) -> Void)? = nil,
	     onSelectionChanged: ((Set<PhotoBrowserItem>) -> Void)? = nil) {
		self.environment = environment
		self.title = title
		self.onItemTapped = onItemTapped
		self.onSelectionChanged = onSelectionChanged
	}

	var body: some View {
		ZStack {
			PhotoCollectionViewRepresentable(
				photos: model.photos,
				selection: $model.selection,
				environment: environment,
				settings: settings,
				onItemTapped: { item in
					onItemTapped?(item)
					print("[PhotoBrowser] Tapped item: \(item.displayName)")
				}
			)

			// Loading overlay for initial load
			if model.isLoading && model.photos.isEmpty {
				loadingOverlay
			}

			// Empty state
			if !model.isLoading && model.photos.isEmpty {
				emptyStateView
			}
		}
		.navigationTitle(title)
		#if os(macOS)
		.navigationSubtitle("\(model.photos.count) photos")
		#endif
		.toolbar {
			// Display settings controls
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

				// Fit/Fill toggle
				Button(action: {
					settings.displayMode = settings.displayMode == .fit ? .fill : .fit
				}) {
					Image(systemName: settings.displayMode == .fit
						? "rectangle.arrowtriangle.2.inward"
						: "rectangle.arrowtriangle.2.outward")
						.help(settings.displayMode == .fit ? "Switch to Fill" : "Switch to Fit")
				}
				.buttonStyle(.plain)

				// Info bar toggle
				Button(action: {
					settings.showInfoBar.toggle()
				}) {
					Image(systemName: settings.showInfoBar ? "square" : "inset.filled.bottomthird.square")
						.help(settings.showInfoBar ? "Hide Info Bar" : "Show Info Bar")
				}
				.buttonStyle(.plain)

				if model.isLoading {
					ProgressView()
						.scaleEffect(0.8)
				}

				// Basket badge
				BasketBadgeView()
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
		.onReceive(environment.source.photosPublisher) { newPhotos in
			withAnimation(.easeInOut(duration: 0.2)) {
				model.photos = newPhotos
			}
		}
		.onReceive(environment.source.isLoadingPublisher) { isLoading in
			model.isLoading = isLoading
		}
		.onChange(of: model.selection) { _, newSelection in
			onSelectionChanged?(newSelection)
		}
		#if os(iOS)
		.sheet(isPresented: $showBasketView) {
			NavigationStack {
				PhotoBasketHostView()
			}
		}
		#endif
	}

	// MARK: - UI Components

	@ViewBuilder
	private var loadingOverlay: some View {
		VStack(spacing: 20) {
			ProgressView()
				.scaleEffect(1.5)
			Text("Loading photos...")
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

	@ViewBuilder
	private var emptyStateView: some View {
		VStack(spacing: 20) {
			if environment.source is S3PhotoSource {
				// Cloud-specific empty state
				Image(systemName: "icloud.slash")
					.font(.system(size: 60))
					.foregroundColor(.secondary)
				Text("No Cloud Photos")
					.font(.title2)
					.bold()
				Text("Upload photos to the cloud to see them here")
					.foregroundColor(.secondary)
			} else {
				// Generic empty state
				Image(systemName: "photo.on.rectangle.angled")
					.font(.system(size: 60))
					.foregroundColor(.secondary)
				Text("No Photos")
					.font(.title2)
					.bold()
				Text("This location doesn't contain any photos")
					.foregroundColor(.secondary)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		#if os(macOS)
		.background(Color(NSColor.windowBackgroundColor).opacity(0.95))
		#else
		.background(Color(UIColor.systemBackground).opacity(0.95))
		#endif
	}

	// MARK: - Actions

	private func loadPhotos() async {
		model.isLoading = true
		defer { model.isLoading = false }

		do {
			let photos = try await environment.source.loadPhotos()
			withAnimation {
				model.photos = photos
			}
		} catch {
			print("[PhotoBrowser] Failed to load photos: \(error)")
			// Just log - let the parent handle errors if needed
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
}

// MARK: - View Model

extension PhotoBrowserView {
	@Observable
	final class Model {
		var photos: [PhotoBrowserItem] = []
		var selection = Set<PhotoBrowserItem>()
		var isLoading = false

		var hasSelection: Bool {
			!selection.isEmpty
		}

		var selectedCount: Int {
			selection.count
		}
	}
}