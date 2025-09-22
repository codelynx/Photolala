//
//  GoogleSignInTest.swift
//  PhotolalaTests
//
//  Manual test for Google Sign-In with browser fallback
//

import Foundation

@MainActor
func testGoogleSignInWithBrowserFallback() async {
	print("\n=== Starting Google Sign-In Test with Browser Fallback ===")

	do {
		let coordinator = GoogleSignInCoordinator()

		print("→ Initiating Google Sign-In flow...")
		print("→ Browser should open for authentication")

		let credential = try await coordinator.performSignIn()

		print("✓ Sign-in successful!")
		print("  - Email: \(credential.claims.email ?? "N/A")")
		print("  - Name: \(credential.claims.name ?? "N/A")")
		print("  - Subject: \(credential.claims.subject)")
		print("  - Email Verified: \(credential.claims.emailVerified ?? false)")

		if !credential.accessToken.isEmpty {
			print("✓ Access token received")
		}

		if !credential.idToken.isEmpty {
			print("✓ ID token received and verified")
		}

		print("\n✓ Test completed successfully!")

	} catch GoogleSignInError.userCancelled {
		print("✗ User cancelled sign-in")
	} catch GoogleSignInError.webAuthenticationUnavailable {
		print("✗ Web authentication unavailable (should not happen with browser fallback)")
	} catch {
		print("✗ Test failed: \(error)")
		if let signInError = error as? GoogleSignInError {
			print("  Error type: \(signInError)")
		}
	}

	print("=== End of Google Sign-In Test ===\n")
}

// Run test
if ProcessInfo.processInfo.arguments.contains("--test-google-signin") {
	Task { @MainActor in
		await testGoogleSignInWithBrowserFallback()
		exit(0)
	}
	RunLoop.main.run()
}