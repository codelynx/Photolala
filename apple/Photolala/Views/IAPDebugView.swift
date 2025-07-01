//
//  IAPDebugView.swift
//  Photolala
//
//  Created by Photolala on 6/17/25.
//

import SwiftUI
import StoreKit

/// Debug view for testing IAP locally
struct IAPDebugView: View {
	@EnvironmentObject var iapManager: IAPManager
	@State private var showingSubscriptionView = false
	
	var body: some View {
		VStack(spacing: 20) {
			Text("IAP Debug Panel")
				.font(.largeTitle)
			
			// Current Status
			GroupBox("Current Status") {
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
						Text(iapManager.hasActiveSubscription ? "Yes" : "None")
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
			
			// Quick Actions
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
					
					Button("Refresh Products") {
						Task {
							await iapManager.loadProducts()
						}
					}
					
					Button("Restore Purchases") {
						Task {
							await iapManager.restorePurchases()
						}
					}
					
					#if DEBUG
					Button("Print Debug Info") {
						printDebugInfo()
					}
					.foregroundColor(.orange)
					#endif
				}
			}
			
			// Products List
			if !iapManager.products.isEmpty {
				GroupBox("Available Products") {
					ForEach(iapManager.products.sorted(by: { $0.price < $1.price }), id: \.id) { product in
						HStack {
							VStack(alignment: .leading) {
								Text(product.displayName)
									.font(.headline)
								Text(product.id)
									.font(.caption)
									.foregroundColor(.secondary)
							}
							Spacer()
							Text(product.displayPrice)
								.fontWeight(.medium)
						}
						.padding(.vertical, 4)
					}
				}
			}
			
			Spacer()
		}
		.padding()
		.frame(width: 400, height: 600)
		.sheet(isPresented: $showingSubscriptionView) {
			SubscriptionView()
		}
	}
	
	func printDebugInfo() {
		print("=== IAP Debug Info ===")
		print("Products: \(iapManager.products.map { $0.id })")
		print("Purchased: \(iapManager.purchasedProductIDs)")
		print("Has Active Sub: \(iapManager.hasActiveSubscription)")
		print("Transaction Listener: Active")
		print("===================")
	}
	
	#if os(macOS)
	func openSubscriptionWindow() {
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

#Preview {
	IAPDebugView()
		.environmentObject(IAPManager.shared)
}
