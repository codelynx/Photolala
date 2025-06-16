import StoreKit
import SwiftUI

struct IAPTestView: View {
	@StateObject private var iapManager = IAPManager.shared
	@StateObject private var identityManager = IdentityManager.shared
	@State private var showingReceipt = false
	@State private var receiptData = ""

	var body: some View {
		VStack(spacing: 20) {
			Text("IAP Testing")
				.font(.largeTitle)
				.fontWeight(.bold)

			// User status
			if self.identityManager.isSignedIn {
				VStack(alignment: .leading) {
					Text("User: \(self.identityManager.currentUser?.email ?? "No email")")
					Text("Subscription: \(self.identityManager.currentUser?.subscription?.displayName ?? "None")")
						.foregroundColor(self.identityManager.currentUser?.subscription != nil ? .green : .red)
				}
				.padding()
				.background(Color.gray.opacity(0.1))
				.cornerRadius(8)
			}

			Divider()

			// Product list
			VStack(alignment: .leading, spacing: 12) {
				Text("Available Products")
					.font(.headline)

				if self.iapManager.products.isEmpty {
					Text("Loading products...")
						.foregroundColor(.secondary)
				} else {
					ForEach(self.iapManager.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
						HStack {
							VStack(alignment: .leading) {
								Text(product.displayName)
									.font(.subheadline)
								Text(product.id)
									.font(.caption)
									.foregroundColor(.secondary)
							}

							Spacer()

							if self.iapManager.purchasedProductIDs.contains(product.id) {
								Image(systemName: "checkmark.circle.fill")
									.foregroundColor(.green)
							}

							Text(product.displayPrice)
								.fontWeight(.medium)
						}
						.padding(.vertical, 4)
					}
				}

				Button("Reload Products") {
					Task {
						await self.iapManager.loadProducts()
					}
				}
				.buttonStyle(.bordered)
			}
			.padding()
			.background(Color.blue.opacity(0.05))
			.cornerRadius(8)

			Divider()

			// Debug actions
			VStack(spacing: 12) {
				Text("Debug Actions")
					.font(.headline)

				Button("Restore Purchases") {
					Task {
						await self.iapManager.restorePurchases()
					}
				}
				.buttonStyle(.bordered)

				Button("Check Transaction Status") {
					Task {
						await self.iapManager.checkTransactionStatus()
					}
				}
				.buttonStyle(.bordered)

				Button("View Receipt") {
					self.loadReceipt()
					self.showingReceipt = true
				}
				.buttonStyle(.bordered)

				if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil {
					#if os(macOS)
						Button("Open StoreKit Config") {
							// This would open the StoreKit configuration in Xcode if available
							NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Xcode.app"))
						}
						.buttonStyle(.bordered)
					#endif
				}
			}

			Spacer()
		}
		.padding()
		.frame(width: 500, height: 600)
		.sheet(isPresented: self.$showingReceipt) {
			ReceiptView(receiptData: self.receiptData)
		}
		.onAppear {
			Task {
				await self.iapManager.loadProducts()
			}
		}
	}

	private func loadReceipt() {
		guard let receiptURL = Bundle.main.appStoreReceiptURL,
		      let receiptData = try? Data(contentsOf: receiptURL)
		else {
			self.receiptData = "No receipt found"
			return
		}

		self.receiptData = receiptData.base64EncodedString()
	}
}

struct ReceiptView: View {
	let receiptData: String
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		VStack {
			Text("App Store Receipt")
				.font(.headline)
				.padding()

			ScrollView {
				Text(self.receiptData)
					.font(.system(.caption, design: .monospaced))
					.textSelection(.enabled)
					.padding()
			}

			Button("Done") {
				self.dismiss()
			}
			.padding()
		}
		.frame(width: 600, height: 400)
	}
}

#Preview {
	IAPTestView()
}
