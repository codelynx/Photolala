import SwiftUI

struct PhotoPreviewView: View {
	// Constants
	private let controlStripHeight: CGFloat = 44
	
	let photos: [PhotoReference]
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
	
	init(photos: [PhotoReference], initialIndex: Int, isPresented: Binding<Bool> = .constant(false)) {
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
					.focused($isFocused)
					.onTapGesture {
						isFocused = true
					}
				
				// Image display
				if let image = currentImage {
					imageView(for: image)
						.scaleEffect(zoomScale)
						.offset(offset)
						.gesture(
							MagnificationGesture()
								.onChanged { value in
									zoomScale = value
								}
								.onEnded { value in
									withAnimation(.spring()) {
										zoomScale = min(max(value, 0.5), 5.0)
									}
								}
						)
						.simultaneousGesture(
							DragGesture()
								.onChanged { value in
									if zoomScale > 1 {
										offset = CGSize(
											width: offset.width + value.translation.width,
											height: offset.height + value.translation.height
										)
									}
								}
						)
						.gesture(
							TapGesture(count: 2)
								.onEnded { _ in
									withAnimation(.spring()) {
										if zoomScale > 1 {
											zoomScale = 1
											offset = .zero
										} else {
											zoomScale = 2
										}
									}
								}
						)
				} else if isLoadingImage {
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
				if showThumbnailStrip {
					VStack(spacing: 0) {
						ControlStrip(
							currentIndex: currentIndex,
							totalCount: photos.count,
							filename: photos[currentIndex].filename, controlStripHeight: self.controlStripHeight,
							onClose: { dismiss() },
							onToggleFullscreen: toggleFullscreen,
							onToggleMetadata: {
								withAnimation(.easeInOut(duration: 0.2)) {
									showMetadataHUD.toggle()
								}
							},
							showMetadata: $showMetadataHUD
						)
						
						Spacer()
					}
					.transition(.move(edge: .top).combined(with: .opacity))
				}
				
				// Thumbnail strip at bottom
				if showThumbnailStrip {
					VStack {
						Spacer()
						
						ThumbnailStrip(
							photos: photos,
							currentIndex: $currentIndex,
							thumbnailSize: CGSize(width: 60, height: 60),
							onTimerExtend: extendControlsTimer
						)
					}
					.transition(.move(edge: .bottom).combined(with: .opacity))
				}
				
				// Metadata HUD
				if showMetadataHUD {
					MetadataHUD(
						photo: photos[currentIndex],
						metadata: currentMetadata,
						geometry: geometry, topMargin: self.controlStripHeight
					)
					.transition(.opacity)
				}
			}
			.contentShape(Rectangle())
			.onTapGesture { location in
				handleTapGesture(at: location, in: geometry)
			}
		}
		.onAppear {
			loadCurrentImage()
			// Add a small delay to ensure the view is fully loaded
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				isFocused = true
			}
		}
		.onDisappear {
			controlsTimer?.invalidate()
		}
		.onChange(of: currentIndex) { _, _ in
			loadCurrentImage()
		}
#if os(macOS)
		.onExitCommand {
			dismiss()
		}
#endif
		.onKeyPress(.leftArrow) {
			navigateToPrevious()
			return .handled
		}
		.onKeyPress(.rightArrow) {
			navigateToNext()
			return .handled
		}
		.onKeyPress(keys: ["f"]) { _ in
			toggleFullscreen()
			return .handled
		}
		.onKeyPress(keys: ["t"]) { _ in
			print("[PhotoPreviewView] Toggle thumbnail strip: \(!showThumbnailStrip), photos count: \(photos.count)")
			withAnimation(.easeInOut(duration: 0.3)) {
				showThumbnailStrip.toggle()
			}
			// Reset timer when toggling
			if showThumbnailStrip {
				controlsTimer?.invalidate()
				controlsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
					withAnimation(.easeInOut(duration: 0.3)) {
						showThumbnailStrip = false
					}
				}
			} else {
				controlsTimer?.invalidate()
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
				showMetadataHUD.toggle()
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
					if value.translation.width > threshold && currentIndex > 0 {
						navigateToPrevious()
					} else if value.translation.width < -threshold && currentIndex < photos.count - 1 {
						navigateToNext()
					}
				}
		)
		.statusBarHidden(true)
