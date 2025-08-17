import CryptoKit
import Foundation
import SwiftUI
import AWSS3
import Photos

@MainActor
class S3BackupManager: ObservableObject {
	static let shared = S3BackupManager()

	@Published var isConfigured = false
	@Published var isUploading = false
	@Published var uploadProgress: Double = 0
	@Published var uploadStatus: String = ""
	@Published var currentUsage: Int64 = 0
	@Published var storageLimit: Int64 = 0

	var s3Service: S3BackupService?

	struct BackupStats {
		let totalFiles: Int
		let totalSize: Int64
	}

	var canBackup: Bool {
		IdentityManager.shared.isSignedIn && self.isConfigured
	}

	var userId: String? {
		let id = IdentityManager.shared.currentUser?.serviceUserID
		if id == nil {
			print("[S3BackupManager] userId computed property returning nil")
			print("[S3BackupManager] IdentityManager.shared: \(IdentityManager.shared)")
			print("[S3BackupManager] currentUser: \(String(describing: IdentityManager.shared.currentUser))")
		}
		return id
	}

	private init() {
		self.checkConfiguration()
	}

	func checkConfiguration() {
		Task {
			await self.initializeServiceIfNeeded()
		}
	}

	private func initializeServiceIfNeeded() async {
		// Reset configuration state
		self.isConfigured = false
		self.s3Service = nil
		
		do {
			// Try to initialize the S3 service
			// This will try keychain, env vars, and encrypted credentials in order
			self.s3Service = try await S3BackupService()
			self.isConfigured = true
			print("S3 service initialized successfully")
		} catch {
			print("Failed to initialize S3 service: \(error)")
			self.isConfigured = false
			
			// Log more details about the failure
			if let s3Error = error as? S3BackupError {
				switch s3Error {
				case .credentialsNotFound:
					print("No valid AWS credentials found in any source")
					print("Checked: Keychain, Environment variables, Encrypted credentials")
				default:
					print("S3 initialization error: \(s3Error.localizedDescription)")
				}
			}
		}
	}
	
	// Add a method to ensure service is initialized before use
	func ensureInitialized() async {
		if self.s3Service == nil {
			print("[S3BackupManager] S3 service not initialized, attempting initialization...")
			await self.initializeServiceIfNeeded()
			
			if self.s3Service != nil {
				print("[S3BackupManager] S3 service initialized successfully")
			} else {
				print("[S3BackupManager] Failed to initialize S3 service")
			}
		}
	}

	func uploadPhoto(_ photoRef: PhotoFile) async throws {
		// Check authentication
		guard let userId else {
			// Add detailed debugging
			print("[S3BackupManager] Upload failed - No userId available")
			print("[S3BackupManager] IdentityManager.isSignedIn: \(IdentityManager.shared.isSignedIn)")
			print("[S3BackupManager] IdentityManager.currentUser: \(String(describing: IdentityManager.shared.currentUser))")
			if let user = IdentityManager.shared.currentUser {
				print("[S3BackupManager] User details - serviceUserID: \(user.serviceUserID), provider: \(user.primaryProvider.rawValue)")
			}
			throw S3BackupError.notSignedIn
		}

		// Ensure S3 service is initialized
		try await self.ensureInitialized()

		// Check subscription limits
		let fileSize = try photoRef.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
		guard try await self.canUploadFile(size: Int64(fileSize)) else {
			throw S3BackupError.quotaExceeded
		}

		guard let s3Service else {
			throw S3BackupError.serviceNotConfigured
		}

		// Load photo data
		guard let data = try? Data(contentsOf: photoRef.fileURL) else {
			throw S3BackupError.uploadFailed
		}

		self.isUploading = true
		self.uploadStatus = "Uploading \(photoRef.filename)..."

		defer {
			isUploading = false
			uploadStatus = ""
		}

		// Upload photo
		let md5 = try await s3Service.uploadPhoto(data: data, userId: userId)

		// Generate and upload thumbnail
		if let thumbnail = try? await PhotoManager.shared.thumbnail(for: photoRef) {
			// Convert to data on main actor to avoid sendable warnings
			let thumbnailData = await MainActor.run {
				thumbnail.jpegData(compressionQuality: 0.8)
			}
			if let thumbnailData {
				try await s3Service.uploadThumbnail(data: thumbnailData, md5: md5, userId: userId)
			}
		}
		
		// Extract and upload metadata
		if let metadata = try? await PhotoManager.shared.metadata(for: photoRef) {
			try await s3Service.uploadMetadata(metadata, md5: md5, userId: userId)
		}

		print("Successfully uploaded: \(photoRef.filename)")
	}
	
