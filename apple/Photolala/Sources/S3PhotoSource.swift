//
//  S3PhotoSource.swift
//  Photolala
//
//  Cloud photo source implementation for AWS S3
//

import Foundation
import SwiftUI
import Combine
import OSLog
import AWSS3

@MainActor
final class S3PhotoSource: PhotoSourceProtocol {
	// MARK: - Properties

	private let logger = Logger(subsystem: "com.photolala", category: "S3PhotoSource")
	private let s3Service: S3Service
	private let cloudBrowsingService: S3CloudBrowsingService
	private let accountManager: AccountManager
	private let cacheManager: CacheManager

	// Publishers
	private let photosSubject = CurrentValueSubject<[PhotoBrowserItem], Never>([])
	private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
	private var authStateSubscription: AnyCancellable?

	// Cache
	private var catalogDatabase: CatalogDatabase?
	private var catalogEntries: [CatalogEntry] = []
	private var thumbnailTasks: [String: Task<PlatformImage?, Error>] = [:]

	// Authentication state for cloud access
	@Published private(set) var authenticationState: PhotoBrowserEnvironment.AuthenticationState = .notSignedIn

	// MARK: - Initialization

	init(accountManager: AccountManager = .shared) async throws {
		self.accountManager = accountManager
		self.s3Service = try await S3Service(environment: .development)  // TODO: Get from settings
		self.cloudBrowsingService = S3CloudBrowsingService(s3Service: s3Service)
		self.cacheManager = CacheManager.shared

		// Set initial auth state
		updateAuthenticationState()

		// Subscribe to AccountManager changes
		authStateSubscription = accountManager.$isSignedIn
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.updateAuthenticationState()
				// Reload photos when auth state changes
				Task { @MainActor [weak self] in
					if self?.accountManager.isSignedIn == true {
						_ = try? await self?.loadPhotos()
					} else {
						self?.photosSubject.send([])
					}
				}
			}
	}

	// MARK: - PhotoSourceProtocol Implementation

	func loadPhotos() async throws -> [PhotoBrowserItem] {
		logger.info("Loading photos from S3")

		// Check authentication
		guard accountManager.isSignedIn,
			  let user = accountManager.getCurrentUser() else {
			logger.warning("Not signed in, returning empty photo list")
			photosSubject.send([])
			throw PhotoSourceError.notAuthorized
		}

		isLoadingSubject.send(true)
		defer { isLoadingSubject.send(false) }

		do {
			// Load cloud catalog - use UUID not email for S3 path
			catalogDatabase = try await cloudBrowsingService.loadCloudCatalog(userID: user.id.uuidString)

			// Get all photos from catalog
			guard let catalog = catalogDatabase else {
				throw PhotoSourceError.sourceUnavailable
			}

			// Query catalog for all entries
			catalogEntries = await catalog.getAllEntries()

			// Convert catalog entries to PhotoBrowserItems
			let items = catalogEntries.map { entry in
				PhotoBrowserItem(
					id: entry.photoMD5 ?? entry.photoHeadMD5,  // Use full MD5 if available, otherwise head MD5
					displayName: formatDisplayName(for: entry)
				)
			}

			logger.info("Loaded \(items.count) photos from cloud")
			photosSubject.send(items)
			return items

		} catch let error as AWSS3.NoSuchKey {
			// No catalog exists yet - this is normal for new users
			logger.info("[S3PhotoSource] No catalog found for user (NoSuchKey) - this is normal for new users")
			logger.info("[S3PhotoSource] User may need to upload photos first")
			photosSubject.send([])
			// Return empty array instead of throwing - valid state for new user
			return []
		} catch {
			logger.error("[S3PhotoSource] Failed to load cloud photos: \(error)")
			logger.error("[S3PhotoSource] Error type: \(type(of: error))")
			photosSubject.send([])
			throw PhotoSourceError.loadFailed(error)
		}
	}

	func loadMetadata(for itemId: String) async throws -> PhotoBrowserMetadata {
		logger.debug("Loading metadata for \(itemId)")

		// Find the catalog entry for this photo
		guard let entry = catalogEntries.first(where: {
			($0.photoMD5 ?? $0.photoHeadMD5) == itemId
		}) else {
			throw PhotoSourceError.itemNotFound
		}

		// Return metadata from catalog entry
		return PhotoBrowserMetadata(
			fileSize: entry.fileSize,
			creationDate: entry.photoDate,
			modificationDate: entry.photoDate,
			width: nil,  // Width not stored in catalog
			height: nil,  // Height not stored in catalog
			mimeType: entry.format.mimeType
		)
	}

	func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
		logger.debug("Loading thumbnail for \(itemId)")

		// Check if we already have a task for this thumbnail
		if let existingTask = thumbnailTasks[itemId] {
			return try await existingTask.value
		}

		// Create new task
		let task = Task<PlatformImage?, Error> {
			guard accountManager.isSignedIn,
				  let user = accountManager.getCurrentUser() else {
				throw PhotoSourceError.notAuthorized
			}

			// Try to load from cache first
			let photoMD5 = PhotoMD5(itemId)
			let thumbnailPath = await cacheManager.getThumbnailPath(photoMD5: photoMD5)
			if FileManager.default.fileExists(atPath: thumbnailPath.path),
			   let cachedData = try? Data(contentsOf: thumbnailPath),
			   let image = PlatformImage(data: cachedData) {
				return image
			}

			// Load from S3 - use UUID not email for S3 path
			let thumbnailData = await cloudBrowsingService.loadThumbnail(
				photoMD5: itemId,
				userID: user.id.uuidString
			)

			// Cache for future use
			if let data = thumbnailData {
				let thumbnailPath = await cacheManager.getThumbnailPath(photoMD5: photoMD5)
				try? data.write(to: thumbnailPath)
			}

			return thumbnailData.flatMap { PlatformImage(data: $0) }
		}

		thumbnailTasks[itemId] = task

		do {
			let result = try await task.value
			thumbnailTasks[itemId] = nil  // Clean up
			return result
		} catch {
			thumbnailTasks[itemId] = nil  // Clean up
			throw error
		}
	}

	func loadFullImage(for itemId: String) async throws -> Data {
		logger.info("Loading full image for \(itemId)")

		guard accountManager.isSignedIn,
			  let user = accountManager.getCurrentUser() else {
			throw PhotoSourceError.notAuthorized
		}

		// S3Service will use credentials from AccountManager internally
		_ = try await accountManager.getSTSCredentials() // Ensure credentials are available

		// Download full image from S3 - use UUID not email for S3 path
		let imageData = try await s3Service.downloadPhoto(
			md5: itemId,
			userID: user.id.uuidString
		)

		logger.info("Successfully loaded full image: \(imageData.count) bytes")
		return imageData
	}

	// MARK: - Protocol Publishers

	var photosPublisher: AnyPublisher<[PhotoBrowserItem], Never> {
		photosSubject.eraseToAnyPublisher()
	}

	var isLoadingPublisher: AnyPublisher<Bool, Never> {
		isLoadingSubject.eraseToAnyPublisher()
	}

	var capabilities: PhotoSourceCapabilities {
		// Cloud is read-only for MVP
		.readOnly
	}

	// MARK: - Cloud-Specific Methods

	func downloadForOfflineViewing(ids: [String]) async throws {
		logger.info("Downloading \(ids.count) photos for offline viewing")

		guard accountManager.isSignedIn else {
			throw PhotoSourceError.notAuthorized
		}

		// Download each photo and cache locally
		for photoID in ids {
			do {
				let imageData = try await loadFullImage(for: photoID)
				// Cache the full image data as thumbnail for offline viewing
				let photoMD5 = PhotoMD5(photoID)
				let thumbnailPath = await cacheManager.getThumbnailPath(photoMD5: photoMD5)
				try? imageData.write(to: thumbnailPath)
				logger.debug("Cached photo \(photoID) for offline viewing")
			} catch {
				logger.error("Failed to download \(photoID): \(error.localizedDescription)")
				// Continue with other downloads
			}
		}
	}

	func syncWithCloud() async throws {
		logger.info("Syncing with cloud")

		// Force reload from cloud
		_ = try await loadPhotos()
	}

	// MARK: - Private Methods

	private func formatDisplayName(for entry: CatalogEntry) -> String {
		// Format: "photo_<short_md5>_<date>"
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyyMMdd"
		let dateStr = dateFormatter.string(from: entry.photoDate)
		let shortMD5 = String((entry.photoMD5 ?? entry.photoHeadMD5).prefix(8))
		return "photo_\(shortMD5)_\(dateStr).\(entry.format.fileExtension)"
	}

	private func updateAuthenticationState() {
		if let user = accountManager.getCurrentUser() {
			authenticationState = .signedIn(user: user)
			logger.info("Authentication state: signed in as \(user.email ?? user.id.uuidString)")
		} else {
			authenticationState = .notSignedIn
			logger.info("Authentication state: not signed in")
		}
	}
}

// MARK: - PhotoBrowserEnvironment Extension

extension PhotoBrowserEnvironment {
	// Nested enum to avoid namespace collisions
	enum AuthenticationState: Equatable {
		case notApplicable  // For local/Apple Photos sources
		case notSignedIn
		case signedIn(user: PhotolalaUser)
		case refreshingCredentials

		static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
			switch (lhs, rhs) {
			case (.notApplicable, .notApplicable),
			     (.notSignedIn, .notSignedIn),
			     (.refreshingCredentials, .refreshingCredentials):
				return true
			case (.signedIn(let lhsUser), .signedIn(let rhsUser)):
				return lhsUser.id == rhsUser.id
			default:
				return false
			}
		}
	}

	// Add computed property for auth state
	var authenticationState: AuthenticationState {
		// Check if source is S3PhotoSource and get its auth state
		if let cloudSource = source as? S3PhotoSource {
			return cloudSource.authenticationState
		}
		return .notApplicable
	}
}