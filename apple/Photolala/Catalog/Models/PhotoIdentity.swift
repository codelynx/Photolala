//
//  PhotoIdentity.swift
//  Photolala
//
//  Core photo identity types for Photolala Directory Catalog System
//

import Foundation
import CryptoKit

// MARK: - Fast Photo Key

/// Fast photo key combining head MD5 and file size for quick identification
/// Format: "{photo-head-md5}:{file-size}"
public struct FastPhotoKey: Hashable, Codable, Sendable {
	let headMD5: String
	let fileSize: Int64
	let detectedFormat: ImageFormat?

	nonisolated init(headMD5: String, fileSize: Int64, format: ImageFormat? = nil) {
		self.headMD5 = headMD5.lowercased()
		self.fileSize = fileSize
		self.detectedFormat = format
	}

	/// Initialize from a file URL by reading first 4KB and detecting format
	init(contentsOf url: URL) async throws {
		let fileSize = try url.fileSize()
		let (headMD5, format) = try await Self.computeHeadMD5AndFormat(for: url)
		self.init(headMD5: headMD5, fileSize: fileSize, format: format)
	}

	/// String representation: "{head-md5}:{file-size}"
	nonisolated var stringValue: String {
		"\(headMD5):\(fileSize)"
	}

	/// Parse from string representation
	nonisolated init?(string: String) {
		let components = string.split(separator: ":")
		guard components.count == 2,
			  let size = Int64(components[1]) else {
			return nil
		}
		self.init(headMD5: String(components[0]), fileSize: size)
	}

	/// Compute MD5 of first 4KB of file and detect format
	private static func computeHeadMD5AndFormat(for url: URL, headSize: Int = 4096) async throws -> (String, ImageFormat) {
		let handle = try FileHandle(forReadingFrom: url)
		defer { try? handle.close() }

		let data = try handle.read(upToCount: headSize) ?? Data()

		// Compute MD5
		let digest = Insecure.MD5.hash(data: data)
		let md5 = digest.map { String(format: "%02x", $0) }.joined()

		// Detect format from the same data
		let format = ImageFormat.detectFromHead(data)

		return (md5, format)
	}
}

// MARK: - Photo MD5

/// Full file MD5 hash for deduplication and cloud sync
public struct PhotoMD5: Hashable, Codable, Sendable {
	let value: String

	nonisolated init(_ value: String) {
		self.value = value.lowercased()
	}

	/// Initialize by computing full MD5 of file
	init(contentsOf url: URL) async throws {
		let md5 = try await Self.computeFullMD5(for: url)
		self.init(md5)
	}

	/// Validate MD5 format (32 hex characters)
	var isValid: Bool {
		let pattern = "^[a-f0-9]{32}$"
		let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
		let range = NSRange(location: 0, length: value.count)
		return regex?.firstMatch(in: value, options: [], range: range) != nil
	}

	/// Get sharding prefix (first 2 characters) for directory organization
	nonisolated var shardPrefix: String {
		String(value.prefix(2))
	}

	/// Compute full MD5 of file with streaming for large files
	private static func computeFullMD5(for url: URL, chunkSize: Int = 1024 * 1024) async throws -> String {
		let handle = try FileHandle(forReadingFrom: url)
		defer { try? handle.close() }

		var hasher = Insecure.MD5()

		while true {
			let data = try handle.read(upToCount: chunkSize) ?? Data()
			if data.isEmpty { break }
			hasher.update(data: data)
		}

		let digest = hasher.finalize()
		return digest.map { String(format: "%02x", $0) }.joined()
	}
}

// MARK: - Unified Photo ID

/// Unified photo identifier supporting both fast and full identification
@preconcurrency public struct PhotoID: Hashable, Codable, Sendable {
	let fastKey: FastPhotoKey
	var fullMD5: PhotoMD5?

	nonisolated public init(fastKey: FastPhotoKey, fullMD5: PhotoMD5? = nil) {
		self.fastKey = fastKey
		self.fullMD5 = fullMD5
	}

	/// Check if full MD5 has been computed
	nonisolated var hasFullMD5: Bool {
		fullMD5 != nil
	}

	/// Get the best available identifier
	nonisolated var primaryIdentifier: String {
		fullMD5?.value ?? fastKey.stringValue
	}

	/// Update with full MD5 when computed
	nonisolated mutating func updateFullMD5(_ md5: PhotoMD5) {
		self.fullMD5 = md5
	}
}

// MARK: - Photo Entry

/// Catalog entry representing a photo in the system
@preconcurrency public struct PhotoEntry: Codable, Sendable {
	var id: PhotoID
	let path: URL
	let fileName: String
	let fileSize: Int64
	let modifiedDate: Date
	var captureDate: Date?
	var dimensions: CGSize?
	var mimeType: String?

	nonisolated init(url: URL) async throws {
		self.path = url
		self.fileName = url.lastPathComponent

		let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
		self.fileSize = attributes[.size] as? Int64 ?? 0
		self.modifiedDate = attributes[.modificationDate] as? Date ?? Date()

		// Compute fast key
		let fastKey = try await FastPhotoKey(contentsOf: url)
		self.id = PhotoID(fastKey: fastKey)

		// Initialize optional properties
		self.captureDate = nil
		self.dimensions = nil
		self.mimeType = nil
	}

	nonisolated public init(
		id: PhotoID,
		path: URL,
		fileName: String,
		fileSize: Int64,
		modifiedDate: Date
	) {
		self.id = id
		self.path = path
		self.fileName = fileName
		self.fileSize = fileSize
		self.modifiedDate = modifiedDate
	}

	/// Update entry with full MD5 when available
	nonisolated mutating func updateFullMD5(_ md5: PhotoMD5) {
		self.id.updateFullMD5(md5)
	}
}

// MARK: - Extensions

extension URL {
	/// Get file size in bytes
	func fileSize() throws -> Int64 {
		let attributes = try FileManager.default.attributesOfItem(atPath: self.path)
		return attributes[.size] as? Int64 ?? 0
	}
}