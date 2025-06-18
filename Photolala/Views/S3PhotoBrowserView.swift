import SwiftUI
import AWSS3
import UniformTypeIdentifiers

struct S3PhotoBrowserView: View {
	@StateObject private var viewModel = S3PhotoBrowserViewModel()
	@State private var thumbnailOption: ThumbnailOption = .medium
	@State private var selectedPhotos: Set<S3Photo> = []
	@State private var showingPhotoDetail: S3Photo?
	@State private var showingError = false
	@State private var errorMessage = ""
	@State private var isRefreshing = false
	
	var body: some View {
		NavigationStack {
			Group {
				if viewModel.isLoading && viewModel.photos.isEmpty {
					// Initial loading state
					VStack {
						ProgressView("Loading catalog...")
							.progressViewStyle(CircularProgressViewStyle())
						
						Text("Syncing with cloud storage")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				} else if viewModel.photos.isEmpty {
					// Empty state
					ContentUnavailableView(
						"No Photos in Cloud",
						systemImage: "cloud",
						description: Text("Upload photos from your local library to see them here")
					)
				} else {
					// Photo grid
					ScrollView {
						LazyVGrid(columns: adaptiveColumns, spacing: thumbnailOption.spacing) {
							ForEach(viewModel.photos) { photo in
								S3PhotoThumbnailView(
									photo: photo,
									thumbnailSize: thumbnailOption.size,
									isSelected: selectedPhotos.contains(photo)
								)
								.onTapGesture {
									handlePhotoTap(photo)
								}
								.contextMenu {
									photoContextMenu(for: photo)
								}
							}
						}
						.padding()
					}
					.refreshable {
						await refreshCatalog()
					}
				}
			}
			.navigationTitle("Cloud Photos")
			.navigationSubtitle("\(viewModel.photos.count) photos")
			.toolbar {
				ToolbarItemGroup(placement: .automatic) {
					// Offline indicator
					if viewModel.isOfflineMode {
						Label("Offline", systemImage: "wifi.slash")
							.foregroundColor(.orange)
					}
					
					// Selection count
					if !selectedPhotos.isEmpty {
						Text("\(selectedPhotos.count) selected")
							.foregroundColor(.secondary)
					}
					
					// Thumbnail size toggle
					Menu {
						ForEach(ThumbnailOption.allCases, id: \.self) { option in
							Button(action: {
								thumbnailOption = option
							}) {
								HStack {
									Text(option.name)
									if thumbnailOption == option {
										Image(systemName: "checkmark")
									}
								}
							}
						}
					} label: {
						Label("Thumbnail Size", systemImage: thumbnailSizeIcon)
					}
					
					// Refresh button
					Button(action: {
						Task {
							await refreshCatalog()
						}
					}) {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
					.disabled(isRefreshing)
				}
			}
			.task {
				await viewModel.loadPhotosFromCatalog()
			}
			.sheet(item: $showingPhotoDetail) { photo in
				S3PhotoDetailView(photo: photo)
			}
			.alert("Error", isPresented: $showingError) {
				Button("OK") { }
			} message: {
				Text(errorMessage)
			}
		}
	}
	
	// MARK: - Computed Properties
	
	private var adaptiveColumns: [GridItem] {
		return Array(repeating: GridItem(.adaptive(minimum: thumbnailOption.size)), count: 1)
	}
	
	private var thumbnailSizeIcon: String {
		switch thumbnailOption {
		case .small:
			return "square.grid.3x3"
		case .medium:
			return "square.grid.2x2"
		case .large:
			return "square"
		}
	}
	
	// MARK: - Actions
	
	private func handlePhotoTap(_ photo: S3Photo) {
		#if os(macOS)
		// macOS: Toggle selection
		if selectedPhotos.contains(photo) {
			selectedPhotos.remove(photo)
		} else {
			selectedPhotos.insert(photo)
		}
		#else
		// iOS: Show detail
		showingPhotoDetail = photo
		#endif
	}
	
	private func refreshCatalog() async {
		isRefreshing = true
		defer { isRefreshing = false }
		
		await viewModel.syncAndReload()
	}
	
	private func downloadPhoto(_ photo: S3Photo) async {
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
			errorMessage = "Download failed: \(error.localizedDescription)"
			showingError = true
		}
	}
	
	// MARK: - Context Menu
	
	@ViewBuilder
	private func photoContextMenu(for photo: S3Photo) -> some View {
		Button(action: {
			showingPhotoDetail = photo
		}) {
			Label("View Details", systemImage: "info.circle")
		}
		
		Divider()
		
		if photo.isArchived {
			Button(action: {
				// TODO: Implement restore from archive
			}) {
				Label("Restore from Archive", systemImage: "arrow.down.circle")
			}
		}
		
		Button(action: {
			Task {
				await downloadPhoto(photo)
			}
		}) {
			Label("Download", systemImage: "arrow.down.to.line")
		}
		
		Divider()
		
		Button(action: {
			#if os(macOS)
			NSPasteboard.general.clearContents()
			NSPasteboard.general.setString(photo.filename, forType: .string)
			#endif
		}) {
			Label("Copy Filename", systemImage: "doc.on.doc")
		}
	}
}

// MARK: - View Model

@MainActor
class S3PhotoBrowserViewModel: ObservableObject {
	@Published var photos: [S3Photo] = []
	@Published var isLoading = false
	@Published var isOfflineMode = false
	@Published var lastError: Error?
	
