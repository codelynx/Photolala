import SwiftUI
import XPlatform

struct PhotoPreviewView: View {
	// Constants
	private let controlStripHeight: CGFloat = 44
	private let useNativeThumbnailStrip = true // Feature flag for testing

	let photos: [PhotoFile]
	let initialIndex: Int
	@Binding var isPresented: Bool

	@State private var currentIndex: Int
	@State private var zoomScale: CGFloat = 1.0
	@State private var offset: CGSize = .zero
	@State private var controlsTimer: Timer?
	@State private var currentImage: XImage?
	@State private var isLoadingImage = false
	@State private var imageLoadError: String?
	@State private var showThumbnailStrip = false
	@State private var isFullscreen = false
	@State private var showMetadataHUD = false
	@State private var currentMetadata: PhotoMetadata?
	@FocusState private var isFocused: Bool

	@Environment(\.dismiss) private var dismiss

	@ViewBuilder
	private func imageView(for image: XImage) -> some View {
		#if os(macOS)
			Image(nsImage: image)
				.resizable()
				.aspectRatio(contentMode: .fit)
		#else
			Image(uiImage: image)
				.resizable()
				.aspectRatio(contentMode: .fit)
		#endif
	}

	init(photos: [PhotoFile], initialIndex: Int, isPresented: Binding<Bool> = .constant(false)) {
		self.photos = photos
		self.initialIndex = initialIndex
		self._isPresented = isPresented
		self._currentIndex = State(initialValue: initialIndex)
	}

