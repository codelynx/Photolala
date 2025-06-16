import SwiftUI

struct PhotoRetrievalView: View {
	let photoReference: PhotoReference
	let archiveInfo: ArchivedPhotoInfo
	@State private var selectedOption: RetrievalOption = .singlePhoto
	@State private var rushDelivery = false
	@Binding var isPresented: Bool
	
	@EnvironmentObject var s3BackupService: S3BackupService
	@EnvironmentObject var identityManager: IdentityManager
	
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
				
				Button(action: startRetrieval) {
					HStack {
						Image(systemName: "flame.fill")
						Text("Thaw Photo\(selectedOption == .singlePhoto ? "" : "s")")
					}
				}
				.primaryButtonStyle()
				.disabled(!canStartRetrieval)
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
		}
		.frame(width: 400)
		.background(Color(XPlatform.secondaryBackgroundColor))
		.cornerRadius(12)
	}
	
	// MARK: - Computed Properties
	
	private func photoCount(for option: RetrievalOption) -> Int {
		switch option {
		case .singlePhoto:
			return 1
		case .selectedPhotos:
			return 18 // TODO: Get from selection manager
		case .entireAlbum:
			return 500 // TODO: Get from album
		}
	}
	
	private func totalSize(for option: RetrievalOption) -> String {
		switch option {
		case .singlePhoto:
			return "12MB"
		case .selectedPhotos:
			return "216MB"
		case .entireAlbum:
			return "6GB"
		}
	}
	
	private func cost(for option: RetrievalOption) -> Double {
		switch option {
		case .singlePhoto:
			return 0.03
		case .selectedPhotos:
			return 0.54
		case .entireAlbum:
			return 15.00
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
		// TODO: Implement retrieval request
		print("Starting retrieval for \(photoCount(for: selectedOption)) photos")
		isPresented = false
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

// MARK: - Preview

struct PhotoRetrievalView_Previews: PreviewProvider {
	static var previews: some View {
		PhotoRetrievalView(
			photoReference: PhotoReference(directoryPath: "/test" as NSString, filename: "test.jpg"),
			archiveInfo: ArchivedPhotoInfo(
				md5: "test",
				archivedDate: Date(),
				storageClass: .deepArchive,
				lastAccessedDate: nil,
				isPinned: false,
				retrieval: nil
			),
			isPresented: .constant(true)
		)
		.environmentObject(IdentityManager())
		.frame(width: 500, height: 600)
		.background(Color.gray.opacity(0.3))
	}
}