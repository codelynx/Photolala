//
//  S3CloudBrowsingServiceTests.swift
//  PhotolalaTests
//
//  Tests for S3 cloud browsing functionality
//

import XCTest
import CryptoKit
@testable import Photolala

final class S3CloudBrowsingServiceTests: XCTestCase {

	private var s3Service: S3Service!
	private var browsingService: S3CloudBrowsingService!
	private let testUserID = "test-browse-user"

	override func setUpWithError() throws {
		try super.setUpWithError()
	}

	override func tearDownWithError() throws {
		s3Service = nil
		browsingService = nil
		try super.tearDownWithError()
	}

	@MainActor
	func testCatalogDownloadAndLoad() async throws {
		s3Service = try await S3Service.forEnvironment(.development)

		// First, upload a test catalog
		let csvContent = """
			photo_head_md5,file_size,photo_md5,photo_date,format
			abc123,1024,def456,1699999999,JPEG
			ghi789,2048,jkl012,1699999998,PNG
			"""

		guard let csvData = csvContent.data(using: .utf8) else {
			XCTFail("Failed to create CSV data")
			return
		}

		// Calculate catalog MD5
		let catalogMD5 = computeMD5(for: csvData)

		// Upload test catalog
		try await s3Service.uploadCatalog(
			csvData: csvData,
			catalogMD5: catalogMD5,
			userID: testUserID
		)

		// Update pointer
		try await s3Service.updateCatalogPointer(
			catalogMD5: catalogMD5,
			userID: testUserID
		)

		// Now test browsing service
		browsingService = S3CloudBrowsingService(s3Service: s3Service)

		// Load catalog
		let database = try await browsingService.loadCloudCatalog(userID: testUserID)
		let entries = await database.getAllEntries()

		XCTAssertEqual(entries.count, 2, "Should have 2 entries from test catalog")
		XCTAssertEqual(entries.first?.photoHeadMD5, "abc123")
		XCTAssertEqual(entries.first?.format, .jpeg)
	}

	func testThumbnailCaching() async throws {
		s3Service = try await S3Service.forEnvironment(.development)
		browsingService = S3CloudBrowsingService(s3Service: s3Service)

		// Upload a test thumbnail
		let thumbnailData = Data("fake thumbnail data".utf8)
		let md5 = "test123456"

		try await s3Service.uploadThumbnail(
			data: thumbnailData,
			md5: md5,
			userID: testUserID
		)

		// First load - downloads from S3
		let data1 = await browsingService.loadThumbnail(
			photoMD5: md5,
			userID: testUserID
		)
		XCTAssertNotNil(data1, "Should download thumbnail from S3")

		// Second load - should use cache (faster)
		let startTime = Date()
		let data2 = await browsingService.loadThumbnail(
			photoMD5: md5,
			userID: testUserID
		)
		let loadTime = Date().timeIntervalSince(startTime)

		XCTAssertNotNil(data2, "Should load thumbnail from cache")
		XCTAssertEqual(data1, data2, "Cached data should match original")
		XCTAssertLessThan(loadTime, 0.1, "Cached load should be fast")
	}

	@MainActor
	func testCloudPhotoItem() async throws {
		// Test CloudPhotoItem creation
		let entry = CatalogEntry(
			photoHeadMD5: "abc123",
			fileSize: 1024,
			photoMD5: "def456",
			photoDate: Date(),
			format: .jpeg
		)

		let cloudItem = CloudPhotoItem(
			entry: entry,
			userID: testUserID
		)

		XCTAssertEqual(cloudItem.id, "def456")
		XCTAssertEqual(cloudItem.format, .jpeg)
		XCTAssertEqual(cloudItem.fileSize, 1024)
		XCTAssertTrue(cloudItem.hasThumbnail)
	}

	func testPrefetchThumbnails() async throws {
		s3Service = try await S3Service.forEnvironment(.development)
		browsingService = S3CloudBrowsingService(s3Service: s3Service)

		// Create test MD5s
		let md5List = (1...5).map { "test-md5-\($0)" }

		// Upload test thumbnails
		for md5 in md5List {
			let data = Data("thumb \(md5)".utf8)
			try await s3Service.uploadThumbnail(
				data: data,
				md5: md5,
				userID: testUserID
			)
		}

		// Prefetch thumbnails
		await browsingService.prefetchThumbnails(
			photoMD5s: md5List,
			userID: testUserID
		)

		// Verify they're cached (should be fast)
		for md5 in md5List.prefix(3) {
			let startTime = Date()
			let data = await browsingService.loadThumbnail(
				photoMD5: md5,
				userID: testUserID
			)
			let loadTime = Date().timeIntervalSince(startTime)

			XCTAssertNotNil(data)
			XCTAssertLessThan(loadTime, 0.1, "Prefetched thumbnails should load quickly")
		}
	}

	func testCacheClear() async throws {
		s3Service = try await S3Service.forEnvironment(.development)
		browsingService = S3CloudBrowsingService(s3Service: s3Service)

		// Load some data
		let _ = try? await browsingService.loadCloudCatalog(userID: testUserID)

		let isLoaded = await browsingService.isCatalogLoaded()
		XCTAssertTrue(isLoaded)

		// Clear cache
		await browsingService.clearCache()

		let isLoadedAfterClear = await browsingService.isCatalogLoaded()
		XCTAssertFalse(isLoadedAfterClear)

		let userID = await browsingService.getCurrentUserID()
		XCTAssertNil(userID)
	}

	// MARK: - Helpers

	private func computeMD5(for data: Data) -> String {
		let digest = Insecure.MD5.hash(data: data)
		return digest.map { String(format: "%02x", $0) }.joined()
	}
}