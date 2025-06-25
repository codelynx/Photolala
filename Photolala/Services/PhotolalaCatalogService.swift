import Foundation
import CryptoKit

/// Service for reading and writing .photolala catalog files
/// Manages 16 sharded CSV files and a binary plist manifest
actor PhotolalaCatalogService {
	
	// MARK: - Types
	
	struct CatalogManifest: Codable {
		let version: String // "4.0" or "5.0"
		let directoryUUID: String? // v5.0 only
		let created: Date
		let modified: Date
		let shardChecksums: [String: String] // shardIndex -> SHA256 checksum
		let photoCount: Int
		
		// Support both old and new field names
		enum CodingKeys: String, CodingKey {
			case version
			case directoryUUID = "directory-uuid"
			case created
			case modified
			case shardChecksums
			case photoCount
		}
	}
	
	struct CatalogEntry: Codable {
		let md5: String
		let filename: String
		let size: Int64
		let photodate: Date
		let modified: Date
		let width: Int?
		let height: Int?
		let applePhotoID: String? // New field for v5.1
		
		// CSV format: md5,filename,size,photodate,modified,width,height[,applePhotoID] (v5.1)
		var csvLine: String {
			let widthStr = width.map(String.init) ?? ""
			let heightStr = height.map(String.init) ?? ""
			let photodateStr = String(Int(photodate.timeIntervalSince1970))
			let modifiedStr = String(Int(modified.timeIntervalSince1970))
			let applePhotoIDStr = applePhotoID ?? ""
			
			// Escape filename if it contains commas or quotes
			let escapedFilename = filename.contains(",") || filename.contains("\"") 
				? "\"\(filename.replacingOccurrences(of: "\"", with: "\"\""))\"" 
				: filename
			
			return "\(md5),\(escapedFilename),\(size),\(photodateStr),\(modifiedStr),\(widthStr),\(heightStr),\(applePhotoIDStr)"
		}
		
		// Memberwise initializer for testing
		#if DEBUG
		init(md5: String, filename: String, size: Int64, photodate: Date, modified: Date, width: Int?, height: Int?, applePhotoID: String? = nil) {
			self.md5 = md5
			self.filename = filename
			self.size = size
			self.photodate = photodate
			self.modified = modified
			self.width = width
			self.height = height
			self.applePhotoID = applePhotoID
		}
		#endif
		
		// Parse from CSV line
		init?(csvLine: String) {
			let scanner = Scanner(string: csvLine)
			scanner.charactersToBeSkipped = nil
			
			// Parse MD5
			guard let md5 = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")) else { return nil }
			_ = scanner.scanCharacter() // consume comma
			
			// Parse filename (handle quoted values)
			let filename: String
			let currentIndex = scanner.currentIndex
			if scanner.scanCharacter() == "\"" {
				// Quoted filename - scan until closing quote
				var quotedValue = ""
				while !scanner.isAtEnd {
					if let chunk = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "\"")) {
						quotedValue += chunk
					}
					if scanner.scanCharacter() == "\"" {
						// Check if it's an escaped quote
						if scanner.scanCharacter() == "\"" {
							quotedValue += "\""
						} else {
							// End of quoted value
							_ = scanner.scanCharacter() // consume comma
							break
						}
					}
				}
				filename = quotedValue
			} else {
				// Unquoted filename - need to backtrack since we consumed a character
				scanner.currentIndex = currentIndex
				guard let value = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")) else { return nil }
				filename = value
				_ = scanner.scanCharacter() // consume comma
			}
			
			// Parse remaining fields
			guard let sizeStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
				  let size = Int64(sizeStr) else { return nil }
			_ = scanner.scanCharacter()
			
			guard let photodateStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
				  let photodateTimestamp = TimeInterval(photodateStr) else { return nil }
			_ = scanner.scanCharacter()
			
			guard let modifiedStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
				  let modifiedTimestamp = TimeInterval(modifiedStr) else { return nil }
			_ = scanner.scanCharacter()
			
			// Optional width
			let widthStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")) ?? ""
			let width = widthStr.isEmpty ? nil : Int(widthStr)
			
			// Optional height and applePhotoID
			let height: Int?
			let applePhotoID: String?
			
			if scanner.scanCharacter() != nil { // consume comma if present
				// Height field exists
				let heightStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",\n")) ?? ""
				height = heightStr.isEmpty ? nil : Int(heightStr)
				
				// Check for optional applePhotoID (v5.1 format)
				if scanner.scanCharacter() != nil { // consume comma if present
					let applePhotoIDStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "\n")) ?? ""
					applePhotoID = applePhotoIDStr.isEmpty ? nil : applePhotoIDStr
				} else {
					applePhotoID = nil
				}
			} else {
				// No comma after width, so no height or applePhotoID
				height = nil
				applePhotoID = nil
			}
			
			self.md5 = md5
			self.filename = filename
			self.size = size
			self.photodate = Date(timeIntervalSince1970: photodateTimestamp)
			self.modified = Date(timeIntervalSince1970: modifiedTimestamp)
			self.width = width
			self.height = height
			self.applePhotoID = applePhotoID
		}
	}
	
	// MARK: - Properties
	
	private let catalogURL: URL
	private var manifest: CatalogManifest?
	private var isDirty = false
	
	// MARK: - Initialization
	
	init(catalogURL: URL) {
		self.catalogURL = catalogURL
	}
	
	// MARK: - Public Methods
	
	/// Load the catalog manifest
	func loadManifest() async throws -> CatalogManifest {
		let manifestURL = catalogURL.appendingPathComponent(".photolala").appendingPathComponent("manifest.plist")
		guard FileManager.default.fileExists(atPath: manifestURL.path) else {
			throw CatalogError.manifestNotFound
		}
		
		let data = try Data(contentsOf: manifestURL)
		let manifest = try PropertyListDecoder().decode(CatalogManifest.self, from: data)
		self.manifest = manifest
		return manifest
	}
	
	enum CatalogError: Error {
		case manifestNotFound
	}
	
	/// Save the catalog manifest
	func saveManifest(_ manifest: CatalogManifest) async throws {
		// Create .photolala directory if needed
		let catalogDir = catalogURL.appendingPathComponent(".photolala")
		try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
		
		let manifestURL = catalogDir.appendingPathComponent("manifest.plist")
		let encoder = PropertyListEncoder()
		encoder.outputFormat = .binary
		let data = try encoder.encode(manifest)
		try data.write(to: manifestURL)
		self.manifest = manifest
		self.isDirty = false
	}
	
	/// Get the shard index for a given MD5 hash (0-15)
	func shardIndex(for md5: String) -> Int {
		guard let firstChar = md5.first,
			  let hexValue = Int(String(firstChar), radix: 16) else {
			return 0
		}
		return hexValue
	}
	
	/// Get the shard filename for a given index
	func shardFilename(for index: Int) -> String {
		return String(format: "%x.csv", index)
	}
	
	/// Get the full path to a shard file
	func shardURL(for index: Int) -> URL {
		let filename = shardFilename(for: index)
		return catalogURL.appendingPathComponent(".photolala").appendingPathComponent(filename)
	}
	
	/// Load all entries from a specific shard
	func loadShard(_ index: Int) async throws -> [CatalogEntry] {
		let shardURL = self.shardURL(for: index)
		
		guard FileManager.default.fileExists(atPath: shardURL.path) else {
			return []
		}
		
		let content = try String(contentsOf: shardURL, encoding: .utf8)
		let lines = content.components(separatedBy: .newlines)
		
		return lines.compactMap { line in
			guard !line.isEmpty else { return nil }
			return CatalogEntry(csvLine: line)
		}
	}
	
	/// Save entries to a specific shard
	func saveShard(_ index: Int, entries: [CatalogEntry]) async throws {
		let shardURL = self.shardURL(for: index)
		
		let content = entries
			.map { $0.csvLine }
			.joined(separator: "\n")
		
		try content.write(to: shardURL, atomically: true, encoding: .utf8)
		
		// Update checksum in manifest
		let checksum = calculateChecksum(for: content)
		await updateManifestChecksum(shardIndex: index, checksum: checksum)
	}
	
	/// Load all entries from all shards
	func loadAllEntries() async throws -> [CatalogEntry] {
		let tasks = (0..<16).map { index in
			Task {
				try await loadShard(index)
			}
		}
		
		var allEntries: [CatalogEntry] = []
		for task in tasks {
			let shardEntries = try await task.value
			allEntries.append(contentsOf: shardEntries)
		}
		
		return allEntries
	}
	
	/// Add or update a catalog entry
	func upsertEntry(_ entry: CatalogEntry) async throws {
		let index = shardIndex(for: entry.md5)
		var entries = try await loadShard(index)
		
		// Check if this is a new entry
		let isNew = !entries.contains { $0.md5 == entry.md5 }
		
		// Remove existing entry if present
		entries.removeAll { $0.md5 == entry.md5 }
		
		// Add new entry
		entries.append(entry)
		
		// Save shard
		try await saveShard(index, entries: entries)
		
		// Update photo count if new entry
		if isNew, let manifest = self.manifest {
			self.manifest = CatalogManifest(
				version: manifest.version,
				directoryUUID: manifest.directoryUUID,
				created: manifest.created,
				modified: Date(),
				shardChecksums: manifest.shardChecksums,
				photoCount: manifest.photoCount + 1
			)
			isDirty = true
		}
	}
	
	/// Save the manifest if it's dirty
	func saveManifestIfNeeded() async throws {
		if isDirty, let manifest = self.manifest {
			try await saveManifest(manifest)
		}
	}
	
	/// Remove an entry by MD5
	func removeEntry(md5: String) async throws {
		let index = shardIndex(for: md5)
		var entries = try await loadShard(index)
		
		let originalCount = entries.count
		entries.removeAll { $0.md5 == md5 }
		
		if entries.count < originalCount {
			try await saveShard(index, entries: entries)
			isDirty = true
		}
	}
	
	/// Find an entry by MD5
	func findEntry(md5: String) async throws -> CatalogEntry? {
		let index = shardIndex(for: md5)
		let entries = try await loadShard(index)
		return entries.first { $0.md5 == md5 }
	}
	
	/// Create a new empty catalog
	func createEmptyCatalog() async throws {
		// Create .photolala directory
		let catalogDir = catalogURL.appendingPathComponent(".photolala")
		try FileManager.default.createDirectory(at: catalogDir, withIntermediateDirectories: true)
		
		// Create empty shards
		for index in 0..<16 {
			let shardURL = self.shardURL(for: index)
			try "".write(to: shardURL, atomically: true, encoding: .utf8)
		}
		
		// Create manifest with UUID
		let manifest = CatalogManifest(
			version: "5.0",
			directoryUUID: UUID().uuidString,
			created: Date(),
			modified: Date(),
			shardChecksums: [:],
			photoCount: 0
		)
		
		try await saveManifest(manifest)
	}
	
	// MARK: - Private Methods
	
	private func calculateChecksum(for content: String) -> String {
		let data = Data(content.utf8)
		let hash = SHA256.hash(data: data)
		return hash.compactMap { String(format: "%02x", $0) }.joined()
	}
	
	private func updateManifestChecksum(shardIndex: Int, checksum: String) async {
		guard let manifest = self.manifest else { return }
		
		var checksums = manifest.shardChecksums
		checksums[String(shardIndex)] = checksum
		
		self.manifest = CatalogManifest(
			version: manifest.version,
			directoryUUID: manifest.directoryUUID,
			created: manifest.created,
			modified: Date(),
			shardChecksums: checksums,
			photoCount: manifest.photoCount
		)
		
		isDirty = true
	}
}