#endif
	}
	
	private func loadCurrentImage() {
		guard currentIndex >= 0 && currentIndex < photos.count else { 
			print("[PhotoPreviewView] Index out of bounds: \(currentIndex) for \(photos.count) photos")
			return 
		}
		
		let photo = photos[currentIndex]
		print("[PhotoPreviewView] Loading image for: \(photo.filename) at index \(currentIndex)")
		isLoadingImage = true
		imageLoadError = nil
		currentImage = nil
		currentMetadata = nil
		
		Task {
			do {
				// Load image
				if let image = try await PhotoManager.shared.loadFullImage(for: photo) {
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
					if let metadata = try? await PhotoManager.shared.metadata(for: photo) {
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
		if currentIndex > 0 {
			currentIndex -= 1
			resetZoom()
		}
	}
	
	private func navigateToNext() {
		if currentIndex < photos.count - 1 {
			currentIndex += 1
			resetZoom()
		}
	}
	
	private func resetZoom() {
		withAnimation(.spring()) {
			zoomScale = 1.0
			offset = .zero
		}
	}
	
	private func toggleFullscreen() {
		#if os(macOS)
		if let window = NSApplication.shared.keyWindow {
			window.toggleFullScreen(nil)
			isFullscreen.toggle()
		}
		#endif
	}
	
	private func handleTapGesture(at location: CGPoint, in geometry: GeometryProxy) {
		let width = geometry.size.width
		let quarterWidth = width * 0.25
		
		// Define tap zones
		if location.x < quarterWidth {
			// Left quarter - navigate to previous
			if currentIndex > 0 {
				navigateToPrevious()
			}
		} else if location.x > width - quarterWidth {
			// Right quarter - navigate to next
			if currentIndex < photos.count - 1 {
				navigateToNext()
			}
		} else {
			// Center area (middle 50%) - toggle controls
			withAnimation(.easeInOut(duration: 0.3)) {
				showThumbnailStrip.toggle()
			}
			
			// Reset timer if showing controls
			if showThumbnailStrip {
				controlsTimer?.invalidate()
				controlsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
					withAnimation(.easeInOut(duration: 0.3)) {
						showThumbnailStrip = false
					}
				}
			} else {
				controlsTimer?.invalidate()
			}
		}
	}
	
	private func extendControlsTimer() {
		// Reset the timer when user interacts with thumbnails
		if showThumbnailStrip {
			controlsTimer?.invalidate()
			controlsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
				withAnimation(.easeInOut(duration: 0.3)) {
					showThumbnailStrip = false
				}
			}
		}
	}
	
	private func preloadAdjacentImages() {
		// Preload ±2 images from current
		var indicesToPreload: [Int] = []
		
		// Add previous images
		if currentIndex - 2 >= 0 { indicesToPreload.append(currentIndex - 2) }
		if currentIndex - 1 >= 0 { indicesToPreload.append(currentIndex - 1) }
		
		// Add next images
		if currentIndex + 1 < photos.count { indicesToPreload.append(currentIndex + 1) }
		if currentIndex + 2 < photos.count { indicesToPreload.append(currentIndex + 2) }
		
		let photosToPreload = indicesToPreload.map { photos[$0] }
		
		Task {
			await PhotoManager.shared.prefetchImages(for: photosToPreload, priority: .low)
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
			Button(action: onClose) {
				Image(systemName: "chevron.left")
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(.white)
					.frame(width: controlStripHeight, height: controlStripHeight)
			}
			.buttonStyle(.plain)
			
			// Progress indicator
			Text("\(currentIndex + 1) / \(totalCount)")
				.font(.system(size: 14, weight: .medium))
				.foregroundColor(.white.opacity(0.8))
				.frame(minWidth: 60)
			
			// Filename
			Text(filename)
				.font(.system(size: 14, weight: .regular))
				.foregroundColor(.white)
				.lineLimit(1)
				.frame(maxWidth: .infinity)
			
			// Metadata toggle
			Button(action: onToggleMetadata) {
				Image(systemName: showMetadata ? "info.circle.fill" : "info.circle")
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(.white)
					.frame(width: controlStripHeight, height: controlStripHeight)
			}
			.buttonStyle(.plain)
			
			// Fullscreen toggle
			Button(action: onToggleFullscreen) {
				Image(systemName: "arrow.up.left.and.arrow.down.right")
					.font(.system(size: 16, weight: .medium))
					.foregroundColor(.white)
					.frame(width: controlStripHeight, height: controlStripHeight)
			}
			.buttonStyle(.plain)
		}
		.padding(.horizontal, 16)
		.frame(height: controlStripHeight)
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
	let photos: [PhotoReference]
	@Binding var currentIndex: Int
	let thumbnailSize: CGSize
	let onTimerExtend: (() -> Void)?
	
	@State private var thumbnails: [Int: XImage] = [:]
	@Namespace private var namespace
	
	var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.horizontal, showsIndicators: false) {
				LazyHStack(spacing: 8) {  // Changed from HStack to LazyHStack
					ForEach(photos.indices, id: \.self) { index in
						ThumbnailView(
							photo: photos[index],
							isSelected: index == currentIndex,
							size: thumbnailSize
						)
						.id(index)
						.onTapGesture {
							withAnimation(.easeInOut(duration: 0.3)) {
								currentIndex = index
							}
							onTimerExtend?()
						}
					}
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
			}
			.frame(height: thumbnailSize.height + 24)
			.background(Color.black.opacity(0.8))
			.onChange(of: currentIndex) { _ in
				withAnimation {
					proxy.scrollTo(currentIndex, anchor: .center)
				}
			}
			.onAppear {
				print("[ThumbnailStrip] onAppear with \(photos.count) photos")
				// Scroll to current photo on appear
				DispatchQueue.main.async {
					proxy.scrollTo(currentIndex, anchor: .center)
				}
			}
		}
	}
}

