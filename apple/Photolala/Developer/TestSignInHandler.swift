//
//  TestSignInHandler.swift
//  Photolala
//

#if os(macOS) && DEBUG
import Foundation
import AuthenticationServices

enum TestSignInHandler {
	@MainActor
	static func testAppleSignIn() async {
		do {
			print("=== Starting Apple Sign-In Test ===")

			// 1. Use AccountManager's test-specific method
			let accountManager = AccountManager.shared
			let (credential, nonce) = try await accountManager.performTestAppleSignIn()
			print("✓ Received Apple credential")
			print("  - Nonce used: yes (SHA256: \(accountManager.sha256(nonce).prefix(8))...)")

			// 2. Log redacted token info (don't store or show sensitive data)
			if let identityToken = credential.identityToken,
			   let tokenString = String(data: identityToken, encoding: .utf8) {
				print("✓ Identity token received:")
				print("  - User: [REDACTED]")
				print("  - Token length: \(tokenString.count) characters")
				// Never log actual token content

				// 3. Validate JWT structure without exposing content
				let parts = tokenString.split(separator: ".")
				if parts.count == 3 {
					print("✓ Valid JWT structure (3 parts)")
				} else {
					print("✗ Invalid JWT structure")
				}
			}

			// Log additional credential info (redacted)
			if credential.email != nil {
				print("  - Email provided: yes (value: [REDACTED])")
			} else {
				print("  - Email provided: no")
			}

			if let fullName = credential.fullName {
				let hasFirstName = fullName.givenName != nil
				let hasLastName = fullName.familyName != nil
				print("  - Full name provided: first=\(hasFirstName), last=\(hasLastName)")
			} else {
				print("  - Full name provided: no")
			}

			print("  - Real user status: \(credential.realUserStatus.rawValue)")

			print("=== Test Complete ===")

		} catch {
			print("✗ Test failed: \(error)")
		}
	}
}
#endif