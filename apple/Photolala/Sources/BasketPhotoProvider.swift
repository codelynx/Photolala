//
//  BasketPhotoProvider.swift
//  Photolala
//
//  Photo source provider backed by basket contents
//

import Foundation
import SwiftUI
import Combine
import OSLog

/// Provides read-only access to basket photos via PhotoSourceProtocol
@MainActor
final class BasketPhotoProvider: PhotoSourceProtocol {
	// MARK: - Properties

	private let basket: PhotoBasket
	private let logger = Logger(subsystem: "com.photolala", category: "BasketPhotoProvider")
	private let metadataResolver: BasketMetadataResolver

	// Publishers
	private let photosSubject = CurrentValueSubject<[PhotoBrowserItem], Never>([])
	private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
	private var cancellables = Set<AnyCancellable>()

	// Cache for resolved sources - keyed by item ID for item-specific context
	private var sourceCache: [String: any PhotoSourceProtocol] = [:]
	private let factory = DefaultPhotoSourceFactory.shared

	// MARK: - Initialization

	init(basket: PhotoBasket = .shared) {
		self.basket = basket
		self.metadataResolver = BasketMetadataResolver()

		// Subscribe to basket changes
		basket.itemsPublisher
			.map { items in
				items.map { item in
					PhotoBrowserItem(
						id: item.id,
						displayName: item.displayName
					)
				}
			}
			.sink { [weak self] items in
				self?.photosSubject.send(items)
			}
			.store(in: &cancellables)

		// Initialize with current basket items
		Task {
			_ = try? await loadPhotos()
		}
	}

	// MARK: - PhotoSourceProtocol

	func loadPhotos() async throws -> [PhotoBrowserItem] {
		logger.info("[BasketProvider] Loading \(self.basket.count) basket items")
		isLoadingSubject.send(true)
		defer { isLoadingSubject.send(false) }

		// Convert basket items to PhotoBrowserItems
		let items = basket.items.map { basketItem in
			PhotoBrowserItem(
				id: basketItem.id,
				displayName: basketItem.displayName
			)
		}

		photosSubject.send(items)
		return items
	}

	func loadMetadata(for itemId: String) async throws -> PhotoBrowserMetadata {
		logger.debug("[BasketProvider] Loading metadata for \(itemId)")

		// Find the basket item
		guard let basketItem = basket.item(withId: itemId) else {
			throw BasketError.itemNotFound
		}

		// Try to resolve from original source with item context
		do {
			let source = try await resolveSourceForItem(basketItem)
			return try await source.loadMetadata(for: itemId)
		} catch {
			logger.warning("[BasketProvider] Failed to load metadata from source: \(error)")

			// Fallback to cached metadata in basket item
			return PhotoBrowserMetadata(
				fileSize: basketItem.fileSize ?? 0,
				creationDate: basketItem.photoDate,
				modificationDate: basketItem.photoDate,
				width: nil,
				height: nil,
				mimeType: "image/jpeg" // Default assumption
			)
		}
	}

	func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
		logger.debug("[BasketProvider] Loading thumbnail for \(itemId)")

		// Find the basket item
		guard let basketItem = basket.item(withId: itemId) else {
			throw BasketError.itemNotFound
		}

