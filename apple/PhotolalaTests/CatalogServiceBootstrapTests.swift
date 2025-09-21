//
//  CatalogServiceBootstrapTests.swift
//  PhotolalaTests
//
//  Verifies bootstrapping and snapshot lifecycle for the Photolala Directory Catalog System.
//

import XCTest
import CryptoKit
@testable import Photolala

final class CatalogServiceBootstrapTests: XCTestCase {

	private let fileManager = FileManager.default
	private var tempRoot: URL!
	private var catalogDirectory: URL!

	override func setUpWithError() throws {
		try super.setUpWithError()

		let base = fileManager.temporaryDirectory.appendingPathComponent("CatalogServiceBootstrapTests-\(UUID().uuidString)", isDirectory: true)
		let catalogDir = base.appendingPathComponent("catalog", isDirectory: true)

		try fileManager.createDirectory(at: catalogDir, withIntermediateDirectories: true)
		try copySamplePhotos(into: catalogDir)

		tempRoot = base
		catalogDirectory = catalogDir
	}

	override func tearDownWithError() throws {
		if let tempRoot {
			try? fileManager.removeItem(at: tempRoot)
		}
		try super.tearDownWithError()
	}

	@MainActor
	func testBootstrapCreatesWorkingCopyAndSnapshots() async throws {
		let service = CatalogService(catalogDirectory: catalogDirectory)

		do {
			try await service.initializeCatalog()
		} catch {
			XCTFail("initializeCatalog failed: \(error)")
			throw error
		}

		// No catalog published yet, but the working database should exist.
		XCTAssertNil(service.catalogInfo)
		let workingURL = workingCatalogURL(for: catalogDirectory)
		XCTAssertTrue(fileManager.fileExists(atPath: workingURL.path), "Expected working catalog at \(workingURL.path)")

		// Build the catalog and publish snapshots.
		do {
			try await service.scanAndBuildCatalog()
		} catch {
			XCTFail("scanAndBuildCatalog failed: \(error)")
			throw error
		}

		let rootPointerURL = catalogDirectory.appendingPathComponent(".photolala.md5")
		let pointer = try String(contentsOf: rootPointerURL, encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
		XCTAssertFalse(pointer.isEmpty, "Pointer file should contain the latest catalog MD5")

		let expectedSnapshotName = ".photolala.\(pointer).csv"
		let rootSnapshotURL = catalogDirectory.appendingPathComponent(expectedSnapshotName)
		XCTAssertTrue(fileManager.fileExists(atPath: rootSnapshotURL.path), "Root snapshot missing at \(rootSnapshotURL.path)")

		let cacheDirectory = cacheDirectory(for: catalogDirectory)
		let cachePointerURL = cacheDirectory.appendingPathComponent(".photolala.md5")
		let cachePointer = try String(contentsOf: cachePointerURL, encoding: .utf8)
			.trimmingCharacters(in: .whitespacesAndNewlines)
		XCTAssertEqual(cachePointer, pointer, "Cache pointer must stay in sync with root pointer")

		let cacheSnapshotURL = cacheDirectory.appendingPathComponent(expectedSnapshotName)
		XCTAssertTrue(fileManager.fileExists(atPath: cacheSnapshotURL.path), "Cache snapshot missing at \(cacheSnapshotURL.path)")

		// Rebootstrap to ensure the service hydrates from the existing snapshot.
		let secondService = CatalogService(catalogDirectory: catalogDirectory)
		try await secondService.initializeCatalog()
		XCTAssertEqual(secondService.catalogInfo?.md5, pointer, "Rehydrated catalog should match published snapshot")

		// Clean cache artifacts to avoid leaking state across tests.
		// optional: clear caches between runs if needed
		// try await CacheManager.shared.clearAllCaches()
	}
}

// MARK: - Helpers

private extension CatalogServiceBootstrapTests {

	func copySamplePhotos(into destination: URL) throws {
		let source = try samplePhotosURL()
		let enumerator = fileManager.enumerator(
			at: source,
			includingPropertiesForKeys: [.isDirectoryKey],
			options: [.skipsHiddenFiles]
		)

		while let item = enumerator?.nextObject() as? URL {
			let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
			let relativePath = item.path.replacingOccurrences(of: source.path + "/", with: "")
			guard !relativePath.isEmpty else { continue }

			let targetURL = destination.appendingPathComponent(relativePath)

			if resourceValues.isDirectory == true {
				try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true)
			} else {
				try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
				try fileManager.copyItem(at: item, to: targetURL)
			}
		}
	}

	func samplePhotosURL() throws -> URL {
		let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
		let sampleURL = testsDirectory.appendingPathComponent("sample-photos", isDirectory: true)
		guard fileManager.fileExists(atPath: sampleURL.path) else {
			throw NSError(domain: "CatalogServiceBootstrapTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing sample photo directory at \(sampleURL.path)"])
		}
		return sampleURL
	}

	func workingCatalogURL(for directory: URL) -> URL {
		let cacheRoot = cacheRootURL()
		let directoryMD5 = computeDirectoryMD5(for: directory)
		return cacheRoot
			.appendingPathComponent(directoryMD5, isDirectory: true)
			.appendingPathComponent(".photolala.csv")
	}

	func cacheDirectory(for directory: URL) -> URL {
		let cacheRoot = cacheRootURL()
		let directoryMD5 = computeDirectoryMD5(for: directory)
		return cacheRoot.appendingPathComponent(directoryMD5, isDirectory: true)
	}

	func cacheRootURL() -> URL {
		fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
			.appendingPathComponent("com.photolala.catalog", isDirectory: true)
	}

	func computeDirectoryMD5(for directory: URL) -> String {
		let normalizedPath = directory.standardizedFileURL.path
		let data = Data(normalizedPath.utf8)
		let digest = Insecure.MD5.hash(data: data)
		return digest.map { String(format: "%02x", $0) }.joined()
	}
}
