//
//  SwiftDataCatalogTests.swift
//  PhotolalaTests
//
//  Tests for SwiftData catalog implementation
//

import XCTest
import SwiftData
@testable import Photolala

final class SwiftDataCatalogTests: XCTestCase {
	var catalogService: PhotolalaCatalogServiceV2!
	var testDirectory: URL!
	
	override func setUp() async throws {
		try await super.setUp()
		
		// Create test catalog service
		catalogService = try await MainActor.run {
			try PhotolalaCatalogServiceV2()
		}
		
		// Create test directory
		let tempDir = FileManager.default.temporaryDirectory
		testDirectory = tempDir.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
	}
	
	override func tearDown() async throws {
		// Clean up test directory
		try? FileManager.default.removeItem(at: testDirectory)
		
		catalogService = nil
		testDirectory = nil
		
		try await super.tearDown()
	}
	
	func testCreateCatalog() async throws {
		// Create catalog
		let catalog = try await catalogService.loadPhotoCatalog(for: testDirectory)
		
		XCTAssertEqual(catalog.directoryPath, testDirectory.path)
		XCTAssertEqual(catalog.version, "6.0")
		XCTAssertEqual(catalog.photoCount, 0)
		
		// Verify all 16 shards exist
		XCTAssertNotNil(catalog.shard0)
		XCTAssertNotNil(catalog.shard1)
		XCTAssertNotNil(catalog.shard2)
		XCTAssertNotNil(catalog.shard3)
		XCTAssertNotNil(catalog.shard4)
		XCTAssertNotNil(catalog.shard5)
		XCTAssertNotNil(catalog.shard6)
		XCTAssertNotNil(catalog.shard7)
		XCTAssertNotNil(catalog.shard8)
		XCTAssertNotNil(catalog.shard9)
		XCTAssertNotNil(catalog.shardA)
		XCTAssertNotNil(catalog.shardB)
		XCTAssertNotNil(catalog.shardC)
		XCTAssertNotNil(catalog.shardD)
		XCTAssertNotNil(catalog.shardE)
		XCTAssertNotNil(catalog.shardF)
	}
	
	func testShardForMD5() async throws {
		let catalog = try await catalogService.loadPhotoCatalog(for: testDirectory)
		
		// Test each hex digit maps to correct shard
		XCTAssertEqual(catalog.shard(for: "0abcdef")?.index, 0)
		XCTAssertEqual(catalog.shard(for: "1abcdef")?.index, 1)
		XCTAssertEqual(catalog.shard(for: "2abcdef")?.index, 2)
		XCTAssertEqual(catalog.shard(for: "3abcdef")?.index, 3)
		XCTAssertEqual(catalog.shard(for: "4abcdef")?.index, 4)
		XCTAssertEqual(catalog.shard(for: "5abcdef")?.index, 5)
		XCTAssertEqual(catalog.shard(for: "6abcdef")?.index, 6)
		XCTAssertEqual(catalog.shard(for: "7abcdef")?.index, 7)
		XCTAssertEqual(catalog.shard(for: "8abcdef")?.index, 8)
		XCTAssertEqual(catalog.shard(for: "9abcdef")?.index, 9)
		XCTAssertEqual(catalog.shard(for: "aabcdef")?.index, 10)
		XCTAssertEqual(catalog.shard(for: "babcdef")?.index, 11)
		XCTAssertEqual(catalog.shard(for: "cabcdef")?.index, 12)
		XCTAssertEqual(catalog.shard(for: "dabcdef")?.index, 13)
		XCTAssertEqual(catalog.shard(for: "eabcdef")?.index, 14)
		XCTAssertEqual(catalog.shard(for: "fabcdef")?.index, 15)
		
		// Test uppercase works too
		XCTAssertEqual(catalog.shard(for: "AABCDEF")?.index, 10)
		XCTAssertEqual(catalog.shard(for: "FABCDEF")?.index, 15)
	}
	
