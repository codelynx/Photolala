//
//  CatalogDatabase.swift
//  Photolala
//
//  Minimal CSV-based catalog database
//

import Foundation
import OSLog
import CryptoKit

/// Minimal CSV catalog entry
public struct CatalogEntry: Sendable {
	public let photoHeadMD5: String
	public let fileSize: Int64
	public var photoMD5: String?
	public let photoDate: Date
	public let format: ImageFormat

	public nonisolated var fastPhotoKey: String {
		"\(photoHeadMD5):\(fileSize)"
	}

	public nonisolated init(photoHeadMD5: String, fileSize: Int64, photoMD5: String? = nil, photoDate: Date, format: ImageFormat = .unknown) {
		self.photoHeadMD5 = photoHeadMD5
		self.fileSize = fileSize
		self.photoMD5 = photoMD5
		self.photoDate = photoDate
		self.format = format
	}
}

/// CSV-based catalog database for minimal photo tracking
public actor CatalogDatabase {
	private let logger = Logger(subsystem: "com.photolala", category: "CatalogDatabase")
	public let csvPath: URL
	private let readOnly: Bool
	private var entries: [String: CatalogEntry] = [:] // Keyed by fast photo key

	// CSV Header
	private static let csvHeader = "photo_head_md5,file_size,photo_md5,photo_date,format"

	// MARK: - Initialization

	public init(path: URL, readOnly: Bool = false) async throws {
		self.csvPath = path
		self.readOnly = readOnly

		if FileManager.default.fileExists(atPath: path.path) {
			try await loadCSV()
			logger.info("Loaded \(self.entries.count) entries from CSV")
		} else if !readOnly {
			// Create new CSV with header
			try Self.csvHeader.write(to: path, atomically: true, encoding: .utf8)
			logger.info("Created new CSV catalog at \(path.lastPathComponent)")
		} else {
			throw CatalogDatabaseError.notFound
		}
	}

	// MARK: - Public Methods

	/// Add or update an entry
	public func upsertEntry(_ entry: CatalogEntry) async throws {
		guard !readOnly else {
			throw CatalogDatabaseError.readOnlyDatabase
		}

		entries[entry.fastPhotoKey] = entry
		try await saveCSV()
	}

	/// Update full MD5 for an entry
	public func updatePhotoMD5(fastKey: String, photoMD5: String) async throws {
		guard !readOnly else {
			throw CatalogDatabaseError.readOnlyDatabase
		}

		if var entry = entries[fastKey] {
			entry.photoMD5 = photoMD5
			entries[fastKey] = entry
			try await saveCSV()
		}
	}

	/// Get all entries
	public func getAllEntries() async -> [CatalogEntry] {
		Array(entries.values).sorted { $0.photoDate > $1.photoDate }
	}

	/// Get entry by fast key
	public func getEntry(fastKey: String) async -> CatalogEntry? {
		entries[fastKey]
	}

	/// Get count of entries
	public func getEntryCount() async -> Int {
		entries.count
	}

	/// Remove an entry
	public func removeEntry(fastKey: String) async throws {
		guard !readOnly else {
			throw CatalogDatabaseError.readOnlyDatabase
		}

		entries.removeValue(forKey: fastKey)
		try await saveCSV()
	}

	/// Clear all entries
	public func clearAll() async throws {
		guard !readOnly else {
			throw CatalogDatabaseError.readOnlyDatabase
		}

		entries.removeAll()
		try await saveCSV()
	}

	/// Close the database (no-op for CSV)
	public func close() async {
		// CSV doesn't need explicit closing
		logger.info("CSV catalog closed")
	}

	/// Get statistics about the catalog
	public func getStatistics() async throws -> CatalogStatistics {
		let allEntries = Array(entries.values)
		let entriesWithFullMD5 = allEntries.filter { $0.photoMD5 != nil }.count
		let totalFileSize = allEntries.reduce(0) { $0 + $1.fileSize }

		return CatalogStatistics(
			totalEntries: allEntries.count,
			entriesWithFullMD5: entriesWithFullMD5,
			totalFileSize: totalFileSize,
			lastUpdated: Date()
		)
	}

	/// Get entries for a specific directory (not applicable for CSV - returns all)
	public func getEntries(directory: URL) async throws -> [PhotoEntry] {
		// CSV doesn't track directory structure, return empty for compatibility
		// This would need to be handled differently if directory filtering is needed
		logger.warning("Directory-based filtering not supported in CSV catalog")
		return []
	}

	/// Get metadata for a photo (stored separately in cache)
	public func getMetadata(photoMD5: PhotoMD5) async throws -> PhotoMetadata? {
		// Metadata is not stored in CSV, only in separate cache files
		// This should be handled by MetadataCache instead
		return nil
	}

	// MARK: - Private Methods

	private func loadCSV() async throws {
		let content = try String(contentsOf: csvPath, encoding: .utf8)
		let lines = content.components(separatedBy: .newlines)

		guard !lines.isEmpty else { return }

		// Skip header and process data rows
		for (index, line) in lines.enumerated() {
			// Skip header and empty lines
			if index == 0 || line.trimmingCharacters(in: .whitespaces).isEmpty {
				continue
			}

			let columns = parseCSVLine(line)
			guard columns.count >= 4 else { // Allow 4 or 5 columns for backwards compatibility
				logger.warning("Skipping malformed CSV row \(index): \(line)")
				continue
			}

			let photoHeadMD5 = columns[0]
			guard let fileSize = Int64(columns[1]) else {
				logger.warning("Invalid file size in row \(index)")
				continue
			}

			let photoMD5 = columns[2].isEmpty ? nil : columns[2]
			guard let timestamp = TimeInterval(columns[3]) else {
				logger.warning("Invalid timestamp in row \(index)")
				continue
			}

			// Format is optional for backwards compatibility
			let format: ImageFormat
			if columns.count > 4 {
				// Try to parse format enum, fallback to UNKNOWN
				format = ImageFormat(rawValue: columns[4]) ?? .unknown
			} else {
				// Default to JPEG for backwards compatibility
				format = .jpeg
			}

			let entry = CatalogEntry(
				photoHeadMD5: photoHeadMD5,
				fileSize: fileSize,
				photoMD5: photoMD5,
				photoDate: Date(timeIntervalSince1970: timestamp),
				format: format
			)

			entries[entry.fastPhotoKey] = entry
		}
	}

	private func saveCSV() async throws {
		var csvContent = Self.csvHeader + "\n"

		for entry in entries.values.sorted(by: { $0.photoDate > $1.photoDate }) {
			let photoMD5 = entry.photoMD5 ?? ""
			let timestamp = Int(entry.photoDate.timeIntervalSince1970)
			let line = "\(entry.photoHeadMD5),\(entry.fileSize),\(photoMD5),\(timestamp),\(entry.format.rawValue)\n"
			csvContent += line
		}

		// Write to temporary file first, then rename atomically
		let tempURL = csvPath.appendingPathExtension("tmp")
		try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

		// Atomic rename
		_ = try FileManager.default.replaceItemAt(csvPath, withItemAt: tempURL)

		logger.debug("Saved \(self.entries.count) entries to CSV")
	}

	private func parseCSVLine(_ line: String) -> [String] {
		// Simple CSV parser - handles basic comma separation
		// Does not handle quoted fields with commas (not needed for our data)
		return line.components(separatedBy: ",").map {
			$0.trimmingCharacters(in: .whitespaces)
		}
	}
}

