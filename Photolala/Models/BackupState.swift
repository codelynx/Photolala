//
//  BackupState.swift
//  Photolala
//
//  Created by Kenta Yoshikawa on 2025/06/18.
//

import Foundation

enum BackupState: String, CaseIterable, Codable {
	case none = "none"
	case queued = "queued"
	case uploading = "uploading"
	case uploaded = "uploaded"
	case failed = "failed"
	
	var iconName: String {
		switch self {
		case .none:
			return ""
		case .queued:
			return "star.fill"
		case .uploading:
			return "arrow.up"
		case .uploaded:
			return "checkmark.icloud.fill"
		case .failed:
			return "exclamationmark.circle.fill"
		}
	}
	
	var badgeColor: String {
		switch self {
		case .none:
			return "clear"
		case .queued:
			return "yellow"
		case .uploading:
			return "blue"
		case .uploaded:
			return "green"
		case .failed:
			return "red"
		}
	}
}