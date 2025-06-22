import XCTest
@testable import Photolala

final class PhotolalaCatalogServiceTests: XCTestCase {
	
	var catalogService: PhotolalaCatalogService!
	var tempDir: URL!
	
	override func setUp() async throws {
		try await super.setUp()
		
		// Create temp directory for test catalog
		tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		
		catalogService = PhotolalaCatalogService(catalogURL: tempDir)
	}
	
	override func tearDown() async throws {
		// Clean up temp directory
		try? FileManager.default.removeItem(at: tempDir)
		
		try await super.tearDown()
	}
	
	// MARK: - Shard Index Tests
	
	func testShardIndexCalculation() async {
		let testCases = [
			("0abcdef123456789", 0),
			("1abcdef123456789", 1),
			("9abcdef123456789", 9),
			("aabcdef123456789", 10),
			("fabcdef123456789", 15),
			("gabcdef123456789", 0), // Invalid hex, defaults to 0
			("", 0) // Empty string, defaults to 0
		]
		
		for (md5, expectedIndex) in testCases {
			let index = await catalogService.shardIndex(for: md5)
			XCTAssertEqual(index, expectedIndex, "MD5 \(md5) should map to shard \(expectedIndex)")
		}
	}
	
	func testShardFilename() async {
		let testCases = [
			(0, ".photolala#0"),
			(1, ".photolala#1"),
			(9, ".photolala#9"),
			(10, ".photolala#a"),
			(15, ".photolala#f")
		]
		
		for (index, expectedFilename) in testCases {
			let filename = await catalogService.shardFilename(for: index)
			XCTAssertEqual(filename, expectedFilename)
		}
	}
	
	// MARK: - Empty Catalog Tests
	
	func testCreateEmptyCatalog() async throws {
		try await catalogService.createEmptyCatalog()
		
		// Verify manifest exists
		let manifestURL = tempDir.appendingPathComponent(".photolala")
		XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
		
		// Verify all 16 shards exist
		for index in 0..<16 {
			let shardFilename = String(format: ".photolala#%x", index)
			let shardURL = tempDir.appendingPathComponent(shardFilename)
			XCTAssertTrue(FileManager.default.fileExists(atPath: shardURL.path))
		}
		
		// Load and verify manifest
		let manifest = try await catalogService.loadManifest()
		XCTAssertEqual(manifest.version, 1)
		XCTAssertEqual(manifest.photoCount, 0)
		XCTAssertTrue(manifest.shardChecksums.isEmpty)
	}
	
	// MARK: - Entry CRUD Tests
	
	func testAddAndFindEntry() async throws {
		try await catalogService.createEmptyCatalog()
		
		let entry = PhotolalaCatalogService.CatalogEntry(
			md5: "1234567890abcdef",
			filename: "test.jpg",
			size: 1024,
			photoDate: Date(timeIntervalSince1970: 1000),
			modified: Date(timeIntervalSince1970: 2000),
			width: 800,
			height: 600
		)
		
		// Add entry
		try await catalogService.upsertEntry(entry)
		
		// Find entry
		let found = try await catalogService.findEntry(md5: entry.md5)
		XCTAssertNotNil(found)
		XCTAssertEqual(found?.md5, entry.md5)
		XCTAssertEqual(found?.filename, entry.filename)
		XCTAssertEqual(found?.size, entry.size)
		XCTAssertEqual(found?.width, entry.width)
		XCTAssertEqual(found?.height, entry.height)
	}
	
	func testUpdateEntry() async throws {
		try await catalogService.createEmptyCatalog()
		
		let originalEntry = PhotolalaCatalogService.CatalogEntry(
			md5: "1234567890abcdef",
			filename: "test.jpg",
			size: 1024,
			photoDate: Date(),
			modified: Date(),
			width: 800,
			height: 600
		)
		
		try await catalogService.upsertEntry(originalEntry)
		
		// Update with new data
		let updatedEntry = PhotolalaCatalogService.CatalogEntry(
			md5: "1234567890abcdef", // Same MD5
			filename: "renamed.jpg",
			size: 2048,
			photoDate: Date(),
			modified: Date(),
			width: 1600,
			height: 1200
		)
		
		try await catalogService.upsertEntry(updatedEntry)
		
		// Verify update
		let found = try await catalogService.findEntry(md5: updatedEntry.md5)
		XCTAssertEqual(found?.filename, "renamed.jpg")
		XCTAssertEqual(found?.size, 2048)
		XCTAssertEqual(found?.width, 1600)
	}
	
