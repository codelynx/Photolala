//
//  IAPDeveloperView.swift
//  Photolala
//
//  Created by Photolala on 6/17/25.
//

import SwiftUI
import StoreKit

/// Consolidated IAP developer tools view combining testing and debugging features
struct IAPDeveloperView: View {
	@StateObject private var iapManager = IAPManager.shared
	@StateObject private var identityManager = IdentityManager.shared
	@State private var showingReceipt = false
	@State private var receiptData = ""
	@State private var showingSubscriptionView = false
	@State private var selectedTab: ViewTab = .status
	
	private enum ViewTab: Int {
		case status = 0
		case products = 1
		case actions = 2
	}
	
	var body: some View {
		VStack {
			// Tab picker
			Picker("", selection: $selectedTab) {
				Text("Status").tag(ViewTab.status)
				Text("Products").tag(ViewTab.products)
				Text("Actions").tag(ViewTab.actions)
			}
			.pickerStyle(.segmented)
			.padding(.horizontal)
			
			// Tab content - Using switch instead of TabView to avoid title bar issues
			Group {
				switch selectedTab {
				case ViewTab.status:
					statusTab
				case ViewTab.products:
					productsTab
				case ViewTab.actions:
					actionsTab
				}
			}
		}
		.padding()
		.frame(width: 600, height: 700)
		// TODO: ReceiptView was removed - implement receipt display if needed
		// .sheet(isPresented: $showingReceipt) {
		// 	ReceiptView(receiptData: receiptData)
		// }
		.onAppear {
			Task {
				await iapManager.loadProducts()
			}
		}
	}
	
	// MARK: - Status Tab
	
