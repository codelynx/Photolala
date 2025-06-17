//
//  ReceiptValidationTestView.swift
//  Photolala
//
//  Created by Claude on 6/17/25.
//

import SwiftUI
import StoreKit

struct ReceiptValidationTestView: View {
	@State private var validationResult: ReceiptValidationResult?
	@State private var isValidating = false
	@State private var sandboxResult: ReceiptValidationResult?
	@State private var receiptExists = false
	@State private var receiptSize = 0
	
	var body: some View {
		VStack(spacing: 20) {
			Text("Receipt Validation Test")
				.font(.largeTitle)
				.fontWeight(.bold)
			
			// Receipt Info
			GroupBox("Receipt Info") {
				VStack(alignment: .leading, spacing: 8) {
					HStack {
						Text("Receipt exists:")
						Spacer()
						Text(receiptExists ? "Yes" : "No")
							.foregroundColor(receiptExists ? .green : .red)
					}
					
					if receiptExists {
						HStack {
							Text("Receipt size:")
							Spacer()
							Text("\(receiptSize) bytes")
								.foregroundColor(.secondary)
						}
					}
					
					HStack {
						Text("Bundle ID:")
						Spacer()
						Text(Bundle.main.bundleIdentifier ?? "Unknown")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				.frame(maxWidth: .infinity)
			}
			
			// StoreKit 2 Validation
			GroupBox("StoreKit 2 Validation") {
				if isValidating {
					ProgressView("Validating...")
						.frame(maxWidth: .infinity)
				} else if let result = validationResult {
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Valid:")
							Spacer()
							Text(result.isValid ? "Yes" : "No")
								.foregroundColor(result.isValid ? .green : .red)
						}
						
						if let error = result.error {
							Text("Error: \(error)")
								.font(.caption)
								.foregroundColor(.red)
						}
						
						if let subscription = result.activeSubscription {
							Divider()
							
							Text("Active Subscription:")
								.font(.headline)
							
							HStack {
								Text("Product:")
								Spacer()
								Text(subscription.productId)
									.font(.caption)
							}
							
							HStack {
								Text("Purchase Date:")
								Spacer()
								Text(subscription.purchaseDate, style: .date)
									.font(.caption)
							}
							
							if let expiration = subscription.expirationDate {
								HStack {
									Text("Expires:")
									Spacer()
									Text(expiration, style: .date)
										.font(.caption)
								}
							}
						}
						
						if !result.allSubscriptions.isEmpty {
							Divider()
							
							Text("All Subscriptions: \(result.allSubscriptions.count)")
								.font(.caption)
								.foregroundColor(.secondary)
						}
					}
				} else {
					Text("Not validated yet")
						.foregroundColor(.secondary)
						.frame(maxWidth: .infinity)
				}
			}
			
			// Sandbox Validation
			GroupBox("Sandbox Server Validation") {
				if let result = sandboxResult {
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Valid:")
							Spacer()
							Text(result.isValid ? "Yes" : "No")
								.foregroundColor(result.isValid ? .green : .red)
						}
						
						if let error = result.error {
							Text("Error: \(error)")
								.font(.caption)
								.foregroundColor(.red)
						}
					}
				} else {
					Text("Not tested yet")
						.foregroundColor(.secondary)
						.frame(maxWidth: .infinity)
				}
			}
			
			// Actions
			VStack(spacing: 12) {
				Button("Validate with StoreKit 2") {
					validateWithStoreKit2()
				}
				.buttonStyle(.borderedProminent)
				.disabled(isValidating)
				
				Button("Validate with Sandbox Server") {
					validateWithSandbox()
				}
				.disabled(!receiptExists)
				
				Button("Refresh Receipt") {
					SKReceiptRefreshRequest().start()
				}
			}
			
			Spacer()
		}
		.padding()
		.frame(width: 500, height: 600)
		.onAppear {
			checkReceiptInfo()
		}
	}
	
	private func checkReceiptInfo() {
		if let receiptURL = Bundle.main.appStoreReceiptURL,
		   let receiptData = try? Data(contentsOf: receiptURL) {
			receiptExists = true
			receiptSize = receiptData.count
		} else {
			receiptExists = false
			receiptSize = 0
		}
	}
	
	private func validateWithStoreKit2() {
		isValidating = true
		
		Task {
			let result = await LocalReceiptValidator.shared.validateReceipt()
			
			await MainActor.run {
				self.validationResult = result
				self.isValidating = false
			}
		}
	}
	
	private func validateWithSandbox() {
		guard let receiptURL = Bundle.main.appStoreReceiptURL,
		      let receiptData = try? Data(contentsOf: receiptURL) else {
			return
		}
		
		Task {
			let result = await LocalReceiptValidator.shared.validateWithSandbox(receiptData: receiptData)
			
			await MainActor.run {
				self.sandboxResult = result
			}
		}
	}
}

#Preview {
	ReceiptValidationTestView()
}