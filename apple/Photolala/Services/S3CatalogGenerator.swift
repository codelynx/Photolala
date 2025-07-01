import Foundation
import AWSS3
import CryptoKit

/// Generates .photolala catalog files from photos stored in S3
actor S3CatalogGenerator {
	
	// MARK: - Properties
	
	private let s3Client: S3Client
	private let bucketName = "photolala"
	
	// MARK: - Initialization
	
	init(s3Client: S3Client) {
		self.s3Client = s3Client
	}
	
	// MARK: - Public Methods
	
	/// Generate a catalog for a user from their uploaded photos
	func generateCatalog(for userId: String) async throws -> (manifest: Data, shards: [Int: Data]) {
		print("Generating catalog for user: \(userId)")
		
		// Step 1: List all photos for the user
		var photos = try await listUserPhotos(userId: userId)
		
		// TEMPORARY: If no photos found, check test-user-123
		if photos.isEmpty && userId != "test-user-123" {
			print("No photos found for \(userId), checking test-user-123...")
			photos = try await listUserPhotos(userId: "test-user-123")
		}
		
		print("Found \(photos.count) photos")
		
		// Step 2: List all metadata files
		var metadata = try await listUserMetadata(userId: userId)
		
		// TEMPORARY: If no metadata found and we're using test photos, get test metadata
		if metadata.isEmpty && photos.count > 0 && userId != "test-user-123" {
			print("No metadata found for \(userId), checking test-user-123...")
			metadata = try await listUserMetadata(userId: "test-user-123")
		}
		
		print("Found \(metadata.count) metadata files")
		
		// Step 3: Create catalog entries
		var catalogEntries: [PhotolalaCatalogService.CatalogEntry] = []
		
		for photo in photos {
			// Extract MD5 from key
			guard let md5 = extractMD5FromKey(photo.key) else { continue }
			
			// Find corresponding metadata (try both path formats)
			var metadataKey = "metadata/\(userId)/\(md5).plist"
			var photoMetadata = metadata[metadataKey]
			
			// If not found, try old path format
			if photoMetadata == nil {
				metadataKey = "users/\(userId)/metadata/\(md5).plist"
				photoMetadata = metadata[metadataKey]
			}
			
			// Create catalog entry
			// Use CSV line format to create entry
			let filename = photoMetadata?.fileName ?? "\(md5).jpg"
			let size = photo.size ?? 0
			let photoDate = photoMetadata?.photoDate ?? photo.lastModified ?? Date()
			let modified = photo.lastModified ?? Date()
			let width = photoMetadata?.pixelWidth
			let height = photoMetadata?.pixelHeight
			let applePhotoID = photoMetadata?.applePhotoID ?? ""
			
			let widthStr = width.map(String.init) ?? ""
			let heightStr = height.map(String.init) ?? ""
			let photoDateStr = String(Int(photoDate.timeIntervalSince1970))
			let modifiedStr = String(Int(modified.timeIntervalSince1970))
			
			// Create CSV line (v5.1 format includes applePhotoID field)
			let csvLine = "\(md5),\(filename),\(size),\(photoDateStr),\(modifiedStr),\(widthStr),\(heightStr),\(applePhotoID)"
			
			guard let entry = PhotolalaCatalogService.CatalogEntry(csvLine: csvLine) else {
				continue
			}
			
			catalogEntries.append(entry)
		}
		
		// Step 4: Sort entries by MD5 for consistent ordering
		catalogEntries.sort { $0.md5 < $1.md5 }
		
		// Step 5: Distribute entries into shards
		var shards: [Int: [PhotolalaCatalogService.CatalogEntry]] = [:]
		for i in 0..<16 {
			shards[i] = []
		}
		
		for entry in catalogEntries {
			let shardIndex = getShardIndex(for: entry.md5)
			shards[shardIndex]?.append(entry)
		}
		
		// Step 6: Create shard data
		var shardData: [Int: Data] = [:]
		var shardChecksums: [String: String] = [:]
		
		for (index, entries) in shards {
			// Always include CSV header
			let header = "md5,filename,size,photodate,modified,width,height,applephotoid"
			let csvLines = if entries.isEmpty {
				[header]  // Just header for empty shards
			} else {
				[header] + entries.map { $0.csvLine }
			}
			let csvContent = csvLines.joined(separator: "\n")
			let data = csvContent.data(using: .utf8) ?? Data()
			shardData[index] = data
			
			// Calculate checksum
			let hash = SHA256.hash(data: data)
			let checksum = hash.compactMap { String(format: "%02x", $0) }.joined()
			shardChecksums[String(index)] = checksum
		}
		
		// Step 7: Create manifest
		let manifest = PhotolalaCatalogService.CatalogManifest(
			version: "5.1", // Updated for Apple Photo ID support
			directoryUUID: UUID().uuidString,
			created: Date(),
			modified: Date(),
			shardChecksums: shardChecksums,
			photoCount: catalogEntries.count
		)
		
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let manifestData = try encoder.encode(manifest)
		
		print("Generated catalog with \(catalogEntries.count) entries across 16 shards")
		
		return (manifest: manifestData, shards: shardData)
	}
	
	/// Upload generated catalog to S3
	func uploadCatalog(for userId: String, manifest: Data, shards: [Int: Data]) async throws {
		print("Uploading catalog for user: \(userId)")
		
		// Upload manifest (v5.1 structure)
		let manifestKey = "catalogs/\(userId)/.photolala/manifest.plist"
		try await uploadData(manifest, to: manifestKey)
		
		// Upload shards (v5.1 structure)
		for (index, data) in shards {
			let shardKey = "catalogs/\(userId)/.photolala/\(String(format: "%x", index)).csv"
			try await uploadData(data, to: shardKey)
		}
		
		print("Catalog upload complete")
	}
	
	/// Generate and upload catalog in one operation
	func generateAndUploadCatalog(for userId: String) async throws {
		let (manifest, shards) = try await generateCatalog(for: userId)
		try await uploadCatalog(for: userId, manifest: manifest, shards: shards)
	}
	
	// MARK: - Private Methods
	
	private func listUserPhotos(userId: String) async throws -> [S3ClientTypes.Object] {
		// Try new path structure first
		var input = ListObjectsV2Input(
			bucket: bucketName,
			prefix: "photos/\(userId)/"
		)
		
		var output = try await s3Client.listObjectsV2(input: input)
		var photos = output.contents ?? []
		
		// If no photos found, try old path structure
		if photos.isEmpty {
			print("No photos found in new path, trying old path: users/\(userId)/photos/")
			input = ListObjectsV2Input(
				bucket: bucketName,
				prefix: "users/\(userId)/photos/"
			)
			output = try await s3Client.listObjectsV2(input: input)
			photos = output.contents ?? []
		}
		
		return photos
	}
	
	private func listUserMetadata(userId: String) async throws -> [String: PhotoMetadataInfo] {
		// Try new path structure first
		var input = ListObjectsV2Input(
			bucket: bucketName,
			prefix: "metadata/\(userId)/"
		)
		
		var output = try await s3Client.listObjectsV2(input: input)
		var objects = output.contents ?? []
		
		// If no metadata found, try old path structure
		if objects.isEmpty {
			print("No metadata found in new path, trying old path: users/\(userId)/metadata/")
			input = ListObjectsV2Input(
				bucket: bucketName,
				prefix: "users/\(userId)/metadata/"
			)
			output = try await s3Client.listObjectsV2(input: input)
			objects = output.contents ?? []
		}
		
		var metadataMap: [String: PhotoMetadataInfo] = [:]
		
		// Download metadata files in parallel
		await withTaskGroup(of: (String, PhotoMetadataInfo?).self) { group in
			for object in objects {
				guard let key = object.key else { continue }
				
				group.addTask {
					do {
						let metadata = try await self.downloadMetadata(key: key)
						return (key, metadata)
					} catch {
						print("Failed to download metadata for \(key): \(error)")
						return (key, nil)
					}
				}
			}
			
			for await (key, metadata) in group {
				if let metadata = metadata {
					metadataMap[key] = metadata
				}
			}
		}
		
		return metadataMap
	}
	
	private func downloadMetadata(key: String) async throws -> PhotoMetadataInfo? {
		let input = GetObjectInput(
			bucket: bucketName,
			key: key
		)
		
		let output = try await s3Client.getObject(input: input)
		
		guard let body = output.body else { return nil }
		
		let data: Data
		switch body {
		case .data(let bodyData):
			data = bodyData ?? Data()
		case .stream(let stream):
			var result = Data()
			while true {
				guard let chunk = try await stream.readAsync(upToCount: 65536) else {
					break
				}
				result.append(chunk)
			}
			data = result
		case .noStream:
			return nil
		@unknown default:
			return nil
		}
		
		// Decode plist - try PhotoMetadata first (actual format)
		do {
			let photoMetadata = try PropertyListDecoder().decode(PhotoMetadata.self, from: data)
			
			// Extract filename from key (format: metadata/{userId}/{md5}.plist)
			let components = key.split(separator: "/")
			let filename = components.last?.replacingOccurrences(of: ".plist", with: "") ?? "unknown"
			
			// Convert PhotoMetadata to PhotoMetadataInfo
			// Create location if GPS data exists
			var location: PhotoMetadataInfo.LocationInfo? = nil
			if let lat = photoMetadata.gpsLatitude, let lon = photoMetadata.gpsLongitude {
				location = PhotoMetadataInfo.LocationInfo(
					latitude: lat,
					longitude: lon,
					altitude: nil
				)
			}
			
			return PhotoMetadataInfo(
				fileName: filename,
				fileSize: photoMetadata.fileSize,
				photoDate: photoMetadata.dateTaken,
				modificationDate: photoMetadata.fileModificationDate,
				pixelWidth: photoMetadata.pixelWidth,
				pixelHeight: photoMetadata.pixelHeight,
				cameraMake: photoMetadata.cameraMake,
				cameraModel: photoMetadata.cameraModel,
				lensMake: nil,  // Not in PhotoMetadata
				lensModel: nil,  // Not in PhotoMetadata
				focalLength: nil,  // Not in PhotoMetadata
				aperture: nil,
				shutterSpeed: nil,
				iso: nil,
				location: location,
				applePhotoID: photoMetadata.applePhotoID
			)
		} catch {
			print("Failed to decode metadata: \(error)")
			return nil
		}
	}
	
	private func uploadData(_ data: Data, to key: String) async throws {
		let input = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			key: key,
			storageClass: .standard
		)
		
		_ = try await s3Client.putObject(input: input)
		print("Uploaded: \(key)")
	}
	
	private func extractMD5FromKey(_ key: String?) -> String? {
		// Key format: photos/{userId}/{md5}.dat OR users/{userId}/photos/{md5}.dat
		guard let key = key else { return nil }
		let components = key.split(separator: "/")
		
		// Handle both old and new path structures
		let filename: String
		if components.count == 3 && components[0] == "photos" {
			// New format: photos/{userId}/{md5}.dat
			filename = String(components[2])
		} else if components.count == 4 && components[0] == "users" && components[2] == "photos" {
			// Old format: users/{userId}/photos/{md5}.dat
			filename = String(components[3])
		} else {
			return nil
		}
		
		return filename.replacingOccurrences(of: ".dat", with: "")
	}
	
	private func getShardIndex(for md5: String) -> Int {
		guard let firstChar = md5.first,
			  let hexValue = Int(String(firstChar), radix: 16) else {
			return 0
		}
		return hexValue
	}
	
	func parseShardEntries(from data: Data) throws -> [PhotolalaCatalogService.CatalogEntry] {
		guard let content = String(data: data, encoding: .utf8) else {
			throw CatalogError.invalidData
		}
		
		var entries: [PhotolalaCatalogService.CatalogEntry] = []
		let lines = content.components(separatedBy: .newlines)
		
		for line in lines where !line.isEmpty {
			// The CSV line is already in the correct format for CatalogEntry
			if let entry = PhotolalaCatalogService.CatalogEntry(csvLine: line) {
				entries.append(entry)
			}
		}
		
		return entries
	}
	
	enum CatalogError: Error {
		case invalidData
	}
}

// MARK: - Photo Metadata Info

struct PhotoMetadataInfo: Codable {
	let fileName: String
	let fileSize: Int64
	let photoDate: Date?
	let modificationDate: Date
	let pixelWidth: Int?
	let pixelHeight: Int?
	let cameraMake: String?
	let cameraModel: String?
	let lensMake: String?
	let lensModel: String?
	let focalLength: Double?
	let aperture: Double?
	let shutterSpeed: String?
	let iso: Int?
	let location: LocationInfo?
	let applePhotoID: String?
	
	struct LocationInfo: Codable {
		let latitude: Double
		let longitude: Double
		let altitude: Double?
	}
}