	private var statusTab: some View {
		ScrollView {
			VStack(spacing: 20) {
				// User status
				GroupBox("User Status") {
					if identityManager.isSignedIn {
						VStack(alignment: .leading, spacing: 8) {
							HStack {
								Text("Email:")
								Spacer()
								Text(identityManager.currentUser?.email ?? "No email")
									.foregroundColor(.secondary)
							}
							
							HStack {
								Text("Subscription:")
								Spacer()
								Text(identityManager.currentUser?.subscription?.displayName ?? "None")
									.foregroundColor(identityManager.currentUser?.subscription != nil ? .green : .red)
							}
							
							if let subscription = identityManager.currentUser?.subscription {
								HStack {
									Text("Expires:")
									Spacer()
									Text(subscription.expiresAt, style: .date)
										.foregroundColor(.secondary)
								}
							}
						}
						.padding(.vertical, 4)
					} else {
						Text("Not signed in")
							.foregroundColor(.secondary)
					}
				}
				
				// IAP Status
				GroupBox("IAP Status") {
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Products Loaded:")
							Spacer()
							Text("\(iapManager.products.count)")
								.foregroundColor(iapManager.products.isEmpty ? .red : .green)
						}
						
						HStack {
							Text("Active Subscription:")
							Spacer()
							Text(iapManager.hasActiveSubscription ? "Yes" : "No")
								.foregroundColor(iapManager.hasActiveSubscription ? .green : .secondary)
						}
						
						HStack {
							Text("Purchased IDs:")
							Spacer()
							Text(iapManager.purchasedProductIDs.isEmpty ? "None" : "\(iapManager.purchasedProductIDs.count)")
								.foregroundColor(.secondary)
						}
					}
					.padding(.vertical, 4)
				}
				
				// Debug info
				GroupBox("Debug Info") {
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Environment:")
							Spacer()
							Text("Sandbox")
								.foregroundColor(.orange)
						}
						
						HStack {
							Text("Bundle ID:")
							Spacer()
							Text(Bundle.main.bundleIdentifier ?? "Unknown")
								.font(.caption)
								.foregroundColor(.secondary)
						}
					}
					.padding(.vertical, 4)
				}
			}
			.padding()
		}
	}
	
	// MARK: - Products Tab
	
	private var productsTab: some View {
		ScrollView {
			VStack(spacing: 20) {
				// Product list
				GroupBox("Available Products") {
					if iapManager.products.isEmpty {
						Text("Loading products...")
							.foregroundColor(.secondary)
							.padding()
					} else {
						ForEach(iapManager.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
							HStack {
								VStack(alignment: .leading, spacing: 4) {
									Text(product.displayName)
										.font(.headline)
									Text(product.id)
										.font(.caption)
										.foregroundColor(.secondary)
									Text(product.description)
										.font(.caption)
										.foregroundColor(.secondary)
										.lineLimit(2)
								}
								
								Spacer()
								
								VStack(alignment: .trailing, spacing: 4) {
									Text(product.displayPrice)
										.fontWeight(.medium)
									
									if iapManager.purchasedProductIDs.contains(product.id) {
										Label("Active", systemImage: "checkmark.circle.fill")
											.font(.caption)
											.foregroundColor(.green)
									}
								}
							}
							.padding(.vertical, 8)
							
							if product.id != iapManager.products.last?.id {
								Divider()
							}
						}
					}
				}
				
				// Purchased products
				if !iapManager.purchasedProductIDs.isEmpty {
					GroupBox("Purchased Products") {
						ForEach(Array(iapManager.purchasedProductIDs), id: \.self) { productID in
							HStack {
								Text(productID)
									.font(.caption)
								Spacer()
								Image(systemName: "checkmark.circle.fill")
									.foregroundColor(.green)
							}
							.padding(.vertical, 4)
						}
					}
				}
			}
			.padding()
		}
	}
	
	// MARK: - Actions Tab
	
	private var actionsTab: some View {
		ScrollView {
			VStack(spacing: 20) {
				// Quick actions
				GroupBox("Quick Actions") {
					VStack(spacing: 12) {
						Button("Open Subscription View") {
							#if os(macOS)
							openSubscriptionWindow()
							#else
							showingSubscriptionView = true
							#endif
						}
						.buttonStyle(.borderedProminent)
						.frame(maxWidth: .infinity)
						
						Button("Refresh Products") {
							Task {
								await iapManager.loadProducts()
							}
						}
						.frame(maxWidth: .infinity)
						
						Button("Restore Purchases") {
							Task {
								await iapManager.restorePurchases()
							}
						}
						.frame(maxWidth: .infinity)
						
						Button("Check Transaction Status") {
							Task {
								await iapManager.checkTransactionStatus()
							}
						}
						.frame(maxWidth: .infinity)
					}
				}
				
				// Debug actions
				GroupBox("Debug Actions") {
					VStack(spacing: 12) {
						Button("View Receipt") {
							loadReceipt()
							showingReceipt = true
						}
						.frame(maxWidth: .infinity)
						
						Button("Print Debug Info") {
							printDebugInfo()
						}
						.foregroundColor(.orange)
						.frame(maxWidth: .infinity)
						
						#if os(macOS)
						Button("Open StoreKit Config") {
							NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Xcode.app"))
						}
						.frame(maxWidth: .infinity)
						#endif
					}
				}
			}
			.padding()
		}
	}
	
	// MARK: - Helper Methods
	
	private func loadReceipt() {
		guard let receiptURL = Bundle.main.appStoreReceiptURL else {
			self.receiptData = "Receipt URL not found"
			return
		}
		
		do {
			let receiptData = try Data(contentsOf: receiptURL)
			let base64Receipt = receiptData.base64EncodedString()
			
			var receiptInfo = "=== App Store Receipt Info ==="
			receiptInfo += "\n\nReceipt URL: \(receiptURL.path)"
			receiptInfo += "\nReceipt Size: \(receiptData.count) bytes"
			receiptInfo += "\nReceipt exists: Yes"
			receiptInfo += "\n\n=== Receipt Data (Base64) ==="
			receiptInfo += "\n\n\(base64Receipt.prefix(1000))..."
			receiptInfo += "\n\n(Showing first 1000 characters of \(base64Receipt.count) total)"
			receiptInfo += "\n\n=== Note ==="
			receiptInfo += "\nIn sandbox/debug mode, receipts may be empty or minimal."
			receiptInfo += "\nFull receipt data is available after TestFlight or App Store purchases."
			
			self.receiptData = receiptInfo
		} catch {
			self.receiptData = "=== App Store Receipt Info ==="
			self.receiptData += "\n\nReceipt URL: \(receiptURL.path)"
			self.receiptData += "\nReceipt exists: No"
			self.receiptData += "\nError: \(error.localizedDescription)"
			self.receiptData += "\n\n=== Note ==="
			self.receiptData += "\nThis is normal in development builds."
			self.receiptData += "\nReceipts are generated when:"
			self.receiptData += "\n  • Making sandbox purchases"
			self.receiptData += "\n  • Installing from TestFlight"
			self.receiptData += "\n  • Installing from App Store"
		}
	}
	
	private func printDebugInfo() {
		print("\n=== IAP Debug Info ===")
		print("Time: \(Date())")
		print("\n--- Products ---")
		print("Count: \(iapManager.products.count)")
		for product in iapManager.products {
			print("  • \(product.id): \(product.displayName) - \(product.displayPrice)")
		}
		
		print("\n--- Purchases ---")
		print("Active IDs: \(iapManager.purchasedProductIDs)")
		print("Has active subscription: \(iapManager.hasActiveSubscription)")
		
		print("\n--- User ---")
		if let user = identityManager.currentUser {
			print("Email: \(user.email ?? "Unknown")")
			if let sub = user.subscription {
				print("Subscription: \(sub.displayName)")
				print("Expires: \(sub.expiresAt)")
			}
		} else {
			print("No user signed in")
		}
		
		print("\n--- Environment ---")
		print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
		print("Sandbox: Yes")
		print("=====================\n")
	}
	
	#if os(macOS)
	private func openSubscriptionWindow() {
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
			styleMask: [.titled, .closable, .resizable],
			backing: .buffered,
			defer: false
		)
		
		window.title = "Manage Subscription"
		window.center()
		window.contentView = NSHostingView(rootView: SubscriptionView())
		window.makeKeyAndOrderFront(nil)
		
		// Keep window in front but not floating
		window.level = .normal
		window.isReleasedWhenClosed = false
	}
	#endif
}

// Receipt View is imported from IAPTestView.swift

#Preview {
	IAPDeveloperView()
		.frame(width: 600, height: 700)
		.padding(.top, 40) // Extra padding for preview
}
