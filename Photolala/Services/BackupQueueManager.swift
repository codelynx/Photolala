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

	@Published var queuedPhotos: Set<PhotoFile> = []
	@Published var backupStatus: [String: BackupState] = [:] // MD5 -> State
	@Published var isUploading = false
	@Published var uploadProgress: Double = 0.0
	
	// Path to MD5 mapping for persistence
	private var pathToMD5: [String: String] = [:] // filepath -> MD5

	// Activity timer
	private var inactivityTimer: Timer?
	#if DEBUG
	private let inactivityInterval: TimeInterval = 30 // 1 minutes for development
	#else
	private let inactivityInterval: TimeInterval = 300 // 5 minutes for production
	#endif

	// Queue persistence
	private let queueStateKey = "BackupQueueState"

	private init() {
		restoreQueueState()
	}

	// MARK: - Queue Management

	func toggleStar(for photo: PhotoFile) {
		// Check current backup status
		let currentStatus = photo.md5Hash != nil ? backupStatus[photo.md5Hash!] : nil
		
		if currentStatus == .queued || currentStatus == .uploaded {
			// Remove from backup (both queued and uploaded states)
			removeFromQueue(photo)
			if let md5 = photo.md5Hash {
				backupStatus[md5] = .none
			}
		} else {
			// Add to backup queue
			addToQueue(photo)
		}
		resetInactivityTimer()
	}

	func addToQueue(_ photo: PhotoFile) {
		print("[BackupQueueManager] Adding to queue: \(photo.filename)")
		queuedPhotos.insert(photo)
		// Ensure MD5 hash is computed
		if photo.md5Hash == nil {
			print("[BackupQueueManager] MD5 hash is nil, computing...")
			Task {
				await computeMD5(for: photo)
				// Update status after MD5 is computed
				if let md5 = photo.md5Hash {
					print("[BackupQueueManager] MD5 computed: \(md5)")
					await MainActor.run {
						backupStatus[md5] = .queued
						pathToMD5[photo.filePath] = md5
						saveQueueState()
						NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
					}
				}
			}
		} else if let md5 = photo.md5Hash {
			print("[BackupQueueManager] Using existing MD5: \(md5)")
			backupStatus[md5] = .queued
			pathToMD5[photo.filePath] = md5
		}
		saveQueueState()
		NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
	}

	func removeFromQueue(_ photo: PhotoFile) {
		print("[BackupQueueManager] Removing from queue: \(photo.filename)")
		queuedPhotos.remove(photo)
		if let md5 = photo.md5Hash, backupStatus[md5] == .queued {
			print("[BackupQueueManager] Removing MD5 from status: \(md5)")
			backupStatus[md5] = BackupState.none
		} else {
			print("[BackupQueueManager] No MD5 hash to remove")
		}
		saveQueueState()
		NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
	}

	func isQueued(_ photo: PhotoFile) -> Bool {
		queuedPhotos.contains(photo)
	}

	func backupState(for photo: PhotoFile) -> BackupState {
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

	private func uploadPhoto(_ photo: PhotoFile) async throws {
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

	private func computeMD5(for photo: PhotoFile) async {
		do {
			let data = try Data(contentsOf: photo.fileURL)
			let digest = Insecure.MD5.hash(data: data)
			let md5String = digest.map { String(format: "%02hhx", $0) }.joined()
			await MainActor.run {
				photo.md5Hash = md5String
				// Store path to MD5 mapping
				pathToMD5[photo.filePath] = md5String
			}
		} catch {
			print("Failed to compute MD5 for \(photo.filename): \(error)")
		}
	}
	
	// Public method to get backup status, computing MD5 if needed
	func getBackupStatus(for photo: PhotoFile) async -> BackupState? {
		// If MD5 already computed, return status immediately
		if let md5 = photo.md5Hash {
			return backupStatus[md5]
		}
		
		// Otherwise compute MD5 first
		await computeMD5(for: photo)
		
		// Now check status
		if let md5 = photo.md5Hash {
			return backupStatus[md5]
		}
		
		return nil
	}
	
	// Match loaded photos with restored backup status
	func matchPhotosWithBackupStatus(_ photos: [PhotoFile]) async {
		print("[BackupQueueManager] Matching \(photos.count) photos with backup status")
		print("[BackupQueueManager] Current backup status contains \(backupStatus.count) entries")
		print("[BackupQueueManager] Path to MD5 mapping contains \(pathToMD5.count) entries")
		
		var matchedCount = 0
		var computedCount = 0
		
		for photo in photos {
			// First check if we have a saved MD5 for this path
			if let savedMD5 = pathToMD5[photo.filePath] {
				photo.md5Hash = savedMD5
				if let status = backupStatus[savedMD5] {
					print("[BackupQueueManager] Restored from path mapping: \(photo.filename) -> \(status)")
					matchedCount += 1
					
					// If it was queued, add back to queue
					if status == .queued {
						await MainActor.run {
							queuedPhotos.insert(photo)
						}
					}
				}
				continue
			}
			
			// Skip if already has MD5
			if photo.md5Hash != nil { 
				// Check if this already-computed photo has backup status
				if let status = backupStatus[photo.md5Hash!] {
					print("[BackupQueueManager] Already has MD5: \(photo.filename) -> \(status)")
					matchedCount += 1
				}
				continue 
			}
			
			// Compute MD5
			await computeMD5(for: photo)
			computedCount += 1
			
			// Check if this photo has backup status
			if let md5 = photo.md5Hash, let status = backupStatus[md5] {
				print("[BackupQueueManager] Matched \(photo.filename) (MD5: \(md5)) -> \(status)")
				matchedCount += 1
				
				// If it was queued, add back to queue
				if status == .queued {
					await MainActor.run {
						queuedPhotos.insert(photo)
					}
				}
			}
		}
		
		print("[BackupQueueManager] Matching complete: computed \(computedCount) MD5s, matched \(matchedCount) photos")
		
		// Notify UI to refresh
		await MainActor.run {
			NotificationCenter.default.post(name: NSNotification.Name("BackupQueueChanged"), object: nil)
		}
	}

	// MARK: - Persistence

	private func saveQueueState() {
		let state = QueueState(
			queuedPhotos: queuedPhotos.compactMap { $0.md5Hash },
			backupStatus: backupStatus,
			lastActivityTime: Date(),
			pathToMD5: pathToMD5
		)

		if let encoded = try? JSONEncoder().encode(state) {
			UserDefaults.standard.set(encoded, forKey: queueStateKey)
			print("[BackupQueueManager] Saved queue state with \(backupStatus.count) backup statuses and \(pathToMD5.count) path mappings")
			// Log first few entries for debugging
			for (index, (md5, status)) in backupStatus.enumerated().prefix(3) {
				print("[BackupQueueManager]   \(md5): \(status)")
			}
		}
	}

	func restoreQueueState() {
		guard let data = UserDefaults.standard.data(forKey: queueStateKey),
			  let state = try? JSONDecoder().decode(QueueState.self, from: data) else {
			print("[BackupQueueManager] No saved queue state found")
			return
		}

		// Restore backup status
		backupStatus = state.backupStatus
		print("[BackupQueueManager] Restored backup status with \(backupStatus.count) entries")
		for (md5, status) in backupStatus {
			print("[BackupQueueManager] Restored: \(md5) -> \(status)")
		}
		
		// Restore path to MD5 mapping
		if let savedPathToMD5 = state.pathToMD5 {
			pathToMD5 = savedPathToMD5
			print("[BackupQueueManager] Restored path to MD5 mapping with \(pathToMD5.count) entries")
		}

		// Note: We can't restore PhotoFile objects from just MD5
		// This would need to be enhanced to store more info or
		// cross-reference with PhotoManager
		
		// Store MD5s that need matching
		NotificationCenter.default.post(
			name: NSNotification.Name("BackupStatusRestored"), 
			object: nil,
			userInfo: ["md5List": Array(backupStatus.keys)]
		)

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
	let pathToMD5: [String: String]? // Optional for backward compatibility
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
