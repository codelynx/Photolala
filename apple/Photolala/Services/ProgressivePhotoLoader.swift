//
//  ProgressivePhotoLoader.swift
//  Photolala
//
//  Loads photos progressively - first batch immediately, rest in background
//

import Foundation
import SwiftUI
import OSLog

/// Loads photos from directories progressively for better perceived performance
@MainActor
class ProgressivePhotoLoader: ObservableObject {
	
	// MARK: - Types
	
	enum LoadingState {
		case idle
		case loadingInitial
		case loadingRemainder
		case completed
		case failed(Error)
	}
	
	// MARK: - Properties
	
	@Published var photos: [PhotoFile] = []
	@Published var loadingState: LoadingState = .idle
	@Published var initialBatchLoaded = false
	@Published var totalPhotosFound = 0
	@Published var photosLoaded = 0
	
	private let catalogLoader = CatalogAwarePhotoLoader()
	private let logger = Logger(subsystem: "com.photolala", category: "ProgressiveLoader")
	
	// Configuration
	private let initialBatchSize = 200  // First photos to load immediately
	private let batchSize = 100        // Size of subsequent batches
	
	private var loadingTask: Task<Void, Never>?
	private var currentDirectory: URL?
	
	// MARK: - Public Methods
	
	/// Load photos from directory progressively
	func loadPhotos(from directory: URL) async {
		// Cancel any existing load
		loadingTask?.cancel()
		
		// Reset state
		photos.removeAll()
		loadingState = .loadingInitial
		initialBatchLoaded = false
		totalPhotosFound = 0
		photosLoaded = 0
		currentDirectory = directory
		
		// Start progressive loading
		loadingTask = Task {
			await performProgressiveLoad(from: directory)
		}
		
		await loadingTask?.value
	}
	
	/// Cancel current loading operation
	func cancelLoading() {
		loadingTask?.cancel()
		loadingTask = nil
		if case .loadingInitial = loadingState {
			loadingState = .idle
		} else if case .loadingRemainder = loadingState {
			loadingState = .completed
		}
	}
	
	// MARK: - Private Methods
	
	private func performProgressiveLoad(from directory: URL) async {
		do {
			// First, try to load from catalog for instant results
			if let catalogPhotos = try? await catalogLoader.loadFromCatalog(directory) {
				logger.info("Loaded \(catalogPhotos.count) photos from catalog instantly")
				
				// Update UI with catalog results immediately
				await MainActor.run {
					self.photos = catalogPhotos
					self.totalPhotosFound = catalogPhotos.count
					self.photosLoaded = catalogPhotos.count
					self.initialBatchLoaded = true
					self.loadingState = .completed
				}
				
				// Verify catalog is up to date in background
				Task.detached { [weak self] in
					await self?.verifyCatalog(directory: directory, catalogPhotos: catalogPhotos)
				}
				
				return
			}
			
			// No catalog - do progressive directory scan
			await performProgressiveDirectoryScan(directory: directory)
			
		} catch {
			logger.error("Progressive load failed: \(error)")
			await MainActor.run {
				self.loadingState = .failed(error)
			}
		}
	}
	
	private func performProgressiveDirectoryScan(directory: URL) async {
		logger.info("Starting progressive directory scan for \(directory.path)")
		
		// Get all photos from directory
		let allPhotos = DirectoryScanner.scanDirectory(atPath: directory.path as NSString)
		
		await MainActor.run {
			self.totalPhotosFound = allPhotos.count
		}
		
		if allPhotos.isEmpty {
			await MainActor.run {
				self.loadingState = .completed
			}
			return
		}
		
		// Load initial batch
		let initialPhotos = Array(allPhotos.prefix(initialBatchSize))
		
		await MainActor.run {
			self.photos = initialPhotos
			self.photosLoaded = initialPhotos.count
			self.initialBatchLoaded = true
			self.loadingState = allPhotos.count <= self.initialBatchSize ? .completed : .loadingRemainder
		}
		
		// Check for cancellation
		if Task.isCancelled { return }
		
		// Load remaining photos in batches
		if allPhotos.count > initialBatchSize {
			await loadRemainingPhotos(
				photos: Array(allPhotos.dropFirst(initialBatchSize)),
				directory: directory
			)
		}
		
		// Generate catalog in background for next time
		if !Task.isCancelled {
			let photosSnapshot = self.photos
			Task.detached { [weak self] in
				try? await self?.catalogLoader.generateCatalog(for: directory, photos: photosSnapshot)
			}
		}
	}
	