	func testRemoveEntry() async throws {
		try await catalogService.createEmptyCatalog()
		
		let entry = PhotolalaCatalogService.CatalogEntry(
			md5: "1234567890abcdef",
			filename: "test.jpg",
			size: 1024,
			photoDate: Date(),
			modified: Date(),
			width: nil,
			height: nil
		)
		
		try await catalogService.upsertEntry(entry)
		
		// Verify exists
		XCTAssertNotNil(try await catalogService.findEntry(md5: entry.md5))
		
		// Remove
		try await catalogService.removeEntry(md5: entry.md5)
		
		// Verify removed
		XCTAssertNil(try await catalogService.findEntry(md5: entry.md5))
	}
	
	// MARK: - CSV Parsing Tests
	
	func testCSVParsing() {
		// Test simple case
		let simpleLine = "abc123,photo.jpg,1024,1000,2000,800,600"
		let entry1 = PhotolalaCatalogService.CatalogEntry(csvLine: simpleLine)
		XCTAssertNotNil(entry1)
		XCTAssertEqual(entry1?.md5, "abc123")
		XCTAssertEqual(entry1?.filename, "photo.jpg")
		XCTAssertEqual(entry1?.size, 1024)
		XCTAssertEqual(entry1?.width, 800)
		XCTAssertEqual(entry1?.height, 600)
		
		// Test filename with comma
		let quotedLine = "def456,\"photo, with comma.jpg\",2048,3000,4000,1600,1200"
		let entry2 = PhotolalaCatalogService.CatalogEntry(csvLine: quotedLine)
		XCTAssertNotNil(entry2)
		XCTAssertEqual(entry2?.filename, "photo, with comma.jpg")
		
		// Test filename with quote
		let escapedQuoteLine = "ghi789,\"photo with \"\"quotes\"\".jpg\",4096,5000,6000,,"
		let entry3 = PhotolalaCatalogService.CatalogEntry(csvLine: escapedQuoteLine)
		XCTAssertNotNil(entry3)
		XCTAssertEqual(entry3?.filename, "photo with \"quotes\".jpg")
		XCTAssertNil(entry3?.width)
		XCTAssertNil(entry3?.height)
	}
	
	func testCSVGeneration() {
		let entry = PhotolalaCatalogService.CatalogEntry(
			md5: "abc123",
			filename: "simple.jpg",
			size: 1024,
			photoDate: Date(timeIntervalSince1970: 1000),
			modified: Date(timeIntervalSince1970: 2000),
			width: 800,
			height: 600
		)
		
		let csv = entry.csvLine
		XCTAssertEqual(csv, "abc123,simple.jpg,1024,1000,2000,800,600")
		
		// Test with special characters
		let specialEntry = PhotolalaCatalogService.CatalogEntry(
			md5: "def456",
			filename: "photo, with comma.jpg",
			size: 2048,
			photoDate: Date(timeIntervalSince1970: 3000),
			modified: Date(timeIntervalSince1970: 4000),
			width: nil,
			height: nil
		)
		
		let specialCsv = specialEntry.csvLine
		XCTAssertEqual(specialCsv, "def456,\"photo, with comma.jpg\",2048,3000,4000,,")
	}
	
	// MARK: - Load All Tests
	
	func testLoadAllEntries() async throws {
		try await catalogService.createEmptyCatalog()
		
		// Add entries across different shards
		let entries = [
			PhotolalaCatalogService.CatalogEntry(
				md5: "0abcdef", // Shard 0
				filename: "photo0.jpg",
				size: 1024,
				photoDate: Date(),
				modified: Date(),
				width: nil,
				height: nil
			),
			PhotolalaCatalogService.CatalogEntry(
				md5: "1abcdef", // Shard 1
				filename: "photo1.jpg",
				size: 2048,
				photoDate: Date(),
				modified: Date(),
				width: nil,
				height: nil
			),
			PhotolalaCatalogService.CatalogEntry(
				md5: "fabcdef", // Shard 15
				filename: "photo15.jpg",
				size: 4096,
				photoDate: Date(),
				modified: Date(),
				width: nil,
				height: nil
			)
		]
		
		for entry in entries {
			try await catalogService.upsertEntry(entry)
		}
		
		// Load all
		let allEntries = try await catalogService.loadAllEntries()
		XCTAssertEqual(allEntries.count, 3)
		
		// Verify all entries are present
		let md5Set = Set(allEntries.map { $0.md5 })
		XCTAssertTrue(md5Set.contains("0abcdef"))
		XCTAssertTrue(md5Set.contains("1abcdef"))
		XCTAssertTrue(md5Set.contains("fabcdef"))
	}
	
	// MARK: - Performance Tests
	
	func testPerformanceAddEntries() async throws {
		try await catalogService.createEmptyCatalog()
		
		await measure {
			// Add 1000 entries
			for i in 0..<1000 {
				let md5 = String(format: "%032x", i)
				let entry = PhotolalaCatalogService.CatalogEntry(
					md5: md5,
					filename: "photo\(i).jpg",
					size: Int64(i * 1024),
					photoDate: Date(),
					modified: Date(),
					width: 800,
					height: 600
				)
				
				try? await catalogService.upsertEntry(entry)
			}
		}
	}
	
