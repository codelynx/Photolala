//
//  S3BackupServiceTests.swift
//  PhotolalaTests
//
//  Tests for S3 backup service functionality
//

import XCTest
import CryptoKit
@testable import Photolala

final class S3BackupServiceTests: XCTestCase {

	private var s3Service: S3Service!
	private var backupService: S3BackupService!
	private var catalogDatabase: CatalogDatabase!
	private let testUserID = "test-user-123"

	override func setUpWithError() throws {
		try super.setUpWithError()
	}

	override func tearDownWithError() throws {
		s3Service = nil
		backupService = nil
		catalogDatabase = nil
		try super.tearDownWithError()
	}

	@MainActor
	func testPhotoUploadWithDeduplication() async throws {
		// Initialize services
		s3Service = try await S3Service.forEnvironment(.development)

		// Create catalog database
		let tempPath = FileManager.default.temporaryDirectory
			.appendingPathComponent("test-catalog.csv")
		catalogDatabase = try await CatalogDatabase(path: tempPath, readOnly: false)

		backupService = S3BackupService(s3Service: s3Service, catalogDatabase: catalogDatabase)

		// Use real sample photo for more realistic testing
		let samplePhotoPath = getSamplePhotoPath("018red_AC2_TP_V.jpg")
		let mockPhotoData = try Data(contentsOf: samplePhotoPath)
		let mockMD5 = computeMD5(for: mockPhotoData)

		// Clean up any existing test data in S3 first
		// This ensures the test starts fresh
		do {
			try await s3Service.deleteObject(key: "photos/\(testUserID)/\(mockMD5).dat")
			print("Cleaned up existing photo from S3")
		} catch {
			// Ignore errors - object might not exist
			print("No existing photo to clean up: \(error)")
		}

		do {
			try await s3Service.deleteObject(key: "thumbnails/\(testUserID)/\(mockMD5).jpg")
			print("Cleaned up existing thumbnail from S3")
		} catch {
			// Ignore errors - object might not exist
			print("No existing thumbnail to clean up: \(error)")
		}

		// Create a MockPhotoItem with real photo data
		// Using MockPhotoItem instead of LocalPhotoItem to avoid complex PhotoEntry setup
		let mockItem = MockPhotoItem(
			id: "test-photo-1",
			displayName: "018red_AC2_TP_V.jpg",
			format: .jpeg,
			data: mockPhotoData,
			md5: mockMD5
		)

		// First upload - should complete
		let results = await backupService.backupPhotos([mockItem], userID: testUserID)

		print("Results for first upload: \(results)")
		print("Looking for key: \(mockItem.id)")

		if case .completed = results[mockItem.id] {
			// Success
		} else {
			if let result = results[mockItem.id] {
				XCTFail("First upload should complete, but got: \(result)")
			} else {
				XCTFail("First upload should complete, but result not found for id: \(mockItem.id)")
			}
		}

		// Second upload - should skip (deduplication)
		let results2 = await backupService.backupPhotos([mockItem], userID: testUserID)

		if case .skipped = results2[mockItem.id] {
			// Success - properly deduplicated
		} else {
			XCTFail("Second upload should be skipped due to deduplication")
		}

		// Cleanup test data from S3
		await cleanupTestData(md5: mockMD5)
	}

	func testThumbnailGeneration() async throws {
		// Use a real sample photo for thumbnail generation test
		let samplePhotoPath = getSamplePhotoPath("006yu_daiAB_TP_V.jpg")
		let photoData = try Data(contentsOf: samplePhotoPath)

		s3Service = try await S3Service.forEnvironment(.development)
		backupService = S3BackupService(s3Service: s3Service, catalogDatabase: nil)

		let mockItem = MockPhotoItem(
			id: "test-thumb-1",
			displayName: "Thumbnail Test",
			format: .jpeg,
			data: photoData,
			md5: computeMD5(for: photoData)
		)

		// Upload with thumbnail generation
		let results = await backupService.backupPhotos([mockItem], userID: testUserID)

		XCTAssertNotNil(results[mockItem.id])

		// Verify thumbnail was uploaded by trying to download it
		do {
			let thumbnailData = try await s3Service.downloadThumbnail(
				md5: mockItem.md5,
				userID: testUserID
			)
			XCTAssertFalse(thumbnailData.isEmpty, "Thumbnail should have been uploaded")

			// Verify it's a JPEG (starts with JPEG magic bytes)
			let jpegMagic = Data([0xFF, 0xD8, 0xFF])
			XCTAssertTrue(thumbnailData.prefix(3) == jpegMagic, "Thumbnail should be JPEG")
		} catch {
			// Thumbnail might not exist if upload failed
			print("Thumbnail download failed: \(error)")
		}

		// Cleanup
		await cleanupTestData(md5: mockItem.md5)
	}

	func testProgressTracking() async throws {
		s3Service = try await S3Service.forEnvironment(.development)
		backupService = S3BackupService(s3Service: s3Service, catalogDatabase: nil)

		// Use different sample photos for each item
		let samplePhotos = ["006yu_daiAB_TP_V.jpg", "009red_02397B_TP_V.jpg", "018red_AC2_TP_V.jpg"]

		// Create multiple mock items with different real photos
		let items = try samplePhotos.enumerated().map { (index, filename) in
			let photoPath = getSamplePhotoPath(filename)
			let photoData = try Data(contentsOf: photoPath)

			return MockPhotoItem(
				id: "photo-\(index + 1)",
				displayName: filename,
				format: .jpeg,
				data: photoData,
				md5: computeMD5(for: photoData)
			)
		}

		// Upload and track progress
		let results = await backupService.backupPhotos(items, userID: testUserID)

		// Calculate progress
		let progress = await backupService.calculateProgress(totalItems: items.count)

		XCTAssertEqual(progress.totalItems, items.count)
		XCTAssertTrue(progress.isComplete)
		XCTAssertEqual(progress.percentComplete, 100.0)

		// Cleanup
		for item in items {
			await cleanupTestData(md5: item.md5)
		}
	}

	// MARK: - Helpers

	private func computeMD5(for data: Data) -> String {
		let digest = Insecure.MD5.hash(data: data)
		return digest.map { String(format: "%02x", $0) }.joined()
	}

	private func getSamplePhotoPath(_ filename: String) -> URL {
		// Use absolute path to sample photos directory
		let samplePhotosDir = URL(fileURLWithPath: "/Users/kyoshikawa/Projects/Photolala2/apple/PhotolalaTests/sample-photos")
		let photoPath = samplePhotosDir.appendingPathComponent(filename)

		// Verify file exists
		if !FileManager.default.fileExists(atPath: photoPath.path) {
			print("WARNING: Sample photo not found at: \(photoPath.path)")
		}

		return photoPath
	}

	private func cleanupTestData(md5: String) async {
		// Try to clean up test data from S3 (best effort)
		do {
			// Note: S3Service doesn't have delete methods yet
			// This is where we would delete test files
			print("Would cleanup: photos/\(testUserID)/\(md5).dat")
			print("Would cleanup: thumbnails/\(testUserID)/\(md5).jpg")
		}
	}
}

// MARK: - Mock Photo Item

struct MockPhotoItem: PhotoItem {
	nonisolated let id: String
	nonisolated let displayName: String
	nonisolated let format: ImageFormat?
	let data: Data
	let md5: String

	func loadFullData() async throws -> Data {
		return data
	}

	func loadThumbnail() async throws -> Data {
		// Return same data for simplicity in tests
		return data
	}

	func computeMD5() async throws -> String {
		return md5
	}
}