//
//  BackupQueueManager.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/06/18.
//

import Foundation
import SwiftUI
import CryptoKit

@MainActor
class BackupQueueManager: ObservableObject {
	static let shared = BackupQueueManager()
	
	@Published var queuedPhotos: Set<PhotoReference> = []
	@Published var backupStatus: [String: BackupState] = [:] // MD5 -> State
	@Published var isUploading = false
	@Published var uploadProgress: Double = 0.0
	
	// Activity timer
	private var inactivityTimer: Timer?
	private let inactivityInterval: TimeInterval = 600 // 10 minutes
	
	// Queue persistence
	private let queueStateKey = "BackupQueueState"
	
	private init() {
		restoreQueueState()
	}
	
	// MARK: - Queue Management
	
	func toggleStar(for photo: PhotoReference) {
		if queuedPhotos.contains(photo) {
			removeFromQueue(photo)
		} else {
			addToQueue(photo)
		}
		resetInactivityTimer()
	}
	
	func addToQueue(_ photo: PhotoReference) {
		queuedPhotos.insert(photo)
		// Ensure MD5 hash is computed
		if photo.md5Hash == nil {
			Task {
				await computeMD5(for: photo)
			}
		}
		if let md5 = photo.md5Hash, backupStatus[md5] == nil {
			backupStatus[md5] = .queued
		}
		saveQueueState()
		NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
	}
	
	func removeFromQueue(_ photo: PhotoReference) {
		queuedPhotos.remove(photo)
		if let md5 = photo.md5Hash, backupStatus[md5] == .queued {
			backupStatus[md5] = BackupState.none
		}
		saveQueueState()
		NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
	}
	
	func isQueued(_ photo: PhotoReference) -> Bool {
		queuedPhotos.contains(photo)
	}
	
	func backupState(for photo: PhotoReference) -> BackupState {
		guard let md5 = photo.md5Hash else { return BackupState.none }
		return backupStatus[md5] ?? BackupState.none
	}
	
	// MARK: - Timer Management
	
	private func resetInactivityTimer() {
		inactivityTimer?.invalidate()
		
		guard !queuedPhotos.isEmpty else { return }
		
		inactivityTimer = Timer.scheduledTimer(
			withTimeInterval: inactivityInterval,
			repeats: false
		) { _ in
			Task { @MainActor in
				await self.performAutoBackup()
			}
		}
	}
	
	// MARK: - Backup Operations
	
	func startManualBackup() async {
		await performBackup()
	}
	
	private func performAutoBackup() async {
		print("Auto-backup triggered after \(Int(inactivityInterval/60)) minutes of inactivity")
		await performBackup()
	}
	
	private func performBackup() async {
		guard !queuedPhotos.isEmpty else { return }
		guard !isUploading else { return }
		
		isUploading = true
		uploadProgress = 0.0
		
		// Update status bar visibility
		BackupStatusManager.shared.startUpload(totalPhotos: queuedPhotos.count)
		
		let photosToUpload = Array(queuedPhotos)
		var successCount = 0
		
		for (index, photo) in photosToUpload.enumerated() {
			// Update status
			if let md5 = photo.md5Hash {
				backupStatus[md5] = .uploading
				NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
			}
			BackupStatusManager.shared.updateProgress(
				uploadedPhotos: index,
				currentPhotoName: photo.filename
			)
			
			// Perform upload
			do {
				try await uploadPhoto(photo)
				if let md5 = photo.md5Hash {
					backupStatus[md5] = .uploaded
				}
				queuedPhotos.remove(photo)
				successCount += 1
				NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
			} catch {
				print("Failed to upload \(photo.filename): \(error)")
				if let md5 = photo.md5Hash {
					backupStatus[md5] = .failed
					NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
				}
			}
			
			// Update progress
			uploadProgress = Double(index + 1) / Double(photosToUpload.count)
		}
		
		// Generate catalog if any uploads succeeded
		if successCount > 0 {
			await generateCatalog()
		}
		
		// Cleanup
		isUploading = false
		BackupStatusManager.shared.completeUpload()
		saveQueueState()
		
		// Reset timer if there are still queued photos
		if !queuedPhotos.isEmpty {
			resetInactivityTimer()
		}
	}
	
	private func uploadPhoto(_ photo: PhotoReference) async throws {
		// S3BackupManager will check authentication internally
		try await S3BackupManager.shared.uploadPhoto(photo)
		print("Successfully uploaded \(photo.filename)")
	}
	
	private func generateCatalog() async {
		guard let userId = IdentityManager.shared.currentUser?.serviceUserID else { return }
		
		do {
			// Get S3 client from backup manager
			guard let s3Client = await S3BackupManager.shared.getS3Client() else {
				print("Failed to generate catalog: S3 client not configured")
				return
			}
			try await S3CatalogGenerator(s3Client: s3Client).generateAndUploadCatalog(for: userId)
			print("Catalog generated successfully")
		} catch {
			print("Failed to generate catalog: \(error)")
		}
	}
	
	// MARK: - MD5 Computation
	
	private func computeMD5(for photo: PhotoReference) async {
		do {
			let data = try Data(contentsOf: photo.fileURL)
			let digest = Insecure.MD5.hash(data: data)
			let md5String = digest.map { String(format: "%02hhx", $0) }.joined()
			await MainActor.run {
				photo.md5Hash = md5String
			}
		} catch {
			print("Failed to compute MD5 for \(photo.filename): \(error)")
		}
	}
	
	// MARK: - Persistence
	
	private func saveQueueState() {
		let state = QueueState(
			queuedPhotos: queuedPhotos.compactMap { $0.md5Hash },
			backupStatus: backupStatus,
			lastActivityTime: Date()
		)
		
		if let encoded = try? JSONEncoder().encode(state) {
			UserDefaults.standard.set(encoded, forKey: queueStateKey)
		}
	}
	
	func restoreQueueState() {
		guard let data = UserDefaults.standard.data(forKey: queueStateKey),
			  let state = try? JSONDecoder().decode(QueueState.self, from: data) else {
			return
		}
		
		// Restore backup status
		backupStatus = state.backupStatus
		
		// Note: We can't restore PhotoReference objects from just MD5
		// This would need to be enhanced to store more info or
		// cross-reference with PhotoManager
		
		// Calculate time since last activity
		let timeSinceActivity = Date().timeIntervalSince(state.lastActivityTime)
		let remainingTime = max(0, inactivityInterval - timeSinceActivity)
		
		// Restart timer if needed
		if remainingTime > 0 && !state.queuedPhotos.isEmpty {
			Timer.scheduledTimer(withTimeInterval: remainingTime, repeats: false) { _ in
				Task { @MainActor in
					await self.performAutoBackup()
				}
			}
		} else if !state.queuedPhotos.isEmpty {
			// Timer would have fired, start backup
			Task {
				await performAutoBackup()
			}
		}
	}
}

// MARK: - Supporting Types

private struct QueueState: Codable {
	let queuedPhotos: [String] // MD5 hashes
	let backupStatus: [String: BackupState]
	let lastActivityTime: Date
}

enum BackupError: LocalizedError {
	case notAuthenticated
	
	var errorDescription: String? {
		switch self {
		case .notAuthenticated:
			return "Please sign in to backup photos"
		}
	}
}