// MARK: - Errors

public enum CatalogDatabaseError: LocalizedError {
	case notFound
	case readOnlyDatabase
	case invalidFormat
	case writeFailed(String)

	public var errorDescription: String? {
		switch self {
		case .notFound:
			return "Catalog database not found"
		case .readOnlyDatabase:
			return "Cannot modify read-only database"
		case .invalidFormat:
			return "Invalid CSV format"
		case .writeFailed(let message):
			return "Failed to write CSV: \(message)"
		}
	}
}

// MARK: - PhotoMetadata for Cache

/// Full metadata stored in cache JSON files (not in catalog)
public struct PhotoMetadata: Sendable, Codable {
	public let photoMD5: PhotoMD5
	public var width: Int?
	public var height: Int?
	public var captureDate: Date?
	public var cameraMake: String?
	public var cameraModel: String?
	public var lensModel: String?
	public var focalLength: Double?
	public var aperture: Double?
	public var shutterSpeed: String?
	public var iso: Int?
	public var gpsLatitude: Double?
	public var gpsLongitude: Double?
	public var exifData: Data?

	public nonisolated init(
		photoMD5: PhotoMD5,
		width: Int? = nil,
		height: Int? = nil,
		captureDate: Date? = nil,
		cameraMake: String? = nil,
		cameraModel: String? = nil,
		lensModel: String? = nil,
		focalLength: Double? = nil,
		aperture: Double? = nil,
		shutterSpeed: String? = nil,
		iso: Int? = nil,
		gpsLatitude: Double? = nil,
		gpsLongitude: Double? = nil,
		exifData: Data? = nil
	) {
		self.photoMD5 = photoMD5
		self.width = width
		self.height = height
		self.captureDate = captureDate
		self.cameraMake = cameraMake
		self.cameraModel = cameraModel
		self.lensModel = lensModel
		self.focalLength = focalLength
		self.aperture = aperture
		self.shutterSpeed = shutterSpeed
		self.iso = iso
		self.gpsLatitude = gpsLatitude
		self.gpsLongitude = gpsLongitude
		self.exifData = exifData
	}
}