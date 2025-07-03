# Google Sign-In iOS/macOS Implementation Guide

## Complete Step-by-Step Implementation

### Phase 1: SDK Installation and Configuration

#### 1.1 Add Google Sign-In SDK via Swift Package Manager

**In Xcode:**
1. Open `Photolala.xcodeproj`
2. Select the project in the navigator
3. Select the "Photolala" project (not target)
4. Go to "Package Dependencies" tab
5. Click the "+" button
6. Enter package URL: `https://github.com/google/GoogleSignIn-iOS`
7. Rules: Up to Next Major Version: 7.1.0
8. Click "Add Package"
9. When prompted, add `GoogleSignIn` to the "Photolala" target
10. Wait for package resolution

#### 1.2 Create OAuth Clients in Google Cloud Console

**For iOS:**
```
Project: photolala
Type: iOS
Name: Photolala iOS
Bundle ID: com.electricwoods.photolala
```

**Note:** You'll get an iOS Client ID like: `105828093997-XXXXXXXXXXXXXXXXXXXXXXXXXX.apps.googleusercontent.com`

### Phase 2: Info.plist Configuration

#### 2.1 Add URL Schemes

Add to `apple/Photolala/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- Reversed iOS client ID -->
            <string>com.googleusercontent.apps.105828093997-XXXXXXXXXXXXXXXXXXXXXXXXXX</string>
        </array>
    </dict>
</array>

<!-- For opening Google app if installed -->
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>googlechrome</string>
    <string>googlechrome-x-callback</string>
</array>
```

### Phase 3: Implementation Files

#### 3.1 Create GoogleAuthProvider.swift

Create new file: `apple/Photolala/Services/GoogleAuthProvider.swift`

```swift
import Foundation
import GoogleSignIn
import AuthenticationServices

actor GoogleAuthProvider {
    static let shared = GoogleAuthProvider()
    
    // Use the Web Client ID for server-side verification
    private let webClientID = "105828093997-qmr9jdj3h4ia0tt2772cnrejh4k0p609.apps.googleusercontent.com"
    
    private init() {}
    
    /// Sign in with Google
    func signIn() async throws -> AuthCredential {
        // Get the presenting view controller
        guard let presentingViewController = await getPresentingViewController() else {
            throw AuthError.unknownError("No presenting view controller")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                GIDSignIn.sharedInstance.signIn(
                    withPresenting: presentingViewController
                ) { result, error in
                    if let error = error {
                        continuation.resume(throwing: self.mapError(error))
                        return
                    }
                    
                    guard let result = result,
                          let profile = result.user.profile else {
                        continuation.resume(throwing: AuthError.unknownError("No user data"))
                        return
                    }
                    
                    let credential = AuthCredential(
                        provider: .google,
                        providerID: result.user.userID ?? "",
                        email: profile.email,
                        fullName: profile.name,
                        photoURL: profile.imageURL(withDimension: 200)?.absoluteString,
                        idToken: result.user.idToken?.tokenString,
                        accessToken: result.user.accessToken.tokenString
                    )
                    
                    continuation.resume(returning: credential)
                }
            }
        }
    }
    
    /// Sign out from Google
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    /// Restore previous sign-in
    func restorePreviousSignIn() async throws -> AuthCredential? {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                    if let error = error {
                        // Not an error if no previous sign-in
                        if (error as NSError).code == GIDSignInError.hasNoAuthInKeychain.rawValue {
                            continuation.resume(returning: nil)
                        } else {
                            continuation.resume(throwing: self.mapError(error))
                        }
                        return
                    }
                    
                    guard let user = user,
                          let profile = user.profile else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let credential = AuthCredential(
                        provider: .google,
                        providerID: user.userID ?? "",
                        email: profile.email,
                        fullName: profile.name,
                        photoURL: profile.imageURL(withDimension: 200)?.absoluteString,
                        idToken: user.idToken?.tokenString,
                        accessToken: user.accessToken.tokenString
                    )
                    
                    continuation.resume(returning: credential)
                }
            }
        }
    }
    
    /// Handle URL callback
    @MainActor
    func handle(url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Private Helpers
    
    @MainActor
    private func getPresentingViewController() -> UIViewController? {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        var presentingViewController = rootViewController
        while let presented = presentingViewController.presentedViewController {
            presentingViewController = presented
        }
        
        return presentingViewController
        #else
        // macOS implementation
        return nil
        #endif
    }
    
    private func mapError(_ error: Error) -> AuthError {
        if let gidError = error as? GIDSignInError {
            switch gidError.code {
            case .canceled:
                return .userCancelled
            case .hasNoAuthInKeychain:
                return .noStoredCredentials
            case .unknown:
                return .unknownError(error.localizedDescription)
            default:
                return .authenticationFailed(error.localizedDescription)
            }
        }
        
        return .authenticationFailed(error.localizedDescription)
    }
}
```

#### 3.2 Update IdentityManager+Authentication.swift

