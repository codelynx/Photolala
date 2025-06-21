import CryptoKit
import Foundation
import SwiftUI
import AWSS3

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
		IdentityManager.shared.currentUser?.serviceUserID
	}

	private init() {
		self.checkConfiguration()
	}

	func checkConfiguration() {
		self.isConfigured = KeychainManager.shared.hasAWSCredentials()
		if self.isConfigured {
			Task {
				await self.initializeService()
			}
		}
	}

	private func initializeService() async {
		do {
			self.s3Service = try await S3BackupService()
			print("S3 service initialized successfully")
		} catch {
			print("Failed to initialize S3 service: \(error)")
			self.isConfigured = false
		}
	}

	func uploadPhoto(_ photoRef: PhotoFile) async throws {
		// Check authentication
		guard let userId else {
			throw S3BackupError.notSignedIn
		}

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
	
	/// Get the S3 client for catalog generation
	func getS3Client() async -> S3Client? {
		// Ensure we're configured
		if !isConfigured {
			await self.initializeService()
		}
		
		return s3Service?.s3Client
	}
}

// MARK: - Updated Error Types

extension S3BackupError {
	static let notSignedIn = S3BackupError.credentialsNotFound
	static let serviceNotConfigured = S3BackupError.credentialsNotFound
	static let quotaExceeded = S3BackupError.uploadFailed
}
