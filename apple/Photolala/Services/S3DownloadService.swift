import Foundation
import AWSS3
import SwiftUI

/// Service for downloading photos and thumbnails from S3
actor S3DownloadService {
	
	// MARK: - Types
	
	enum DownloadError: LocalizedError {
		case noS3Client
		case downloadFailed(Error)
		case invalidImageData
		case userNotAuthenticated
		
		var errorDescription: String? {
			switch self {
			case .noS3Client:
				return "S3 client not initialized"
			case .downloadFailed(let error):
				return "Download failed: \(error.localizedDescription)"
			case .invalidImageData:
				return "Invalid image data received"
			case .userNotAuthenticated:
				return "User not authenticated"
			}
		}
	}
	
	// MARK: - Properties
	
	private var s3Client: S3Client?
	private let bucketName = "photolala"
	private var downloadTasks: [String: Task<Data, Error>] = [:] // Key -> Download task
	
	// Cache configuration
	private let maxCacheSize: Int64 = 1_000_000_000 // 1GB
	
	// MARK: - Initialization
	
	init() {
		// CacheManager handles directory creation
	}
	
	// MARK: - Public Methods
	
	/// Initialize the S3 client
	func initialize() async throws {
		guard await IdentityManager.shared.currentUser?.serviceUserID != nil else {
			throw DownloadError.userNotAuthenticated
		}
		
		// Get S3 client from backup manager (which has credentials)
		guard let client = await S3BackupManager.shared.getS3Client() else {
			throw DownloadError.noS3Client
		}
		self.s3Client = client
	}
	
	/// Download a thumbnail from S3
	func downloadThumbnail(for photo: PhotoS3) async throws -> XImage {
		let key = photo.thumbnailKey
		
		// Check if already downloading
		if let existingTask = downloadTasks[key] {
			let data = try await existingTask.value
			guard let image = XImage(data: data) else {
				throw DownloadError.invalidImageData
			}
			return image
		}
		
		// Check cache first
		guard let userId = await IdentityManager.shared.currentUser?.serviceUserID else {
			throw DownloadError.userNotAuthenticated
		}
		let cacheFile = CacheManager.shared.cloudThumbnailURL(service: .s3, userId: userId, md5: photo.md5)
		if let cachedImage = loadCachedImage(at: cacheFile) {
			return cachedImage
		}
		
		// Start download task
		let task = Task<Data, Error> {
			try await downloadFromS3(key: key)
		}
		downloadTasks[key] = task
		
		do {
			let data = try await task.value
			downloadTasks.removeValue(forKey: key)
			
			// Save to cache
			try data.write(to: cacheFile)
			cleanupCacheIfNeeded()
			
			// Convert to image
			guard let image = XImage(data: data) else {
				throw DownloadError.invalidImageData
			}
			
			return image
		} catch {
			downloadTasks.removeValue(forKey: key)
			throw error
		}
	}
	
	/// Download thumbnail data from S3 (returns raw data instead of image)
	func downloadThumbnailData(key: String, userId: String) async throws -> Data? {
		// Check if already downloading
		if let existingTask = downloadTasks[key] {
			return try await existingTask.value
		}
		
		// Extract MD5 from key (format: thumbnails/userId/md5.dat)
		let components = key.split(separator: "/")
		guard components.count >= 3,
			  let md5Component = components.last?.split(separator: ".").first else {
			return nil
		}
		let md5 = String(md5Component)
		
		// Check cache first
		let cacheFile = CacheManager.shared.cloudThumbnailURL(service: .s3, userId: userId, md5: md5)
		if FileManager.default.fileExists(atPath: cacheFile.path) {
			return try? Data(contentsOf: cacheFile)
		}
		
		// Start download task
		let task = Task<Data, Error> {
			try await downloadFromS3(key: key)
		}
		downloadTasks[key] = task
		
		do {
			let data = try await task.value
			downloadTasks.removeValue(forKey: key)
			
			// Save to cache
			try data.write(to: cacheFile)
			cleanupCacheIfNeeded()
			
			return data
		} catch {
			downloadTasks.removeValue(forKey: key)
			throw error
		}
	}
	
	/// Download a full photo from S3
	func downloadPhoto(for photo: PhotoS3) async throws -> Data {
		let key = photo.photoKey
		
		// Check cache first
		guard let userId = await IdentityManager.shared.currentUser?.serviceUserID else {
			throw DownloadError.userNotAuthenticated
		}
		let cacheFile = CacheManager.shared.cloudPhotoURL(service: .s3, userId: userId, md5: photo.md5)
		if let cachedData = try? Data(contentsOf: cacheFile) {
			return cachedData
		}
		
		// Download from S3
		let data = try await downloadFromS3(key: key)
		
		// Save to cache
		try data.write(to: cacheFile)
		cleanupCacheIfNeeded()
		
		return data
	}
	
	/// Clear all caches
	func clearCache() throws {
		try CacheManager.shared.clearCloudCaches(for: .s3)
	}
	
	// MARK: - Private Methods
	
	private func downloadFromS3(key: String) async throws -> Data {
		guard let s3Client = s3Client else {
			throw DownloadError.noS3Client
		}
		
		let getRequest = GetObjectInput(
			bucket: bucketName,
			key: key
		)
		
		do {
			let response = try await s3Client.getObject(input: getRequest)
			
			// Handle the ByteStream body
			guard let body = response.body else {
				throw DownloadError.downloadFailed(NSError(domain: "S3Download", code: -1, 
														   userInfo: [NSLocalizedDescriptionKey: "Empty response body"]))
			}
			
			// Collect data from stream
			var resultData: Data?
			
			switch body {
			case .data(let data):
				resultData = data
				
			case .stream(let stream):
				var result = Data()
				while true {
					guard let chunk = try await stream.readAsync(upToCount: 65536) else {
						break
					}
					result.append(chunk)
				}
				resultData = result
				
			@unknown default:
				throw DownloadError.downloadFailed(NSError(domain: "S3Download", code: -1,
														   userInfo: [NSLocalizedDescriptionKey: "Unknown ByteStream type"]))
			}
			
			guard let data = resultData else {
				throw DownloadError.downloadFailed(NSError(domain: "S3Download", code: -1,
														   userInfo: [NSLocalizedDescriptionKey: "No data received"]))
			}
			
			return data
		} catch {
			throw DownloadError.downloadFailed(error)
		}
	}
	
	private func loadCachedImage(at url: URL) -> XImage? {
		guard FileManager.default.fileExists(atPath: url.path),
			  let data = try? Data(contentsOf: url),
			  let image = XImage(data: data) else {
			return nil
		}
		
		// Update access time for LRU
		try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
		
		return image
	}
	
	private func cleanupCacheIfNeeded() {
		// Simple cleanup: remove oldest files if cache is too large
		Task.detached {
			let maxSize: Int64 = 500_000_000 // 500MB per cache type
			
			// Get user ID for cache paths
			guard let userId = await IdentityManager.shared.currentUser?.serviceUserID else { return }
			
			// Get cache directories
			let thumbnailDir = CacheManager.shared.cloudThumbnailURL(service: .s3, userId: userId, md5: "dummy")
				.deletingLastPathComponent()
			let photoDir = CacheManager.shared.cloudPhotoURL(service: .s3, userId: userId, md5: "dummy")
				.deletingLastPathComponent()
			
			for cacheURL in [thumbnailDir, photoDir] {
				guard let files = try? FileManager.default.contentsOfDirectory(
					at: cacheURL,
					includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
				) else { continue }
				
				// Calculate total size
				var totalSize: Int64 = 0
				var fileInfos: [(url: URL, size: Int64, date: Date)] = []
				
				for file in files {
					if let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
					   let size = attrs.fileSize,
					   let date = attrs.contentModificationDate {
						totalSize += Int64(size)
						fileInfos.append((file, Int64(size), date))
					}
				}
				
				// Remove oldest files if over limit
				if totalSize > maxSize {
					fileInfos.sort { $0.date < $1.date } // Sort by date, oldest first
					
					for fileInfo in fileInfos {
						if totalSize <= maxSize { break }
						
						try? FileManager.default.removeItem(at: fileInfo.url)
						totalSize -= fileInfo.size
					}
				}
			}
		}
	}
}

// MARK: - Shared Instance

extension S3DownloadService {
	static let shared = S3DownloadService()
}