	var body: some View {
		GeometryReader { geometry in
			ZStack {
				// Background
				Color.black
					.ignoresSafeArea()
					.contentShape(Rectangle())
					.focusable()
					.focused(self.$isFocused)
					.onTapGesture {
						self.isFocused = true
					}

				// Image display
				if let image = currentImage {
					self.imageView(for: image)
						.scaleEffect(self.zoomScale)
						.offset(self.offset)
						.gesture(
							MagnificationGesture()
								.onChanged { value in
									self.zoomScale = value
								}
								.onEnded { value in
									withAnimation(.spring()) {
										self.zoomScale = min(max(value, 0.5), 5.0)
									}
								}
						)
						.simultaneousGesture(
							DragGesture()
								.onChanged { value in
									if self.zoomScale > 1 {
										self.offset = CGSize(
											width: self.offset.width + value.translation.width,
											height: self.offset.height + value.translation.height
										)
									}
								}
						)
						.gesture(
							TapGesture(count: 2)
								.onEnded { _ in
									withAnimation(.spring()) {
										if self.zoomScale > 1 {
											self.zoomScale = 1
											self.offset = .zero
										} else {
											self.zoomScale = 2
										}
									}
								}
						)
				} else if self.isLoadingImage {
					ProgressView()
						.progressViewStyle(CircularProgressViewStyle(tint: .white))
						.scaleEffect(1.5)
				} else if let error = imageLoadError {
					VStack(spacing: 16) {
						Image(systemName: "exclamationmark.triangle")
							.font(.system(size: 48))
							.foregroundColor(.white)
						Text("Failed to load image")
							.foregroundColor(.white)
						Text(error)
							.font(.caption)
							.foregroundColor(.gray)
					}
				}

				// Control strip at top
				if self.showThumbnailStrip {
					VStack(spacing: 0) {
						ControlStrip(
							currentIndex: self.currentIndex,
							totalCount: self.photos.count,
							filename: self.photos[self.currentIndex].filename,
							controlStripHeight: self.controlStripHeight,
							onClose: { self.dismiss() },
							onToggleFullscreen: self.toggleFullscreen,
							onToggleMetadata: {
								withAnimation(.easeInOut(duration: 0.2)) {
									self.showMetadataHUD.toggle()
								}
							},
							showMetadata: self.$showMetadataHUD
						)

						Spacer()
					}
					.transition(.move(edge: .top).combined(with: .opacity))
				}

				// Thumbnail strip at bottom
				if self.showThumbnailStrip {
					VStack {
						Spacer()

						if self.useNativeThumbnailStrip {
							// Native collection view implementation
							ThumbnailStripView(
								photos: self.photos,
								currentIndex: self.$currentIndex,
								thumbnailSize: CGSize(width: 60, height: 60),
								onTimerExtend: self.extendControlsTimer
							)
							.frame(height: 84) // 60 + 24 for padding
						} else {
							// Original SwiftUI implementation
							ThumbnailStrip(
								photos: self.photos,
								currentIndex: self.$currentIndex,
								thumbnailSize: CGSize(width: 60, height: 60),
								onTimerExtend: self.extendControlsTimer
							)
						}
					}
					.transition(.move(edge: .bottom).combined(with: .opacity))
				}

				// Metadata HUD
				if self.showMetadataHUD {
					MetadataHUD(
						photo: self.photos[self.currentIndex],
						metadata: self.currentMetadata,
						geometry: geometry, topMargin: self.controlStripHeight
					)
					.transition(.opacity)
				}
			}
			.contentShape(Rectangle())
			.onTapGesture { location in
				self.handleTapGesture(at: location, in: geometry)
			}
		}
		.onAppear {
			self.loadCurrentImage()
			// Add a small delay to ensure the view is fully loaded
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				self.isFocused = true
			}
		}
		.onDisappear {
			self.controlsTimer?.invalidate()
		}
		.onChange(of: self.currentIndex) {
			self.loadCurrentImage()
		}
		#if os(macOS)
		.onExitCommand {
			self.dismiss()
		}
		#endif
		.onKeyPress(.leftArrow) {
			self.navigateToPrevious()
			return .handled
		}
		.onKeyPress(.rightArrow) {
			self.navigateToNext()
			return .handled
		}
		.onKeyPress(keys: ["f"]) { _ in
			self.toggleFullscreen()
			return .handled
		}
		.onKeyPress(keys: ["t"]) { _ in
			print(
				"[PhotoPreviewView] Toggle thumbnail strip: \(!self.showThumbnailStrip), photos count: \(self.photos.count)"
			)
			withAnimation(.easeInOut(duration: 0.3)) {
				self.showThumbnailStrip.toggle()
			}
			// Reset timer when toggling
			if self.showThumbnailStrip {
				self.controlsTimer?.invalidate()
				self.controlsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
					withAnimation(.easeInOut(duration: 0.3)) {
						self.showThumbnailStrip = false
					}
				}
			} else {
				self.controlsTimer?.invalidate()
			}
			return .handled
		}
		.onKeyPress(.space) {
			// TODO: Implement slideshow play/pause
			print("Slideshow play/pause - not yet implemented")
			return .handled
		}
		.onKeyPress(keys: ["i"]) { _ in
			withAnimation(.easeInOut(duration: 0.2)) {
				self.showMetadataHUD.toggle()
			}
			return .handled
		}
		.onKeyPress(keys: ["?"]) { _ in
			// TODO: Show help overlay
			print("Help overlay - not yet implemented")
			return .handled
		}
		#if os(iOS)
		.gesture(
			DragGesture()
				.onEnded { value in
					let threshold: CGFloat = 50
					if value.translation.width > threshold, self.currentIndex > 0 {
						self.navigateToPrevious()
					} else if value.translation.width < -threshold, self.currentIndex < self.photos.count - 1 {
						self.navigateToNext()
					}
				}
		)
		.statusBarHidden(true)
		#endif
	}

	private func loadCurrentImage() {
		guard self.currentIndex >= 0, self.currentIndex < self.photos.count else {
			print("[PhotoPreviewView] Index out of bounds: \(self.currentIndex) for \(self.photos.count) photos")
			return
		}

		let photo = self.photos[self.currentIndex]
		print("[PhotoPreviewView] Loading image for: \(photo.filename) at index \(self.currentIndex)")
		self.isLoadingImage = true
		self.imageLoadError = nil
		self.currentImage = nil
		self.currentMetadata = nil

		Task {
			do {
				// Load image
				if let image = try await PhotoManagerV2.shared.loadFullImage(for: photo) {
					print("[PhotoPreviewView] Successfully loaded image: \(photo.filename)")
					await MainActor.run {
						self.currentImage = image
						self.isLoadingImage = false
						// Preload adjacent images after current image loads
						self.preloadAdjacentImages()
					}
				} else {
					print("[PhotoPreviewView] loadFullImage returned nil for: \(photo.filename)")
					await MainActor.run {
						self.imageLoadError = "Image could not be loaded"
						self.isLoadingImage = false
					}
				}

				// Load metadata (don't block on this)
				Task {
					if let metadata = try? await PhotoManagerV2.shared.metadata(for: photo) {
						await MainActor.run {
							self.currentMetadata = metadata
						}
					}
				}
			} catch {
				print("[PhotoPreviewView] Error loading image: \(error)")
				await MainActor.run {
					self.imageLoadError = error.localizedDescription
					self.isLoadingImage = false
				}
			}
		}
	}

	private func navigateToPrevious() {
		if self.currentIndex > 0 {
			self.currentIndex -= 1
			self.resetZoom()
		}
	}

	private func navigateToNext() {
		if self.currentIndex < self.photos.count - 1 {
			self.currentIndex += 1
			self.resetZoom()
		}
	}

	private func resetZoom() {
		withAnimation(.spring()) {
			self.zoomScale = 1.0
			self.offset = .zero
		}
	}

	private func toggleFullscreen() {
		#if os(macOS)
			if let window = NSApplication.shared.keyWindow {
				window.toggleFullScreen(nil)
				self.isFullscreen.toggle()
			}
		#endif
	}

	private func handleTapGesture(at location: CGPoint, in geometry: GeometryProxy) {
		let width = geometry.size.width
		let quarterWidth = width * 0.25

		// Define tap zones
		if location.x < quarterWidth {
			// Left quarter - navigate to previous
			if self.currentIndex > 0 {
				self.navigateToPrevious()
			}
		} else if location.x > width - quarterWidth {
			// Right quarter - navigate to next
			if self.currentIndex < self.photos.count - 1 {
				self.navigateToNext()
			}
		} else {
			// Center area (middle 50%) - toggle controls
			withAnimation(.easeInOut(duration: 0.3)) {
				self.showThumbnailStrip.toggle()
			}

			// Reset timer if showing controls
			if self.showThumbnailStrip {
				self.controlsTimer?.invalidate()
				self.controlsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
					withAnimation(.easeInOut(duration: 0.3)) {
						self.showThumbnailStrip = false
					}
				}
			} else {
				self.controlsTimer?.invalidate()
			}
		}
	}

	private func extendControlsTimer() {
		// Reset the timer when user interacts with thumbnails
		if self.showThumbnailStrip {
			self.controlsTimer?.invalidate()
			self.controlsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
				withAnimation(.easeInOut(duration: 0.3)) {
					self.showThumbnailStrip = false
				}
			}
		}
	}

	private func preloadAdjacentImages() {
		// Preload ±2 images from current
		var indicesToPreload: [Int] = []

		// Add previous images
		if self.currentIndex - 2 >= 0 { indicesToPreload.append(self.currentIndex - 2) }
		if self.currentIndex - 1 >= 0 { indicesToPreload.append(self.currentIndex - 1) }

		// Add next images
		if self.currentIndex + 1 < self.photos.count { indicesToPreload.append(self.currentIndex + 1) }
		if self.currentIndex + 2 < self.photos.count { indicesToPreload.append(self.currentIndex + 2) }

		let photosToPreload = indicesToPreload.map { self.photos[$0] }

		Task {
			await PhotoManagerV2.shared.prefetchImages(for: photosToPreload, priority: .low)
		}
	}
}