	// MARK: - Backward Compatibility Tests
	
	func testParseV50CatalogEntry() async throws {
		// Test parsing v5.0 format (7 fields)
		let v50Line = "abc123def456,photo.jpg,1024000,1701234567,1701234568,4000,3000"
		
		guard let entry = PhotolalaCatalogService.CatalogEntry(csvLine: v50Line) else {
			XCTFail("Failed to parse v5.0 catalog entry")
			return
		}
		
		XCTAssertEqual(entry.md5, "abc123def456")
		XCTAssertEqual(entry.filename, "photo.jpg")
		XCTAssertEqual(entry.size, 1024000)
		XCTAssertEqual(entry.photodate, Date(timeIntervalSince1970: 1701234567))
		XCTAssertEqual(entry.modified, Date(timeIntervalSince1970: 1701234568))
		XCTAssertEqual(entry.width, 4000)
		XCTAssertEqual(entry.height, 3000)
		XCTAssertNil(entry.applePhotoID, "v5.0 entry should have nil applePhotoID")
	}
	
	func testParseV51CatalogEntry() async throws {
		// Test parsing v5.1 format (8 fields)
		let v51Line = "abc123def456,photo.jpg,1024000,1701234567,1701234568,4000,3000,A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
		
		guard let entry = PhotolalaCatalogService.CatalogEntry(csvLine: v51Line) else {
			XCTFail("Failed to parse v5.1 catalog entry")
			return
		}
		
		XCTAssertEqual(entry.md5, "abc123def456")
		XCTAssertEqual(entry.filename, "photo.jpg")
		XCTAssertEqual(entry.size, 1024000)
		XCTAssertEqual(entry.photodate, Date(timeIntervalSince1970: 1701234567))
		XCTAssertEqual(entry.modified, Date(timeIntervalSince1970: 1701234568))
		XCTAssertEqual(entry.width, 4000)
		XCTAssertEqual(entry.height, 3000)
		XCTAssertEqual(entry.applePhotoID, "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
	}
	
	func testParseV51CatalogEntryWithEmptyApplePhotoID() async throws {
		// Test parsing v5.1 format with empty applePhotoID
		let v51Line = "abc123def456,photo.jpg,1024000,1701234567,1701234568,4000,3000,"
		
		guard let entry = PhotolalaCatalogService.CatalogEntry(csvLine: v51Line) else {
			XCTFail("Failed to parse v5.1 catalog entry with empty applePhotoID")
			return
		}
		
		XCTAssertNil(entry.applePhotoID, "Empty applePhotoID should be parsed as nil")
	}
	
	func testWriteV51CatalogEntry() async throws {
		// Test writing v5.1 format
		#if DEBUG
		let entry = PhotolalaCatalogService.CatalogEntry(
			md5: "abc123def456",
			filename: "photo.jpg",
			size: 1024000,
			photodate: Date(timeIntervalSince1970: 1701234567),
			modified: Date(timeIntervalSince1970: 1701234568),
			width: 4000,
			height: 3000,
			applePhotoID: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
		)
		#else
		// If not in DEBUG mode, parse from CSV
		let csvLine = "abc123def456,photo.jpg,1024000,1701234567,1701234568,4000,3000,A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
		guard let entry = PhotolalaCatalogService.CatalogEntry(csvLine: csvLine) else {
			XCTFail("Failed to create catalog entry")
			return
		}
		#endif
		
		let csvLine = entry.csvLine
		XCTAssertEqual(csvLine, "abc123def456,photo.jpg,1024000,1701234567,1701234568,4000,3000,A1B2C3D4-E5F6-7890-ABCD-EF1234567890")
	}
	
	func testWriteV51CatalogEntryWithoutApplePhotoID() async throws {
		// Test writing v5.1 format without applePhotoID
		#if DEBUG
		let entry = PhotolalaCatalogService.CatalogEntry(
			md5: "abc123def456",
			filename: "photo.jpg",
			size: 1024000,
			photodate: Date(timeIntervalSince1970: 1701234567),
			modified: Date(timeIntervalSince1970: 1701234568),
			width: 4000,
			height: 3000,
			applePhotoID: nil
		)
		#else
		// If not in DEBUG mode, parse from CSV
		let csvLine = "abc123def456,photo.jpg,1024000,1701234567,1701234568,4000,3000,"
		guard let entry = PhotolalaCatalogService.CatalogEntry(csvLine: csvLine) else {
			XCTFail("Failed to create catalog entry")
			return
		}
		#endif
		
		let csvLine = entry.csvLine
		XCTAssertEqual(csvLine, "abc123def456,photo.jpg,1024000,1701234567,1701234568,4000,3000,")
	}
}