		// Resolve thumbnail from original source with item context
		do {
			let source = try await resolveSourceForItem(basketItem)
			return try await source.loadThumbnail(for: itemId)
		} catch {
			logger.warning("[BasketProvider] Failed to load thumbnail from source: \(error)")
			// Return placeholder if source unavailable
			return createPlaceholderImage(for: basketItem)
		}
	}

	func loadFullImage(for itemId: String) async throws -> Data {
		logger.info("[BasketProvider] Loading full image for \(itemId)")

		// Find the basket item
		guard let basketItem = basket.item(withId: itemId) else {
			throw BasketError.itemNotFound
		}

		// Must resolve from original source with item context
		let source = try await resolveSourceForItem(basketItem)
		return try await source.loadFullImage(for: itemId)
	}

	// MARK: - Publishers

	var photosPublisher: AnyPublisher<[PhotoBrowserItem], Never> {
		photosSubject.eraseToAnyPublisher()
	}

	var isLoadingPublisher: AnyPublisher<Bool, Never> {
		isLoadingSubject.eraseToAnyPublisher()
	}

	// MARK: - Capabilities

	var capabilities: PhotoSourceCapabilities {
		// Basket is read-only - actions are performed via BasketActionService
		.readOnly
	}

	// MARK: - Private Methods

	/// Resolve source for a specific basket item with its context
	private func resolveSourceForItem(_ item: BasketItem) async throws -> (any PhotoSourceProtocol) {
		// Check cache first
		if let cached = sourceCache[item.id] {
			return cached
		}

		// Create source based on item's specific context
		let source: (any PhotoSourceProtocol)?

		switch item.sourceType {
		case .local:
			source = await createLocalSource(for: item)

		case .cloud:
			source = await createCloudSource(for: item)

		case .applePhotos:
			source = await createApplePhotosSource(for: item)
		}

		// Ensure source was created and contains the item
		guard let source = source else {
			logger.error("[BasketProvider] Failed to create source for item \(item.id) of type \(item.sourceType.rawValue)")
			throw BasketError.sourceUnavailable(item.sourceType.displayName)
		}

		// Verify the source can access the item
		if !(await verifySourceContainsItem(source: source, itemId: item.id)) {
			logger.error("[BasketProvider] Source does not contain item \(item.id)")
			throw BasketError.itemNotFound
		}

		// Cache for future use (keyed by item ID for item-specific context)
		sourceCache[item.id] = source

		return source
	}

	/// Verify that a source contains a specific item
	private func verifySourceContainsItem(source: any PhotoSourceProtocol, itemId: String) async -> Bool {
		do {
			let photos = try await source.loadPhotos()
			return photos.contains { $0.id == itemId }
		} catch {
			logger.warning("[BasketProvider] Failed to verify source contains item: \(error)")
			return false
		}
	}

	/// Create a local source for a specific basket item
	private func createLocalSource(for item: BasketItem) async -> LocalPhotoSource? {
		// Try to resolve from bookmark first
		if let resolved = item.resolveURL() {
			let url = resolved.url

			// Determine the directory URL (parent if it's a file)
			var directoryURL = url
			var isDirectory: ObjCBool = false
			if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
				if !isDirectory.boolValue {
					// It's a file, use parent directory
					directoryURL = url.deletingLastPathComponent()
				}
			}

			// Create source with the directory
			// LocalPhotoSource should manage the security scope lifetime
			let source = LocalPhotoSource(
				directoryURL: directoryURL,
				requiresSecurityScope: resolved.didStartAccessing,
				securityScopedURL: resolved.didStartAccessing ? url : nil
			)

			// Load photos to verify access
			do {
				_ = try await source.loadPhotos()
				return source
			} catch {
				logger.warning("[BasketProvider] Failed to load photos from local source: \(error)")
				// Clean up security scope if needed
				if resolved.didStartAccessing {
					url.stopAccessingSecurityScopedResource()
				}
				return nil
			}
		}

		// Fallback to sourceIdentifier (path)
		if let path = item.sourceIdentifier {
			let url = URL(fileURLWithPath: path)

			// Determine the directory URL
			var directoryURL = url
			var isDirectory: ObjCBool = false
			if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
				if !isDirectory.boolValue {
					// It's a file, use parent directory
					directoryURL = url.deletingLastPathComponent()
				}

				let source = LocalPhotoSource(
					directoryURL: directoryURL,
					requiresSecurityScope: false
				)

				do {
					_ = try await source.loadPhotos()
					return source
				} catch {
					logger.warning("[BasketProvider] Failed to load photos from path: \(error)")
					return nil
				}
			}
		}

		logger.warning("[BasketProvider] Failed to create local source for item \(item.id)")
		return nil
	}

	/// Create a cloud source for a specific basket item
	private func createCloudSource(for item: BasketItem) async -> S3PhotoSource? {
		// Cloud source doesn't need item-specific context as it uses user's catalog
		do {
			let source = try await factory.makeCloudSource() as? S3PhotoSource
			if let source = source {
				// Verify source can be accessed
				do {
					_ = try await source.loadPhotos()
					return source
				} catch {
					logger.warning("[BasketProvider] Cloud source cannot load photos: \(error)")
					return nil
				}
			}
			return nil
		} catch {
			logger.warning("[BasketProvider] Failed to create cloud source: \(error)")
			return nil
		}
	}

	/// Create an Apple Photos source for a specific basket item
	private func createApplePhotosSource(for item: BasketItem) async -> ApplePhotosSource? {
		// Apple Photos source uses the Photos framework which has its own context
		guard let source = factory.makeApplePhotosSource() as? ApplePhotosSource else {
			logger.warning("[BasketProvider] Failed to create Apple Photos source")
			return nil
		}

		// Verify source can be accessed
		do {
			_ = try await source.loadPhotos()
			return source
		} catch {
			logger.warning("[BasketProvider] Apple Photos source cannot load photos: \(error)")
			return nil
		}
	}

	private func createPlaceholderImage(for item: BasketItem) -> PlatformImage? {
		// Create a simple placeholder with source type indicator
		#if os(macOS)
		let size = NSSize(width: 200, height: 200)
		let image = NSImage(size: size)

		image.lockFocus()
		NSColor.secondaryLabelColor.setFill()
		NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

		// Draw source icon
		let iconName = item.sourceType.icon
		if let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
			icon.draw(in: NSRect(x: 75, y: 75, width: 50, height: 50))
		}

		image.unlockFocus()
		return image
		#else
		let size = CGSize(width: 200, height: 200)
		return UIGraphicsImageRenderer(size: size).image { context in
			UIColor.secondaryLabel.setFill()
			context.fill(CGRect(origin: .zero, size: size))

			// Draw source icon
			let iconName = item.sourceType.icon
			if let icon = UIImage(systemName: iconName) {
				icon.draw(in: CGRect(x: 75, y: 75, width: 50, height: 50))
			}
		}
		#endif
	}
}

