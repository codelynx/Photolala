//
//  UsageTrackingService.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/01/17.
//

import Foundation
import Combine

/// Service for tracking and managing storage usage
@MainActor
class UsageTrackingService: ObservableObject {
	static let shared = UsageTrackingService()
	
	// MARK: - Published Properties
	
	@Published var currentUsage: StorageUsage?
	@Published var isCalculating = false
	@Published var lastError: Error?
	
	// MARK: - Private Properties
	
	private let cacheKey = "com.photolala.usage.cache"
	private let cacheExpiration: TimeInterval = 86400 // 24 hours
	private let userDefaults = UserDefaults.standard
	
	private init() {}
	
	// MARK: - Public Methods
	
	/// Check current usage, using cache if available
	func checkUsage(forceRefresh: Bool = false) async throws -> StorageUsage {
		// Check cache first
		if !forceRefresh, let cached = getCachedUsage() {
			currentUsage = cached
			return cached
		}
		
		// Calculate from S3
		isCalculating = true
		lastError = nil
		defer { isCalculating = false }
		
		do {
			let usage = try await calculateUsageFromS3()
			cacheUsage(usage)
			currentUsage = usage
			return usage
		} catch {
			lastError = error
			throw error
		}
	}
	
	/// Check if a file upload is allowed based on current usage
	func canUploadFile(sizeBytes: Int64) async -> (allowed: Bool, message: String?) {
		do {
			let usage = try await checkUsage()
			guard let limit = IAPManager.shared.currentStorageLimit else {
				return (false, "No active subscription")
			}
			
			let projectedUsage = usage.totalBytes + sizeBytes
			let projectedPercent = Double(projectedUsage) / Double(limit) * 100
			
			// Hard limit at 110% (10% buffer)
			if projectedPercent > 110 {
				return (false, "Storage limit exceeded. Please upgrade your plan or delete some photos.")
			}
			
			// Warning at 100%
			if projectedPercent > 100 {
				return (true, "Warning: This upload will exceed your storage limit.")
			}
			
			// Warning at 95%
			if projectedPercent >= 95 {
				return (true, "You're at \(Int(projectedPercent))% of your storage limit.")
			}
			
			// Warning at 80%
			if projectedPercent >= 80 {
				return (true, "You're approaching your storage limit (\(Int(projectedPercent))%).")
			}
			
			return (true, nil)
		} catch {
			// If we can't check usage, allow upload but log error
			print("Failed to check usage: \(error)")
			return (true, nil)
		}
	}
	
	/// Clear cached usage data
	func clearCache() {
		userDefaults.removeObject(forKey: cacheKey)
		currentUsage = nil
	}
	
	// MARK: - Private Methods
	
	private func calculateUsageFromS3() async throws -> StorageUsage {
		// Get the S3 service through S3BackupManager
		guard let s3Service = S3BackupManager.shared.s3Service else {
			throw S3BackupError.notConfigured
		}
		
		// Get current user ID
		guard let userId = S3BackupManager.shared.userId else {
			throw S3BackupError.notAuthenticated
		}
		
		// For now, use the existing calculateStorageStats method
		// In the future, we might want to add a dedicated method for usage tracking
		await s3Service.calculateStorageStats(userId: userId)
		
		// Get the stats from backup stats
		let stats = s3Service.backupStats
		
		return StorageUsage(
			totalBytes: stats.totalSize,
			standardBytes: stats.photoSize, // Assuming most photos are in standard storage
			deepArchiveBytes: 0, // Will need to implement proper tracking
			fileCount: 0, // Will need to implement file counting
			lastUpdated: Date()
		)
	}
	
	private func getCachedUsage() -> StorageUsage? {
		guard let data = userDefaults.data(forKey: cacheKey),
			  let usage = try? JSONDecoder().decode(StorageUsage.self, from: data) else {
			return nil
		}
		
		// Check if cache is expired
		let age = Date().timeIntervalSince(usage.lastUpdated)
		if age > cacheExpiration {
			return nil
		}
		
		return usage
	}
	
	private func cacheUsage(_ usage: StorageUsage) {
		if let data = try? JSONEncoder().encode(usage) {
			userDefaults.set(data, forKey: cacheKey)
		}
	}
}

// MARK: - Errors

enum UsageTrackingError: LocalizedError {
	case noSubscription
	case calculationFailed(Error)
	
	var errorDescription: String? {
		switch self {
		case .noSubscription:
			return "No active subscription found"
		case .calculationFailed(let error):
			return "Failed to calculate usage: \(error.localizedDescription)"
		}
	}
}