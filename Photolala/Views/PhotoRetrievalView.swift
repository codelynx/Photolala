import SwiftUI
import CryptoKit

struct PhotoRetrievalView: View {
	let PhotoFile: PhotoFile
	let archiveInfo: ArchivedPhotoInfo
	let selectedPhotos: [PhotoFile]
	@State private var selectedOption: RetrievalOption = .singlePhoto
	@State private var rushDelivery = false
	@Binding var isPresented: Bool
	
	@EnvironmentObject var s3BackupManager: S3BackupManager
	@EnvironmentObject var identityManager: IdentityManager
	@State private var isRetrieving = false
	@State private var retrievalError: String?
	
	init(PhotoFile: PhotoFile, archiveInfo: ArchivedPhotoInfo, selectedPhotos: [PhotoFile] = [], isPresented: Binding<Bool>) {
		self.PhotoFile = PhotoFile
		self.archiveInfo = archiveInfo
		self.selectedPhotos = selectedPhotos
		self._isPresented = isPresented
		
		// Default to selected photos option if multiple photos are selected
		let archivedSelectedPhotos = selectedPhotos.filter { $0.archiveInfo != nil && !$0.archiveInfo!.storageClass.isImmediatelyAccessible }
		if archivedSelectedPhotos.count > 1 {
			self._selectedOption = State(initialValue: .selectedPhotos)
		}
	}
	
	enum RetrievalOption: String, CaseIterable {
		case singlePhoto = "single"
		case selectedPhotos = "selected"
		case entireAlbum = "album"
		
		var title: String {
			switch self {
			case .singlePhoto:
				return "This photo only"
			case .selectedPhotos:
				return "Selected photos"
			case .entireAlbum:
				return "Entire album"
			}
		}
	}
	
	var body: some View {
		VStack(spacing: 0) {
			// Header
			VStack(spacing: 12) {
				Image(systemName: "snowflake")
					.font(.system(size: 48))
					.foregroundColor(.blue)
				
				Text("Archived Photo")
					.font(.title2)
					.fontWeight(.semibold)
				
				Text("This photo was auto-archived after 6 months to save costs.")
					.font(.subheadline)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.padding(.horizontal)
			}
			.padding(.vertical, 24)
			
			Divider()
			
			// Options
			VStack(alignment: .leading, spacing: 16) {
				Text("Retrieval Options")
					.font(.headline)
					.padding(.horizontal)
				
				ForEach(RetrievalOption.allCases, id: \.self) { option in
					if shouldShowOption(option) {
						RetrievalOptionRow(
							option: option,
							isSelected: selectedOption == option,
							photoCount: photoCount(for: option),
							totalSize: totalSize(for: option),
							cost: cost(for: option)
						) {
							selectedOption = option
						}
					}
				}
				
				// Rush delivery option
				Toggle(isOn: $rushDelivery) {
					HStack {
						Image(systemName: "bolt.fill")
							.foregroundColor(.orange)
						Text("Rush delivery (3-5 hours)")
						Spacer()
						Text("+$5.00")
							.foregroundColor(.secondary)
					}
				}
				.padding(.horizontal)
				.padding(.vertical, 8)
				
				// Delivery time
				HStack {
					Image(systemName: "clock")
						.foregroundColor(.secondary)
					Text("Estimated delivery: \(deliveryTimeText)")
						.font(.subheadline)
						.foregroundColor(.secondary)
				}
				.padding(.horizontal)
			}
			.padding(.vertical)
			
			Divider()
			
			// Action buttons
			HStack(spacing: 12) {
				Button("Cancel") {
					isPresented = false
				}
				.secondaryButtonStyle()
				.disabled(isRetrieving)
				
				Button(action: startRetrieval) {
					if isRetrieving {
						HStack {
							ProgressView()
								.progressViewStyle(CircularProgressViewStyle())
								.scaleEffect(0.8)
							Text("Processing...")
						}
					} else {
						HStack {
							Image(systemName: "flame.fill")
							Text("Thaw Photo\(selectedOption == .singlePhoto ? "" : "s")")
						}
					}
				}
				.primaryButtonStyle()
				.disabled(!canStartRetrieval || isRetrieving)
			}
			.padding()
			
			// Cost summary
			VStack(spacing: 8) {
				HStack {
					Text("Retrieval cost:")
					Spacer()
					Text(formattedCost)
						.fontWeight(.medium)
				}
				.font(.subheadline)
				
				if let credits = userCredits {
					HStack {
						Text("Your credits:")
						Spacer()
						Text("\(credits) remaining")
							.foregroundColor(credits > 0 ? .green : .red)
					}
					.font(.caption)
				}
			}
			.padding(.horizontal)
			.padding(.bottom)
			
			// Error display
			if let error = retrievalError {
				HStack {
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundColor(.red)
					Text(error)
						.font(.caption)
						.foregroundColor(.red)
				}
				.padding(.horizontal)
				.padding(.bottom, 8)
			}
		}
		.frame(width: 400)
		.background(Color(XPlatform.secondaryBackgroundColor))
		.cornerRadius(12)
	}
	