// MARK: - Control Strip

struct ControlStrip: View {
	let currentIndex: Int
	let totalCount: Int
	let filename: String
	let controlStripHeight: CGFloat
	let onClose: () -> Void
	let onToggleFullscreen: () -> Void
	let onToggleMetadata: () -> Void
	@Binding var showMetadata: Bool

	var body: some View {
		HStack(spacing: 16) {
			// Back/Close button
			Button(action: self.onClose) {
				Image(systemName: "chevron.left")
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(.white)
					.frame(width: self.controlStripHeight, height: self.controlStripHeight)
			}
			.buttonStyle(.plain)

			// Progress indicator
			Text("\(self.currentIndex + 1) / \(self.totalCount)")
				.font(.system(size: 14, weight: .medium))
				.foregroundColor(.white.opacity(0.8))
				.frame(minWidth: 60)

			// Filename
			Text(self.filename)
				.font(.system(size: 14, weight: .regular))
				.foregroundColor(.white)
				.lineLimit(1)
				.frame(maxWidth: .infinity)

			// Metadata toggle
			Button(action: self.onToggleMetadata) {
				Image(systemName: self.showMetadata ? "info.circle.fill" : "info.circle")
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(.white)
					.frame(width: self.controlStripHeight, height: self.controlStripHeight)
			}
			.buttonStyle(.plain)

			// Fullscreen toggle
			Button(action: self.onToggleFullscreen) {
				Image(systemName: "arrow.up.left.and.arrow.down.right")
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(.white)
					.frame(width: self.controlStripHeight, height: self.controlStripHeight)
			}
			.buttonStyle(.plain)
		}
		.padding(.horizontal, 16)
		.frame(height: self.controlStripHeight)
		.background(Color.black.opacity(0.8))
	}
}

