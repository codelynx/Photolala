import Foundation
import SwiftUI
import AWSS3

/// Manages photo retrieval requests from S3 Deep Archive
@MainActor
class S3RetrievalManager: ObservableObject {
	@Published var activeRetrievals: [String: PhotoRetrieval] = [:] // MD5 -> Retrieval
	@Published var isRetrieving = false
	
	private let s3Service: S3BackupService
	private let identityManager: IdentityManager
	
	init(s3Service: S3BackupService, identityManager: IdentityManager) {
		self.s3Service = s3Service
		self.identityManager = identityManager
	}
	
	/// Request retrieval for a single photo
	func requestRetrieval(for photo: PhotoReference, rushDelivery: Bool = false) async throws {
		guard let md5 = photo.md5Hash,
		      let userId = identityManager.currentUser?.appleUserID else {
			throw PhotoRetrievalError.missingUserInfo
		}
		
		// Check if already retrieving
		if activeRetrievals[md5] != nil {
			throw PhotoRetrievalError.alreadyRetrieving
		}
		
		isRetrieving = true
		defer { isRetrieving = false }
		
		// Create retrieval request
		let retrieval = PhotoRetrieval(
			photoMD5: md5,
			requestedAt: Date(),
			estimatedReadyAt: rushDelivery ? Date().addingTimeInterval(5 * 3600) : Date().addingTimeInterval(24 * 3600),
			status: .pending
		)
		
		activeRetrievals[md5] = retrieval
		
		// Initiate S3 restore request
		do {
			try await s3Service.restorePhoto(md5: md5, userId: userId, rushDelivery: rushDelivery)
			
			// Update status to in progress
			activeRetrievals[md5] = PhotoRetrieval(
				photoMD5: md5,
				requestedAt: retrieval.requestedAt,
				estimatedReadyAt: retrieval.estimatedReadyAt,
				status: .inProgress(percentComplete: 0.0)
			)
			
			// Start monitoring restore status
			Task {
				await monitorRestoreStatus(for: md5, userId: userId)
			}
			
		} catch {
			// Update status to failed
			activeRetrievals[md5] = PhotoRetrieval(
				photoMD5: md5,
				requestedAt: retrieval.requestedAt,
				estimatedReadyAt: retrieval.estimatedReadyAt,
				status: .failed(error: error.localizedDescription)
			)
			throw error
		}
	}
	
	/// Request retrieval for multiple photos
	func requestBatchRetrieval(for photos: [PhotoReference], rushDelivery: Bool = false) async throws {
		var errors: [Error] = []
		
		for photo in photos {
			do {
				try await requestRetrieval(for: photo, rushDelivery: rushDelivery)
			} catch {
				errors.append(error)
			}
		}
		
		if !errors.isEmpty {
			throw PhotoRetrievalError.batchErrors(errors)
		}
	}
	
	/// Monitor restore status for a photo
	private func monitorRestoreStatus(for md5: String, userId: String) async {
		var checkCount = 0
		let maxChecks = 48 // Check for up to 48 hours
		let checkInterval: TimeInterval = 900 // Check every 15 minutes initially
		
		while checkCount < maxChecks {
			// Wait before checking (shorter initially, longer as time goes on)
			let waitTime = checkCount < 4 ? checkInterval : checkInterval * 4 // Every hour after first hour
			try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
			
			// Check if still monitoring this retrieval
			guard let retrieval = activeRetrievals[md5] else { break }
			
			do {
				// Check restore status
				let status = try await s3Service.checkRestoreStatus(md5: md5, userId: userId)
				
				switch status {
				case .completed(let expiresAt):
					// Restore complete!
					activeRetrievals[md5] = PhotoRetrieval(
						photoMD5: md5,
						requestedAt: retrieval.requestedAt,
						estimatedReadyAt: Date(),
						status: .completed
					)
					
					// Update archive info if we have the photo reference
					if let expiresAt = expiresAt {
						// TODO: Update photo's archive info with expiry date
						print("[S3RetrievalManager] Photo restored, expires at: \(expiresAt)")
					}
					
					// Send notification
					await sendRestoreCompleteNotification(for: md5)
					return
					
				case .inProgress(let estimatedCompletion):
					// Update progress estimate
					let progress = Double(checkCount) / Double(maxChecks)
					activeRetrievals[md5] = PhotoRetrieval(
						photoMD5: md5,
						requestedAt: retrieval.requestedAt,
						estimatedReadyAt: estimatedCompletion ?? retrieval.estimatedReadyAt,
						status: .inProgress(percentComplete: progress)
					)
					
				case .notStarted:
					// Shouldn't happen, but handle it
					print("[S3RetrievalManager] Warning: Restore not started for \(md5)")
					activeRetrievals[md5] = PhotoRetrieval(
						photoMD5: md5,
						requestedAt: retrieval.requestedAt,
						estimatedReadyAt: retrieval.estimatedReadyAt,
						status: .failed(error: "Restore not started")
					)
					return
					
				case .available:
					// Photo is already available (not archived)
					activeRetrievals[md5] = PhotoRetrieval(
						photoMD5: md5,
						requestedAt: retrieval.requestedAt,
						estimatedReadyAt: Date(),
						status: .completed
					)
					return
				}
			} catch {
				print("[S3RetrievalManager] Error checking restore status: \(error)")
			}
			
			checkCount += 1
		}
		
		// If we've exceeded max checks and still not complete, mark as failed
		if checkCount >= maxChecks, let retrieval = activeRetrievals[md5] {
			activeRetrievals[md5] = PhotoRetrieval(
				photoMD5: md5,
				requestedAt: retrieval.requestedAt,
				estimatedReadyAt: retrieval.estimatedReadyAt,
				status: .failed(error: "Restore timeout exceeded")
			)
		}
	}
	
	/// Send notification when restore is complete
	private func sendRestoreCompleteNotification(for md5: String) async {
		// TODO: Implement push notifications using UserNotifications framework
		print("Photo \(md5) has been restored and is ready for download!")
		
		#if os(macOS)
		// Using UserNotifications framework for macOS 11+
		if #available(macOS 11.0, *) {
			// TODO: Implement UserNotifications
		} else {
			// Legacy notification for older macOS
			let notification = NSUserNotification()
			notification.title = "Photo Ready"
			notification.informativeText = "Your archived photo has been restored and is ready for viewing."
			notification.soundName = NSUserNotificationDefaultSoundName
			NSUserNotificationCenter.default.deliver(notification)
		}
		#endif
	}
	
	/// Get retrieval status for a photo
	func retrievalStatus(for photo: PhotoReference) -> PhotoRetrieval? {
		guard let md5 = photo.md5Hash else { return nil }
		return activeRetrievals[md5]
	}
	
	/// Cancel a retrieval request (if possible)
	func cancelRetrieval(for photo: PhotoReference) {
		guard let md5 = photo.md5Hash else { return }
		activeRetrievals.removeValue(forKey: md5)
	}
}