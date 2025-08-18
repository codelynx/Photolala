//
//  CacheStatisticsView.swift
//  photolala
//
//  Created by Assistant on 2025/06/14.
//

import SwiftUI

struct CacheStatisticsView: View {
	@State private var stats: PhotoManagerV2.CacheStatisticsReport = PhotoManagerV2.shared.getCacheStatistics()
	@State private var memoryUsage: PhotoManagerV2.MemoryUsageInfo = PhotoManagerV2.shared.getMemoryUsageInfo()
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
					self.dismiss()
				}
				.keyboardShortcut(.defaultAction)
			}
			.padding()

			Divider()

			// Statistics Content
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					// Memory Cache Section
					StatisticSection(
						title: "Memory Cache",
						icon: "memorychip",
						color: .blue,
						stats: [
							("Max items", "\(self.stats.memoryCount)"),
							("Max size", "\(self.stats.memoryUsage / 1024 / 1024) MB"),
						]
					)

					// Disk Cache Section
					StatisticSection(
						title: "Disk Cache",
						icon: "internaldrive",
						color: .green,
						stats: [
							("Thumbnails", "\(self.stats.diskCount)"),
							("Total size", "\(self.stats.diskUsage / 1024 / 1024) MB"),
						]
					)


					// Memory Section
					StatisticSection(
						title: "System Memory",
						icon: "memorychip",
						color: .red,
						stats: [
							("Used memory", "\(self.memoryUsage.usedMemory / 1_024 / 1_024) MB"),
							("Available", "\(self.memoryUsage.availableMemory / 1_024 / 1_024) MB"),
							("Total RAM", "\(self.memoryUsage.totalMemory / 1_024 / 1_024 / 1_024) GB"),
						]
					)
				}
				.padding()
			}

			Divider()

			// Actions
			HStack {
				Button("Reset Statistics") {
					PhotoManagerV2.shared.resetStatistics()
					self.stats = PhotoManagerV2.shared.getCacheStatistics()
				}
				.buttonStyle(.bordered)

				Spacer()

				Button("Refresh") {
					self.stats = PhotoManagerV2.shared.getCacheStatistics()
					self.memoryUsage = PhotoManagerV2.shared.getMemoryUsageInfo()
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
				Image(systemName: self.icon)
					.foregroundColor(self.color)
					.font(.title3)
				Text(self.title)
					.font(.headline)
			}

			// Stats Grid
			VStack(alignment: .leading, spacing: 8) {
				ForEach(self.stats, id: \.0) { stat in
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
