import SwiftUI

// MARK: - Image Extension

extension Image {
	init(xImage: XImage) {
		#if os(macOS)
		self.init(nsImage: xImage)
		#else
		self.init(uiImage: xImage)
		#endif
	}
}

struct S3PhotoThumbnailView: View {
	let photo: S3Photo
	let thumbnailSize: CGFloat
	let isSelected: Bool
	
	@State private var thumbnail: XImage?
	@State private var isLoadingThumbnail = false
	@StateObject private var thumbnailCache = S3ThumbnailCache.shared
	
	var body: some View {
		ZStack {
			// Background
			RoundedRectangle(cornerRadius: 8)
				.fill(Color.secondary.opacity(0.1))
				.overlay(
					RoundedRectangle(cornerRadius: 8)
						.stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
				)
			
			// Thumbnail or placeholder
			if let thumbnail = thumbnail {
				Image(xImage: thumbnail)
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame(width: thumbnailSize, height: thumbnailSize)
					.clipped()
					.cornerRadius(6)
			} else {
				// Placeholder
				VStack {
					Image(systemName: "photo")
						.font(.system(size: thumbnailSize * 0.3))
						.foregroundColor(.secondary)
					
					if isLoadingThumbnail {
						ProgressView()
							.scaleEffect(0.5)
					}
				}
				.frame(width: thumbnailSize, height: thumbnailSize)
			}
			
			// Overlays
			VStack {
				HStack {
					// Archive badge
					if photo.isArchived {
						Label("Archived", systemImage: "archivebox.fill")
							.font(.caption2)
							.padding(.horizontal, 6)
							.padding(.vertical, 2)
							.background(Color.orange.opacity(0.9))
							.foregroundColor(.white)
							.cornerRadius(4)
					}
					
					Spacer()
				}
				
				Spacer()
				
				// Info bar (always show for now)
				HStack {
					Text(photo.filename)
						.font(.caption2)
						.lineLimit(1)
					
					Spacer()
					
					Text(photo.formattedSize)
						.font(.caption2)
				}
				.padding(.horizontal, 4)
				.padding(.vertical, 2)
				.background(Color.black.opacity(0.6))
				.foregroundColor(.white)
			}
			.padding(4)
		}
		.frame(width: thumbnailSize, height: thumbnailSize)
		.task {
			await loadThumbnail()
		}
	}
	
	
	private func loadThumbnail() async {
		// Check local cache first
		if let cached = thumbnailCache.getCachedThumbnail(md5: photo.md5) {
			self.thumbnail = cached
			return
		}
		
		// Check if we have the original locally
		if let localThumbnail = await checkLocalThumbnail() {
			self.thumbnail = localThumbnail
			thumbnailCache.cacheThumbnail(localThumbnail, for: photo.md5)
			return
		}
		
		// Fetch from S3
		isLoadingThumbnail = true
		defer { isLoadingThumbnail = false }
		
		do {
			if let s3Thumbnail = try await fetchS3Thumbnail() {
				self.thumbnail = s3Thumbnail
				thumbnailCache.cacheThumbnail(s3Thumbnail, for: photo.md5)
			}
		} catch {
			print("Failed to load thumbnail for \(photo.md5): \(error)")
		}
	}
	
	private func checkLocalThumbnail() async -> XImage? {
		// Check if PhotoManager has this photo by MD5
		// TODO: Add PhotoManager method to look up by MD5
		return nil
	}
	
	private func fetchS3Thumbnail() async throws -> XImage? {
		#if DEBUG
		// In debug mode, generate a placeholder image
		print("DEBUG: Would download thumbnail for \(photo.md5)")
		
		// Create a colored placeholder based on MD5
		let colors: [XColor] = [.red, .blue, .green, .orange, .purple, .yellow, .cyan, .magenta]
		let colorIndex = photo.md5.hash % colors.count
		let color = colors[colorIndex]
		
		#if os(macOS)
		let size = NSSize(width: 200, height: 200)
		let image = NSImage(size: size)
		image.lockFocus()
		color.setFill()
		NSBezierPath.fill(NSRect(origin: .zero, size: size))
		
		// Draw MD5 prefix
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.systemFont(ofSize: 12),
			.foregroundColor: NSColor.white
		]
		let text = String(photo.md5.prefix(8))
		let textSize = text.size(withAttributes: attributes)
		let textRect = NSRect(x: (size.width - textSize.width) / 2,
							  y: (size.height - textSize.height) / 2,
							  width: textSize.width,
							  height: textSize.height)
		text.draw(in: textRect, withAttributes: attributes)
		
		image.unlockFocus()
		return image
		#else
		// iOS implementation
		let size = CGSize(width: 200, height: 200)
		let renderer = UIGraphicsImageRenderer(size: size)
		return renderer.image { context in
			color.setFill()
			context.fill(CGRect(origin: .zero, size: size))
		}
		#endif
		#else
		// Production: actually download from S3
		try await S3DownloadService.shared.initialize()
		return try await S3DownloadService.shared.downloadThumbnail(for: photo)
		#endif
	}
}

// MARK: - Thumbnail Cache

@MainActor
class S3ThumbnailCache: ObservableObject {
	static let shared = S3ThumbnailCache()
	
	private var cache: [String: XImage] = [:]
	private let maxCacheSize = 100 // Maximum number of thumbnails to cache
	private var accessOrder: [String] = [] // For LRU eviction
	
	private init() {}
	
	func getCachedThumbnail(md5: String) -> XImage? {
		if let thumbnail = cache[md5] {
			// Update access order for LRU
			accessOrder.removeAll { $0 == md5 }
			accessOrder.append(md5)
			return thumbnail
		}
		return nil
	}
	
	func cacheThumbnail(_ thumbnail: XImage, for md5: String) {
		// Check if we need to evict
		if cache.count >= maxCacheSize && cache[md5] == nil {
			// Evict least recently used
			if let lru = accessOrder.first {
				cache.removeValue(forKey: lru)
				accessOrder.removeFirst()
			}
		}
		
		// Add to cache
		cache[md5] = thumbnail
		accessOrder.append(md5)
	}
	
	func clearCache() {
		cache.removeAll()
		accessOrder.removeAll()
	}
}