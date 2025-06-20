//
//  PhotoBrowserView.swift
//  photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import Observation
import SwiftUI

struct PhotoBrowserView: View {
	let directoryPath: NSString
	@State private var settings = ThumbnailDisplaySettings()
	@State private var photosCount = 0
	@State private var selectedPhotos: [PhotoFile] = []
	@State private var navigationPath = NavigationPath()
	@State private var selectedPhotoNavigation: PreviewNavigation?
	@State private var allPhotos: [PhotoFile] = []
	@State private var showingHelp = false
	@State private var showingS3UploadProgress = false
	@State private var showingSignInPrompt = false
	@State private var showingUpgradePrompt = false
	@State private var archivedPhotoForRetrieval: PhotoFile?
	@State private var showingRetrievalDialog = false
	@State private var isRefreshing = false
	@State private var showingInspector = false
	@StateObject private var s3BackupManager = S3BackupManager.shared
	@StateObject private var identityManager = IdentityManager.shared
	@StateObject private var backupQueueManager = BackupQueueManager.shared
	@StateObject private var photoProvider: EnhancedLocalPhotoProvider
	
	// Computed property to ensure inspector gets PhotoItems
	private var inspectorSelection: [any PhotoItem] {
		selectedPhotos.map { $0 as any PhotoItem }
	}

	init(directoryPath: NSString) {
		self.directoryPath = directoryPath
		self._photoProvider = StateObject(wrappedValue: EnhancedLocalPhotoProvider(directoryPath: directoryPath as String))
	}

	var body: some View {
		#if os(macOS)
			VStack(spacing: 0) {
				NavigationStack(path: self.$navigationPath) {
					self.collectionContent
						.navigationDestination(for: PreviewNavigation.self) { navigation in
							PhotoPreviewView(
								photos: navigation.photos,
								initialIndex: navigation.initialIndex
							)
							.navigationBarBackButtonHidden(true)
						}
				}
				.onKeyPress(.space) {
					self.handleSpaceKeyPress()
					return .handled
				}
				.onKeyPress(keys: ["s"]) { _ in
					// Print cache statistics
					PhotoManager.shared.printCacheStatistics()
					return .handled
				}
				.onKeyPress(keys: ["r"]) { _ in
					// Reset cache statistics
					PhotoManager.shared.resetStatistics()
					return .handled
				}
				.sheet(isPresented: self.$showingSignInPrompt) {
					SignInPromptView()
				}
				.sheet(isPresented: self.$showingUpgradePrompt) {
					SubscriptionView()
				}
				.sheet(isPresented: self.$showingRetrievalDialog) {
					if let photo = archivedPhotoForRetrieval,
					   let archiveInfo = photo.archiveInfo {
						PhotoRetrievalView(
							PhotoFile: photo,
							archiveInfo: archiveInfo,
							isPresented: self.$showingRetrievalDialog
						)
						.environmentObject(s3BackupManager)
						.environmentObject(identityManager)
					}
				}
				
				// Backup status bar
				BackupStatusBar()
			}
			.inspector(
				isPresented: $showingInspector,
				selection: inspectorSelection
			)
		#else
			self.collectionContent
				.navigationDestination(item: self.$selectedPhotoNavigation) { navigation in
					PhotoPreviewView(
						photos: navigation.photos,
						initialIndex: navigation.initialIndex
					)
					.navigationBarBackButtonHidden(true)
				}
				.sheet(isPresented: self.$showingHelp) {
					HelpView()
				}
				.sheet(isPresented: self.$showingRetrievalDialog) {
					if let photo = archivedPhotoForRetrieval,
					   let archiveInfo = photo.archiveInfo {
						PhotoRetrievalView(
							PhotoFile: photo,
							archiveInfo: archiveInfo,
							selectedPhotos: self.selectedPhotos,
							isPresented: self.$showingRetrievalDialog
						)
						.environmentObject(s3BackupManager)
						.environmentObject(identityManager)
					}
				}
				.onReceive(NotificationCenter.default.publisher(for: .showHelp)) { _ in
					self.showingHelp = true
				}
		#endif
	}

