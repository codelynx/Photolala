import Foundation
import StoreKit

// MARK: - IAP Product IDs

enum IAPProductID: String, CaseIterable {
	case starter = "com.electricwoods.photolala.starter"
	case essential = "com.electricwoods.photolala.essential"
	case plus = "com.electricwoods.photolala.plus"
	case family = "com.electricwoods.photolala.family"

	var tier: SubscriptionTier {
		switch self {
		case .starter: .starter
		case .essential: .essential
		case .plus: .plus
		case .family: .family
		}
	}
}

// MARK: - IAP Manager

@MainActor
class IAPManager: ObservableObject {
	static let shared = IAPManager()

	// Published properties
	@Published var products: [Product] = []
	@Published var purchasedProductIDs = Set<String>()
	@Published var isLoading = false
	@Published var errorMessage: String?

	// Private properties
	private var updates: Task<Void, Never>? = nil
	private let productIDs = IAPProductID.allCases.map(\.rawValue)

	private init() {
		// Start listening for transactions
		self.updates = self.observeTransactionUpdates()

		Task {
			await self.loadProducts()
			await self.updatePurchasedProducts()
		}
	}

	deinit {
		updates?.cancel()
	}

	// MARK: - Public Methods

	func loadProducts() async {
		self.isLoading = true

		do {
			// Load products from App Store
			self.products = try await Product.products(for: self.productIDs)

			// Sort by price
			self.products.sort { $0.price < $1.price }

			print("Loaded \(self.products.count) products")
			for product in self.products {
				print("- \(product.id): \(product.displayName) - \(product.displayPrice)")
			}

			self.isLoading = false
		} catch {
			print("Failed to load products: \(error)")
			self.errorMessage = error.localizedDescription
			self.isLoading = false
		}
	}

	func purchase(_ product: Product) async throws {
		print("Attempting to purchase: \(product.id)")

		// Make the purchase
		let result = try await product.purchase()

		switch result {
		case let .success(verification):
			// Verify the transaction
			let transaction = try checkVerified(verification)

			// Update purchased products
			await updatePurchasedProducts()

			// Update user's subscription
			await updateUserSubscription(for: transaction)

			// Finish the transaction
			await transaction.finish()

			print("Purchase successful: \(product.id)")

		case .userCancelled:
			print("User cancelled purchase")
			throw IAPError.userCancelled

		case .pending:
			print("Purchase pending")
			throw IAPError.purchasePending

		@unknown default:
			print("Unknown purchase result")
			throw IAPError.unknown
		}
	}

	func restorePurchases() async {
		print("Restoring purchases...")

		do {
			// Sync with App Store
			try await AppStore.sync()

			// Update purchased products
			await self.updatePurchasedProducts()

			print("Restore completed")
		} catch {
			print("Restore failed: \(error)")
			self.errorMessage = error.localizedDescription
		}
	}

	func checkTransactionStatus() async {
		print("Checking transaction status...")

		// Update current purchases
		await self.updatePurchasedProducts()

		// Check subscription status
		if let status = await subscriptionStatus() {
			print("Active subscription: \(status.tier.displayName)")
			print("Expires: \(status.expiresAt)")
			print("Days until expiration: \(status.daysUntilExpiration)")
		} else {
			print("No active subscription")
		}
	}

	// MARK: - Private Methods

