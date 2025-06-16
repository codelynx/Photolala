import PhotosUI
import SwiftUI

struct S3BackupTestView: View {
	@StateObject private var backupManager = S3BackupManager.shared
	@StateObject private var identityManager = IdentityManager.shared
	@StateObject private var iapManager = IAPManager.shared
	@State private var selectedPhoto: PhotosPickerItem?
	@State private var uploadStatus = ""
	@State private var isUploading = false
	@State private var uploadedPhotos: [PhotoEntry] = []
	@State private var showSignInPrompt = false
	@State private var showSubscriptionView = false
	@State private var currentStats: S3BackupManager.BackupStats?

	var body: some View {
		VStack(spacing: 20) {
			self.headerSection

			if self.identityManager.isSignedIn {
				self.userInfoSection
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
						await self.identityManager.signOut()
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

	private var uploadSection: some View {
		VStack(spacing: 16) {
			PhotosPicker(
				selection: self.$selectedPhoto,
				matching: .images
			) {
				Label("Select Photo to Backup", systemImage: "photo.badge.plus")
					.frame(maxWidth: .infinity)
					.frame(height: 50)
					.background(Color.blue)
					.foregroundColor(.white)
					.cornerRadius(10)
			}
			.disabled(self.isUploading)
			.onChange(of: self.selectedPhoto) { _, _ in
				Task {
					await self.uploadPhoto()
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
				Button("Refresh") {
					Task {
						await self.loadPhotos()
					}
				}
				.buttonStyle(.bordered)
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

	private func uploadPhoto() async {
		guard let selectedPhoto else { return }

		self.isUploading = true
		self.uploadStatus = "Loading photo..."

		do {
			// Load photo data
			guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
				self.uploadStatus = "Failed to load photo"
				self.isUploading = false
				return
			}

			self.uploadStatus = "Creating backup..."

			// Create a temporary photo reference
			let tempDir = FileManager.default.temporaryDirectory
			let tempURL = tempDir.appendingPathComponent("temp_photo.jpg")
			try data.write(to: tempURL)

			let photoRef = PhotoReference(
				directoryPath: tempDir.path as NSString,
				filename: "temp_photo.jpg"
			)

			// Upload using backup manager
			try await self.backupManager.uploadPhoto(photoRef)

			self.uploadStatus = "✅ Successfully backed up!"

			// Clean up temp file
			try? FileManager.default.removeItem(at: tempURL)

			// Refresh list and stats
			await self.loadPhotos()
			await self.loadUserData()

		} catch {
			if case S3BackupError.uploadFailed = error {
				self.uploadStatus = "❌ Storage quota exceeded. Please upgrade your plan."
				self.showSubscriptionView = true
			} else if case S3BackupError.credentialsNotFound = error {
				self.uploadStatus = "❌ Please sign in first"
				self.showSignInPrompt = true
			} else {
				self.uploadStatus = "❌ Error: \(error.localizedDescription)"
			}
		}

		self.isUploading = false
	}

	private func loadPhotos() async {
		guard self.identityManager.isSignedIn else { return }

		do {
			if let service = backupManager.s3Service {
				self.uploadedPhotos = try await service.listUserPhotosWithMetadata(
					userId: self.identityManager.currentUser?.serviceUserID ?? ""
				)
			}
		} catch {
			print("Failed to load photos: \(error)")
		}
	}

	private func loadUserData() async {
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
}

#Preview {
	S3BackupTestView()
}