	@ViewBuilder
	private var collectionContent: some View {
		UnifiedPhotoCollectionViewRepresentable(
			photoProvider: photoProvider,
			settings: settings,
			onSelectPhoto: { photo, allPhotos in
				if let photoFile = photo as? PhotoFile {
					handlePhotoSelection(photoFile, allPhotos.compactMap { $0 as? PhotoFile })
				}
			},
			onSelectionChanged: { photos in
				self.selectedPhotos = photos.compactMap { $0 as? PhotoFile }
				print("[PhotoBrowserView] Selection changed: \(photos.count) photos selected")
			}
		)
		.onAppear {
			Task {
				try? await photoProvider.loadPhotos()
			}
		}
		.onReceive(photoProvider.photosPublisher) { photos in
			self.allPhotos = photos.compactMap { $0 as? PhotoFile }
			self.photosCount = photos.count
			// Don't load archive status for local photos - it's not needed and causes unnecessary S3 requests
		}
		.navigationTitle(self.directoryPath.lastPathComponent)
		#if os(macOS)
			.navigationSubtitle(self.directoryPath as String)
		#endif
			.onReceive(NotificationCenter.default.publisher(for: .deselectAll)) { _ in
				self.selectedPhotos = []
			}
			.onReceive(NotificationCenter.default.publisher(for: .toggleInspector)) { _ in
				self.showingInspector.toggle()
			}
			.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("BackupQueueChanged"))) { _ in
				// Force refresh of collection view to update star states
				self.photosCount = self.allPhotos.count + 1  // Trigger a refresh
				self.photosCount = self.allPhotos.count      // Reset to correct count
			}
			.overlay {
				if self.showingS3UploadProgress {
					ZStack {
						Color.black.opacity(0.4)
							.ignoresSafeArea()

						VStack(spacing: 16) {
							ProgressView()
								.progressViewStyle(CircularProgressViewStyle())
								.scaleEffect(1.5)

							Text(self.s3BackupManager.uploadStatus)
								.font(.headline)
								.foregroundColor(.white)

							if self.s3BackupManager.uploadProgress > 0 {
								ProgressView(value: self.s3BackupManager.uploadProgress)
									.frame(width: 200)
							}
						}
						.padding(32)
						.background(Color.secondary.opacity(0.9))
						.cornerRadius(16)
					}
				} else if photoProvider.isLoading && photoProvider.loadingProgress > 0 {
					// Show progressive loading status at the top
					VStack {
						HStack {
							ProgressView(value: photoProvider.loadingProgress) {
								Text(photoProvider.loadingStatusText)
									.font(.caption)
									.foregroundColor(.secondary)
							}
							.progressViewStyle(.linear)
							.frame(maxWidth: 300)
							.padding(.horizontal)
							.padding(.vertical, 8)
							.background(Color(NSColor.controlBackgroundColor))
							.cornerRadius(8)
							.shadow(radius: 2)
						}
						.padding(.top, 8)
						
						Spacer()
					}
				}
			}
			.toolbar {
				ToolbarItemGroup(placement: .automatic) {
					// Backup queue indicator
					if backupQueueManager.queuedPhotos.count > 0 {
						Button(action: {
							// Start manual backup
							Task {
								await backupQueueManager.startManualBackup()
							}
						}) {
							HStack(spacing: 4) {
								Image(systemName: "star.fill")
									.foregroundColor(.yellow)
								Text("\(backupQueueManager.queuedPhotos.count)")
							}
						}
						#if os(macOS)
						.help("Backup \(backupQueueManager.queuedPhotos.count) starred photos")
						#endif
					}
					
					// Preview selected photos button
					if !self.selectedPhotos.isEmpty {
						Button(action: self.previewSelectedPhotos) {
							Label("Preview", systemImage: "eye")
						}
						#if os(macOS)
						.help("Preview selected photos")
						#endif
					}
					// Display mode toggle
					Button(action: {
						self.settings.displayMode = self.settings
							.displayMode == .scaleToFit ? .scaleToFill : .scaleToFit
					}) {
						Image(systemName: self.settings.displayMode == .scaleToFit ? "aspectratio" : "aspectratio.fill")
					}
					#if os(macOS)
					.help(self.settings.displayMode == .scaleToFit ? "Switch to Fill" : "Switch to Fit")
					#endif
					
					// Item info toggle
					Button(action: {
						self.settings.showItemInfo.toggle()
					}) {
						Image(systemName: "squares.below.rectangle")
					}
					#if os(macOS)
					.help(self.settings.showItemInfo ? "Hide item info" : "Show item info")
					#endif

					#if os(iOS)
						// Size menu for iOS
						Menu {
							Button("S") {
								self.settings.thumbnailOption = .small
							}
							Button("M") {
								self.settings.thumbnailOption = .medium
							}
							Button("L") {
								self.settings.thumbnailOption = .large
							}
						} label: {
							Image(systemName: "slider.horizontal.3")
						}
					#else
						// Size picker for macOS
						Picker("Size", selection: self.$settings.thumbnailOption) {
							Text("S").tag(ThumbnailOption.small)
							Text("M").tag(ThumbnailOption.medium)
							Text("L").tag(ThumbnailOption.large)
						}
						.pickerStyle(.segmented)
						.help("Thumbnail size")
					#endif

					// Sort picker
					#if os(iOS)
						Menu {
							ForEach(PhotoSortOption.allCases, id: \.self) { option in
								Button(action: {
									self.settings.sortOption = option
									Task {
										await photoProvider.applySorting(option)
									}
								}) {
									Label(option.rawValue, systemImage: option.systemImage)
									if option == self.settings.sortOption {
										Image(systemName: "checkmark")
									}
								}
							}
						} label: {
							Label("Sort", systemImage: self.settings.sortOption.systemImage)
						}
					#else
						// macOS: Use a picker with menu style
						Picker("Sort", selection: Binding(
							get: { self.settings.sortOption },
							set: { newValue in
								self.settings.sortOption = newValue
								Task {
									await photoProvider.applySorting(newValue)
								}
							}
						)) {
							ForEach(PhotoSortOption.allCases, id: \.self) { option in
								Text(option.rawValue)
									.tag(option)
							}
						}
						.pickerStyle(.menu)
						.frame(width: 150)
						.help("Sort photos by")
					#endif

					// Grouping picker
					#if os(iOS)
						Menu {
							Button(action: {
								self.settings.groupingOption = .year
								Task {
									await photoProvider.applyGrouping(.year)
								}
							}) {
								Label("Year", systemImage: "calendar")
								if self.settings.groupingOption == .year {
									Image(systemName: "checkmark")
								}
							}
							Button(action: {
								self.settings.groupingOption = .month
								Task {
									await photoProvider.applyGrouping(.month)
								}
							}) {
								Label("Month", systemImage: "calendar.badge.clock")
								if self.settings.groupingOption == .month {
									Image(systemName: "checkmark")
								}
							}
							Button(action: {
								self.settings.groupingOption = .day
								Task {
									await photoProvider.applyGrouping(.day)
								}
							}) {
								Label("Day", systemImage: "calendar.circle")
								if self.settings.groupingOption == .day {
									Image(systemName: "checkmark")
								}
							}

							Divider()

							Button(action: {
								self.settings.groupingOption = .none
								Task {
									await photoProvider.applyGrouping(.none)
								}
							}) {
								Label("None", systemImage: "square.grid.3x3")
								if self.settings.groupingOption == .none {
									Image(systemName: "checkmark")
								}
							}
						} label: {
							if self.settings.groupingOption != .none {
								Label(
									self.settings.groupingOption.rawValue,
									systemImage: self.settings.groupingOption.systemImage
								)
							} else {
								Image(systemName: "calendar")
							}
						}
					#else
						// macOS: Use a picker with menu style
						Picker("Group by", selection: Binding(
							get: { self.settings.groupingOption },
							set: { newValue in
								self.settings.groupingOption = newValue
								Task {
									await photoProvider.applyGrouping(newValue)
								}
							}
						)) {
							Text("Year").tag(PhotoGroupingOption.year)
							Text("Month").tag(PhotoGroupingOption.month)
							Text("Day").tag(PhotoGroupingOption.day)
							Divider()
							Text("None").tag(PhotoGroupingOption.none)
						}
						.pickerStyle(.menu)
						.frame(width: 120)
						.help("Group photos by date")
					#endif
					
					// Refresh button
					Button(action: {
						Task {
							isRefreshing = true
							defer { isRefreshing = false }
							try? await photoProvider.refresh()
						}
					}) {
						Label("Refresh", systemImage: "arrow.clockwise")
					}
					.disabled(isRefreshing)
					#if os(macOS)
					.help("Refresh folder contents")
					#endif
					
					// Inspector button
					Button(action: {
						showingInspector.toggle()
					}) {
						Label("Inspector", systemImage: "info.circle")
					}
					#if os(macOS)
					.help(showingInspector ? "Hide Inspector" : "Show Inspector")
					#endif

					// S3 Backup button
					if !self.selectedPhotos.isEmpty && FeatureFlags.isS3BackupEnabled {
						Button(action: self.backupSelectedPhotos) {
							Label("Backup", systemImage: "icloud.and.arrow.up")
						}
						.disabled(self.s3BackupManager.isUploading)
						#if os(macOS)
							.help(
								self.identityManager
									.isSignedIn ? "Backup selected photos to cloud" : "Sign in to backup photos"
							)
						#endif
					}
				}
			}
	}

	private func handleSpaceKeyPress() {
		// If we don't have photos yet, return
		guard !self.allPhotos.isEmpty else { return }

		// Always show all photos, but start from selected if any
		let photosToShow = self.allPhotos
		let initialIndex: Int = if !self.selectedPhotos.isEmpty {
			// Find the first selected photo in the full list
			if let firstSelected = selectedPhotos.first,
			   let index = allPhotos.firstIndex(of: firstSelected)
			{
				index
			} else {
				0
			}
		} else {
			0
		}

		print(
			"[PhotoBrowserView] Space key: Showing all \(photosToShow.count) photos, starting at index \(initialIndex)"
		)

		let navigation = PreviewNavigation(photos: photosToShow, initialIndex: initialIndex)

		#if os(macOS)
			self.navigationPath.append(navigation)
		#else
			self.selectedPhotoNavigation = navigation
		#endif
	}

	private func handlePhotoSelection(_ photo: PhotoFile, _ allPhotos: [PhotoFile]) {
		print("[PhotoBrowserView] handlePhotoSelection called for: \(photo.filename)")

		// Store all photos for space key navigation
		self.allPhotos = allPhotos

		// If there's an active selection, show only selected photos
		let photosToShow: [PhotoFile]
		let initialIndex: Int

		if !self.selectedPhotos.isEmpty {
			// Convert selection to array maintaining order
			photosToShow = allPhotos.filter { self.selectedPhotos.contains($0) }
			initialIndex = photosToShow.firstIndex(of: photo) ?? 0
			print("[PhotoBrowserView] Showing \(photosToShow.count) selected photos")
		} else {
			// Show all photos
			photosToShow = allPhotos
			initialIndex = allPhotos.firstIndex(of: photo) ?? 0
			print("[PhotoBrowserView] Showing all \(photosToShow.count) photos")
		}

		// Navigate to preview
		print("[PhotoBrowserView] Navigating to preview with index: \(initialIndex)")
		let navigation = PreviewNavigation(photos: photosToShow, initialIndex: initialIndex)

		#if os(macOS)
			self.navigationPath.append(navigation)
		#else
			self.selectedPhotoNavigation = navigation
		#endif
	}

	private func previewSelectedPhotos() {
		// Get the selected photos in order
		let sortedPhotos = self.selectedPhotos.sorted { photo1, photo2 in
			// Sort by filename to maintain consistent order
			photo1.filename < photo2.filename
		}

		guard !sortedPhotos.isEmpty else { return }

		print("[PhotoBrowserView] Previewing \(sortedPhotos.count) selected photos")

		// Start preview from the first selected photo
		let navigation = PreviewNavigation(photos: sortedPhotos, initialIndex: 0)

		#if os(macOS)
			self.navigationPath.append(navigation)
		#else
			self.selectedPhotoNavigation = navigation
		#endif
	}

	private func backupSelectedPhotos() {
		// Check if signed in
		guard self.identityManager.isSignedIn else {
			self.showingSignInPrompt = true
			return
		}

		// Check if service is configured
		guard self.s3BackupManager.isConfigured else {
			// In production, this would be automatic
			// For now, show error
			return
		}

		self.showingS3UploadProgress = true

		Task {
			do {
				try await self.s3BackupManager.uploadPhotos(self.selectedPhotos)
				await MainActor.run {
					self.showingS3UploadProgress = false
					self.selectedPhotos = [] // Clear selection after upload
				}
			} catch S3BackupError.uploadFailed {
				// Might be quota exceeded
				await MainActor.run {
					self.showingS3UploadProgress = false
					if self.s3BackupManager.currentUsage >= self.s3BackupManager.storageLimit {
						self.showingUpgradePrompt = true
					}
				}
			} catch {
				await MainActor.run {
					self.showingS3UploadProgress = false
					// Show error
				}
			}
		}
	}
	
	private func loadArchiveStatus(for photos: [PhotoFile]) async {
		// Only load if S3 backup is configured and user is signed in
		guard s3BackupManager.isConfigured,
		      let userId = identityManager.currentUser?.appleUserID else { return }
		
		print("[PhotoBrowserView] Loading archive status for \(photos.count) photos")
		
		// Load archive status in batches to avoid overwhelming the API
		let batchSize = 50
		guard let s3Service = s3BackupManager.s3Service else { return }
		
		for batch in photos.chunked(into: batchSize) {
			await PhotoManager.shared.loadArchiveStatus(
				for: batch,
				s3Service: s3Service,
				userId: userId
			)
		}
	}
}

// Navigation data model
struct PreviewNavigation: Hashable {
	let photos: [PhotoFile]
	let initialIndex: Int
}


// Helper extension for array chunking
extension Array {
	func chunked(into size: Int) -> [[Element]] {
		return stride(from: 0, to: count, by: size).map {
			Array(self[$0..<Swift.min($0 + size, count)])
		}
	}
}

#Preview {
	PhotoBrowserView(directoryPath: "/Users/example/Pictures")
}