	private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
		switch result {
		case .unverified:
			throw IAPError.verificationFailed
		case let .verified(safe):
			return safe
		}
	}

	private func updatePurchasedProducts() async {
		// Check current entitlements
		for await result in Transaction.currentEntitlements {
			do {
				let transaction = try checkVerified(result)

				// Only consider auto-renewable subscriptions
				if transaction.productType == .autoRenewable {
					self.purchasedProductIDs.insert(transaction.productID)
				}
			} catch {
				print("Failed to verify transaction: \(error)")
			}
		}

		print("Current subscriptions: \(self.purchasedProductIDs)")
	}

	private func observeTransactionUpdates() -> Task<Void, Never> {
		Task(priority: .background) {
			// Listen for transaction updates
			for await result in Transaction.updates {
				do {
					let transaction = try await checkVerified(result)

					// Update purchased products
					await updatePurchasedProducts()

					// Update user's subscription
					await updateUserSubscription(for: transaction)

					// Finish the transaction
					await transaction.finish()
				} catch {
					print("Transaction verification failed: \(error)")
				}
			}
		}
	}

	private func updateUserSubscription(for transaction: Transaction) async {
		guard let identityManager = IdentityManager.shared.currentUser,
		      let productID = IAPProductID(rawValue: transaction.productID)
		else {
			return
		}

		// Update user's subscription
		let subscription = Subscription(
			tier: productID.tier,
			expiresAt: transaction.expirationDate ?? Date.distantFuture,
			originalTransactionId: String(transaction.originalID)
		)

		// Update identity manager
		await IdentityManager.shared.updateSubscription(subscription)

		// Update S3 backup manager
		await S3BackupManager.shared.updateStorageInfo()

		print("Updated subscription to \(productID.tier.displayName)")
	}

	// MARK: - Computed Properties

	var hasActiveSubscription: Bool {
		!self.purchasedProductIDs.isEmpty
	}

	func product(for tier: SubscriptionTier) -> Product? {
		self.products.first { product in
			IAPProductID(rawValue: product.id)?.tier == tier
		}
	}

	func isSubscribed(to tier: SubscriptionTier) -> Bool {
		guard let productID = IAPProductID.allCases.first(where: { $0.tier == tier }) else {
			return false
		}
		return self.purchasedProductIDs.contains(productID.rawValue)
	}

	// MARK: - Subscription Status

	func subscriptionStatus() async -> SubscriptionStatus? {
		// Get the highest tier subscription
		var highestTier: SubscriptionTier?
		var expirationDate: Date?

		for await result in Transaction.currentEntitlements {
			do {
				let transaction = try checkVerified(result)

				if let productID = IAPProductID(rawValue: transaction.productID),
				   transaction.productType == .autoRenewable
				{

					// Check if this is a higher tier
					if highestTier == nil || productID.tier.storageLimit > highestTier!.storageLimit {
						highestTier = productID.tier
						expirationDate = transaction.expirationDate
					}
				}
			} catch {
				continue
			}
		}

		guard let tier = highestTier else { return nil }

		return SubscriptionStatus(
			tier: tier,
			expiresAt: expirationDate ?? Date.distantFuture,
			isActive: true
		)
	}
}

// MARK: - Supporting Types

struct SubscriptionStatus {
	let tier: SubscriptionTier
	let expiresAt: Date
	let isActive: Bool

	var isExpired: Bool {
		Date() > self.expiresAt
	}

	var daysUntilExpiration: Int {
		Calendar.current.dateComponents([.day], from: Date(), to: self.expiresAt).day ?? 0
	}
}

enum IAPError: LocalizedError {
	case verificationFailed
	case userCancelled
	case purchasePending
	case unknown

	var errorDescription: String? {
		switch self {
		case .verificationFailed:
			"Purchase verification failed"
		case .userCancelled:
			"Purchase was cancelled"
		case .purchasePending:
			"Purchase is pending approval"
		case .unknown:
			"An unknown error occurred"
		}
	}
}

// MARK: - Extensions

extension IdentityManager {
	func updateSubscription(_ subscription: Subscription) async {
		guard var user = currentUser else { return }

		user.subscription = subscription
		currentUser = user

		// Save to Keychain
		do {
			let userData = try JSONEncoder().encode(user)
			try KeychainManager.shared.save(userData, for: "com.electricwoods.photolala.user")
		} catch {
			print("Failed to save updated user: \(error)")
		}
	}
}
