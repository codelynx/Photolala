//
//  StarCheckpointManager.swift
//  Photolala
//
//  Manages checkpoints for resumable star/upload operations
//

import Foundation
import OSLog
import SwiftUI
import Combine

/// Checkpoint for a star operation that can be resumed
struct StarCheckpoint: Codable {
	let id: UUID
	let startDate: Date
	let action: String // Store as string for Codable
	let totalItems: Int
	var processedItems: [ProcessedItem]
	var failedItems: [FailedItem]
	var status: CheckpointStatus
	var lastUpdated: Date
	
	struct ProcessedItem: Codable {
		let basketItemId: String
		let displayName: String
		let md5: String?
		let processedAt: Date
		let uploaded: Bool
	}
	
	struct FailedItem: Codable {
		let basketItemId: String
		let displayName: String
		let error: String
		var failedAt: Date
		var retryCount: Int
	}
	
	enum CheckpointStatus: String, Codable {
		case inProgress = "in_progress"
		case paused = "paused"
		case completed = "completed"
		case failed = "failed"
	}
	
	var percentComplete: Double {
		guard totalItems > 0 else { return 0 }
		return Double(processedItems.count) / Double(totalItems)
	}
	
	var canResume: Bool {
		status == .inProgress || status == .paused || status == .failed
	}
}

/// Manages checkpoints for resumable operations
@MainActor
final class StarCheckpointManager: ObservableObject {
	private let logger = Logger(subsystem: "com.photolala", category: "StarCheckpointManager")
	
	// Published state
	@Published private(set) var activeCheckpoint: StarCheckpoint?
	@Published private(set) var availableCheckpoints: [StarCheckpoint] = []
	
	// Persistence
	private let checkpointDirectory: URL
	private let maxCheckpoints = 10
	
	init() {
		// Setup checkpoint directory
		let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
												   in: .userDomainMask).first!
		let checkpointDir = appSupport
			.appendingPathComponent("Photolala", isDirectory: true)
			.appendingPathComponent("Checkpoints", isDirectory: true)
		
		try? FileManager.default.createDirectory(at: checkpointDir,
												  withIntermediateDirectories: true)
		
		self.checkpointDirectory = checkpointDir
		