// MARK: - Thumbnail Strip

// TODO: For large photo collections (1000+ photos), this LazyHStack approach
// still has performance limitations. Should be replaced with a native
// NSCollectionView (macOS) / UICollectionView (iOS) implementation with
// proper cell recycling, similar to PhotoCollectionViewController.
// This would require:
// - Creating a NSViewRepresentable/UIViewRepresentable wrapper
// - Implementing collection view with horizontal flow layout
// - Reusing cells for efficient memory usage
// - Proper prefetching delegates for smooth scrolling
// Current LazyHStack solution works well for moderate collections (<1000 photos)

struct ThumbnailStrip: View {
	let photos: [PhotoFile]
	@Binding var currentIndex: Int
	let thumbnailSize: CGSize
	let onTimerExtend: (() -> Void)?

	@State private var thumbnails: [Int: XImage] = [:]
	@Namespace private var namespace

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.horizontal, showsIndicators: false) {
				LazyHStack(spacing: 8) { // Changed from HStack to LazyHStack
					ForEach(self.photos.indices, id: \.self) { index in
						ThumbnailView(
							photo: self.photos[index],
							isSelected: index == self.currentIndex,
							size: self.thumbnailSize
						)
						.id(index)
						.onTapGesture {
							withAnimation(.easeInOut(duration: 0.3)) {
								self.currentIndex = index
							}
							self.onTimerExtend?()
						}
					}
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
			}
			.frame(height: self.thumbnailSize.height + 24)
			.background(Color.black.opacity(0.8))
			.onChange(of: self.currentIndex) {
				withAnimation {
					proxy.scrollTo(self.currentIndex, anchor: .center)
				}
			}
			.onAppear {
				print("[ThumbnailStrip] onAppear with \(self.photos.count) photos")
				// Scroll to current photo on appear
				DispatchQueue.main.async {
					proxy.scrollTo(self.currentIndex, anchor: .center)
				}
			}
		}
	}
}

struct ThumbnailView: View {
	let photo: PhotoFile
	let isSelected: Bool
	let size: CGSize

	@State private var thumbnail: XImage?
	@State private var loadTask: Task<Void, Never>?

