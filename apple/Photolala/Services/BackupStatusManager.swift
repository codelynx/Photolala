//
//  BackupStatusManager.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/06/18.
//

import Foundation
import SwiftUI

@MainActor
class BackupStatusManager: ObservableObject {
	static let shared = BackupStatusManager()
	
	@Published var isVisible = false
	@Published var totalPhotos = 0
	@Published var uploadedPhotos = 0
	@Published var currentPhotoName = ""
	@Published var uploadSpeed = ""
	@Published var timeRemaining = ""
	
	private var uploadStartTime: Date?
	private var lastUpdateTime: Date?
	private var bytesUploaded: Int64 = 0
	
	private init() {}
	
	var progress: Double {
		guard totalPhotos > 0 else { return 0 }
		return Double(uploadedPhotos) / Double(totalPhotos)
	}
	
	func startUpload(totalPhotos: Int) {
		self.totalPhotos = totalPhotos
		self.uploadedPhotos = 0
		self.currentPhotoName = ""
		self.uploadSpeed = ""
		self.timeRemaining = ""
		self.isVisible = true
		self.uploadStartTime = Date()
		self.lastUpdateTime = Date()
		self.bytesUploaded = 0
	}
	
	func updateProgress(uploadedPhotos: Int, currentPhotoName: String) {
		self.uploadedPhotos = uploadedPhotos
		self.currentPhotoName = currentPhotoName
		
		// Calculate speed and time remaining
		if let startTime = uploadStartTime {
			let elapsed = Date().timeIntervalSince(startTime)
			if elapsed > 0 && uploadedPhotos > 0 {
				let photosPerSecond = Double(uploadedPhotos) / elapsed
				let remainingPhotos = totalPhotos - uploadedPhotos
				let estimatedSeconds = Double(remainingPhotos) / photosPerSecond
				
				// Format time remaining
				if estimatedSeconds < 60 {
					timeRemaining = "~\(Int(estimatedSeconds))s"
				} else if estimatedSeconds < 3600 {
					timeRemaining = "~\(Int(estimatedSeconds / 60))m"
				} else {
					timeRemaining = "~\(Int(estimatedSeconds / 3600))h"
				}
			}
		}
	}
	
	func updateSpeed(bytesPerSecond: Int64) {
		// Format upload speed
		if bytesPerSecond < 1024 {
			uploadSpeed = "\(bytesPerSecond) B/s"
		} else if bytesPerSecond < 1024 * 1024 {
			uploadSpeed = String(format: "%.1f KB/s", Double(bytesPerSecond) / 1024.0)
		} else {
			uploadSpeed = String(format: "%.1f MB/s", Double(bytesPerSecond) / (1024.0 * 1024.0))
		}
	}
	
	func completeUpload() {
		// Show completion briefly before hiding
		Task {
			uploadedPhotos = totalPhotos
			currentPhotoName = "Complete"
			uploadSpeed = ""
			timeRemaining = ""
			
			try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
			
			withAnimation(.easeInOut(duration: 0.3)) {
				isVisible = false
			}
		}
	}
	
	func cancelUpload() {
		withAnimation(.easeInOut(duration: 0.3)) {
			isVisible = false
		}
		// Reset all values
		totalPhotos = 0
		uploadedPhotos = 0
		currentPhotoName = ""
		uploadSpeed = ""
		timeRemaining = ""
	}
}