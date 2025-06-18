import SwiftUI
import UniformTypeIdentifiers

struct S3PhotoDetailView: View {
	let photo: S3Photo
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
			// Initialize S3 download service
			try await S3DownloadService.shared.initialize()
			
			// Download photo data
			let data = try await S3DownloadService.shared.downloadPhoto(for: photo)
			
			// Convert to image
			guard let image = XImage(data: data) else {
				throw S3PhotoError.invalidImageData
			}
			
			fullImage = image
		} catch {
			loadError = error
		}
	}
	
	private func downloadPhoto() async {
		isDownloading = true
		defer { isDownloading = false }
		
		do {
			// Initialize S3 download service
			try await S3DownloadService.shared.initialize()
			
			// Download photo data
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