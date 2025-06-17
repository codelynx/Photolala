//
//  StorageUsage.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/01/17.
//

import Foundation

/// Represents the current storage usage for a user's backup
struct StorageUsage: Codable {
	let totalBytes: Int64
	let standardBytes: Int64
	let deepArchiveBytes: Int64
	let fileCount: Int
	let lastUpdated: Date
	
	/// Total storage in gigabytes
	var totalGB: Double {
		Double(totalBytes) / 1_000_000_000
	}
	
	/// Standard storage in gigabytes
	var standardGB: Double {
		Double(standardBytes) / 1_000_000_000
	}
	
	/// Deep archive storage in gigabytes
	var deepArchiveGB: Double {
		Double(deepArchiveBytes) / 1_000_000_000
	}
	
	/// Percentage of storage limit used
	var percentageUsed: Double {
		guard let limit = IAPManager.shared.currentStorageLimit else { return 0 }
		return Double(totalBytes) / Double(limit) * 100
	}
	
	/// Whether the user is approaching their limit (>80%)
	var isApproachingLimit: Bool {
		percentageUsed >= 80
	}
	
	/// Whether the user has exceeded their limit
	var isOverLimit: Bool {
		percentageUsed > 100
	}
}

extension StorageUsage {
	/// Empty usage for initial state
	static var empty: StorageUsage {
		StorageUsage(
			totalBytes: 0,
			standardBytes: 0,
			deepArchiveBytes: 0,
			fileCount: 0,
			lastUpdated: Date()
		)
	}
}