//
//  LocalReceiptValidator.swift
//  Photolala
//
//  Created by Claude on 6/17/25.
//

import Foundation
import StoreKit
import CryptoKit

/// Local receipt validation for development and testing
/// WARNING: This is for development only. Production apps should use server-side validation.
class LocalReceiptValidator {
	static let shared = LocalReceiptValidator()
	
	private init() {}
	
	/// Validates the local App Store receipt
	/// - Returns: Validation result with subscription info
	func validateReceipt() async -> ReceiptValidationResult {
		guard let receiptURL = Bundle.main.appStoreReceiptURL,
		      let receiptData = try? Data(contentsOf: receiptURL) else {
			return ReceiptValidationResult(isValid: false, error: "No receipt found")
		}
		
		// For local validation in development, we can check:
		// 1. Receipt exists
		// 2. Basic receipt structure
		// 3. Bundle ID matches
		// 4. Use StoreKit 2 for transaction verification
		
		do {
			// StoreKit 2 approach - verify transactions directly
			let verificationResult = await Transaction.currentEntitlements
			
			var activeSubscriptions: [SubscriptionInfo] = []
			
			for await transaction in verificationResult {
				switch transaction {
				case .verified(let verifiedTransaction):
					// Check if transaction is for our subscription products
					if isSubscriptionProduct(verifiedTransaction.productID) {
						let info = SubscriptionInfo(
							productId: verifiedTransaction.productID,
							purchaseDate: verifiedTransaction.purchaseDate,
							expirationDate: verifiedTransaction.expirationDate,
							isActive: verifiedTransaction.expirationDate ?? Date() > Date()
						)
						activeSubscriptions.append(info)
					}
				case .unverified(_, let error):
					print("Unverified transaction: \(error)")
				}
			}
			
			// Find the highest tier active subscription
			let activeSubscription = activeSubscriptions
				.filter { $0.isActive }
				.sorted { getSubscriptionTier($0.productId) > getSubscriptionTier($1.productId) }
				.first
			
			return ReceiptValidationResult(
				isValid: true,
				activeSubscription: activeSubscription,
				allSubscriptions: activeSubscriptions
			)
			
		} catch {
			return ReceiptValidationResult(isValid: false, error: error.localizedDescription)
		}
	}
	
	/// Validates receipt with Apple's sandbox server (for testing)
	/// - Parameter receiptData: Base64 encoded receipt data
	/// - Returns: Validation result
	func validateWithSandbox(receiptData: Data) async -> ReceiptValidationResult {
		let receiptString = receiptData.base64EncodedString()
		
		// Create request body
		let requestBody = [
			"receipt-data": receiptString,
			"password": getSharedSecret(), // Your app's shared secret
			"exclude-old-transactions": true
		] as [String : Any]
		
		guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
			return ReceiptValidationResult(isValid: false, error: "Failed to create request")
		}
		
		// Sandbox URL
		let sandboxURL = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!
		
		var request = URLRequest(url: sandboxURL)
		request.httpMethod = "POST"
		request.httpBody = bodyData
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		
		do {
			let (data, _) = try await URLSession.shared.data(for: request)
			let response = try JSONDecoder().decode(AppleReceiptResponse.self, from: data)
			
			if response.status == 0 {
				// Parse subscription info from latest_receipt_info
				let subscriptions = parseSubscriptions(from: response)
				let activeSubscription = subscriptions
					.filter { $0.isActive }
					.sorted { getSubscriptionTier($0.productId) > getSubscriptionTier($1.productId) }
					.first
				
				return ReceiptValidationResult(
					isValid: true,
					activeSubscription: activeSubscription,
					allSubscriptions: subscriptions
				)
			} else {
				return ReceiptValidationResult(
					isValid: false,
					error: "Apple validation failed with status: \(response.status)"
				)
			}
		} catch {
			return ReceiptValidationResult(isValid: false, error: error.localizedDescription)
		}
	}
	
	// MARK: - Helper Methods
	
	private func isSubscriptionProduct(_ productId: String) -> Bool {
		let subscriptionIds = [
			"com.electricwoods.photolala.starter",
			"com.electricwoods.photolala.essential",
			"com.electricwoods.photolala.plus",
			"com.electricwoods.photolala.family"
		]
		return subscriptionIds.contains(productId)
	}
	
	private func getSubscriptionTier(_ productId: String) -> Int {
		switch productId {
		case "com.electricwoods.photolala.starter": return 1
		case "com.electricwoods.photolala.essential": return 2
		case "com.electricwoods.photolala.plus": return 3
		case "com.electricwoods.photolala.family": return 4
		default: return 0
		}
	}
	
	private func getSharedSecret() -> String {
		// In production, this should be stored securely
		// For now, return empty string for local testing
		return ""
	}
	
	private func parseSubscriptions(from response: AppleReceiptResponse) -> [SubscriptionInfo] {
		// Parse latest_receipt_info array
		// This would need proper implementation based on Apple's response format
		return []
	}
}

// MARK: - Models

struct ReceiptValidationResult {
	let isValid: Bool
	let activeSubscription: SubscriptionInfo?
	let allSubscriptions: [SubscriptionInfo]
	let error: String?
	
	init(isValid: Bool, activeSubscription: SubscriptionInfo? = nil, allSubscriptions: [SubscriptionInfo] = [], error: String? = nil) {
		self.isValid = isValid
		self.activeSubscription = activeSubscription
		self.allSubscriptions = allSubscriptions
		self.error = error
	}
}

struct SubscriptionInfo {
	let productId: String
	let purchaseDate: Date
	let expirationDate: Date?
	let isActive: Bool
}

// Simplified Apple receipt response structure
struct AppleReceiptResponse: Codable {
	let status: Int
	let receipt: Receipt?
	let latest_receipt_info: [LatestReceiptInfo]?
	
	struct Receipt: Codable {
		let bundle_id: String
		let application_version: String
	}
	
	struct LatestReceiptInfo: Codable {
		let product_id: String
		let purchase_date_ms: String
		let expires_date_ms: String?
	}
}