# Testing Environment Implementation Plan

## Overview

Minimal implementation plan for a macOS-only developer menu with a single "Test Sign-In with Apple" menu item for isolated testing of the Apple Sign-In token exchange flow.

## Goal

Test Apple Sign-In and token exchange in isolation without triggering the full account creation process.

## Implementation (1 Day)

### Developer Menu (macOS Only)

```swift
// DeveloperMenu.swift
#if os(macOS) && DEBUG
import SwiftUI

struct DeveloperMenuCommands: Commands {
    var body: some Commands {
        CommandMenu("Developer") {
            Button("Test Sign-In with Apple") {
                Task {
                    await TestSignInHandler.testAppleSignIn()
                }
            }
            .keyboardShortcut("T", modifiers: [.command, .shift])
        }
    }
}
#endif
```

### Test Handler

```swift
// TestSignInHandler.swift
#if os(macOS) && DEBUG
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

            print("=== Test Complete ===")

        } catch {
            print("✗ Test failed: \(error)")
        }
    }
}

// Note: Required changes to AccountManager.swift:
// 1. Change: private func randomNonceString() -> internal func randomNonceString()
// 2. Change: private func sha256() -> internal func sha256()
// 3. Change: private class AppleSignInCoordinator -> internal class AppleSignInCoordinator

// Extension to AccountManager for test support
extension AccountManager {
    #if os(macOS) && DEBUG
    @MainActor
    func performTestAppleSignIn() async throws -> (credential: ASAuthorizationAppleIDCredential, nonce: String) {
        // Generate nonce using now-internal helper
        let nonce = randomNonceString()
        // Note: currentNonce remains private, we just return it for test inspection

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)  // Using now-internal helper

        // Reuse now-internal coordinator
        let coordinator = AppleSignInCoordinator()
        let credential = try await coordinator.performSignIn(request: request)

        // Return for test inspection without backend processing
        return (credential, nonce)
    }
    #endif
}
#endif
```

### App Integration

```swift
// PhotolalaApp.swift
@main
struct PhotolalaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS) && DEBUG
        .commands {
            DeveloperMenuCommands()
        }
        #endif
    }
}
```

## Security Considerations

1. **DEBUG Only**: All code wrapped in `#if os(macOS) && DEBUG`
2. **No Token Storage**: Tokens are never stored, only validated
3. **Redacted Logging**: All sensitive data (user IDs, tokens, nonces) are redacted in console output
4. **No Log Shipping**: Console logs must NEVER be included in non-DEBUG builds or bug reports
5. **Auto-Clear**: No persistent data, everything cleared on completion
6. **Shared Code Path**: Reuses AccountManager's security-sensitive helpers (no duplication)

## What This Does

1. Shows "Developer" menu in macOS menu bar (DEBUG builds only)
2. Single menu item: "Test Sign-In with Apple" (⌘⇧T)
3. Performs Apple Sign-In flow
4. Logs redacted token info to console (no UI, no storage)
5. Validates JWT structure without exposing content

## What This Doesn't Do

- No token inspector UI
- No debug console windows
- No network simulation
- No token history
- No data export
- No complex test scenarios

## Console Output Example

```
=== Starting Apple Sign-In Test ===
✓ Received Apple credential
✓ Identity token received:
  - User: [REDACTED]
  - Token length: 1024 characters
✓ Valid JWT structure (3 parts)
=== Test Complete ===
```

**WARNING**: Even this redacted output should never be shared in bug reports or logs.

## Implementation Steps

1. Modify `AccountManager.swift`:
   - Change `private func randomNonceString()` to `internal func randomNonceString()`
   - Change `private func sha256()` to `internal func sha256()`
   - Change `private class AppleSignInCoordinator` to `internal class AppleSignInCoordinator`
   - Add DEBUG-only extension with `performTestAppleSignIn()` method
2. Add `DeveloperMenu.swift` with menu command
3. Add `TestSignInHandler.swift` with @MainActor annotation
4. Add menu to `PhotolalaApp.swift`
5. Test with ⌘⇧T shortcut

## Time Estimate

- 2-3 hours total implementation
- Reuses existing code from AccountManager
- No new UI components needed
- Console logging only

---

*Last Updated: September 2024*
*Scope: Minimal Apple Sign-In test hook*
*Platform: macOS DEBUG builds only*