Update the `authenticateWithProvider` method:

```swift
private func authenticateWithProvider(_ provider: AuthProvider) async throws -> AuthCredential {
    switch provider {
    case .apple:
        return try await AppleAuthProvider.shared.signIn()
    case .google:
        return try await GoogleAuthProvider.shared.signIn()
    }
}
```

#### 3.3 Update PhotolalaApp.swift

Add URL handling for Google Sign-In callbacks:

```swift
import SwiftUI
import GoogleSignIn

@main
struct PhotolalaApp: App {
    @StateObject private var navigationManager = NavigationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(navigationManager)
                .onOpenURL { url in
                    // Handle Google Sign-In callback
                    if GoogleAuthProvider.shared.handle(url: url) {
                        return
                    }
                    // Handle other URLs...
                }
                .onAppear {
                    configureGoogleSignIn()
                }
        }
    }
    
    private func configureGoogleSignIn() {
        // Configure Google Sign-In with server client ID for ID token
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]],
              let urlSchemes = urlTypes.first?["CFBundleURLSchemes"] as? [String],
              let reversedClientId = urlSchemes.first(where: { $0.hasPrefix("com.googleusercontent.apps.") }) else {
            print("Error: Google Sign-In client ID not found in Info.plist")
            return
        }
        
        // Extract client ID from reversed client ID
        let clientId = reversedClientId
            .replacingOccurrences(of: "com.googleusercontent.apps.", with: "")
            .components(separatedBy: ".").reversed().joined(separator: ".")
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: clientId,
            serverClientID: "105828093997-qmr9jdj3h4ia0tt2772cnrejh4k0p609.apps.googleusercontent.com"
        )
    }
}
```

#### 3.4 Update AuthenticationChoiceView.swift

Remove the TODO and enable the Google Sign-In button:

```swift
case .google:
    do {
        showLoading = true
        try await identityManager.authenticate(
            provider: .google,
            intent: authIntent
        )
        onSuccess()
    } catch {
        handleError(error)
    }
```

### Phase 4: Platform-Specific Adjustments

#### 4.1 macOS Support

For macOS, create a NSViewController wrapper since Google Sign-In expects UIViewController:

```swift
#if os(macOS)
import AppKit
import GoogleSignIn

extension GoogleAuthProvider {
    @MainActor
    private func getPresentingViewController() -> NSViewController? {
        return NSApplication.shared.keyWindow?.contentViewController
    }
}

// Bridge for macOS
extension GIDSignIn {
    func signIn(withPresenting presentingViewController: NSViewController,
                completion: @escaping (GIDSignInResult?, Error?) -> Void) {
        // Implementation depends on Google Sign-In SDK macOS support
        // May need to use web-based flow for macOS
    }
}
#endif
```

### Phase 5: Testing Checklist

#### 5.1 Configuration Verification
- [ ] Google Sign-In SDK added to project
- [ ] Info.plist contains reversed client ID URL scheme
- [ ] OAuth clients created for iOS (and optionally macOS)
- [ ] Web Client ID correctly set in code

#### 5.2 Functionality Testing
- [ ] Sign in with new Google account
- [ ] Sign in with existing Google account
- [ ] Cancel sign-in flow
- [ ] Sign out functionality
- [ ] Error handling (network issues, etc.)
- [ ] Cross-device authentication with Android

#### 5.3 UI/UX Testing
- [ ] Google button properly styled
- [ ] Loading states during authentication
- [ ] Error messages display correctly
- [ ] Success navigation works

### Phase 6: Troubleshooting

#### Common Issues:

1. **"Invalid client ID" error**
   - Verify Info.plist URL scheme matches OAuth client
   - Ensure client ID is correctly reversed

2. **"User cancelled" when not cancelled**
   - Check Bundle ID matches OAuth client exactly
   - Verify OAuth consent screen is configured

3. **No callback after sign-in**
   - Check `onOpenURL` is implemented
   - Verify URL scheme is registered

4. **"Server client ID not found"**
   - Ensure serverClientID is set in configuration
   - This should be the Web OAuth client ID

### Phase 7: Security Considerations

1. **ID Token Validation**
   - Always use serverClientID to get ID tokens
   - Validate tokens on your backend

2. **Keychain Storage**
   - Google Sign-In SDK handles token storage
   - Our IdentityManager adds additional encryption

3. **Error Messages**
   - Don't expose internal errors to users
   - Map errors to user-friendly messages

### Estimated Timeline

- SDK Integration: 30 minutes
- OAuth Client Setup: 30 minutes
- Implementation: 2-3 hours
- Testing: 1-2 hours
- Total: ~4-6 hours

### Next Steps After Implementation

1. Update PROJECT_STATUS.md
2. Test cross-platform authentication
3. Add analytics for sign-in success/failure
4. Consider implementing Sign in with Google button styling guidelines
5. Add unit tests for GoogleAuthProvider