// MARK: - Metadata Resolver

/// Resolves metadata for basket items from their original sources
actor BasketMetadataResolver {
	private var cache: [String: PhotoBrowserMetadata] = [:]

	func metadata(for item: BasketItem) async -> PhotoBrowserMetadata? {
		// Check cache
		if let cached = cache[item.id] {
			return cached
		}

		// Resolve based on source type
		let metadata: PhotoBrowserMetadata?

		switch item.sourceType {
		case .local:
			metadata = await resolveLocalMetadata(item)
		case .cloud:
			metadata = await resolveCloudMetadata(item)
		case .applePhotos:
			metadata = await resolveApplePhotosMetadata(item)
		}

		// Cache result
		if let metadata = metadata {
			cache[item.id] = metadata
		}

		return metadata
	}

	private func resolveLocalMetadata(_ item: BasketItem) async -> PhotoBrowserMetadata? {
		// Resolve URL from bookmark if available
		let resolvedURL = await MainActor.run { item.resolveURL() }
		guard let resolved = resolvedURL else { return nil }

		let url = resolved.url
		defer {
			if resolved.didStartAccessing {
				url.stopAccessingSecurityScopedResource()
			}
		}

		// Get file attributes
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
			return PhotoBrowserMetadata(
				fileSize: attributes[.size] as? Int64,
				creationDate: attributes[.creationDate] as? Date,
				modificationDate: attributes[.modificationDate] as? Date,
				width: nil,
				height: nil,
				mimeType: url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
			)
		} catch {
			return nil
		}
	}

	private func resolveCloudMetadata(_ item: BasketItem) async -> PhotoBrowserMetadata? {
		// Would query S3 or catalog database
		// For now, return cached values from basket item
		return PhotoBrowserMetadata(
			fileSize: item.fileSize,
			creationDate: item.photoDate,
			modificationDate: item.photoDate,
			width: nil,
			height: nil,
			mimeType: "image/jpeg"
		)
	}

	private func resolveApplePhotosMetadata(_ item: BasketItem) async -> PhotoBrowserMetadata? {
		// Would query Photos framework
		// For now, return minimal metadata
		return PhotoBrowserMetadata(
			fileSize: item.fileSize,
			creationDate: item.photoDate,
			modificationDate: item.photoDate,
			width: nil,
			height: nil,
			mimeType: "image/heic"
		)
	}
}