	var body: some View {
		ZStack {
			if let thumbnail {
				#if os(macOS)
					Image(nsImage: thumbnail)
						.resizable()
						.aspectRatio(contentMode: .fill)
				#else
					Image(uiImage: thumbnail)
						.resizable()
						.aspectRatio(contentMode: .fill)
				#endif
			} else {
				// Placeholder
				Rectangle()
					.fill(Color.gray.opacity(0.3))

				ProgressView()
					.scaleEffect(0.5)
			}
		}
		.frame(width: self.size.width, height: self.size.height)
		.clipShape(RoundedRectangle(cornerRadius: 4))
		.overlay(
			RoundedRectangle(cornerRadius: 4)
				.stroke(
					self.isSelected ? Color.white : Color.gray.opacity(0.5),
					lineWidth: self.isSelected ? 3 : 1
				)
		)
		.scaleEffect(self.isSelected ? 1.1 : 1.0)
		.animation(.easeInOut(duration: 0.2), value: self.isSelected)
		.onAppear {
			// Check if thumbnail is already cached in the photo object
			if let cached = photo.thumbnail {
				self.thumbnail = cached
			} else {
				// Load thumbnail
				self.loadTask = Task {
					await self.loadThumbnail()
				}
			}
		}
		.onDisappear {
			// Cancel loading task when view disappears
			self.loadTask?.cancel()
			self.loadTask = nil
		}
	}

	private func loadThumbnail() async {
		print("[ThumbnailView] Loading thumbnail for: \(self.photo.filename)")
		do {
			// Check for cancellation
			if Task.isCancelled { return }

			if let thumb = try await PhotoManagerV2.shared.thumbnail(for: photo) {
				// Check for cancellation again after async operation
				if Task.isCancelled { return }

				print("[ThumbnailView] Loaded thumbnail for: \(self.photo.filename)")
				await MainActor.run {
					if !Task.isCancelled {
						self.thumbnail = thumb
					}
				}
			}
		} catch {
			if !Task.isCancelled {
				print("[ThumbnailView] Failed to load thumbnail for: \(self.photo.filename)")
			}
		}
	}
}

// MARK: - Metadata HUD

struct MetadataHUD: View {
	let photo: PhotoFile
	let metadata: PhotoMetadata?
	let geometry: GeometryProxy
	let topMargin: CGFloat

	private var dateFormatter: DateFormatter {
		let formatter = DateFormatter()
		formatter.dateStyle = .medium
		formatter.timeStyle = .medium
		return formatter
	}

	var body: some View {
		HStack {
			Spacer()

			VStack {
				Spacer()
					.frame(height: self.topMargin + 8) // Space from top to avoid toolbar

				VStack(alignment: .leading, spacing: 12) {
					// Filename
					HudRow(label: "Filename", value: self.photo.filename)

					Divider()
						.background(Color.white.opacity(0.3))

					// File info group
					if let metadata {
						if let dimensions = metadata.dimensions {
							HudRow(label: "Dimensions", value: dimensions)
						}

						HudRow(label: "File Size", value: metadata.formattedFileSize)

						HudRow(label: "Date", value: self.dateFormatter.string(from: metadata.displayDate))

						if let cameraInfo = metadata.cameraInfo {
							HudRow(label: "Camera", value: cameraInfo)
						}
					} else if let fileDate = photo.fileCreationDate {
						// Show file date if metadata not loaded yet
						HudRow(label: "Created", value: self.dateFormatter.string(from: fileDate))
					}
				}
				.padding(20)
				.background(
					RoundedRectangle(cornerRadius: 12)
						.fill(Color.black.opacity(0.75))
						.background(
							RoundedRectangle(cornerRadius: 12)
								.stroke(Color.white.opacity(0.2), lineWidth: 1)
						)
				)

				Spacer() // Push to center vertically
			}

			Spacer()
		}
		.padding(20)
	}
}

struct HudRow: View {
	let label: String
	let value: String

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			Text(self.label + ":")
				.font(.system(size: 14, weight: .medium))
				.foregroundColor(.white.opacity(0.7))
				.frame(width: 100, alignment: .trailing)

			Text(self.value)
				.font(.system(size: 14))
				.foregroundColor(.white)
				.frame(maxWidth: .infinity, alignment: .leading)
				.textSelection(.enabled)
		}
	}
}
