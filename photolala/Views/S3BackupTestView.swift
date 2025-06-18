import PhotosUI
import SwiftUI
import AWSS3

struct S3BackupTestView: View {
	@StateObject private var backupManager = S3BackupManager.shared
	@StateObject private var identityManager = IdentityManager.shared
	@StateObject private var iapManager = IAPManager.shared
	@State private var selectedPhoto: PhotosPickerItem?
	@State private var selectedPhotos: [PhotosPickerItem] = []
	@State private var uploadStatus = ""
	@State private var isUploading = false
	@State private var uploadedPhotos: [PhotoEntry] = []
	@State private var showSignInPrompt = false
	@State private var showSubscriptionView = false
	@State private var currentStats: S3BackupManager.BackupStats?
	@State private var isGeneratingCatalog = false
	@State private var catalogStatus = ""
	@State private var isGeneratingThumbnails = false
	
	// TESTING MODE: Allow hardcoded user for S3 testing
	private let isTestingMode = true
	private let testUserId = "test-s3-user-001"

	var body: some View {
		VStack(spacing: 20) {
			self.headerSection

			if self.identityManager.isSignedIn || self.isTestingMode {
				if self.identityManager.isSignedIn {
					self.userInfoSection
				} else if self.isTestingMode {
					self.testingModeSection
				}
				self.uploadSection
				Divider()
				self.uploadedPhotosSection
			} else {
				self.signInPromptSection
			}

			Spacer()
		}
		.padding()
		.frame(width: 700, height: 800)
		.sheet(isPresented: self.$showSignInPrompt) {
			SignInPromptView()
		}
		.sheet(isPresented: self.$showSubscriptionView) {
			SubscriptionView()
		}
		.task {
			// Ensure backup manager is configured
			self.backupManager.checkConfiguration()
			await self.loadUserData()
		}
	}

	private var headerSection: some View {
		VStack(spacing: 8) {
			Text("S3 Backup Service")
				.font(.largeTitle)
				.fontWeight(.bold)

			Text("Secure cloud backup for your photos")
				.font(.headline)
				.foregroundColor(.secondary)
		}
	}

	private var userInfoSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Image(systemName: "person.circle.fill")
					.font(.title)
					.foregroundColor(.accentColor)

				VStack(alignment: .leading) {
					Text(self.identityManager.currentUser?.fullName ?? "Photolala User")
						.font(.headline)
					Text(self.identityManager.currentUser?.email ?? "No email")
						.font(.caption)
						.foregroundColor(.secondary)
				}

				Spacer()

