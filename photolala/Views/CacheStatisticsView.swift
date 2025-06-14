//
//  CacheStatisticsView.swift
//  photolala
//
//  Created by Assistant on 2025/06/14.
//

import SwiftUI

struct CacheStatisticsView: View {
	@State private var stats: PhotoManager.CacheStatisticsReport = PhotoManager.shared.getCacheStatistics()
	@State private var memoryUsage = PhotoManager.shared.getMemoryUsageInfo()
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		VStack(spacing: 0) {
			// Header
			HStack {
				Text("Cache Statistics")
					.font(.title2)
					.fontWeight(.semibold)
				
				Spacer()
				
				Button("Done") {
					dismiss()
				}
				.keyboardShortcut(.defaultAction)
			}
			.padding()
			
			Divider()
			
			// Statistics Content
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					// Images Section
					StatisticSection(
						title: "Images",
						icon: "photo",
						color: .blue,
						stats: [
							("Cache hits", "\(stats.imageHits)"),
							("Cache misses", "\(stats.imageMisses)"),
							("Hit rate", String(format: "%.1f%%", stats.imageHitRate * 100)),
							("Cache limit", "\(memoryUsage.imageCacheLimit) images")
						]
					)
					
					// Thumbnails Section
					StatisticSection(
						title: "Thumbnails",
						icon: "square.grid.3x3",
						color: .green,
						stats: [
							("Cache hits", "\(stats.thumbnailHits)"),
							("Cache misses", "\(stats.thumbnailMisses)"),
							("Hit rate", String(format: "%.1f%%", stats.thumbnailHitRate * 100)),
							("Cache limit", "1000 thumbnails")
						]
					)
					
					// Disk Operations Section
					StatisticSection(
						title: "Disk Operations",
						icon: "internaldrive",
						color: .orange,
						stats: [
							("Disk reads", "\(stats.diskReads)"),
							("Disk writes", "\(stats.diskWrites)")
						]
					)
					
					// Performance Section
					StatisticSection(
						title: "Performance",
						icon: "speedometer",
						color: .purple,
						stats: [
							("Total operations", "\(stats.loadCount)"),
							("Average load time", String(format: "%.3fs", stats.averageLoadTime)),
							("Total time", String(format: "%.3fs", stats.totalLoadTime))
						]
					)
					
					// Memory Section
					StatisticSection(
						title: "Memory",
						icon: "memorychip",
						color: .red,
						stats: [
							("Process memory", memoryUsage.processMemory),
							("Cache budget", "\(memoryUsage.cacheBudget / 1024 / 1024)MB"),
							("Physical RAM", "\(memoryUsage.totalMemory / 1024 / 1024 / 1024)GB")
						]
					)
				}
				.padding()
			}
			
			Divider()
			
			// Actions
			HStack {
				Button("Reset Statistics") {
					PhotoManager.shared.resetStatistics()
					stats = PhotoManager.shared.getCacheStatistics()
				}
				.buttonStyle(.bordered)
				
				Spacer()
				
				Button("Refresh") {
					stats = PhotoManager.shared.getCacheStatistics()
					memoryUsage = PhotoManager.shared.getMemoryUsageInfo()
				}
				.buttonStyle(.bordered)
			}
			.padding()
		}
		.frame(width: 500, height: 600)
		#if os(macOS)
		.background(Color(NSColor.windowBackgroundColor))
		#endif
	}
}

struct StatisticSection: View {
	let title: String
	let icon: String
	let color: Color
	let stats: [(String, String)]
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			// Section Header
			HStack {
				Image(systemName: icon)
					.foregroundColor(color)
					.font(.title3)
				Text(title)
					.font(.headline)
			}
			
			// Stats Grid
			VStack(alignment: .leading, spacing: 8) {
				ForEach(stats, id: \.0) { stat in
					HStack {
						Text(stat.0)
							.foregroundColor(.secondary)
						Spacer()
						Text(stat.1)
							.fontWeight(.medium)
							.monospacedDigit()
					}
				}
			}
			.padding(.leading, 28)
		}
		.padding()
		.background(Color.gray.opacity(0.1))
		.cornerRadius(8)
	}
}

// Preview
struct CacheStatisticsView_Previews: PreviewProvider {
	static var previews: some View {
		CacheStatisticsView()
	}
}