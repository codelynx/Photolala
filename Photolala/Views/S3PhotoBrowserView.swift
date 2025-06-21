import SwiftUI
import AWSS3
import UniformTypeIdentifiers

struct S3PhotoBrowserView: View {
	@State private var thumbnailSettings = ThumbnailDisplaySettings()
	@State private var selectedPhotos: [PhotoS3] = []
	@State private var showingPhotoDetail: PhotoS3?
	@State private var showingError = false
	@State private var errorMessage = ""
	@State private var isRefreshing = false
	@State private var showingInspector = false
	@StateObject private var photoProvider: S3PhotoProvider
	@StateObject private var identityManager = IdentityManager.shared
	
	// Computed property to ensure inspector gets PhotoItems
	private var inspectorSelection: [any PhotoItem] {
		selectedPhotos.map { $0 as any PhotoItem }
	}
	
	init() {
		// Initialize with the current user's ID or a placeholder
		let userId = IdentityManager.shared.currentUser?.serviceUserID ?? "pending"
		self._photoProvider = StateObject(wrappedValue: S3PhotoProvider(userId: userId))
	}
	
	var body: some View {
		NavigationStack {
			Group {
				if photoProvider.isLoading && photoProvider.photos.isEmpty {
					// Initial loading state
					VStack {
						ProgressView("Loading catalog...")
							.progressViewStyle(CircularProgressViewStyle())
						
						Text("Syncing with cloud storage")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				} else if photoProvider.photos.isEmpty {
					// Empty state
					ContentUnavailableView(
						"No Photos in Cloud",
						systemImage: "cloud",
						description: Text("Upload photos from your local library to see them here")
					)
				} else {
					// Use unified collection view
					UnifiedPhotoCollectionViewRepresentable(
						photoProvider: photoProvider,
						settings: $thumbnailSettings,
						onSelectPhoto: { photo, allPhotos in
							if let s3Photo = photo as? PhotoS3 {
								handlePhotoTap(s3Photo)
							}
						},
						onSelectionChanged: { photos in
							self.selectedPhotos = photos.compactMap { $0 as? PhotoS3 }
						}
					)
					.refreshable {
						await refreshCatalog()
					}
				}
			}
			.onAppear {
				Task {
					do {
						try await photoProvider.loadPhotos()
					} catch {
						errorMessage = error.localizedDescription
						showingError = true
					}
				}
			}
			.navigationTitle("Cloud Photos")
			#if os(macOS)
			.navigationSubtitle("\(photoProvider.photos.count) photos")
			#endif
			.photoBrowserToolbar(
				settings: $thumbnailSettings,
				showingInspector: $showingInspector,
				isRefreshing: isRefreshing,
				onRefresh: refreshCatalog
			) {
				ToolbarItemGroup(placement: .automatic) {
					// S3-specific items before core items
					
					// Offline indicator
					if let s3Provider = photoProvider as? S3PhotoProvider,
					   s3Provider.displaySubtitle.contains("Offline") {
						Label("Offline", systemImage: "wifi.slash")
							.foregroundColor(.orange)
					}
					
					// Selection count
					if !selectedPhotos.isEmpty {
						Text("\(selectedPhotos.count) selected")
							.foregroundColor(.secondary)
					}
				}
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
		#if os(macOS)
		.frame(minWidth: 600, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
		#endif
		.inspector(
			isPresented: $showingInspector,
			selection: inspectorSelection
		)
	}
	// MARK: - Actions
	
	private func handlePhotoTap(_ photo: PhotoS3) {
		// Show detail view
		showingPhotoDetail = photo
	}
	
	private func refreshCatalog() async {
		isRefreshing = true
		defer { isRefreshing = false }
		
		do {
			try await photoProvider.refresh()
		} catch {
			errorMessage = error.localizedDescription
			showingError = true
		}
	}
	
	private func downloadPhoto(_ photo: PhotoS3) async {
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
	private func photoContextMenu(for photo: PhotoS3) -> some View {
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
	@Published var photos: [PhotoS3] = []
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
			guard let userId = IdentityManager.shared.currentUser?.serviceUserID else {
				print("ERROR: No signed-in user")
				throw NSError(domain: "S3PhotoBrowser", code: 401, userInfo: [NSLocalizedDescriptionKey: "Please sign in to view cloud photos"])
			}
			
			print("Using signed-in userId: \(userId)")
			
			// Initialize sync service if needed
			if syncService == nil {
				// Get S3 client from backup manager (which has credentials)
				guard let s3Client = await S3BackupManager.shared.getS3Client() else {
					print("ERROR: S3 client not configured")
					throw NSError(domain: "S3PhotoBrowser", code: 500, userInfo: [NSLocalizedDescriptionKey: "S3 service not configured"])
				}
				syncService = try S3CatalogSyncService(s3Client: s3Client, userId: userId)
			}
			
			// Try to sync catalog (non-blocking)
			if let syncService = syncService {
				let synced = try await syncService.syncCatalogIfNeeded()
				isOfflineMode = !synced
				print("TESTING: S3 sync completed, offline mode: \(isOfflineMode)")
			} else {
				isOfflineMode = true
			}
			
			// Load from cached catalog
			if let syncService = syncService {
				catalogService = try await syncService.loadCachedCatalog()
				s3MasterCatalog = try await syncService.loadS3MasterCatalog()
				print("DEBUG: Loaded catalog service and master catalog")
			}
			
			// Build photo list from catalog
			guard let catalog = catalogService else { 
				print("DEBUG: No catalog service available")
				return 
			}
			
			let entries = try await catalog.loadAllEntries()
			print("DEBUG: Loaded \(entries.count) entries from catalog")
			
			photos = entries.map { entry in
				PhotoS3(
					from: entry,
					s3Info: s3MasterCatalog?.photos[entry.md5],
					userId: userId
				)
			}
			.sorted { $0.photoDate > $1.photoDate }
			
			print("DEBUG: Created \(photos.count) S3Photo objects")
			
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

