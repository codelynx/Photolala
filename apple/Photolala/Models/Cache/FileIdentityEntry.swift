//
//  FileIdentityEntry.swift
//  Photolala
//
//  Level 1 Cache: Maps file identity to content MD5
//

import Foundation
import SwiftData
import CryptoKit

/// SwiftData model for Level 1 cache: File identity → Content MD5
@Model
final class FileIdentityEntry {
	/// Unique key combining normalized path and file size
	@Attribute(.unique) let identityKey: String
	
	/// Normalized file path
	let normalizedPath: String
	
	/// File size in bytes
	let fileSize: Int64
	
	/// MD5 hash of the file contents
	let contentMD5: String
	
	/// When this entry was created
	let createdDate: Date
	
	/// When this entry was last accessed
	var lastAccessDate: Date
	
	/// Initialize a new file identity entry
	init(path: String, fileSize: Int64, modificationDate: Date? = nil, contentMD5: String) {
		// Normalize the path
		let normalizedPath = (path as NSString).standardizingPath
		
		// Store file attributes
		self.normalizedPath = normalizedPath
		self.fileSize = fileSize
		self.contentMD5 = contentMD5
		
		// Generate unique identity key using path + file size only
		self.identityKey = FileIdentityKey.buildKey(path: normalizedPath, fileSize: fileSize)
		
		// Set timestamps
		self.createdDate = Date()
		self.lastAccessDate = Date()
	}
	
	/// Update access time when entry is used
	func touch() {
		self.lastAccessDate = Date()
	}
	
	/// Check if this entry matches the given file attributes
	func matches(path: String, fileSize: Int64) -> Bool {
		let normalizedPath = (path as NSString).standardizingPath
		
		return self.normalizedPath == normalizedPath &&
			   self.fileSize == fileSize
	}
	
	/// Generate identity key for a file (static helper)
	static func generateKey(path: String, fileSize: Int64, modificationDate: Date? = nil) -> String {
		// modificationDate is ignored - we only use path + file size
		return FileIdentityKey.buildKey(path: path, fileSize: fileSize)
	}
}