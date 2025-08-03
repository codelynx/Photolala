//
//  PriorityThumbnailLoaderV2.swift
//  Photolala
//
//  Priority-based thumbnail loader using PhotoManagerV2
//

import Foundation
import SwiftUI
import XPlatform

/// Manages thumbnail loading with priorities using PhotoManagerV2
@MainActor
class PriorityThumbnailLoaderV2: ObservableObject {
	static let shared = PriorityThumbnailLoaderV2()
	
	// MARK: - Types
	
	enum Priority: Int, Comparable {
		case visible = 0      // Currently visible on screen
		case nearVisible = 1  // Within 1-2 screens of visible area
		case prefetch = 2     // Further away but worth prefetching
		case background = 3   // Everything else
		
		static func < (lhs: Priority, rhs: Priority) -> Bool {
			lhs.rawValue < rhs.rawValue
		}
	}
	
	struct LoadRequest {
		let photo: any PhotoItem
		let priority: Priority
		let requestTime: Date
		let id: UUID = UUID()
	}
	
	// MARK: - Properties
	
	private let photoManager = PhotoManagerV2.shared
	private var loadingQueue: [LoadRequest] = []
	private var activeLoads: Set<String> = [] // Track by photo ID
	private var loadingTask: Task<Void, Never>?
	
	// Configuration
	private let maxConcurrentLoads = 12  // Increased for better performance
	private let visibleRangeBuffer = 20
	
	// Stats
	@Published var queueSize: Int = 0
	@Published var activeLoadCount: Int = 0
	
	// MARK: - Public Methods
	
	/// Request thumbnail for a photo with given priority
	func requestThumbnail(for photo: any PhotoItem, priority: Priority = .background) {
		// Skip if already has thumbnail
		if hasThumbnail(for: photo) {
			return
		}
		
		// Skip if already loading
		if activeLoads.contains(photo.id) {
			return
		}
		
		// Add to queue
		let request = LoadRequest(photo: photo, priority: priority, requestTime: Date())
		loadingQueue.append(request)
		
		// Sort by priority and request time
		loadingQueue.sort { lhs, rhs in
			if lhs.priority != rhs.priority {
				return lhs.priority < rhs.priority
			}
			return lhs.requestTime < rhs.requestTime
		}
		
		queueSize = loadingQueue.count
		
		// Start processing if not already running
		if loadingTask == nil {
			startProcessing()
		}
	}
	
	/// Update visible range for a photo collection
	func updateVisibleRange(_ range: Range<Int>, photos: [any PhotoItem]) {
		// Cancel lower priority loads
		loadingQueue.removeAll { $0.priority == .background || $0.priority == .prefetch }
		
		// Request visible items with high priority
		for i in range {
			if i < photos.count {
				requestThumbnail(for: photos[i], priority: .visible)
			}
		}
		
		// Request near-visible items
		let nearStart = max(0, range.lowerBound - visibleRangeBuffer)
		let nearEnd = min(photos.count, range.upperBound + visibleRangeBuffer)
		
		for i in nearStart..<range.lowerBound {
			requestThumbnail(for: photos[i], priority: .nearVisible)
		}
		
		for i in range.upperBound..<nearEnd {
			requestThumbnail(for: photos[i], priority: .nearVisible)
		}
	}
	
	/// Cancel all pending loads
	func cancelAll() {
		loadingQueue.removeAll()
		loadingTask?.cancel()
		loadingTask = nil
		queueSize = 0
	}
	
	// MARK: - Private Methods
	
	private func hasThumbnail(for photo: any PhotoItem) -> Bool {
		switch photo {
		case let photoFile as PhotoFile:
			return photoFile.thumbnail != nil
		case let photoApple as PhotoApple:
			// Apple Photos always need loading (unless we check cache)
			return false
		case let photoS3 as PhotoS3:
			// S3 photos always need loading (unless we check cache)
			return false
		default:
			return false
		}
	}
	
	private func startProcessing() {
		loadingTask = Task {
			while !loadingQueue.isEmpty && !Task.isCancelled {
				// Process up to maxConcurrentLoads in parallel
				let batch = Array(loadingQueue.prefix(maxConcurrentLoads))
				loadingQueue.removeFirst(min(batch.count, loadingQueue.count))
				
				await withTaskGroup(of: Void.self) { group in
					for request in batch {
						if activeLoads.count < maxConcurrentLoads {
							activeLoads.insert(request.photo.id)
							activeLoadCount = activeLoads.count
							
							group.addTask { [weak self] in
								await self?.loadThumbnail(for: request.photo)
							}
						}
					}
				}
				
				queueSize = loadingQueue.count
			}
			
			loadingTask = nil
		}
	}
	
	private func loadThumbnail(for photo: any PhotoItem) async {
		defer {
			activeLoads.remove(photo.id)
			activeLoadCount = activeLoads.count
		}
		
		do {
			// Use PhotoManagerV2 for all photo types
			if let thumbnail = try await photoManager.thumbnail(for: photo) {
				await updatePhotoThumbnail(photo: photo, thumbnail: thumbnail)
			}
		} catch {
			print("[PriorityLoaderV2] Failed to load thumbnail for \(photo.filename): \(error)")
			await updatePhotoLoadingState(photo: photo, error: error)
		}
	}
	
	private func updatePhotoThumbnail(photo: any PhotoItem, thumbnail: XImage) async {
		switch photo {
		case let photoFile as PhotoFile:
			photoFile.thumbnail = thumbnail
			photoFile.thumbnailLoadingState = .loaded
		default:
			// Other photo types might not have mutable thumbnail properties
			// This would be handled by the UI observing cache updates
			break
		}
	}
	
	private func updatePhotoLoadingState(photo: any PhotoItem, error: Error) async {
		switch photo {
		case let photoFile as PhotoFile:
			photoFile.thumbnailLoadingState = .failed(error)
		default:
			// Other photo types might not have loading state
			break
		}
	}
}

// MARK: - Collection View Integration

extension PriorityThumbnailLoaderV2 {
	/// Calculate visible indices from collection view
	func visibleIndices(for collectionView: XCollectionView, itemCount: Int) -> Range<Int> {
		#if os(macOS)
		let visibleRect = collectionView.visibleRect
		guard let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout else {
			return 0..<min(50, itemCount)
		}
		
		let itemSize = layout.itemSize
		let spacing = layout.minimumInteritemSpacing
		let insets = layout.sectionInset
		
		// Calculate items per row
		let availableWidth = collectionView.bounds.width - insets.left - insets.right
		let itemsPerRow = max(1, Int((availableWidth + spacing) / (itemSize.width + spacing)))
		
		// Calculate visible rows
		let firstVisibleRow = max(0, Int((visibleRect.minY - insets.top) / (itemSize.height + spacing)))
		let lastVisibleRow = Int((visibleRect.maxY - insets.top) / (itemSize.height + spacing))
		
		// Convert to indices
		let firstIndex = firstVisibleRow * itemsPerRow
		let lastIndex = min((lastVisibleRow + 1) * itemsPerRow, itemCount)
		
		return firstIndex..<lastIndex
		#else
		// iOS implementation would go here
		return 0..<min(50, itemCount)
		#endif
	}
}