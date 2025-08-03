//
//  DirectoryPhotoProvider.swift
//  Photolala
//
//  Enhanced local photo provider with progressive loading and priority thumbnails
//

import Foundation
import Combine
import SwiftUI
import OSLog
import XPlatform

@MainActor
class DirectoryPhotoProvider: ObservableObject, PhotoProvider {
	
	// MARK: - PhotoProvider Protocol
	
	@Published private(set) var photos: [any PhotoItem] = []
	var photosPublisher: AnyPublisher<[any PhotoItem], Never> {
		$photos.eraseToAnyPublisher()
	}
	
	@Published private(set) var isLoading: Bool = false
	var isLoadingPublisher: AnyPublisher<Bool, Never> {
		$isLoading.eraseToAnyPublisher()
	}
	
	var displayTitle: String {
		URL(fileURLWithPath: directoryPath).lastPathComponent
	}
	
	var displaySubtitle: String {
		let count = photos.count
		return count == 1 ? "1 photo" : "\(count) photos"
	}
	
	let supportsGrouping = true
	let supportsSorting = true
	
	// MARK: - Properties
	
	private let directoryPath: String
	private let progressiveLoader = ProgressivePhotoLoader()
	private let priorityLoader = PriorityThumbnailLoader()
	private let backupQueueManager = BackupQueueManager.shared
	private let logger = Logger(subsystem: "com.photolala", category: "DirectoryPhotoProvider")
	
	// Grouping and sorting
	@Published var currentGrouping: PhotoGroupingOption = .none
	@Published var currentSorting: PhotoSortOption = .filename
	
	// Progress tracking
	@Published var loadingProgress: Double = 0
	@Published var loadingStatusText: String = ""
	
	// Cancellables
	private var cancellables = Set<AnyCancellable>()
	
	// MARK: - Capabilities
	
	var capabilities: PhotoProviderCapabilities {
		[.hierarchicalNavigation, .backup, .sorting, .grouping, .preview, .star]
	}
	
	// MARK: - Initialization
	
	init(directoryPath: String) {
		self.directoryPath = directoryPath
		
		// Subscribe to progressive loader updates
		progressiveLoader.$photos
			.sink { [weak self] photos in
				self?.updatePhotos(photos)
			}
			.store(in: &cancellables)
		
		progressiveLoader.$loadingState
			.sink { [weak self] state in
				self?.updateLoadingState(state)
			}
			.store(in: &cancellables)
		
		// Subscribe to priority loader stats
		priorityLoader.$queueSize
			.combineLatest(priorityLoader.$activeLoadCount)
			.sink { [weak self] queueSize, activeCount in
				if queueSize > 0 || activeCount > 0 {
					self?.logger.debug("Thumbnail queue: \(queueSize), active: \(activeCount)")
				}
			}
			.store(in: &cancellables)
	}
	
	// MARK: - PhotoProvider Methods
	
	func loadPhotos() async throws {
		isLoading = true
		loadingProgress = 0
		loadingStatusText = "Loading photos..."
		
		let directoryURL = URL(fileURLWithPath: directoryPath)
		await progressiveLoader.loadPhotos(from: directoryURL)
	}
	
	func refresh() async throws {
		// Clear thumbnail queue
		priorityLoader.clearQueue()
		
		// Reload photos
		try await loadPhotos()
	}
	
	func applyGrouping(_ option: PhotoGroupingOption) async {
		self.currentGrouping = option
		// Grouping will be handled by the view
	}
	
	func applySorting(_ option: PhotoSortOption) async {
		self.currentSorting = option
		// Sorting will be handled by the view
	}
	
	// MARK: - Priority Loading
	
	/// Update visible range for priority loading
	func updateVisibleRange(_ visibleIndices: Range<Int>) {
		guard !photos.isEmpty else { return }
		
		// Convert PhotoItems to PhotoFiles for priority loader
		let photoFiles = photos.compactMap { $0 as? PhotoFile }
		priorityLoader.updateVisibleRange(photoFiles, visibleIndices: visibleIndices)
	}
	
	/// Update visible range from collection view
	func updateVisibleRange(for collectionView: XCollectionView) {
		let photoFiles = photos.compactMap { $0 as? PhotoFile }
		let visibleIndices = priorityLoader.visibleIndices(for: collectionView, itemCount: photoFiles.count)
		priorityLoader.updateVisibleRange(photoFiles, visibleIndices: visibleIndices)
	}
	
	/// Cancel non-visible loads when scrolling fast
	func onFastScroll() {
		priorityLoader.cancelNonVisibleRequests()
	}
	
	// MARK: - Private Methods
	
	private func updatePhotos(_ newPhotos: [PhotoFile]) {
		// Update photos array
		self.photos = newPhotos
		
		// Match with backup status
		Task {
			await backupQueueManager.matchPhotosWithBackupStatus(newPhotos)
		}
		
		// Update progress
		loadingProgress = progressiveLoader.loadingProgress
		
		// If initial batch loaded, start thumbnail loading for visible items
		if progressiveLoader.initialBatchLoaded && !newPhotos.isEmpty {
			// Request thumbnails for first visible items
			let initialVisible = min(50, newPhotos.count)
			for i in 0..<initialVisible {
				priorityLoader.requestThumbnail(for: newPhotos[i], priority: i < 20 ? .visible : .nearVisible)
			}
		}
	}
	
	private func updateLoadingState(_ state: ProgressivePhotoLoader.LoadingState) {
		switch state {
		case .idle:
			isLoading = false
			loadingStatusText = ""
		case .loadingInitial:
			isLoading = true
			loadingStatusText = "Loading photos..."
		case .loadingRemainder:
			isLoading = true
			loadingStatusText = progressiveLoader.loadingStatusText
		case .completed:
			isLoading = false
			loadingStatusText = "\(photos.count) photos"
		case .failed(let error):
			isLoading = false
			loadingStatusText = "Error: \(error.localizedDescription)"
			logger.error("Failed to load photos: \(error)")
		}
	}
}

// MARK: - Collection View Scroll Monitoring

extension DirectoryPhotoProvider {
	#if os(macOS)
	/// Monitor scroll events to optimize loading
	func setupScrollMonitoring(for scrollView: NSScrollView) {
		NotificationCenter.default.publisher(for: NSScrollView.didLiveScrollNotification, object: scrollView)
			.throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
			.sink { [weak self] _ in
				guard let collectionView = scrollView.documentView as? NSCollectionView else { return }
				self?.updateVisibleRange(for: collectionView)
			}
			.store(in: &cancellables)
		
		NotificationCenter.default.publisher(for: NSScrollView.didEndLiveScrollNotification, object: scrollView)
			.sink { [weak self] _ in
				guard let collectionView = scrollView.documentView as? NSCollectionView else { return }
				self?.updateVisibleRange(for: collectionView)
			}
			.store(in: &cancellables)
	}
	#endif
}