	func testAddEntry() async throws {
		let catalog = try await catalogService.loadPhotoCatalog(for: testDirectory)
		
		// Create test entry
		let entry = CatalogPhotoEntry(
			md5: "a1b2c3d4e5f6",
			filename: "test.jpg",
			fileSize: 1024,
			photoDate: Date(),
			fileModifiedDate: Date()
		)
		
		// Add entry
		try await MainActor.run {
			try catalogService.upsertEntry(entry, in: catalog)
		}
		
		// Verify entry was added
		let found = try await catalogService.findPhotoEntry(md5: "a1b2c3d4e5f6")
		XCTAssertNotNil(found)
		XCTAssertEqual(found?.filename, "test.jpg")
		XCTAssertEqual(found?.fileSize, 1024)
		
		// Verify shard was marked modified
		XCTAssertTrue(catalog.shardA?.isModified ?? false)
		XCTAssertEqual(catalog.photoCount, 1)
	}
	
	func testCSVExport() async throws {
		let catalog = try await catalogService.loadPhotoCatalog(for: testDirectory)
		
		// Add multiple entries to same shard
		let entries = [
			CatalogPhotoEntry(md5: "a111111", filename: "photo1.jpg", fileSize: 1000, photoDate: Date(), fileModifiedDate: Date()),
			CatalogPhotoEntry(md5: "a222222", filename: "photo2.jpg", fileSize: 2000, photoDate: Date(), fileModifiedDate: Date()),
			CatalogPhotoEntry(md5: "a333333", filename: "photo3.jpg", fileSize: 3000, photoDate: Date(), fileModifiedDate: Date())
		]
		
		for entry in entries {
			try await MainActor.run {
				try catalogService.upsertEntry(entry, in: catalog)
			}
		}
		
		// Export shard A (index 10)
		let csv = try await catalogService.exportShardToCSV(shard: catalog.shardA!)
		
		// Verify CSV contains all entries
		XCTAssertTrue(csv.contains("a111111"))
		XCTAssertTrue(csv.contains("a222222"))
		XCTAssertTrue(csv.contains("a333333"))
		XCTAssertTrue(csv.contains("photo1.jpg"))
		XCTAssertTrue(csv.contains("photo2.jpg"))
		XCTAssertTrue(csv.contains("photo3.jpg"))
		
		// Verify entries are sorted by MD5
		let lines = csv.components(separatedBy: "\n")
		XCTAssertEqual(lines.count, 3)
		XCTAssertTrue(lines[0].hasPrefix("a111111"))
		XCTAssertTrue(lines[1].hasPrefix("a222222"))
		XCTAssertTrue(lines[2].hasPrefix("a333333"))
	}
	
	func testCatalogEntryCSVParsing() throws {
		// Test basic CSV parsing
		let csv = "abc123,test.jpg,1024,1609459200,1609459200,800,600,apple-photo-123"
		let entry = CatalogEntry(csvLine: csv)
		
		XCTAssertNotNil(entry)
		XCTAssertEqual(entry?.md5, "abc123")
		XCTAssertEqual(entry?.filename, "test.jpg")
		XCTAssertEqual(entry?.size, 1024)
		XCTAssertEqual(entry?.width, 800)
		XCTAssertEqual(entry?.height, 600)
		XCTAssertEqual(entry?.applePhotoID, "apple-photo-123")
		
		// Test quoted filename
		let csvQuoted = "abc123,\"test,file.jpg\",1024,1609459200,1609459200,800,600,"
		let entryQuoted = CatalogEntry(csvLine: csvQuoted)
		
		XCTAssertNotNil(entryQuoted)
		XCTAssertEqual(entryQuoted?.filename, "test,file.jpg")
		XCTAssertNil(entryQuoted?.applePhotoID)
		
		// Test escaped quotes
		let csvEscaped = "abc123,\"test\"\"file\"\".jpg\",1024,1609459200,1609459200,,,"
		let entryEscaped = CatalogEntry(csvLine: csvEscaped)
		
		XCTAssertNotNil(entryEscaped)
		XCTAssertEqual(entryEscaped?.filename, "test\"file\".jpg")
		XCTAssertNil(entryEscaped?.width)
		XCTAssertNil(entryEscaped?.height)
	}
}