	func uploadApplePhoto(_ photo: PhotoApple) async throws {
		// Check authentication
		guard let userId else {
			// Add detailed debugging
			print("[S3BackupManager] Apple Photo upload failed - No userId available")
			print("[S3BackupManager] IdentityManager.isSignedIn: \(IdentityManager.shared.isSignedIn)")
			print("[S3BackupManager] IdentityManager.currentUser: \(String(describing: IdentityManager.shared.currentUser))")
			if let user = IdentityManager.shared.currentUser {
				print("[S3BackupManager] User details - serviceUserID: \(user.serviceUserID), provider: \(user.primaryProvider.rawValue)")
			}
			throw S3BackupError.notSignedIn
		}
		
		// Ensure S3 service is initialized
		try await self.ensureInitialized()
		
		// Load photo data
		let data = try await photo.loadImageData()
		
		// Check subscription limits
		guard try await self.canUploadFile(size: Int64(data.count)) else {
			throw S3BackupError.quotaExceeded
		}
		
		guard let s3Service else {
			throw S3BackupError.serviceNotConfigured
		}
		
		self.isUploading = true
		self.uploadStatus = "Uploading \(photo.filename)..."
		
		defer {
			isUploading = false
			uploadStatus = ""
		}
		
		// Upload photo
		let md5 = try await s3Service.uploadPhoto(data: data, userId: userId)
		
		// Generate and upload thumbnail (using cached version if available)
		if let thumbnail = try? await PhotoManager.shared.thumbnail(for: photo) {
			// Convert to data on main actor to avoid sendable warnings
			let thumbnailData = await MainActor.run {
				thumbnail.jpegData(compressionQuality: 0.8)
			}
			if let thumbnailData {
				try await s3Service.uploadThumbnail(data: thumbnailData, md5: md5, userId: userId)
			}
		}
		
		// Extract and upload metadata (using cached version if available)
		let photoMetadata = try await PhotoManager.shared.metadata(for: photo)
		try await s3Service.uploadMetadata(photoMetadata, md5: md5, userId: userId)
		
		print("Successfully uploaded Apple Photo: \(photo.filename) with ID: \(photo.asset.localIdentifier)")
	}
	
	func deletePhoto(_ photoRef: PhotoFile) async throws {
		// Check authentication
		guard let userId else {
			throw S3BackupError.notSignedIn
		}
		
		guard let s3Service else {
			throw S3BackupError.serviceNotConfigured
		}
		
		// Get MD5 hash
		guard let md5 = photoRef.md5Hash else {
			// Need to compute MD5 if not available
			guard let data = try? Data(contentsOf: photoRef.fileURL) else {
				throw S3BackupError.uploadFailed
			}
			let computedMd5 = data.md5Digest.hexadecimalString
			try await s3Service.deletePhoto(md5: computedMd5, userId: userId)
			return
		}
		
		// Delete from S3
		try await s3Service.deletePhoto(md5: md5, userId: userId)
		print("Successfully deleted from S3: \(photoRef.filename)")
	}
	
