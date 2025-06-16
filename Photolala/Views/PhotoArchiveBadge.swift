import SwiftUI

/// Badge overlay for photos showing their archive status
struct PhotoArchiveBadge: View {
	let archiveInfo: ArchivedPhotoInfo?
	let retrieval: PhotoRetrieval?
	
	var body: some View {
		if let info = archiveInfo {
			badgeView(for: info)
		}
	}
	
	@ViewBuilder
	private func badgeView(for info: ArchivedPhotoInfo) -> some View {
		// Show retrieval status if in progress
		if let retrieval = info.retrieval {
			switch retrieval.status {
			case .pending, .inProgress:
				ProgressBadge()
			case .completed:
				SparklesBadge()
			case .failed:
				ErrorBadge()
			}
		} else if info.isPinned {
			// Pinned photos show star
			StarBadge()
		} else if !info.storageClass.isImmediatelyAccessible {
			// Archived photos show freeze icon
			FrozenBadge()
		} else if info.isExpiringSoon {
			// About to re-archive
			WarningBadge(daysRemaining: info.daysUntilReArchive ?? 0)
		} else if info.daysUntilReArchive != nil {
			// Recently retrieved
			SparklesBadge()
		}
	}
}

// MARK: - Badge Components

struct FrozenBadge: View {
	var body: some View {
		Text("❄️")
			.font(.system(size: 16))
			.padding(4)
			.background(Circle().fill(Color.blue.opacity(0.8)))
			.overlay(Circle().stroke(Color.white, lineWidth: 1))
	}
}

struct ProgressBadge: View {
	@State private var isAnimating = false
	
	var body: some View {
		Image(systemName: "hourglass")
			.font(.system(size: 14))
			.foregroundColor(.white)
			.padding(4)
			.background(Circle().fill(Color.orange.opacity(0.8)))
			.overlay(Circle().stroke(Color.white, lineWidth: 1))
			.rotationEffect(.degrees(isAnimating ? 180 : 0))
			.animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
			.onAppear {
				isAnimating = true
			}
	}
}

struct SparklesBadge: View {
	@State private var sparkleOffset: CGFloat = 0
	
	var body: some View {
		Text("✨")
			.font(.system(size: 16))
			.padding(4)
			.background(Circle().fill(Color.yellow.opacity(0.8)))
			.overlay(Circle().stroke(Color.white, lineWidth: 1))
			.offset(y: sparkleOffset)
			.animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: sparkleOffset)
			.onAppear {
				sparkleOffset = -2
			}
	}
}

struct StarBadge: View {
	var body: some View {
		Text("⭐")
			.font(.system(size: 16))
			.padding(4)
			.background(Circle().fill(Color.yellow.opacity(0.8)))
			.overlay(Circle().stroke(Color.white, lineWidth: 1))
	}
}

struct WarningBadge: View {
	let daysRemaining: Int
	
	var body: some View {
		HStack(spacing: 2) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 12))
			Text("\(daysRemaining)d")
				.font(.system(size: 10, weight: .bold))
		}
		.foregroundColor(.white)
		.padding(.horizontal, 6)
		.padding(.vertical, 3)
		.background(Capsule().fill(Color.orange.opacity(0.9)))
		.overlay(Capsule().stroke(Color.white, lineWidth: 1))
	}
}

struct ErrorBadge: View {
	var body: some View {
		Image(systemName: "exclamationmark.circle.fill")
			.font(.system(size: 16))
			.foregroundColor(.white)
			.background(Circle().fill(Color.red.opacity(0.8)))
			.overlay(Circle().stroke(Color.white, lineWidth: 1))
	}
}

// MARK: - Preview

struct PhotoArchiveBadge_Previews: PreviewProvider {
	static var previews: some View {
		VStack(spacing: 20) {
			// Frozen
			PhotoArchiveBadge(
				archiveInfo: ArchivedPhotoInfo(
					md5: "test",
					archivedDate: Date(),
					storageClass: .deepArchive,
					lastAccessedDate: nil,
					isPinned: false,
					retrieval: nil
				),
				retrieval: nil
			)
			
			// In Progress
			PhotoArchiveBadge(
				archiveInfo: ArchivedPhotoInfo(
					md5: "test",
					archivedDate: Date(),
					storageClass: .deepArchive,
					lastAccessedDate: nil,
					isPinned: false,
					retrieval: PhotoRetrieval(
						photoMD5: "test",
						requestedAt: Date(),
						estimatedReadyAt: Date().addingTimeInterval(86400),
						status: .inProgress(percentComplete: 0.5)
					)
				),
				retrieval: nil
			)
			
			// Expiring Soon
			PhotoArchiveBadge(
				archiveInfo: ArchivedPhotoInfo(
					md5: "test",
					archivedDate: Date(),
					storageClass: .standard,
					lastAccessedDate: Date().addingTimeInterval(-23 * 86400), // 23 days ago
					isPinned: false,
					retrieval: nil
				),
				retrieval: nil
			)
		}
		.padding()
		.background(Color.gray)
	}
}