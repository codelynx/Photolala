import SwiftUI
import UniformTypeIdentifiers

struct S3PhotoDetailView: View {
	let photo: PhotoS3
	@Environment(\.dismiss) private var dismiss
	@State private var fullImage: XImage?
	@State private var isLoadingImage = false
	@State private var loadError: Error?
	@State private var showingRestoreConfirmation = false
	@State private var isDownloading = false
	@State private var downloadProgress: Double = 0
	
	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				// Image viewer
				GeometryReader { geometry in
					ZStack {
						Color.black
						
						if let image = fullImage {
							Image(xImage: image)
								.resizable()
								.aspectRatio(contentMode: .fit)
								.frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
						} else if isLoadingImage {
							VStack {
								ProgressView()
									.progressViewStyle(CircularProgressViewStyle())
									.scaleEffect(1.5)
								
								Text("Loading photo...")
									.foregroundColor(.white)
									.padding(.top)
							}
						} else if loadError != nil {
							VStack {
								Image(systemName: "exclamationmark.triangle")
									.font(.largeTitle)
									.foregroundColor(.yellow)
								
								Text("Failed to load photo")
									.foregroundColor(.white)
									.padding(.top)
								
								if photo.isArchived {
									Text("This photo is archived and needs to be restored first")
										.font(.caption)
										.foregroundColor(.gray)
										.multilineTextAlignment(.center)
										.padding(.horizontal)
										.padding(.top, 4)
								}
							}
						} else {
							// Placeholder
							Image(systemName: "photo")
								.font(.system(size: 100))
								.foregroundColor(.gray)
						}
					}
				}
				
