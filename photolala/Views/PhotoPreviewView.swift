import SwiftUI

struct PhotoPreviewView: View {
	let photos: [PhotoReference]
	let initialIndex: Int
	@Binding var isPresented: Bool
	
	@State private var currentIndex: Int
	@State private var zoomScale: CGFloat = 1.0
	@State private var offset: CGSize = .zero
	@State private var showControls = true
	@State private var controlsTimer: Timer?
	@State private var currentImage: XImage?
	@State private var isLoadingImage = false
	@State private var imageLoadError: String?
	
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
						.gesture(
							TapGesture()
								.onEnded { _ in
									withAnimation {
										showControls.toggle()
									}
									resetControlsTimer()
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
				
				// Overlay controls
				if showControls {
					OverlayControls(
						currentIndex: currentIndex,
						totalCount: photos.count,
						canGoPrevious: currentIndex > 0,
						canGoNext: currentIndex < photos.count - 1,
						onClose: { dismiss() },
						onPrevious: navigateToPrevious,
						onNext: navigateToNext,
						onResetZoom: resetZoom
					)
					.transition(.opacity)
				}
			}
		}
		.onAppear {
			loadCurrentImage()
			resetControlsTimer()
		}
		.onDisappear {
			controlsTimer?.invalidate()
		}
		.onChange(of: currentIndex) { _ in
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
		
		Task {
			do {
				if let image = try await PhotoManager.shared.loadFullImage(for: photo) {
					print("[PhotoPreviewView] Successfully loaded image: \(photo.filename)")
					await MainActor.run {
						self.currentImage = image
						self.isLoadingImage = false
					}
				} else {
					print("[PhotoPreviewView] loadFullImage returned nil for: \(photo.filename)")
					await MainActor.run {
						self.imageLoadError = "Image could not be loaded"
						self.isLoadingImage = false
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
			resetControlsTimer()
		}
	}
	
	private func navigateToNext() {
		if currentIndex < photos.count - 1 {
			currentIndex += 1
			resetZoom()
			resetControlsTimer()
		}
	}
	
	private func resetZoom() {
		withAnimation(.spring()) {
			zoomScale = 1.0
			offset = .zero
		}
	}
	
	private func resetControlsTimer() {
		controlsTimer?.invalidate()
		showControls = true
		
		controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
			withAnimation {
				showControls = false
			}
		}
	}
}

// Overlay controls
struct OverlayControls: View {
	let currentIndex: Int
	let totalCount: Int
	let canGoPrevious: Bool
	let canGoNext: Bool
	let onClose: () -> Void
	let onPrevious: () -> Void
	let onNext: () -> Void
	let onResetZoom: () -> Void
	
	var body: some View {
		VStack {
			// Top bar
			HStack {
				// Close button
				Button(action: onClose) {
					Image(systemName: "xmark")
						.font(.title2)
						.foregroundColor(.white)
						.frame(width: 44, height: 44)
						.background(Color.black.opacity(0.5))
						.clipShape(Circle())
				}
				.buttonStyle(.plain)
				
				Spacer()
				
				// Photo counter
				Text("\(currentIndex + 1) of \(totalCount)")
					.foregroundColor(.white)
					.padding(.horizontal, 16)
					.padding(.vertical, 8)
					.background(Color.black.opacity(0.5))
					.clipShape(Capsule())
				
				Spacer()
				
				// Reset zoom button
				Button(action: onResetZoom) {
					Image(systemName: "arrow.up.left.and.arrow.down.right")
						.font(.title2)
						.foregroundColor(.white)
						.frame(width: 44, height: 44)
						.background(Color.black.opacity(0.5))
						.clipShape(Circle())
				}
				.buttonStyle(.plain)
			}
			.padding()
			
			Spacer()
			
			// Navigation controls
			HStack(spacing: 40) {
				// Previous button
				Button(action: onPrevious) {
					Image(systemName: "chevron.left")
						.font(.title)
						.foregroundColor(.white)
						.frame(width: 60, height: 60)
						.background(Color.black.opacity(0.5))
						.clipShape(Circle())
				}
				.buttonStyle(.plain)
				.disabled(!canGoPrevious)
				.opacity(canGoPrevious ? 1 : 0.3)
				
				// Next button
				Button(action: onNext) {
					Image(systemName: "chevron.right")
						.font(.title)
						.foregroundColor(.white)
						.frame(width: 60, height: 60)
						.background(Color.black.opacity(0.5))
						.clipShape(Circle())
				}
				.buttonStyle(.plain)
				.disabled(!canGoNext)
				.opacity(canGoNext ? 1 : 0.3)
			}
			.padding(.bottom, 50)
		}
	}
}