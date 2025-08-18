//
//  PriorityThumbnailLoader.swift
//  Photolala
//
//  Manages thumbnail loading with priority queue for visible items
//

import Foundation
import SwiftUI
import XPlatform

/// Manages thumbnail loading with priorities to ensure visible items load first
@MainActor
class PriorityThumbnailLoader: ObservableObject {
	
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
		let photo: PhotoFile
		let priority: Priority
		let requestTime: Date
		let id: UUID = UUID()
	}
	
	// MARK: - Properties
	
	private let photoManager = PhotoManagerV2.shared
	private var loadingQueue: [LoadRequest] = []
	private var activeLoads: Set<String> = [] // Track by filePath
	private var loadingTask: Task<Void, Never>?
	
	// Configuration
	private let maxConcurrentLoads = 4
	private let visibleRangeBuffer = 20 // Items to load around visible range
	
	// Stats
	@Published var queueSize: Int = 0
	@Published var activeLoadCount: Int = 0
	
	// MARK: - Public Methods
	
	/// Request thumbnail for a photo with given priority
	func requestThumbnail(for photo: PhotoFile, priority: Priority = .background) {
		// Skip if already has thumbnail
		if photo.thumbnail != nil {
			return
		}
		
		// Skip if already loading
		if activeLoads.contains(photo.filePath) {
			return
		}
		
		// Add to queue
		let request = LoadRequest(photo: photo, priority: priority, requestTime: Date())
		loadingQueue.append(request)
		
		// Sort queue by priority and request time
		loadingQueue.sort { lhs, rhs in
			if lhs.priority == rhs.priority {
				return lhs.requestTime < rhs.requestTime
			}
			return lhs.priority < rhs.priority
		}
		
		queueSize = loadingQueue.count
		
		// Start processing if not already running
		if loadingTask == nil {
			startProcessing()
		}
	}
	
	/// Update priorities for visible range of photos
	func updateVisibleRange(_ photos: [PhotoFile], visibleIndices: Range<Int>) {
		// Cancel existing requests for these photos
		let photoPaths = Set(photos.map { $0.filePath })
		loadingQueue.removeAll { photoPaths.contains($0.photo.filePath) }
		
		// Add requests with appropriate priorities
		for (index, photo) in photos.enumerated() {
			if photo.thumbnail != nil { continue }
			
			let priority: Priority
			if visibleIndices.contains(index) {
				priority = .visible
			} else if index >= visibleIndices.lowerBound - visibleRangeBuffer && 
					  index < visibleIndices.upperBound + visibleRangeBuffer {
				priority = .nearVisible
			} else if index >= visibleIndices.lowerBound - visibleRangeBuffer * 2 && 
					  index < visibleIndices.upperBound + visibleRangeBuffer * 2 {
				priority = .prefetch
			} else {
				priority = .background
			}
			
			requestThumbnail(for: photo, priority: priority)
		}
	}
	
	/// Cancel all non-visible requests (called when scrolling fast)
	func cancelNonVisibleRequests() {
		loadingQueue.removeAll { $0.priority != .visible }
		queueSize = loadingQueue.count
	}
	
	/// Clear all requests
	func clearQueue() {
		loadingQueue.removeAll()
		queueSize = 0
		loadingTask?.cancel()
		loadingTask = nil
	}
	
	// MARK: - Private Methods
	
	private func startProcessing() {
		loadingTask = Task {
			await processQueue()
		}
	}
	
	private func processQueue() async {
		while !loadingQueue.isEmpty {
			// Check for cancellation
			if Task.isCancelled { break }
			
			// Process up to maxConcurrentLoads items
			await withTaskGroup(of: Void.self) { group in
				var loadCount = 0
				
				while loadCount < maxConcurrentLoads && !loadingQueue.isEmpty {
					if let request = loadingQueue.first {
						loadingQueue.removeFirst()
						queueSize = loadingQueue.count
						
						// Skip if photo already has thumbnail
						if request.photo.thumbnail != nil {
							continue
						}
						
						activeLoads.insert(request.photo.filePath)
						activeLoadCount = activeLoads.count
						loadCount += 1
						
						group.addTask { [weak self] in
							await self?.loadThumbnail(for: request.photo)
						}
					}
				}
				
				// Wait for this batch to complete
				await group.waitForAll()
			}
		}
		
		// Clear task when done
		loadingTask = nil
	}
	
	private func loadThumbnail(for photo: PhotoFile) async {
		defer {
			activeLoads.remove(photo.filePath)
			activeLoadCount = activeLoads.count
		}
		
		do {
			// Load thumbnail through PhotoManagerV2
			if let thumbnail = try await photoManager.thumbnail(for: photo) {
				await MainActor.run {
					photo.thumbnail = thumbnail
					photo.thumbnailLoadingState = .loaded
				}
			}
		} catch {
			print("[PriorityLoader] Failed to load thumbnail for \(photo.filename): \(error)")
			await MainActor.run {
				photo.thumbnailLoadingState = .failed(error)
			}
		}
	}
}

// MARK: - Collection View Integration

extension PriorityThumbnailLoader {
	/// Calculate visible indices from NSCollectionView visible rect
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
		// iOS implementation
		let indexPaths = collectionView.indexPathsForVisibleItems
		let indices = indexPaths.map { $0.item }.sorted()
		if let first = indices.first, let last = indices.last {
			return first..<(last + 1)
		}
		return 0..<min(50, itemCount)
		#endif
	}
}