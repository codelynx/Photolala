//
//  BackupStatusBar.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/06/18.
//

import SwiftUI
import XPlatform

struct BackupStatusBar: View {
	@ObservedObject var status = BackupStatusManager.shared
	
	var body: some View {
		VStack(spacing: 0) {
			Divider()
			
			if status.isVisible {
				HStack(spacing: 12) {
					// Progress indicator
					ProgressView(value: status.progress)
						.progressViewStyle(.linear)
						.frame(width: 200)
					
					// Status text
					Text("\(status.uploadedPhotos)/\(status.totalPhotos) photos")
						.font(.system(size: 11))
					
					// Current file
					Text(status.currentPhotoName)
						.font(.system(size: 11))
						.foregroundColor(.secondary)
						.lineLimit(1)
						.frame(maxWidth: 200)
					
					Spacer()
					
					// Speed and time
					if !status.uploadSpeed.isEmpty {
						Text(status.uploadSpeed)
							.font(.system(size: 11))
							.foregroundColor(.secondary)
					}
					
					if !status.timeRemaining.isEmpty {
						Text(status.timeRemaining)
							.font(.system(size: 11))
							.foregroundColor(.secondary)
					}
					
					// Cancel button
					Button(action: {
						// TODO: Implement cancel functionality
						status.cancelUpload()
					}) {
						Image(systemName: "xmark.circle.fill")
							.foregroundColor(.secondary)
					}
					.buttonStyle(.plain)
				}
				.padding(.horizontal, 12)
				.padding(.vertical, 6)
				.background(Color(XPlatform.primaryBackgroundColor))
			}
		}
		.animation(.easeInOut(duration: 0.2), value: status.isVisible)
	}
}