				// Metadata panel
				ScrollView {
					VStack(alignment: .leading, spacing: 16) {
						// Basic info
						GroupBox("Photo Information") {
							LabeledContent("Filename", value: photo.filename)
							LabeledContent("Size", value: photo.formattedSize)
							LabeledContent("MD5", value: photo.md5)
								.font(.system(.caption, design: .monospaced))
							
							if let width = photo.width, let height = photo.height {
								LabeledContent("Dimensions", value: "\(width) × \(height)")
							}
							
							LabeledContent("Photo Date", value: photo.photoDate.formatted())
							LabeledContent("Modified", value: photo.modified.formatted())
						}
						
						// S3 info
						GroupBox("Cloud Storage") {
							LabeledContent("Storage Class", value: photo.storageClass.displayName)
							
							if let uploadDate = photo.uploadDate {
								LabeledContent("Uploaded", value: uploadDate.formatted())
							}
							
							if photo.isArchived {
								Label("Archived - Restore required to download", systemImage: "archivebox.fill")
									.foregroundColor(.orange)
									.font(.caption)
							}
							
							if let retrievalTime = photo.storageClass.retrievalTime {
								LabeledContent("Retrieval Time", value: retrievalTime)
									.font(.caption)
							}
						}
						
						// Actions
						GroupBox("Actions") {
							VStack(spacing: 12) {
								if photo.isArchived {
									Button(action: {
										showingRestoreConfirmation = true
									}) {
										Label("Restore from Archive", systemImage: "arrow.down.circle")
											.frame(maxWidth: .infinity)
									}
									.buttonStyle(.borderedProminent)
									.controlSize(.large)
								} else {
									Button(action: {
										Task {
											await downloadPhoto()
										}
									}) {
										if isDownloading {
											HStack {
												ProgressView()
													.scaleEffect(0.8)
												Text("Downloading...")
											}
											.frame(maxWidth: .infinity)
										} else {
											Label("Download Original", systemImage: "arrow.down.to.line")
												.frame(maxWidth: .infinity)
										}
									}
									.buttonStyle(.borderedProminent)
									.controlSize(.large)
									.disabled(isDownloading)
								}
								
								#if os(macOS)
								Button(action: {
									NSPasteboard.general.clearContents()
									NSPasteboard.general.setString(photo.md5, forType: .string)
								}) {
									Label("Copy MD5", systemImage: "doc.on.doc")
										.frame(maxWidth: .infinity)
								}
								.buttonStyle(.bordered)
								#endif
							}
						}
					}
					.padding()
				}
				.frame(maxHeight: 300)
			}
			.navigationTitle(photo.filename)
			#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
			#endif
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done") {
						dismiss()
					}
				}
			}
			.task {
				if !photo.isArchived {
					await loadFullImage()
				}
			}
			.alert("Restore from Archive", isPresented: $showingRestoreConfirmation) {
				Button("Standard (12-48 hours)", role: .none) {
					Task {
						await initiateRestore(expedited: false)
					}
				}
				Button("Expedited (1-5 hours)", role: .none) {
					Task {
						await initiateRestore(expedited: true)
					}
				}
				Button("Cancel", role: .cancel) {}
			} message: {
				Text("Choose restoration speed. Expedited retrieval incurs additional charges.")
			}
		}
		#if os(iOS)
		.presentationDetents([.large])
		#endif
	}
	
	private func loadFullImage() async {
		isLoadingImage = true
		defer { isLoadingImage = false }
		
		do {
			#if DEBUG
			// In debug mode, show a larger placeholder
			print("DEBUG: Would download full photo for \(photo.md5)")
			
			#if os(macOS)
			let size = NSSize(width: 800, height: 600)
			let image = NSImage(size: size)
			image.lockFocus()
			
			// Gradient background
			let gradient = NSGradient(colors: [.systemBlue, .systemPurple])
			gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)
			
			// Draw info
			let attributes: [NSAttributedString.Key: Any] = [
				.font: NSFont.systemFont(ofSize: 24),
				.foregroundColor: NSColor.white
			]
			let text = photo.filename
			let textSize = text.size(withAttributes: attributes)
			let textRect = NSRect(x: (size.width - textSize.width) / 2,
								  y: (size.height - textSize.height) / 2,
								  width: textSize.width,
								  height: textSize.height)
			text.draw(in: textRect, withAttributes: attributes)
			
			image.unlockFocus()
			fullImage = image
			#else
			// iOS placeholder
			let size = CGSize(width: 800, height: 600)
			let renderer = UIGraphicsImageRenderer(size: size)
			fullImage = renderer.image { context in
				let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
										  colors: [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor] as CFArray,
										  locations: nil)!
				context.cgContext.drawLinearGradient(gradient,
													 start: .zero,
													 end: CGPoint(x: size.width, y: size.height),
													 options: [])
			}
			#endif
			#else
			// Production: actually download from S3
			try await S3DownloadService.shared.initialize()
			let data = try await S3DownloadService.shared.downloadPhoto(for: photo)
			
			guard let image = XImage(data: data) else {
				throw S3PhotoError.invalidImageData
			}
			
			fullImage = image
			#endif
		} catch {
			loadError = error
		}
	}
	
	private func downloadPhoto() async {
		isDownloading = true
		defer { isDownloading = false }
		
		do {
			#if DEBUG
			// Simulate download in debug mode
			print("DEBUG: Simulating download for \(photo.filename)")
			
			// Simulate delay
			try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
			
			// Create test data
			let testString = "Test photo data for \(photo.filename)"
			let data = testString.data(using: .utf8)!
			
			#if os(macOS)
			let panel = NSSavePanel()
			panel.nameFieldStringValue = photo.filename
			panel.canCreateDirectories = true
			panel.allowedContentTypes = [.jpeg, .png, .heic]
			
			let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
			if response == .OK, let url = panel.url {
				try data.write(to: url)
				print("DEBUG: Saved test file to \(url.path)")
			}
			#endif
			#else
			// Production: actually download from S3
			try await S3DownloadService.shared.initialize()
			let data = try await S3DownloadService.shared.downloadPhoto(for: photo)
			
			// Save to Downloads folder
			#if os(macOS)
			let panel = NSSavePanel()
			panel.nameFieldStringValue = photo.filename
			panel.canCreateDirectories = true
			panel.allowedContentTypes = [.jpeg, .png, .heic]
			
			let response = await panel.beginSheetModal(for: NSApp.keyWindow!)
			if response == .OK, let url = panel.url {
				try data.write(to: url)
			}
			#else
			// On iOS, save to photo library
			guard let image = UIImage(data: data) else { return }
			UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
			#endif
			#endif
		} catch {
			print("Download failed: \(error)")
			loadError = error
		}
	}
	
	private func initiateRestore(expedited: Bool) async {
		// TODO: Implement archive restoration
		print("Restore not implemented - expedited: \(expedited)")
	}
}

enum S3PhotoError: LocalizedError {
	case notImplemented
	case invalidImageData
	
	var errorDescription: String? {
		switch self {
		case .notImplemented:
			return "This feature is not yet implemented"
		case .invalidImageData:
			return "The downloaded data is not a valid image"
		}
	}
}