	// MARK: - Computed Properties
	
	private func shouldShowOption(_ option: RetrievalOption) -> Bool {
		switch option {
		case .singlePhoto:
			return true
		case .selectedPhotos:
			// Only show if there are multiple archived photos selected
			let archivedCount = selectedPhotos.filter { photo in
				guard let archiveInfo = photo.archiveInfo else { return false }
				return !archiveInfo.storageClass.isImmediatelyAccessible
			}.count
			return archivedCount > 0
		case .entireAlbum:
			return true // TODO: Only show if in album context
		}
	}
	
	private func photoCount(for option: RetrievalOption) -> Int {
		switch option {
		case .singlePhoto:
			return 1
		case .selectedPhotos:
			// Count only archived photos in selection
			let archivedCount = selectedPhotos.filter { photo in
				guard let archiveInfo = photo.archiveInfo else { return false }
				return !archiveInfo.storageClass.isImmediatelyAccessible
			}.count
			return max(1, archivedCount) // At least the clicked photo
		case .entireAlbum:
			return 500 // TODO: Get from album
		}
	}
	
	private func totalSize(for option: RetrievalOption) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		
		switch option {
		case .singlePhoto:
			// Use archive info size if available
			return formatter.string(fromByteCount: archiveInfo.originalSize)
		case .selectedPhotos:
			// Sum sizes of archived photos in selection
			let totalBytes = selectedPhotos.reduce(Int64(0)) { sum, photo in
				guard let archiveInfo = photo.archiveInfo,
				      !archiveInfo.storageClass.isImmediatelyAccessible else {
					return sum
				}
				return sum + archiveInfo.originalSize
			}
			// Include current photo if not in selection
			let finalSize = totalBytes > 0 ? totalBytes : archiveInfo.originalSize
			return formatter.string(fromByteCount: finalSize)
		case .entireAlbum:
			return "6 GB" // TODO: Calculate from album
		}
	}
	
	private func cost(for option: RetrievalOption) -> Double {
		// S3 Deep Archive retrieval cost: $0.025 per GB (standard)
		let costPerGB = rushDelivery ? 0.10 : 0.025
		
		switch option {
		case .singlePhoto:
			let sizeGB = Double(archiveInfo.originalSize) / 1_000_000_000
			return max(0.01, sizeGB * costPerGB) // Minimum $0.01
		case .selectedPhotos:
			// Calculate cost for all archived photos
			let totalBytes = selectedPhotos.reduce(Int64(0)) { sum, photo in
				guard let archiveInfo = photo.archiveInfo,
				      !archiveInfo.storageClass.isImmediatelyAccessible else {
					return sum
				}
				return sum + archiveInfo.originalSize
			}
			let finalSize = totalBytes > 0 ? totalBytes : archiveInfo.originalSize
			let sizeGB = Double(finalSize) / 1_000_000_000
			return max(0.01, sizeGB * costPerGB)
		case .entireAlbum:
			return rushDelivery ? 60.00 : 15.00 // TODO: Calculate from album
		}
	}
	
	private var formattedCost: String {
		let baseCost = cost(for: selectedOption)
		let rushCost = rushDelivery ? 5.0 : 0.0
		let total = baseCost + rushCost
		return String(format: "$%.2f", total)
	}
	
	private var deliveryTimeText: String {
		if rushDelivery {
			return "3-5 hours"
		} else {
			return "12-48 hours"
		}
	}
	
	private var userCredits: Int? {
		// TODO: Get from user subscription
		return 32
	}
	
	private var canStartRetrieval: Bool {
		// TODO: Check user credits/payment method
		return true
	}
	
	// MARK: - Actions
	
	private func startRetrieval() {
		guard let s3Service = s3BackupManager.s3Service,
		      let userId = identityManager.currentUser?.appleUserID else {
			retrievalError = "Service not configured"
			return
		}
		
		isRetrieving = true
		
		Task {
			do {
				switch selectedOption {
				case .singlePhoto:
					// Restore single photo
					let md5: String
					if let existingMD5 = PhotoFile.md5Hash {
						md5 = existingMD5
					} else {
						guard let computedMD5 = await computeMD5() else {
							throw PhotoRetrievalError.missingMD5
						}
						md5 = computedMD5
					}
					try await s3Service.restorePhoto(md5: md5, userId: userId, rushDelivery: rushDelivery)
					
				case .selectedPhotos:
					// Restore all archived photos in selection
					var photosToRestore: [PhotoFile] = []
					
					// Add selected archived photos
					for photo in selectedPhotos {
						if let archiveInfo = photo.archiveInfo,
						   !archiveInfo.storageClass.isImmediatelyAccessible {
							photosToRestore.append(photo)
						}
					}
					
					// Include current photo if not already in list
					if !photosToRestore.contains(where: { $0.fileURL == PhotoFile.fileURL }) {
						photosToRestore.append(PhotoFile)
					}
					
					// Restore each photo
					var errors: [Error] = []
					for photo in photosToRestore {
						do {
							let md5: String
							if let existingMD5 = photo.md5Hash {
								md5 = existingMD5
							} else {
								guard let computedMD5 = await computeMD5(for: photo) else {
									throw PhotoRetrievalError.missingMD5
								}
								md5 = computedMD5
							}
							try await s3Service.restorePhoto(md5: md5, userId: userId, rushDelivery: rushDelivery)
						} catch {
							errors.append(error)
						}
					}
					
					if !errors.isEmpty {
						throw PhotoRetrievalError.batchErrors(errors)
					}
					
				case .entireAlbum:
					// TODO: Get all photos in album
					// For now, just restore the single photo
					let md5: String
					if let existingMD5 = PhotoFile.md5Hash {
						md5 = existingMD5
					} else {
						guard let computedMD5 = await computeMD5() else {
							throw PhotoRetrievalError.missingMD5
						}
						md5 = computedMD5
					}
					try await s3Service.restorePhoto(md5: md5, userId: userId, rushDelivery: rushDelivery)
				}
				
				await MainActor.run {
					isRetrieving = false
					isPresented = false
				}
			} catch {
				await MainActor.run {
					isRetrieving = false
					retrievalError = error.localizedDescription
				}
			}
		}
	}
	
	private func computeMD5() async -> String? {
		do {
			let data = try Data(contentsOf: PhotoFile.fileURL)
			let digest = Insecure.MD5.hash(data: data)
			return digest.map { String(format: "%02hhx", $0) }.joined()
		} catch {
			return nil
		}
	}
	
	private func computeMD5(for photo: PhotoFile) async -> String? {
		do {
			let data = try Data(contentsOf: photo.fileURL)
			let digest = Insecure.MD5.hash(data: data)
			return digest.map { String(format: "%02hhx", $0) }.joined()
		} catch {
			return nil
		}
	}
}