	private func loadRemainingPhotos(photos: [PhotoFile], directory: URL) async {
		var remainingPhotos = photos
		
		while !remainingPhotos.isEmpty && !Task.isCancelled {
			// Take next batch
			let batchPhotos = Array(remainingPhotos.prefix(batchSize))
			remainingPhotos = Array(remainingPhotos.dropFirst(batchSize))
			
			// Update UI
			await MainActor.run {
				self.photos.append(contentsOf: batchPhotos)
				self.photosLoaded = self.photos.count
			}
			
			// Small delay to not block UI
			try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
		}
		
		await MainActor.run {
			self.loadingState = .completed
		}
	}
	
	// Removed loadPhotoBatch as we're working with PhotoFile objects directly
	
	private func verifyCatalog(directory: URL, catalogPhotos: [PhotoFile]) async {
		// Scan directory to verify catalog is complete
		let currentPhotos = DirectoryScanner.scanDirectory(atPath: directory.path as NSString)
		let currentURLs = Set(currentPhotos.map { $0.fileURL })
		
		let catalogURLs = Set(catalogPhotos.map { $0.fileURL })
		
		// Find new photos not in catalog
		let newURLs = currentURLs.subtracting(catalogURLs)
		
		if !newURLs.isEmpty {
			logger.info("Found \(newURLs.count) new photos not in catalog")
			
			// Load new photos
			let newPhotos = currentPhotos.filter { newURLs.contains($0.fileURL) }
			
			await MainActor.run {
				self.photos.append(contentsOf: newPhotos)
				self.photos.sort { $0.filename < $1.filename }
				self.totalPhotosFound = self.photos.count
				self.photosLoaded = self.photos.count
			}
			
			// Regenerate catalog
			let photosSnapshot = self.photos
			Task.detached { [weak self] in
				try? await self?.catalogLoader.generateCatalog(for: directory, photos: photosSnapshot)
			}
		}
		
		// Check for deleted photos
		let deletedURLs = catalogURLs.subtracting(currentURLs)
		if !deletedURLs.isEmpty {
			logger.info("Found \(deletedURLs.count) deleted photos in catalog")
			
			await MainActor.run {
				self.photos.removeAll { deletedURLs.contains($0.fileURL) }
				self.totalPhotosFound = self.photos.count
				self.photosLoaded = self.photos.count
			}
			
			// Regenerate catalog
			let photosSnapshot = self.photos
			Task.detached { [weak self] in
				try? await self?.catalogLoader.generateCatalog(for: directory, photos: photosSnapshot)
			}
		}
	}
}

// MARK: - Progress Helpers

extension ProgressivePhotoLoader {
	var loadingProgress: Double {
		guard totalPhotosFound > 0 else { return 0 }
		return Double(photosLoaded) / Double(totalPhotosFound)
	}
	
	var loadingStatusText: String {
		switch loadingState {
		case .idle:
			return "Ready"
		case .loadingInitial:
			return "Loading photos..."
		case .loadingRemainder:
			return "Loading \(photosLoaded) of \(totalPhotosFound) photos..."
		case .completed:
			return "\(totalPhotosFound) photos"
		case .failed(let error):
			return "Error: \(error.localizedDescription)"
		}
	}
}