//
//  PhotoBrowserView.swift
//  Photolala
//
//  Pure view for displaying photos - no source management
//

import SwiftUI
import Combine

// MARK: - Browser Mode

enum PhotoBrowserMode {
	case standard  // Normal photo browsing
	case basket    // Basket view (no add operations)
}

struct PhotoBrowserView: View {
	// Immutable environment passed in from parent
	let environment: PhotoBrowserEnvironment
	let title: String
	let mode: PhotoBrowserMode

	// View state
	@State private var model = Model()
	@State private var settings = PhotoBrowserSettings()
	#if os(iOS)
	@State private var showBasketView = false
	#endif
	@State private var basketToast: BasketToast?

	// Optional callbacks
	let onItemTapped: ((PhotoBrowserItem) -> Void)?
	let onSelectionChanged: ((Set<PhotoBrowserItem>) -> Void)?

	init(environment: PhotoBrowserEnvironment,
	     title: String = "Photos",
	     mode: PhotoBrowserMode = .standard,
	     onItemTapped: ((PhotoBrowserItem) -> Void)? = nil,
	     onSelectionChanged: ((Set<PhotoBrowserItem>) -> Void)? = nil) {
		self.environment = environment
		self.title = title
		self.mode = mode
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

				// Context-specific basket actions
				if mode == .standard {
					// Standard mode: show add/remove basket actions
					if model.hasSelection {
						if selectionInBasket() {
							// Show remove button when selection is in basket
							Button(action: removeSelectionFromBasket) {
								HStack(spacing: 2) {
									Image(systemName: "basket")
									Image(systemName: "minus.circle.fill")
										.foregroundColor(.red)
								}
							}
							.buttonStyle(.plain)
							.help("Remove selected items from basket (⌥B)")
							.keyboardShortcut("b", modifiers: .option)
						} else {
							// Show add button when selection is not in basket (or mixed)
							Button(action: addSelectionToBasket) {
								HStack(spacing: 2) {
									Image(systemName: "basket")
									Image(systemName: "plus.circle.fill")
										.foregroundColor(.green)
								}
							}
							.buttonStyle(.plain)
							.help("Add selected items to basket (B)")
							.keyboardShortcut("b", modifiers: [])
						}
					}

					// Basket badge - only in standard mode
					BasketBadgeView()
				} else {
					// Basket mode: show batch actions and stats
					if model.hasSelection {
						// Remove from basket button
						Button(action: removeSelectionFromBasket) {
							Label("Remove", systemImage: "trash")
								.foregroundColor(.red)
						}
						.buttonStyle(.plain)
						.help("Remove selected items from basket (Delete)")
						.keyboardShortcut(.delete, modifiers: [])

						// Selection stats
						Text("\(model.selection.count) selected")
							.font(.caption)
							.foregroundColor(.secondary)
					}

					// Clear all button
					Button(action: clearBasket) {
						Label("Clear All", systemImage: "trash.fill")
							.foregroundColor(.red)
					}
					.buttonStyle(.plain)
					.help("Clear entire basket (⌘K)")
					.keyboardShortcut("k", modifiers: .command)
					.disabled(PhotoBasket.shared.isEmpty)
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
		.overlay(alignment: .bottom) {
			if let toast = basketToast {
				ToastView(toast: toast)
					.transition(.move(edge: .bottom).combined(with: .opacity))
					.animation(.spring(), value: basketToast)
					.onAppear {
						DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
							basketToast = nil
						}
					}
			}
		}
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

	// MARK: - Basket Actions

	private func addSelectionToBasket() {
		guard !model.selection.isEmpty else { return }

		// Get source context for all selected items
		for item in model.selection {
			let sourceType = getSourceType()
			var url: URL?
			var identifier: String?

			// Resolve source-specific context
			if let localSource = environment.source as? LocalPhotoSource {
				url = localSource.fileURL(for: item.id)
				identifier = url?.path ?? item.id
			} else if environment.source is S3PhotoSource {
				identifier = item.id // S3 key
			} else if environment.source is ApplePhotosSource {
				identifier = item.id // Asset identifier
			}

			// Add to basket with proper context
			PhotoBasket.shared.add(item, sourceType: sourceType, sourceIdentifier: identifier, url: url)
		}

		// Show toast
		basketToast = BasketToast(
			message: "Added \(model.selection.count) item\(model.selection.count == 1 ? "" : "s") to basket",
			type: .success
		)

		// Optional: Clear selection after adding
		// model.selection.removeAll()
	}

	private func removeSelectionFromBasket() {
		guard !model.selection.isEmpty else { return }

		let count = model.selection.count

		// Remove selected items from basket
		for item in model.selection {
			PhotoBasket.shared.remove(item.id)
		}

		// Show toast
		basketToast = BasketToast(
			message: "Removed \(count) item\(count == 1 ? "" : "s") from basket",
			type: .info
		)

		// In basket mode, update photos after removal
		if mode == .basket {
			Task {
				_ = try? await environment.source.loadPhotos()
			}
		}
	}

	private func clearBasket() {
		let count = PhotoBasket.shared.count
		PhotoBasket.shared.clear()

		// Show toast
		basketToast = BasketToast(
			message: "Cleared \(count) item\(count == 1 ? "" : "s") from basket",
			type: .info
		)

		// Update view
		Task {
			_ = try? await environment.source.loadPhotos()
		}
	}

	private func selectionInBasket() -> Bool {
		// Check if ALL selected items are in the basket
		// For mixed state, we show the add button (returns false)
		guard !model.selection.isEmpty else { return false }
		return model.selection.allSatisfy { PhotoBasket.shared.contains($0.id) }
	}

	private func getSourceType() -> PhotoSourceType {
		if environment.source is LocalPhotoSource {
			return .local
		} else if environment.source is S3PhotoSource {
			return .cloud
		} else if environment.source is ApplePhotosSource {
			return .applePhotos
		} else {
			return .local // Default
		}
	}

}

// MARK: - Toast Support

struct BasketToast: Equatable {
	let message: String
	let type: ToastType
	let id = UUID()

	enum ToastType {
		case success, info, warning
	}
}

struct ToastView: View {
	let toast: BasketToast

	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: icon)
				.foregroundColor(iconColor)

			Text(toast.message)
				.font(.callout)
				.foregroundColor(.primary)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 12)
		.background(
			RoundedRectangle(cornerRadius: 8)
				.fill(.regularMaterial)
				.shadow(color: .black.opacity(0.1), radius: 4, y: 2)
		)
		.padding()
	}

	private var icon: String {
		switch toast.type {
		case .success: return "checkmark.circle.fill"
		case .info: return "info.circle.fill"
		case .warning: return "exclamationmark.triangle.fill"
		}
	}

	private var iconColor: Color {
		switch toast.type {
		case .success: return .green
		case .info: return .blue
		case .warning: return .orange
		}
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