	private var catalogService: PhotolalaCatalogService?
	private var s3MasterCatalog: S3MasterCatalog?
	private var syncService: S3CatalogSyncService?
	
	func loadPhotosFromCatalog() async {
		isLoading = true
		defer { isLoading = false }
		
		do {
			// Get user ID from identity manager
			#if DEBUG
			// Use hardcoded test user ID for development
			let userId = "test-user-123"
			print("DEBUG: Using hardcoded userId: \(userId)")
			
			// Generate test catalog if needed
			try await TestCatalogGenerator.generateTestCatalog(userId: userId)
			#else
			guard let userId = IdentityManager.shared.currentUser?.serviceUserID else {
				throw S3BrowserError.noUserAuthenticated
			}
			#endif
			
			// Initialize sync service if needed
			if syncService == nil {
				let s3Client = try await S3Client()
				syncService = try S3CatalogSyncService(s3Client: s3Client, userId: userId)
			}
			
			// Try to sync catalog (non-blocking)
			if let syncService = syncService {
				let synced = try await syncService.syncCatalogIfNeeded()
				isOfflineMode = !synced
			} else {
				isOfflineMode = true
			}
			
			// Load from cached catalog
			if let syncService = syncService {
				catalogService = try await syncService.loadCachedCatalog()
				s3MasterCatalog = try await syncService.loadS3MasterCatalog()
			}
			
			// Build photo list from catalog
			guard let catalog = catalogService else { return }
			
			let entries = try await catalog.loadAllEntries()
			photos = entries.map { entry in
				S3Photo(
					from: entry,
					s3Info: s3MasterCatalog?.photos[entry.md5],
					userId: userId
				)
			}
			.sorted { $0.photoDate > $1.photoDate }
			
		} catch {
			lastError = error
			print("Failed to load S3 photos: \(error)")
			// Try to load from cached catalog anyway
			isOfflineMode = true
		}
	}
	
	func syncAndReload() async {
		guard let syncService = syncService else { return }
		
		do {
			_ = try await syncService.forceSync()
			await loadPhotosFromCatalog()
		} catch {
			lastError = error
			// Continue with cached data
		}
	}
}

// MARK: - Error Types

enum S3BrowserError: LocalizedError {
	case noUserAuthenticated
	case catalogMissing
	case syncFailed(Error)
	
	var errorDescription: String? {
		switch self {
		case .noUserAuthenticated:
			return "Please sign in to view cloud photos"
		case .catalogMissing:
			return "No cloud photo catalog found"
		case .syncFailed(let error):
			return "Sync failed: \(error.localizedDescription)"
		}
	}
}