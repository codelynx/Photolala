import StoreKit
import SwiftUI

struct SubscriptionView: View {
	@StateObject private var iapManager = IAPManager.shared
	@StateObject private var identityManager = IdentityManager.shared
	@State private var selectedProduct: Product?
	@State private var isPurchasing = false
	@State private var showError = false
	@State private var errorMessage = ""
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationView {
			ScrollView {
				VStack(spacing: 24) {
					self.headerSection

					if let user = identityManager.currentUser {
						self.currentPlanSection(user: user)
					}

					self.subscriptionOptionsSection

					self.featuresComparisonSection
				}
				.padding()
			}
			.frame(minWidth: 256)
			.navigationTitle("Photolala Backup")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Done") {
						#if os(macOS)
							if let window = NSApp.keyWindow {
								window.close()
							}
						#else
							self.dismiss()
						#endif
					}
				}
			}
		}
		.alert("Purchase Error", isPresented: self.$showError) {
			Button("OK") {}
		} message: {
			Text(self.errorMessage)
		}
		.onAppear {
			Task {
				await self.iapManager.loadProducts()
			}
		}
	}

	private var headerSection: some View {
		VStack(spacing: 12) {
			Image(systemName: "icloud.and.arrow.up")
				.font(.system(size: 48))
				.foregroundColor(.accentColor)

			Text("Secure Cloud Backup")
				.font(.title)
				.fontWeight(.bold)

			Text("Never lose your precious memories")
				.font(.headline)
				.foregroundColor(.secondary)
		}
		.padding(.vertical)
	}

	private func currentPlanSection(user: PhotolalaUser) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Current Plan")
				.font(.headline)

			HStack {
				Image(systemName: "checkmark.circle.fill")
					.foregroundColor(.green)

				VStack(alignment: .leading) {
					Text(user.subscription?.displayName ?? "Free Plan")
						.font(.title3)
						.fontWeight(.semibold)

					Text(
						"Storage: \(self.formatBytes(user.subscription?.quotaBytes ?? 5_000_000_000)) / \(self.formatBytes(user.subscription?.quotaBytes ?? 5_000_000_000))"
					)
					.font(.caption)
					.foregroundColor(.secondary)
				}

				Spacer()

				if user.subscription != nil {
					VStack(alignment: .trailing) {
						Text("Renews")
							.font(.caption)
							.foregroundColor(.secondary)
						Text(user.subscription!.expiresAt, style: .date)
							.font(.caption)
							.fontWeight(.medium)
					}
				}
			}
			.padding()
			.background(Color.accentColor.opacity(0.1))
			.cornerRadius(12)
		}
	}

	private var subscriptionOptionsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Choose Your Plan")
				.font(.headline)

			ForEach(self.iapManager.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
				SubscriptionOptionView(
					product: product,
					isSelected: self.selectedProduct?.id == product.id,
					isPurchased: self.iapManager.purchasedProductIDs.contains(product.id)
				) {
					self.selectedProduct = product
					self.purchaseSelected()
				}
			}
		}
	}

	private var featuresComparisonSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("All Plans Include")
				.font(.headline)

			FeatureRow(
				icon: "lock.shield",
				title: "End-to-End Encryption",
				description: "Your photos are encrypted before leaving your device"
			)
			FeatureRow(
				icon: "arrow.up.arrow.down",
				title: "Automatic Sync",
				description: "Seamlessly backup new photos as you take them"
			)
			FeatureRow(
				icon: "clock.arrow.circlepath",
				title: "Version History",
				description: "Restore previous versions of edited photos"
			)
			FeatureRow(
				icon: "person.2",
				title: "Family Sharing",
				description: "Share storage with up to 5 family members (Family plan)"
			)
			FeatureRow(icon: "speedometer", title: "Fast Uploads", description: "Optimized for quick, reliable backups")
			FeatureRow(
				icon: "checkmark.shield",
				title: "30-Day Recovery",
				description: "Recover deleted photos within 30 days"
			)
		}
		.padding(.top)
	}

	private func purchaseSelected() {
		guard let product = selectedProduct else { return }

		Task {
			self.isPurchasing = true
			do {
				try await self.iapManager.purchase(product)
				// Success is handled by IAPManager updating the user
			} catch {
				self.errorMessage = error.localizedDescription
				self.showError = true
			}
			self.isPurchasing = false
		}
	}

	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .binary
		return formatter.string(fromByteCount: bytes)
	}
}

struct SubscriptionOptionView: View {
	let product: Product
	let isSelected: Bool
	let isPurchased: Bool
	let action: () -> Void

	var body: some View {
		Button(action: self.action) {
			HStack {
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text(self.productTitle)
							.font(.title3)
							.fontWeight(.semibold)

						if self.isPurchased {
							Label("Current", systemImage: "checkmark.circle.fill")
								.font(.caption)
								.foregroundColor(.green)
						}

						if self.product.id.contains("family") {
							Label("Best Value", systemImage: "star.fill")
								.font(.caption)
								.foregroundColor(.orange)
						}
					}

					Text(self.productDescription)
						.font(.caption)
						.foregroundColor(.secondary)

					HStack {
						Text(self.product.displayPrice)
							.font(.headline)

						if let savings = calculateSavings() {
							Text(savings)
								.font(.caption)
								.foregroundColor(.green)
						}
					}
				}

				Spacer()

				Image(systemName: self.isPurchased ? "checkmark.circle.fill" : "circle")
					.font(.title2)
					.foregroundColor(self.isPurchased ? .green : .secondary)
			}
			.padding()
			.background(self.isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(self.isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
			)
			.cornerRadius(12)
		}
		.buttonStyle(.plain)
		.disabled(self.isPurchased)
	}

	private var productTitle: String {
		switch self.product.id {
		case IAPProductID.starter.rawValue:
			"Starter - 500GB Photos"
		case IAPProductID.essential.rawValue:
			"Essential - 1TB Photos"
		case IAPProductID.plus.rawValue:
			"Plus - 2TB Photos"
		case IAPProductID.family.rawValue:
			"Family - 5TB Photos"
		default:
			self.product.displayName
		}
	}

	private var productDescription: String {
		switch self.product.id {
		case IAPProductID.starter.rawValue:
			"Store 100,000 photos"
		case IAPProductID.essential.rawValue:
			"Store 200,000 photos"
		case IAPProductID.plus.rawValue:
			"Store 300,000 photos"
		case IAPProductID.family.rawValue:
			"300,000 photos - shareable with family"
		default:
			self.product.description
		}
	}

	private func calculateSavings() -> String? {
		// Calculate annual savings for yearly plans
		if self.product.id.contains("yearly") {
			// This would need the monthly price to calculate
			// For now, return a placeholder
			return "Save 17%"
		}
		return nil
	}
}

struct FeatureRow: View {
	let icon: String
	let title: String
	let description: String

	var body: some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: self.icon)
				.font(.title3)
				.foregroundColor(.accentColor)
				.frame(width: 30)

			VStack(alignment: .leading, spacing: 2) {
				Text(self.title)
					.font(.subheadline)
					.fontWeight(.medium)

				Text(self.description)
					.font(.caption)
					.foregroundColor(.secondary)
			}

			Spacer()
		}
		.padding(.vertical, 4)
	}
}

#Preview {
	SubscriptionView()
}