	func deletePhotos(_ photoRefs: [PhotoFile]) async throws {
		// Check authentication
		guard let userId else {
			throw S3BackupError.notSignedIn
		}
		
		guard let s3Service else {
			throw S3BackupError.serviceNotConfigured
		}
		
		// Collect MD5 hashes
		var md5Hashes: [String] = []
		
		for photo in photoRefs {
			if let md5 = photo.md5Hash {
				md5Hashes.append(md5)
			} else {
				// Compute MD5 if not available
				if let data = try? Data(contentsOf: photo.fileURL) {
					let computedMd5 = data.md5Digest.hexadecimalString
					md5Hashes.append(computedMd5)
				}
			}
		}
		
		// Batch delete from S3
		if !md5Hashes.isEmpty {
			try await s3Service.deletePhotos(md5Hashes: md5Hashes, userId: userId)
			print("Successfully deleted \(md5Hashes.count) photos from S3")
		}
	}

	func uploadPhotos(_ photos: [PhotoFile]) async throws {
		let total = photos.count
		var completed = 0

		for photo in photos {
			try await self.uploadPhoto(photo)
			completed += 1
			self.uploadProgress = Double(completed) / Double(total)
		}

		self.uploadProgress = 0
	}

	func isPhotoBackedUp(_ photoRef: PhotoFile) async -> Bool {
		guard let s3Service,
		      let userId else { return false }

		// Calculate MD5 for the photo
		guard let data = try? Data(contentsOf: photoRef.fileURL) else { return false }
		let md5 = data.md5Digest.hexadecimalString

		// Check if exists in S3
		do {
			_ = try await s3Service.getPhotoInfo(md5: md5, userId: userId)
			return true
		} catch {
			return false
		}
	}

	// MARK: - Storage Management

	func updateStorageInfo() async {
		guard let user = IdentityManager.shared.currentUser else { return }

		let tier = user.subscription?.tier ?? .free
		self.storageLimit = tier.storageLimit

		// In production, this would query the backend
		// For now, calculate from S3
		if let userId, let s3Service {
			do {
				let photos = try await s3Service.listUserPhotos(userId: userId)
				self.currentUsage = photos.reduce(0) { $0 + $1.size }
			} catch {
				print("Failed to calculate usage: \(error)")
			}
		}
	}

	private func canUploadFile(size: Int64) async throws -> Bool {
		await self.updateStorageInfo()
		return (self.currentUsage + size) <= self.storageLimit
	}

	func getBackupStats() async -> BackupStats? {
		guard let userId,
		      let service = s3Service else { return nil }

		do {
			let photos = try await service.listUserPhotos(userId: userId)
			let totalSize = photos.reduce(0) { $0 + $1.size }
			return BackupStats(totalFiles: photos.count, totalSize: totalSize)
		} catch {
			print("Failed to get backup stats: \(error)")
			return nil
		}
	}

	func clearCache() {
		// Clear any cached data when signing out
		self.currentUsage = 0
		self.storageLimit = 0
	}
	
	// MARK: - Identity Management
	
	func createFolder(at path: String) async throws {
		guard let s3Service else {
			throw S3BackupError.serviceNotConfigured
		}
		
		// S3 doesn't need explicit folder creation, but we'll create a placeholder
		// to ensure the directory structure exists
		let folderKey = path.hasSuffix("/") ? path : path + "/"
		let placeholderKey = folderKey + ".keep"
		
		try await s3Service.uploadData(Data(), to: placeholderKey)
	}
	
	func uploadData(_ data: Data, to path: String) async throws {
		guard let s3Service else {
			throw S3BackupError.serviceNotConfigured
		}
		
		try await s3Service.uploadData(data, to: path)
	}
	
	/// Get the S3 client for catalog generation
	func getS3Client() async -> S3Client? {
		// Ensure we're configured
		if !isConfigured {
			await self.initializeServiceIfNeeded()
		}
		
		return s3Service?.s3Client
	}
}

