import SwiftUI

struct S3PhotoDetailView: View {
	let photo: S3Photo
	@Environment(\.dismiss) private var dismiss
	@State private var fullImage: XImage?
	@State private var isLoadingImage = false
	@State private var loadError: Error?
	@State private var showingRestoreConfirmation = false
	
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
										Label("Download Original", systemImage: "arrow.down.to.line")
											.frame(maxWidth: .infinity)
									}
									.buttonStyle(.borderedProminent)
									.controlSize(.large)
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
			// TODO: Implement full image loading from S3
			// For now, just show an error
			throw S3PhotoError.notImplemented
		} catch {
			loadError = error
		}
	}
	
	private func downloadPhoto() async {
		// TODO: Implement photo download
		print("Download not implemented")
	}
	
	private func initiateRestore(expedited: Bool) async {
		// TODO: Implement archive restoration
		print("Restore not implemented - expedited: \(expedited)")
	}
}

enum S3PhotoError: LocalizedError {
	case notImplemented
	
	var errorDescription: String? {
		switch self {
		case .notImplemented:
			return "This feature is not yet implemented"
		}
	}
}