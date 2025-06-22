//
//  FeatureFlags.swift
//  Photolala
//
//  Created by Photolala on 6/17/25.
//

import Foundation

/// Feature flags for controlling app functionality
struct FeatureFlags {
	/// Enable S3 backup functionality
	static let isS3BackupEnabled = true
	
	/// Enable archive retrieval features
	static let isArchiveRetrievalEnabled = false
	
	/// Show "Coming Soon" badge for disabled features
	static let showComingSoonBadges = true
	
	/// Enable background uploads
	static let isBackgroundUploadEnabled = false
	
	/// Enable push notifications
	static let isPushNotificationEnabled = false
	
	/// Use sandbox IAP environment
	static let isSandboxIAP = true
	
	/// Use SwiftData for local catalog storage
	static let useSwiftDataCatalog = false
	
	/// Show debug information in UI
	#if DEBUG
	static let showDebugInfo = true
	#else
	static let showDebugInfo = false
	#endif
}