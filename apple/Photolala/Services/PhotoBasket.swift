//
//  PhotoBasket.swift
//  Photolala
//
//  Singleton service managing the photo basket for batch operations
//

import Foundation
import Combine
import SwiftUI

/// Manages the photo basket for collecting items across different sources
@MainActor
final class PhotoBasket: ObservableObject {
	// MARK: - Singleton

	static let shared = PhotoBasket()

	// MARK: - Properties

	@Published private(set) var items: [BasketItem] = []
	@Published private(set) var isProcessing = false
	@Published private(set) var lastError: Error?

	// No max items limit - user may need to retrieve 100K+ deep archive photos
	private var cancellables = Set<AnyCancellable>()

	// Persistence keys
	private let userDefaults = UserDefaults.standard
	private let basketItemsKey = "PhotolalaBasketItems"
	private let basketPersistenceEnabled = false // Start without persistence

	// MARK: - Computed Properties

	var count: Int { items.count }
	var isEmpty: Bool { items.isEmpty }

	var itemsPublisher: AnyPublisher<[BasketItem], Never> {
		$items.eraseToAnyPublisher()
	}

	var totalFileSize: Int64 {
		items.compactMap { $0.fileSize }.reduce(0, +)
	}

	// MARK: - Initialization

	private init() {
		if basketPersistenceEnabled {
			loadFromDisk()
		}

		// Auto-save when items change (if persistence enabled)
		$items
			.debounce(for: .seconds(1), scheduler: DispatchQueue.main)
			.sink { [weak self] _ in
				if self?.basketPersistenceEnabled == true {
					self?.saveToDisk()
				}
			}
			.store(in: &cancellables)
	}

	// MARK: - Public Methods

	/// Add an item to the basket
	/// - Parameters:
	///   - item: The photo browser item to add
	///   - sourceType: The type of source (local, cloud, applePhotos)
	///   - sourceIdentifier: Source-specific identifier (file path for local, S3 key for cloud, etc.)
	///   - url: Optional URL for creating security-scoped bookmark (for local sources)
	@discardableResult
	func add(_ item: PhotoBrowserItem, sourceType: PhotoSourceType, sourceIdentifier: String? = nil, url: URL? = nil) -> Bool {

		guard !contains(item.id) else {
			return false // Already in basket
		}

		// Create security-scoped bookmark if URL provided (for local sources)
		var bookmark: Data? = nil
		if let url = url, sourceType == .local {
			// Check if the URL is accessible
			if FileManager.default.isReadableFile(atPath: url.path) {
				bookmark = BasketItem.createBookmark(from: url)
				if bookmark == nil {
					print("[PhotoBasket] Warning: Failed to create bookmark for \(url.path)")
					print("[PhotoBasket] The file is readable, but bookmark creation failed. This might be a sandbox issue.")
				}
			} else {
				print("[PhotoBasket] Warning: File not accessible for bookmark creation: \(url.path)")
			}
		}

		let basketItem = item.toBasketItem(
			sourceType: sourceType,
			sourceIdentifier: sourceIdentifier ?? url?.path,
			bookmark: bookmark
		)

		items.append(basketItem)
		return true
	}

	/// Add multiple items to the basket
	@discardableResult
	func addMultiple(_ photosItems: [PhotoBrowserItem], sourceType: PhotoSourceType) -> Int {
		var addedCount = 0
		for item in photosItems {
			if add(item, sourceType: sourceType) {
				addedCount += 1
			}
		}
		return addedCount
	}

	/// Remove an item from the basket
	func remove(_ itemId: String) {
		items.removeAll { $0.id == itemId }
	}

	/// Remove multiple items
	func removeMultiple(_ itemIds: Set<String>) {
		items.removeAll { itemIds.contains($0.id) }
	}

	/// Toggle an item in the basket
	func toggle(_ item: PhotoBrowserItem, sourceType: PhotoSourceType, sourceIdentifier: String? = nil, url: URL? = nil) {
		if contains(item.id) {
			remove(item.id)
		} else {
			add(item, sourceType: sourceType, sourceIdentifier: sourceIdentifier, url: url)
		}
	}

	/// Check if basket contains an item
	func contains(_ itemId: String) -> Bool {
		items.contains { $0.id == itemId }
	}

	/// Clear all items from the basket
	func clear() {
		items.removeAll()
		lastError = nil
	}

	/// Get basket item by ID
	func item(withId id: String) -> BasketItem? {
		items.first { $0.id == id }
	}

	/// Get items filtered by source type
	func items(from sourceType: PhotoSourceType) -> [BasketItem] {
		items.filter { $0.sourceType == sourceType }
	}

	/// Group items by source type for batch processing
	func itemsBySource() -> [PhotoSourceType: [BasketItem]] {
		Dictionary(grouping: items) { $0.sourceType }
	}

	/// Update bookmark for an item (when refreshed due to staleness)
	func updateBookmark(for itemId: String, bookmark: Data) {
		guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }

		var updatedItem = items[index]
		updatedItem = BasketItem(
			id: updatedItem.id,
			displayName: updatedItem.displayName,
			sourceType: updatedItem.sourceType,
			sourceIdentifier: updatedItem.sourceIdentifier,
			sourceBookmark: bookmark, // Update bookmark
			fileSize: updatedItem.fileSize,
			photoDate: updatedItem.photoDate,
			addedDate: updatedItem.addedDate
		)
		items[index] = updatedItem
	}

	// MARK: - Persistence

	private func saveToDisk() {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		do {
			let data = try encoder.encode(items)
			userDefaults.set(data, forKey: basketItemsKey)
			print("[PhotoBasket] Saved \(items.count) items to disk")
		} catch {
			print("[PhotoBasket] Failed to save to disk: \(error)")
		}
	}

	private func loadFromDisk() {
		guard let data = userDefaults.data(forKey: basketItemsKey) else { return }

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601

		do {
			items = try decoder.decode([BasketItem].self, from: data)
			print("[PhotoBasket] Loaded \(items.count) items from disk")
		} catch {
			print("[PhotoBasket] Failed to load from disk: \(error)")
			// Clear corrupted data
			userDefaults.removeObject(forKey: basketItemsKey)
		}
	}

	// MARK: - Statistics

	func statistics() -> BasketStatistics {
		BasketStatistics(
			totalItems: items.count,
			localItems: items(from: .local).count,
			cloudItems: items(from: .cloud).count,
			applePhotosItems: items(from: .applePhotos).count,
			totalSize: totalFileSize,
			oldestItem: items.min(by: { $0.addedDate < $1.addedDate }),
			newestItem: items.max(by: { $0.addedDate < $1.addedDate })
		)
	}
}

// MARK: - Supporting Types

struct BasketStatistics {
	let totalItems: Int
	let localItems: Int
	let cloudItems: Int
	let applePhotosItems: Int
	let totalSize: Int64
	let oldestItem: BasketItem?
	let newestItem: BasketItem?

	var formattedTotalSize: String {
		ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
	}

	var isEmpty: Bool {
		totalItems == 0
	}
}

enum BasketError: LocalizedError {
	case itemNotFound
	case sourceUnavailable(String) // Store display name as String
	case actionFailed(String)

	var errorDescription: String? {
		switch self {
		case .itemNotFound:
			return "Item not found in basket"
		case .sourceUnavailable(let sourceName):
			return "\(sourceName) source is not available"
		case .actionFailed(let reason):
			return "Action failed: \(reason)"
		}
	}
}