// MARK: - Retrieval Option Row

struct RetrievalOptionRow: View {
	let option: PhotoRetrievalView.RetrievalOption
	let isSelected: Bool
	let photoCount: Int
	let totalSize: String
	let cost: Double
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack {
				Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
					.foregroundColor(isSelected ? .accentColor : .secondary)
					.font(.title3)
				
				VStack(alignment: .leading, spacing: 4) {
					Text(option.title)
						.font(.body)
						.foregroundColor(.primary)
					
					HStack(spacing: 8) {
						Text("\(photoCount) photo\(photoCount == 1 ? "" : "s")")
						Text("•")
						Text(totalSize)
						Text("•")
						Text(String(format: "$%.2f", cost))
							.fontWeight(.medium)
					}
					.font(.caption)
					.foregroundColor(.secondary)
				}
				
				Spacer()
				
				if option == .entireAlbum {
					Text("Best value!")
						.font(.caption)
						.fontWeight(.medium)
						.foregroundColor(.green)
						.padding(.horizontal, 8)
						.padding(.vertical, 2)
						.background(Color.green.opacity(0.1))
						.cornerRadius(4)
				}
			}
			.padding()
			.background(
				RoundedRectangle(cornerRadius: 8)
					.fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
			)
			.overlay(
				RoundedRectangle(cornerRadius: 8)
					.stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
			)
		}
		.buttonStyle(.plain)
		.padding(.horizontal)
	}
}

// MARK: - Errors

enum PhotoRetrievalError: LocalizedError {
	case missingMD5
	case missingUserInfo
	case alreadyRetrieving
	case batchErrors([Error])
	
	var errorDescription: String? {
		switch self {
		case .missingMD5:
			return "Unable to compute photo identifier"
		case .missingUserInfo:
			return "User information not available"
		case .alreadyRetrieving:
			return "This photo is already being retrieved"
		case .batchErrors(let errors):
			return "Failed to retrieve \(errors.count) photos"
		}
	}
}

// MARK: - Preview

struct PhotoRetrievalView_Previews: PreviewProvider {
	static var previews: some View {
		PhotoRetrievalView(
			PhotoFile: PhotoFile(directoryPath: "/test" as NSString, filename: "test.jpg"),
			archiveInfo: ArchivedPhotoInfo(
				md5: "test",
				archivedDate: Date(),
				storageClass: .deepArchive,
				lastAccessedDate: nil,
				isPinned: false,
				retrieval: nil,
				originalSize: 12_000_000
			),
			selectedPhotos: [
				PhotoFile(directoryPath: "/test" as NSString, filename: "test2.jpg"),
				PhotoFile(directoryPath: "/test" as NSString, filename: "test3.jpg")
			],
			isPresented: .constant(true)
		)
		.environmentObject(IdentityManager())
		.environmentObject(S3BackupManager.shared)
		.frame(width: 500, height: 600)
		.background(Color.gray.opacity(0.3))
	}
}