		// Load existing checkpoints
		Task {
			await loadCheckpoints()
		}
	}
	
	// MARK: - Public API
	
	/// Create a new checkpoint for an operation
	func createCheckpoint(action: BasketAction, items: [BasketItem]) -> StarCheckpoint {
		let checkpoint = StarCheckpoint(
			id: UUID(),
			startDate: Date(),
			action: action.rawValue,
			totalItems: items.count,
			processedItems: [],
			failedItems: [],
			status: .inProgress,
			lastUpdated: Date()
		)
		
		activeCheckpoint = checkpoint
		Task {
			await saveCheckpoint(checkpoint)
		}
		
		logger.info("Created checkpoint \(checkpoint.id) for \(action.rawValue) with \(items.count) items")
		return checkpoint
	}
	
	/// Update checkpoint with processed item
	func markItemProcessed(checkpointId: UUID, basketItemId: String, displayName: String, md5: String?, uploaded: Bool = false) {
		guard var checkpoint = activeCheckpoint, checkpoint.id == checkpointId else { return }
		
		let processedItem = StarCheckpoint.ProcessedItem(
			basketItemId: basketItemId,
			displayName: displayName,
			md5: md5,
			processedAt: Date(),
			uploaded: uploaded
		)
		
		checkpoint.processedItems.append(processedItem)
		checkpoint.lastUpdated = Date()
		
		// Update status if all items processed
		if checkpoint.processedItems.count + checkpoint.failedItems.count >= checkpoint.totalItems {
			checkpoint.status = checkpoint.failedItems.isEmpty ? .completed : .failed
		}
		
		activeCheckpoint = checkpoint
		Task {
			await saveCheckpoint(checkpoint)
		}
	}
	
	/// Mark item as failed
	func markItemFailed(checkpointId: UUID, basketItemId: String, displayName: String, error: String) {
		guard var checkpoint = activeCheckpoint, checkpoint.id == checkpointId else { return }
		
		// Check if already failed
		if let existingIndex = checkpoint.failedItems.firstIndex(where: { $0.basketItemId == basketItemId }) {
			checkpoint.failedItems[existingIndex].retryCount += 1
			checkpoint.failedItems[existingIndex].failedAt = Date()
		} else {
			let failedItem = StarCheckpoint.FailedItem(
				basketItemId: basketItemId,
				displayName: displayName,
				error: error,
				failedAt: Date(),
				retryCount: 0
			)
			checkpoint.failedItems.append(failedItem)
		}
		
		checkpoint.lastUpdated = Date()
		activeCheckpoint = checkpoint
		Task {
			await saveCheckpoint(checkpoint)
		}
	}
	
	/// Pause current checkpoint
	func pauseCheckpoint() {
		guard var checkpoint = activeCheckpoint else { return }
		checkpoint.status = .paused
		checkpoint.lastUpdated = Date()
		activeCheckpoint = checkpoint
		Task {
			await saveCheckpoint(checkpoint)
		}
		logger.info("Paused checkpoint \(checkpoint.id)")
	}
	
	/// Resume a checkpoint
	func resumeCheckpoint(_ checkpointId: UUID) async throws -> StarCheckpoint? {
		guard let checkpoint = availableCheckpoints.first(where: { $0.id == checkpointId }),
			  checkpoint.canResume else {
			return nil
		}
		
		var resumedCheckpoint = checkpoint
		resumedCheckpoint.status = .inProgress
		resumedCheckpoint.lastUpdated = Date()
		
		activeCheckpoint = resumedCheckpoint
		await saveCheckpoint(resumedCheckpoint)
		
		logger.info("Resumed checkpoint \(checkpointId)")
		return resumedCheckpoint
	}
	
	/// Get unprocessed items for a checkpoint
	func getUnprocessedItems(for checkpoint: StarCheckpoint, from originalItems: [BasketItem]) -> [BasketItem] {
		let processedIds = Set(checkpoint.processedItems.map { $0.basketItemId })
		let failedIds = Set(checkpoint.failedItems.filter { $0.retryCount < 3 }.map { $0.basketItemId })
		
		return originalItems.filter { item in
			!processedIds.contains(item.id) || failedIds.contains(item.id)
		}
	}
	
	/// Delete a checkpoint
	func deleteCheckpoint(_ checkpointId: UUID) async {
		availableCheckpoints.removeAll { $0.id == checkpointId }
		if activeCheckpoint?.id == checkpointId {
			activeCheckpoint = nil
		}
		
		let url = checkpointDirectory.appendingPathComponent("\(checkpointId.uuidString).json")
		try? FileManager.default.removeItem(at: url)
		
		logger.info("Deleted checkpoint \(checkpointId)")
	}
	
	/// Clean up old checkpoints
	func cleanupOldCheckpoints() async {
		// Sort by date and keep only recent ones
		let sorted = availableCheckpoints.sorted { $0.lastUpdated > $1.lastUpdated }
		if sorted.count > maxCheckpoints {
			for checkpoint in sorted.dropFirst(maxCheckpoints) {
				await deleteCheckpoint(checkpoint.id)
			}
		}
	}
	
	// MARK: - Private Methods
	
	private func loadCheckpoints() async {
		do {
			let files = try FileManager.default.contentsOfDirectory(
				at: checkpointDirectory,
				includingPropertiesForKeys: [.contentModificationDateKey],
				options: .skipsHiddenFiles
			)
			
			var checkpoints: [StarCheckpoint] = []
			for file in files where file.pathExtension == "json" {
				if let checkpoint = try? loadCheckpoint(from: file) {
					checkpoints.append(checkpoint)
				}
			}
			
			availableCheckpoints = checkpoints.sorted { $0.lastUpdated > $1.lastUpdated }
			
			// Find active checkpoint
			activeCheckpoint = availableCheckpoints.first { $0.status == .inProgress }
			
			logger.info("Loaded \(checkpoints.count) checkpoints")
		} catch {
			logger.error("Failed to load checkpoints: \(error)")
		}
	}
	
	private func loadCheckpoint(from url: URL) throws -> StarCheckpoint {
		let data = try Data(contentsOf: url)
		return try JSONDecoder().decode(StarCheckpoint.self, from: data)
	}
	
	private func saveCheckpoint(_ checkpoint: StarCheckpoint) async {
		do {
			let data = try JSONEncoder().encode(checkpoint)
			let url = checkpointDirectory.appendingPathComponent("\(checkpoint.id.uuidString).json")
			try data.write(to: url, options: .atomic)
			
			// Update available checkpoints list
			if let index = availableCheckpoints.firstIndex(where: { $0.id == checkpoint.id }) {
				availableCheckpoints[index] = checkpoint
			} else {
				availableCheckpoints.append(checkpoint)
			}
			
			logger.debug("Saved checkpoint \(checkpoint.id)")
		} catch {
			logger.error("Failed to save checkpoint: \(error)")
		}
	}
}

// MARK: - Checkpoint UI Support

extension StarCheckpoint {
	var summary: String {
		let processed = processedItems.count
		let failed = failedItems.count
		let remaining = totalItems - processed - failed
		
		return "\(processed) processed, \(failed) failed, \(remaining) remaining"
	}
	
	var durationText: String {
		let duration = lastUpdated.timeIntervalSince(startDate)
		let formatter = DateComponentsFormatter()
		formatter.allowedUnits = [.hour, .minute, .second]
		formatter.unitsStyle = .abbreviated
		return formatter.string(from: duration) ?? "0s"
	}
	
	var statusColor: String {
		switch status {
		case .inProgress: return "blue"
		case .paused: return "orange"
		case .completed: return "green"
		case .failed: return "red"
		}
	}
}