import Foundation
import CryptoKit

/// Service for reading and writing .photolala catalog files
/// Manages 16 sharded CSV files and a binary plist manifest
actor PhotolalaCatalogService {
	
	// MARK: - Types
	
	struct CatalogManifest: Codable {
		let version: Int
		let created: Date
		let modified: Date
		let shardChecksums: [String: String] // shardIndex -> SHA256 checksum
		let photoCount: Int
	}
	
	struct CatalogEntry: Codable {
		let md5: String
		let filename: String
		let size: Int64
		let photoDate: Date
		let modified: Date
		let width: Int?
		let height: Int?
		
		// CSV format: md5,filename,size,photoDate,modified,width,height
		var csvLine: String {
			let widthStr = width.map(String.init) ?? ""
			let heightStr = height.map(String.init) ?? ""
			let photoDateStr = String(Int(photoDate.timeIntervalSince1970))
			let modifiedStr = String(Int(modified.timeIntervalSince1970))
			
			// Escape filename if it contains commas or quotes
			let escapedFilename = filename.contains(",") || filename.contains("\"") 
				? "\"\(filename.replacingOccurrences(of: "\"", with: "\"\""))\"" 
				: filename
			
			return "\(md5),\(escapedFilename),\(size),\(photoDateStr),\(modifiedStr),\(widthStr),\(heightStr)"
		}
		
		// Memberwise initializer for testing
		#if DEBUG
		init(md5: String, filename: String, size: Int64, photoDate: Date, modified: Date, width: Int?, height: Int?) {
			self.md5 = md5
			self.filename = filename
			self.size = size
			self.photoDate = photoDate
			self.modified = modified
			self.width = width
			self.height = height
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
				// Unquoted filename
				guard let value = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")) else { return nil }
				filename = value
				_ = scanner.scanCharacter() // consume comma
			}
			
			// Parse remaining fields
			guard let sizeStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
				  let size = Int64(sizeStr) else { return nil }
			_ = scanner.scanCharacter()
			
			guard let photoDateStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
				  let photoDateTimestamp = TimeInterval(photoDateStr) else { return nil }
			_ = scanner.scanCharacter()
			
			guard let modifiedStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")),
				  let modifiedTimestamp = TimeInterval(modifiedStr) else { return nil }
			_ = scanner.scanCharacter()
			
			// Optional width
			let widthStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: ",")) ?? ""
			let width = widthStr.isEmpty ? nil : Int(widthStr)
			_ = scanner.scanCharacter()
			
			// Optional height
			let heightStr = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "\n")) ?? ""
			let height = heightStr.isEmpty ? nil : Int(heightStr)
			
			self.md5 = md5
			self.filename = filename
			self.size = size
			self.photoDate = Date(timeIntervalSince1970: photoDateTimestamp)
			self.modified = Date(timeIntervalSince1970: modifiedTimestamp)
			self.width = width
			self.height = height
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
		let manifestURL = catalogURL.appendingPathComponent(".photolala")
		let data = try Data(contentsOf: manifestURL)
		let manifest = try PropertyListDecoder().decode(CatalogManifest.self, from: data)
		self.manifest = manifest
		return manifest
	}
	
	/// Save the catalog manifest
	func saveManifest(_ manifest: CatalogManifest) async throws {
		let manifestURL = catalogURL.appendingPathComponent(".photolala")
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
		return String(format: ".photolala#%x", index)
	}
	
	/// Load all entries from a specific shard
	func loadShard(_ index: Int) async throws -> [CatalogEntry] {
		let shardURL = catalogURL.appendingPathComponent(shardFilename(for: index))
		
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
		let shardURL = catalogURL.appendingPathComponent(shardFilename(for: index))
		
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
		if isNew, var manifest = self.manifest {
			self.manifest = CatalogManifest(
				version: manifest.version,
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
		// Create directory if needed
		try FileManager.default.createDirectory(at: catalogURL, withIntermediateDirectories: true)
		
		// Create empty shards
		for index in 0..<16 {
			let shardURL = catalogURL.appendingPathComponent(shardFilename(for: index))
			try "".write(to: shardURL, atomically: true, encoding: .utf8)
		}
		
		// Create manifest
		let manifest = CatalogManifest(
			version: 1,
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
		guard var manifest = self.manifest else { return }
		
		var checksums = manifest.shardChecksums
		checksums[String(shardIndex)] = checksum
		
		self.manifest = CatalogManifest(
			version: manifest.version,
			created: manifest.created,
			modified: Date(),
			shardChecksums: checksums,
			photoCount: manifest.photoCount
		)
		
		isDirty = true
	}
}