				Button("Sign Out") {
					Task {
						self.identityManager.signOut()
					}
				}
				.linkButtonStyle()
			}
			.padding()
			.background(Color.gray.opacity(0.1))
			.cornerRadius(12)

			// Storage usage
			if let stats = currentStats {
				HStack {
					VStack(alignment: .leading) {
						Text("Storage Used")
							.font(.caption)
							.foregroundColor(.secondary)
						Text(self.formatBytes(stats.totalSize))
							.font(.title3)
							.fontWeight(.semibold)
					}

					Spacer()

					VStack(alignment: .trailing) {
						Text("Photos Backed Up")
							.font(.caption)
							.foregroundColor(.secondary)
						Text("\(stats.totalFiles)")
							.font(.title3)
							.fontWeight(.semibold)
					}
				}
				.padding()
				.background(Color.accentColor.opacity(0.1))
				.cornerRadius(12)
			}

			// Subscription status
			HStack {
				VStack(alignment: .leading) {
					Text("Current Plan")
						.font(.caption)
						.foregroundColor(.secondary)
					Text(self.identityManager.currentUser?.subscription?.displayName ?? "Free (5GB)")
						.font(.headline)
				}

				Spacer()

				Button("Upgrade") {
					self.showSubscriptionView = true
				}
				.buttonStyle(.borderedProminent)
				.disabled(self.identityManager.currentUser?.subscription?.tier == .family)
			}
			.padding()
			.background(Color.blue.opacity(0.1))
			.cornerRadius(12)
		}
	}

	private var signInPromptSection: some View {
		VStack(spacing: 20) {
			Image(systemName: "icloud.slash")
				.font(.system(size: 60))
				.foregroundColor(.secondary)

			Text("Sign in to use backup service")
				.font(.title2)

			Button("Sign in with Apple") {
				self.showSignInPrompt = true
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
		}
		.padding(40)
	}
	
	private var testingModeSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Image(systemName: "testtube.2")
					.font(.title)
					.foregroundColor(.orange)

				VStack(alignment: .leading) {
					Text("Testing Mode")
						.font(.headline)
					Text("Using test user ID: \(self.testUserId)")
						.font(.caption)
						.foregroundColor(.secondary)
				}

				Spacer()
			}
			.padding()
			.background(Color.orange.opacity(0.1))
			.cornerRadius(12)
		}
	}

	private var uploadSection: some View {
		VStack(spacing: 16) {
			PhotosPicker(
				selection: self.$selectedPhotos,
				maxSelectionCount: 10,  // Allow multiple selection
				matching: .images
			) {
				Label("Select Photos to Backup (up to 10)", systemImage: "photo.badge.plus")
					.frame(maxWidth: .infinity)
					.frame(height: 50)
					.background(Color.blue)
					.foregroundColor(.white)
					.cornerRadius(10)
			}
			.disabled(self.isUploading)
			.onChange(of: self.selectedPhotos) { _, newPhotos in
				if !newPhotos.isEmpty {
					Task {
						await self.uploadPhotos()
					}
				}
			}

			if self.isUploading {
				HStack {
					ProgressView()
						.progressViewStyle(CircularProgressViewStyle())
					Text("Uploading...")
						.foregroundColor(.secondary)
				}
			}

			if !self.uploadStatus.isEmpty {
				Text(self.uploadStatus)
					.font(.caption)
					.foregroundColor(self.uploadStatus.contains("❌") ? .red : .green)
					.multilineTextAlignment(.center)
			}
		}
	}

	private var uploadedPhotosSection: some View {
		VStack(alignment: .leading) {
			HStack {
				Text("Your Backed Up Photos")
					.font(.headline)
				Spacer()
				Button("Generate Catalog") {
					Task {
						await self.generateCatalog()
					}
				}
				.buttonStyle(.borderedProminent)
				.disabled(self.isGeneratingCatalog)
				
				Button("Generate Thumbnails") {
					Task {
						await self.generateThumbnails()
					}
				}
				.buttonStyle(.bordered)
				.disabled(self.isGeneratingThumbnails)
				
				Button("Refresh") {
					Task {
						await self.loadPhotos()
					}
				}
				.buttonStyle(.bordered)
			}
			
			if !self.catalogStatus.isEmpty {
				Text(self.catalogStatus)
					.font(.caption)
					.foregroundColor(self.catalogStatus.contains("❌") ? .red : .green)
					.multilineTextAlignment(.center)
			}

			if self.uploadedPhotos.isEmpty {
				Text("No photos backed up yet")
					.foregroundColor(.secondary)
					.frame(maxWidth: .infinity, maxHeight: 200)
			} else {
				List(self.uploadedPhotos, id: \.md5) { photo in
					VStack(alignment: .leading, spacing: 4) {
						Text("MD5: \(photo.md5)")
							.font(.caption.monospaced())
						HStack {
							Text("Size: \(self.formatBytes(photo.size))")
							Text("•")
							Text("Storage: \(photo.storageClass)")
							Text("•")
							Text(photo.lastModified, style: .relative)
						}
						.font(.caption2)
						.foregroundColor(.secondary)
						
						// Show metadata if available
						if let metadata = photo.metadata {
							HStack {
								if let dimensions = metadata.dimensions {
									Label(dimensions, systemImage: "aspectratio")
								}
								if let camera = metadata.cameraInfo {
									Label(camera, systemImage: "camera")
								}
							}
							.font(.caption2)
							.foregroundColor(.blue)
						}
					}
					.padding(.vertical, 4)
				}
				.frame(maxHeight: 300)
			}
		}
		.padding()
	}

	private func uploadPhotos() async {
		guard !self.selectedPhotos.isEmpty else { return }

		self.isUploading = true
		self.uploadStatus = "Loading photos..."
		
		var successCount = 0
		var failCount = 0

		for (index, selectedPhoto) in self.selectedPhotos.enumerated() {
			do {
				// Load photo data
				guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
					failCount += 1
					continue
				}

				self.uploadStatus = "Uploading photo \(index + 1) of \(self.selectedPhotos.count)..."

				// For testing mode, upload directly to S3
				if self.isTestingMode {
					// Ensure backup manager is initialized
					guard await self.backupManager.getS3Client() != nil else {
						self.uploadStatus = "❌ S3 client not available"
						self.isUploading = false
						return
					}
					
					// Get S3 service from backup manager or create new one
					let s3Service: S3BackupService
					if let existingService = self.backupManager.s3Service {
						s3Service = existingService
					} else {
						s3Service = try await S3BackupService()
					}
					
					// Use test user ID or signed-in user ID
					let userId = self.identityManager.currentUser?.serviceUserID ?? self.testUserId
					
					// Upload photo with appropriate user ID
					let md5 = try await s3Service.uploadPhoto(data: data, userId: userId)
					
					// Generate and upload thumbnail
					if let image = XImage(data: data) {
						let thumbnailSize = CGSize(width: 512, height: 512)
						let thumbnail: XImage
						
						#if os(macOS)
						let imageSize = image.size
						let scale = min(thumbnailSize.width / imageSize.width, thumbnailSize.height / imageSize.height)
						let newSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
						
						thumbnail = NSImage(size: newSize)
						thumbnail.lockFocus()
						image.draw(in: NSRect(origin: .zero, size: newSize))
						thumbnail.unlockFocus()
						#else
						UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
						image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
						thumbnail = UIGraphicsGetImageFromCurrentImageContext()!
						UIGraphicsEndImageContext()
						#endif
						
						if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
							try await s3Service.uploadThumbnail(data: thumbnailData, md5: md5, userId: userId)
						}
					}
					
					successCount += 1
				} else {
					// Use normal flow for signed-in users
					// Create a temporary photo reference
					let tempDir = FileManager.default.temporaryDirectory
					let tempURL = tempDir.appendingPathComponent("temp_photo_\(index).jpg")
					try data.write(to: tempURL)

					let photoRef = PhotoReference(
						directoryPath: tempDir.path as NSString,
						filename: "temp_photo_\(index).jpg"
					)

					// Upload using backup manager
					try await self.backupManager.uploadPhoto(photoRef)
					
					// Clean up temp file
					try? FileManager.default.removeItem(at: tempURL)
					
					successCount += 1
				}

			} catch {
				print("Failed to upload photo \(index + 1): \(error)")
				failCount += 1
			}
		}
		
		if successCount > 0 && failCount == 0 {
			self.uploadStatus = "✅ Successfully backed up \(successCount) photo(s)!"
		} else if successCount > 0 && failCount > 0 {
			self.uploadStatus = "⚠️ Uploaded \(successCount) photo(s), \(failCount) failed"
		} else {
			self.uploadStatus = "❌ Failed to upload photos"
		}

		self.isUploading = false
		
		// Clear selection after upload
		self.selectedPhotos = []
		
		// Refresh list and stats
		await self.loadPhotos()
		await self.loadUserData()
	}

	private func loadPhotos() async {
		// For testing mode, allow loading without sign-in
		let userId: String
		if self.identityManager.isSignedIn {
			userId = self.identityManager.currentUser?.serviceUserID ?? ""
		} else if self.isTestingMode {
			userId = self.testUserId
		} else {
			return
		}

		do {
			if let service = backupManager.s3Service {
				// Load photos for the current user (signed-in or test)
				let photos = try await service.listUserPhotosWithMetadata(
					userId: userId
				)
				
				self.uploadedPhotos = photos
			}
		} catch {
			print("Failed to load photos: \(error)")
		}
	}

	private func loadUserData() async {
		// Skip stats for testing mode without sign-in
		if !self.identityManager.isSignedIn && self.isTestingMode {
			// Load photos only
			await self.loadPhotos()
			return
		}
		
		guard self.identityManager.isSignedIn else { return }

		// Load backup stats
		self.currentStats = await self.backupManager.getBackupStats()

		// Load photos
		await self.loadPhotos()

		// Ensure IAP products are loaded
		await self.iapManager.loadProducts()
	}

	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .binary
		return formatter.string(fromByteCount: bytes)
	}
	
	private func generateCatalog() async {
		self.isGeneratingCatalog = true
		self.catalogStatus = "Generating catalog..."
		
		do {
			// Use test user ID if in testing mode
			let userId: String
			if let signedInUserId = self.identityManager.currentUser?.serviceUserID {
				userId = signedInUserId
			} else if self.isTestingMode {
				userId = self.testUserId
			} else {
				self.catalogStatus = "❌ Not signed in"
				self.isGeneratingCatalog = false
				return
			}
			
			// Get S3 client from backup manager
			guard let s3Client = await backupManager.getS3Client() else {
				self.catalogStatus = "❌ S3 client not available"
				self.isGeneratingCatalog = false
				return
			}
			
			// Create catalog generator
			let generator = S3CatalogGenerator(s3Client: s3Client)
			
			// Generate and upload catalog
			self.catalogStatus = "Scanning S3 for photos..."
			try await generator.generateAndUploadCatalog(for: userId)
			
			self.catalogStatus = "✅ Catalog generated successfully!"
			
			// Refresh the photo list after a short delay
			try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
			self.catalogStatus = ""
			
		} catch {
			self.catalogStatus = "❌ Failed to generate catalog: \(error.localizedDescription)"
		}
		
		self.isGeneratingCatalog = false
	}
	
	private func generateThumbnails() async {
		self.isGeneratingThumbnails = true
		self.catalogStatus = "Generating thumbnails..."
		
		// Use test user ID if in testing mode
		let userId: String
		if let signedInUserId = self.identityManager.currentUser?.serviceUserID {
			userId = signedInUserId
		} else if self.isTestingMode {
			userId = self.testUserId
		} else {
			self.catalogStatus = "❌ User not signed in"
			self.isGeneratingThumbnails = false
			return
		}
		
		do {
			// Get S3 client
			guard let s3Client = await self.backupManager.getS3Client() else {
				self.catalogStatus = "❌ S3 client not initialized"
				self.isGeneratingThumbnails = false
				return
			}
			
			// Get backup service from manager
			guard let s3Service = self.backupManager.s3Service else {
				self.catalogStatus = "❌ Backup service not initialized"
				self.isGeneratingThumbnails = false
				return
			}
			
			// Use catalog generator to find photos (handles both old and new paths)
			let generator = S3CatalogGenerator(s3Client: s3Client)
			
			// Generate catalog to get photo entries
			let (_, shards) = try await generator.generateCatalog(for: userId)
			
			// Load catalog entries from shards
			var allEntries: [PhotolalaCatalogService.CatalogEntry] = []
			for (_, shardData) in shards {
				let entries = try await generator.parseShardEntries(from: shardData)
				allEntries.append(contentsOf: entries)
			}
			
			var successCount = 0
			var failCount = 0
			
			// Process each catalog entry
			for entry in allEntries {
				let md5 = entry.md5
				
				// Try to download photo from the correct user path
				// First try new path structure, then fall back to old path
				let photoKeys = [
					"photos/\(userId)/\(md5).dat",  // New path
					"users/\(userId)/photos/\(entry.filename)"  // Old path
				]
				
				var photoData: Data?
				
				for photoKey in photoKeys {
					do {
						// Try to download photo
						let getPhotoRequest = GetObjectInput(
							bucket: "photolala",
							key: photoKey
						)
					
					let photoResponse = try await s3Client.getObject(input: getPhotoRequest)
					guard let body = photoResponse.body else { continue }
					
					// Convert ByteStream to Data
					switch body {
					case .data(let data):
						photoData = data
					case .stream(let stream):
						var result = Data()
						while true {
							guard let chunk = try await stream.readAsync(upToCount: 65536) else {
								break
							}
							result.append(chunk)
						}
						photoData = result
					case .noStream:
						continue
					@unknown default:
						continue
					}
					
					// If we found the photo, break out of the key loop
					if photoData != nil {
						break
					}
				} catch {
					// Try next key
					continue
				}
			}
			
			// Process the photo if we found it
			if let data = photoData {
				do {
					
					// Create thumbnail
					guard let image = XImage(data: data) else {
						failCount += 1
						continue
					}
					
					// Generate thumbnail (512x512 max)
					let thumbnailSize = CGSize(width: 512, height: 512)
					let thumbnail: XImage
					
					#if os(macOS)
					let imageSize = image.size
					let scale = min(thumbnailSize.width / imageSize.width, thumbnailSize.height / imageSize.height)
					let newSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
					
					thumbnail = NSImage(size: newSize)
					thumbnail.lockFocus()
					image.draw(in: NSRect(origin: .zero, size: newSize))
					thumbnail.unlockFocus()
					#else
					UIGraphicsBeginImageContextWithOptions(thumbnailSize, false, 0.0)
					image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
					thumbnail = UIGraphicsGetImageFromCurrentImageContext()!
					UIGraphicsEndImageContext()
					#endif
					
					// Convert to JPEG data
					if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.8) {
						// Upload thumbnail
						try await s3Service.uploadThumbnail(data: thumbnailData, md5: md5, userId: userId)
						successCount += 1
						self.catalogStatus = "Generating thumbnails... (\(successCount)/\(allEntries.count))"
					} else {
						failCount += 1
					}
					
				} catch {
					print("Failed to generate thumbnail for \(md5): \(error)")
					failCount += 1
				}
			} else {
				// No photo data found for this entry
				print("No photo found for \(md5)")
				failCount += 1
			}
		}
		
		self.catalogStatus = "✅ Thumbnails generated: \(successCount) success, \(failCount) failed"
			
		} catch {
			self.catalogStatus = "❌ Failed: \(error.localizedDescription)"
		}
		
		self.isGeneratingThumbnails = false
	}
}

#Preview {
	S3BackupTestView()
}
