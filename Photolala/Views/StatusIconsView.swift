//
//  StatusIconsView.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/19.
//

import SwiftUI

struct StatusIconsView: View {
	let selection: [any PhotoItem]
	
	var body: some View {
		HStack(spacing: 12) {
			let photoFiles = selection.compactMap { $0 as? PhotoFile }
			let starred = photoFiles.filter { photo in
				if let md5 = photo.md5Hash {
					let status = BackupQueueManager.shared.backupStatus[md5]
					return status == .queued || status == .uploaded
				}
				return false
			}.count
			let failed = photoFiles.filter { photo in
				if let md5 = photo.md5Hash {
					return BackupQueueManager.shared.backupStatus[md5] == .failed
				}
				return false
			}.count
			let archived = selection.filter { $0.isArchived }.count
			let retrieving = selection.filter { $0.archiveStatus == .deepArchive }.count // TODO: Add .retrieving status
			
			if starred > 0 {
				Label("\(starred)", systemImage: "star.fill")
					.foregroundColor(.yellow)
			}
			
			if failed > 0 {
				Label("\(failed)", systemImage: "exclamationmark.circle.fill")
					.foregroundColor(.red)
			}
			
			if archived > 0 {
				Label("\(archived)", systemImage: "archivebox")
					.foregroundColor(.orange)
			}
			
			if retrieving > 0 {
				Label("\(retrieving)", systemImage: "arrow.down.circle")
					.foregroundColor(.blue)
			}
			
			let unstarred = photoFiles.count - starred - archived
			if unstarred > 0 && (starred > 0 || archived > 0 || retrieving > 0) {
				Text("\(unstarred) unstarred")
					.foregroundColor(.secondary)
			}
		}
		.font(.caption)
	}
}

#Preview {
	VStack(spacing: 20) {
		StatusIconsView(selection: [])
			.padding()
			.background(Color.gray.opacity(0.1))
		
		// Mock preview data would go here
		Text("Preview with mock data")
	}
}