import Foundation
import AuthenticationServices

#if targetEnvironment(simulator)
extension IdentityManager {
	/// Mock authentication for iOS Simulator testing
	func mockSignIn() async {
		// Create a mock user for testing in simulator
		let mockUser = PhotolalaUser(
			serviceUserID: UUID().uuidString.lowercased(),
			provider: .apple,
			providerID: "simulator-test-user",
			email: "test@simulator.local",
			fullName: "Test User",
			subscription: Subscription.freeTrial()
		)
		
		// Save to keychain
		do {
			let encoder = JSONEncoder()
			encoder.dateEncodingStrategy = .iso8601
			let userData = try encoder.encode(mockUser)
			try KeychainManager.shared.save(userData, for: keychainKey)
			
			await MainActor.run {
				self.currentUser = mockUser
				self.isSignedIn = true
			}
			
			print("Mock sign-in successful for simulator")
		} catch {
			print("Mock sign-in failed: \(error)")
		}
	}
}
#endif