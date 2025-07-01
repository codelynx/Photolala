//
//  PhotoCellBadge.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/06/18.
//

import SwiftUI

struct PhotoCellBadge: View {
	let state: BackupState
	let action: () -> Void
	
	@State private var isHovering = false
	@State private var isAnimating = false
	
	var body: some View {
		if state != .none {
			Button(action: action) {
				ZStack {
					// Badge background
					Circle()
						.fill(Color.white)
						.frame(width: 24, height: 24)
						.shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
					
					// Badge icon
					Image(systemName: state.iconName)
						.font(.system(size: 14))
						.foregroundColor(Color(state.badgeColor))
						.scaleEffect(isHovering ? 1.1 : 1.0)
						.rotationEffect(state == .uploading && isAnimating ? .degrees(360) : .degrees(0))
				}
			}
			.buttonStyle(.plain)
			.help(helpText)
			.onHover { hovering in
				withAnimation(.easeInOut(duration: 0.1)) {
					isHovering = hovering
				}
			}
			.onAppear {
				if state == .uploading {
					withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
						isAnimating = true
					}
				}
			}
		}
	}
	
	private var helpText: String {
		switch state {
		case .none:
			return ""
		case .queued:
			return "Remove from backup queue"
		case .uploading:
			return "Uploading..."
		case .uploaded:
			return "Already backed up"
		case .failed:
			return "Upload failed - Click to retry"
		}
	}
}