//
//  CatalogServiceProtocol.swift
//  Photolala
//
//  Protocol abstraction for catalog services to support both CSV and SwiftData implementations
//

import Foundation
import SwiftData

// MARK: - Protocols

/// Common protocol for catalog entries across implementations
protocol CatalogEntryProtocol {
	var md5: String { get }
	var filename: String { get }
	var fileSize: Int64 { get }
	var photoDate: Date { get }
	var fileModifiedDate: Date { get }
	var pixelWidth: Int? { get }
	var pixelHeight: Int? { get }
	var applePhotoID: String? { get }
	var isStarred: Bool { get }
	var backupStatus: BackupStatus { get }
}

/// Protocol for catalog services supporting both CSV and SwiftData
protocol CatalogService {
	/// Load or create catalog for directory
	func loadCatalog(for directoryURL: URL) async throws -> Any
	
	/// Find entry by MD5
	func findEntry(md5: String) async throws -> CatalogEntryProtocol?
	
	/// Update star status for entry
	func updateStarStatus(md5: String, isStarred: Bool) async throws
	
	/// Update backup status for entry
	func updateBackupStatus(md5: String, status: BackupStatus) async throws
	
	/// Get all starred entries
	func getStarredEntries() async throws -> [CatalogEntryProtocol]
	
	/// Get catalog statistics
	func getCatalogStats() async throws -> CatalogStats
}

/// Catalog statistics
struct CatalogStats {
	let totalPhotos: Int
	let starredPhotos: Int
	let backedUpPhotos: Int
	let lastModified: Date?
}

// MARK: - CSV Implementation Note

// PhotolalaCatalogService (CSV-based) does not currently conform to CatalogService
// This is intentional as we're migrating to SwiftData for catalog operations
// CSV catalog remains for legacy compatibility but new features use SwiftData

// MARK: - SwiftData Implementation Note

// PhotolalaCatalogServiceV2 conformance to CatalogService is implemented
// directly in PhotolalaCatalogServiceV2.swift to access private properties

// Make CatalogPhotoEntry conform to CatalogEntryProtocol
extension CatalogPhotoEntry: CatalogEntryProtocol {
	// Properties already match the protocol
}