struct ThumbnailView: View {
	let photo: PhotoReference
	let isSelected: Bool
	let size: CGSize
	
	@State private var thumbnail: XImage?
	@State private var loadTask: Task<Void, Never>?
	
	var body: some View {
		ZStack {
			if let thumbnail = thumbnail {
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
		.frame(width: size.width, height: size.height)
		.clipShape(RoundedRectangle(cornerRadius: 4))
		.overlay(
			RoundedRectangle(cornerRadius: 4)
				.stroke(isSelected ? Color.white : Color.gray.opacity(0.5), 
						lineWidth: isSelected ? 3 : 1)
		)
		.scaleEffect(isSelected ? 1.1 : 1.0)
		.animation(.easeInOut(duration: 0.2), value: isSelected)
		.onAppear {
			// Check if thumbnail is already cached in the photo object
			if let cached = photo.thumbnail {
				self.thumbnail = cached
			} else {
				// Load thumbnail
				loadTask = Task {
					await loadThumbnail()
				}
			}
		}
		.onDisappear {
			// Cancel loading task when view disappears
			loadTask?.cancel()
			loadTask = nil
		}
	}
	
	private func loadThumbnail() async {
		print("[ThumbnailView] Loading thumbnail for: \(photo.filename)")
		do {
			// Check for cancellation
			if Task.isCancelled { return }
			
			if let thumb = try await PhotoManager.shared.thumbnail(for: photo) {
				// Check for cancellation again after async operation
				if Task.isCancelled { return }
				
				print("[ThumbnailView] Loaded thumbnail for: \(photo.filename)")
				await MainActor.run {
					if !Task.isCancelled {
						self.thumbnail = thumb
					}
				}
			}
		} catch {
			if !Task.isCancelled {
				print("[ThumbnailView] Failed to load thumbnail for: \(photo.filename)")
			}
		}
	}
}


// MARK: - Metadata HUD

struct MetadataHUD: View {
	let photo: PhotoReference
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
					.frame(height: topMargin + 8) // Space from top to avoid toolbar
				
				VStack(alignment: .leading, spacing: 12) {
					// Filename
					HudRow(label: "Filename", value: photo.filename)
					
					Divider()
						.background(Color.white.opacity(0.3))
					
					// File info group
					if let metadata = metadata {
						if let dimensions = metadata.dimensions {
							HudRow(label: "Dimensions", value: dimensions)
						}
						
						HudRow(label: "File Size", value: metadata.formattedFileSize)
						
						HudRow(label: "Date", value: dateFormatter.string(from: metadata.displayDate))
						
						if let cameraInfo = metadata.cameraInfo {
							HudRow(label: "Camera", value: cameraInfo)
						}
					} else if let fileDate = photo.fileModificationDate {
						// Show file date if metadata not loaded yet
						HudRow(label: "Modified", value: dateFormatter.string(from: fileDate))
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
			Text(label + ":")
				.font(.system(size: 14, weight: .medium))
				.foregroundColor(.white.opacity(0.7))
				.frame(width: 100, alignment: .trailing)
			
			Text(value)
				.font(.system(size: 14))
				.foregroundColor(.white)
				.frame(maxWidth: .infinity, alignment: .leading)
				.textSelection(.enabled)
		}
	}
}
