# Google Sign-In Implementation Plan

## Overview

Implementation plan for Google Sign-In (Phase 2) in Photolala2, following the patterns established with Apple Sign-In but adapted for OAuth 2.0 flow using ASWebAuthenticationSession.

## Goals

1. **OAuth 2.0 Authentication**: Implement standard OAuth flow without SDK dependencies
2. **Platform Compatibility**: Support both macOS and iOS with unified approach
3. **Security**: Use PKCE and state parameters for secure authentication
4. **Integration**: Reuse existing Lambda endpoints and AccountManager patterns
5. **Testing**: Provide isolated test flow similar to Apple Sign-In

## Architecture

### Core Components

```
AccountManager (existing)
    ↓
GoogleSignInCoordinator (new)
    ↓
ASWebAuthenticationSession
    ↓
OAuth 2.0 Flow
    ↓
Lambda (photolala-auth-signin)
```

### No External Dependencies
- Use native ASWebAuthenticationSession (no Google Sign-In SDK)
- Leverage existing GoogleOAuthConfiguration
- Reuse Lambda integration from Apple Sign-In

## Data Structures

```swift
// Token exchange response from Google
struct TokenResponse: Codable {
    let idToken: String
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

// Typed JWT claims structure (Sendable)
struct GoogleJWTClaims: Sendable {
    let subject: String        // sub
    let email: String?
    let emailVerified: Bool?
    let name: String?
    let picture: String?
    let issuer: String         // iss
    let audience: String       // aud
    let expiration: Date       // exp
    let issuedAt: Date         // iat
    let nonce: String?         // nonce for replay protection
}

// Verified token with typed claims
struct VerifiedToken: Sendable {
    let idToken: String
    let claims: GoogleJWTClaims
}

// Google credential returned from coordinator
struct GoogleCredential: Sendable {
    let idToken: String
    let accessToken: String
    let claims: GoogleJWTClaims  // Typed claims instead of [String: Any]
}

// Google JWK Set structure
struct GoogleJWKSet: Codable {
    let keys: [GoogleJWK]
}

struct GoogleJWK: Codable {
    let kid: String
    let kty: String
    let alg: String
    let use: String
    let n: String  // modulus
    let e: String  // exponent
}
```

## Implementation Details

### 1. GoogleSignInCoordinator

```swift
// Services/GoogleSignInCoordinator.swift
// Use actor for thread-safe OAuth state management
actor GoogleSignInCoordinator {
    // Store OAuth parameters during flow
    private var currentState: String?
    private var currentCodeVerifier: String?
    private var currentNonce: String?

    func performSignIn() async throws -> GoogleCredential {
        // 1. Generate PKCE parameters
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        // 2. Generate state for CSRF protection
        let state = UUID().uuidString

        // 3. Generate nonce for replay protection
        let nonce = randomNonceString()

        // Store for verification
        self.currentState = state
        self.currentCodeVerifier = codeVerifier
        self.currentNonce = nonce

        // 4. Build authorization URL with PKCE and nonce
        let authURL = buildAuthorizationURL(
            state: state,
            nonce: nonce,
            codeChallenge: codeChallenge,
            codeChallengeMethod: "S256"
        )

        // 4. Present ASWebAuthenticationSession (UI operation needs MainActor)
        let callbackURL = try await MainActor.run {
            try await self.presentAuthSession(authURL)
        }

        // 5. Verify state and extract code
        let code = try verifyStateAndExtractCode(from: callbackURL, expectedState: state)

        // 6. Exchange code for tokens (network operation)
        let tokens = try await exchangeCodeForTokens(
            code: code,
            codeVerifier: codeVerifier
        )

        // 7. Verify ID token properly before use
        let verifiedToken = try await verifyGoogleIDToken(tokens.idToken)

        // Clean up stored values
        self.currentState = nil
        self.currentCodeVerifier = nil

        return GoogleCredential(
            idToken: verifiedToken.idToken,
            accessToken: tokens.accessToken,
            userInfo: verifiedToken.decodedClaims
        )
    }

    private func verifyStateAndExtractCode(
        from url: URL,
        expectedState: String
    ) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GoogleSignInError.invalidAuthorizationResponse
        }

        // Verify state parameter
        let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value
        guard returnedState == expectedState else {
            throw GoogleSignInError.stateMismatch
        }

        // Extract authorization code
        guard let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GoogleSignInError.noAuthorizationCode
        }

        return code
    }

    @MainActor
    private func presentAuthSession(_ url: URL) async throws -> URL {
        // Present ASWebAuthenticationSession on MainActor
        // Implementation details for iOS/macOS
    }
}
```

### 2. AccountManager Extension

```swift
// Services/AccountManager.swift
extension AccountManager {
    @MainActor
    func signInWithGoogle() async throws -> PhotolalaUser {
        // 1. Perform Google Sign-In
        let coordinator = GoogleSignInCoordinator()
        let credential = try await coordinator.performSignIn()

        // 2. Prepare Lambda payload
        let payload: [String: Any] = [
            "idToken": credential.idToken,
            "provider": "google"
            // No nonce needed for OAuth
        ]

        // 3. Call Lambda (reuse existing method)
        let data = try JSONSerialization.data(withJSONObject: payload)
        let result = try await callAuthLambdaWithData(
            "photolala-auth-signin",
            payloadData: data
        )

        // 4. Store credentials (same as Apple)
        self.currentUser = result.user
        self.stsCredentials = result.credentials
        self.isSignedIn = true
        await saveSession()

        return result.user
    }
}
```

### 3. PKCE Implementation & Authorization URL

```swift
// PKCE (Proof Key for Code Exchange) for OAuth security
extension GoogleSignInCoordinator {
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = verifier.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func buildAuthorizationURL(
        state: String,
        codeChallenge: String,
        codeChallengeMethod: String
    ) -> URL {
        var components = URLComponents(string: GoogleOAuthConfiguration.authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleOAuthConfiguration.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleOAuthConfiguration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleOAuthConfiguration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: codeChallengeMethod),  // REQUIRED
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        return components.url!
    }
}
```

### 4. Token Exchange

```swift
extension GoogleSignInCoordinator {
    private func exchangeCodeForTokens(
        code: String,
        codeVerifier: String
    ) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: GoogleOAuthConfiguration.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded",
                        forHTTPHeaderField: "Content-Type")

        let parameters = [
            "code": code,
            "client_id": GoogleOAuthConfiguration.clientID,
            "code_verifier": codeVerifier,
            "redirect_uri": GoogleOAuthConfiguration.redirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = formEncode(parameters)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func formEncode(_ parameters: [String: String]) -> Data {
        // Proper form encoding for application/x-www-form-urlencoded
        // Must escape: + & = and other special characters
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

        let encoded = parameters.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? ""
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        return encoded.data(using: .utf8)!
    }
}
```

### 5. JWT Verification (CRITICAL)

```swift
// Separate actor for managing Google's public key cache
actor GooglePublicKeyCache {
    static let shared = GooglePublicKeyCache()

    private var cachedKeys: [String: SecKey]?
    private var cacheExpiry: Date?

    func getPublicKeys() async throws -> [String: SecKey] {
        // Check cache
        if let cached = cachedKeys,
           let expiry = cacheExpiry,
           expiry > Date() {
            return cached
        }

        // Fetch from Google
        let url = URL(string: "https://www.googleapis.com/oauth2/v3/certs")!
        let (data, _) = try await URLSession.shared.data(from: url)

        // Parse JWK set
        let jwks = try JSONDecoder().decode(GoogleJWKSet.self, from: data)
        var keys: [String: SecKey] = [:]

        for jwk in jwks.keys {
            if let key = try? createPublicKey(from: jwk) {
                keys[jwk.kid] = key
            }
        }

        // Cache for 1 hour
        self.cachedKeys = keys
        self.cacheExpiry = Date().addingTimeInterval(3600)

        return keys
    }
}

extension GoogleSignInCoordinator {
    private func verifyGoogleIDToken(_ idToken: String) async throws -> VerifiedToken {
        // 1. Decode JWT header and payload
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else {
            throw GoogleSignInError.invalidIDToken
        }

        // 2. Decode header to get kid (key ID)
        let header = try decodeJWTSegment(String(parts[0]))
        guard let kid = header["kid"] as? String else {
            throw GoogleSignInError.missingKeyID
        }

        // 3. Fetch Google's public keys from cache actor
        let publicKeys = try await GooglePublicKeyCache.shared.getPublicKeys()
        guard let publicKey = publicKeys[kid] else {
            throw GoogleSignInError.unknownKeyID
        }

        // 4. Verify signature using the public key
        let signedData = "\(parts[0]).\(parts[1])".data(using: .utf8)!
        let signature = try base64URLDecode(String(parts[2]))

        guard verifySignature(signature, for: signedData, with: publicKey) else {
            throw GoogleSignInError.invalidSignature
        }

        // 5. Decode and validate claims
        let claims = try decodeJWTSegment(String(parts[1]))

        // Verify issuer
        guard let iss = claims["iss"] as? String,
              (iss == "https://accounts.google.com" || iss == "accounts.google.com") else {
            throw GoogleSignInError.invalidIssuer
        }

        // Verify audience (must match our client ID)
        // Google can return aud as either a string or an array of strings
        let validAudience: Bool
        if let audString = claims["aud"] as? String {
            validAudience = (audString == GoogleOAuthConfiguration.clientID)
        } else if let audArray = claims["aud"] as? [String] {
            validAudience = audArray.contains(GoogleOAuthConfiguration.clientID)
        } else {
            validAudience = false
        }

        guard validAudience else {
            throw GoogleSignInError.invalidAudience
        }

        // Verify expiration
        guard let exp = claims["exp"] as? TimeInterval,
              Date(timeIntervalSince1970: exp) > Date() else {
            throw GoogleSignInError.tokenExpired
        }

        // Verify issued at time (not in the future)
        if let iat = claims["iat"] as? TimeInterval {
            guard Date(timeIntervalSince1970: iat) <= Date().addingTimeInterval(60) else {
                throw GoogleSignInError.invalidIssuedAt
            }
        }

        return VerifiedToken(
            idToken: idToken,
            decodedClaims: claims,
            subject: claims["sub"] as? String ?? "",
            email: claims["email"] as? String
        )
    }
}
```

### 5. Test Support

```swift
// Developer/TestGoogleSignInHandler.swift
#if os(macOS) && DEBUG
enum TestGoogleSignInHandler {
    @MainActor
    static func testGoogleSignIn() async {
        do {
            print("=== Starting Google Sign-In Test ===")

            let accountManager = AccountManager.shared
            let credential = try await accountManager.performTestGoogleSignIn()

            print("✓ Received Google credential")
            print("  - State used: yes")
            print("  - PKCE: enabled")
            print("  - ID Token: [REDACTED]")
            print("  - User info: [REDACTED]")

            print("=== Test Complete ===")
        } catch {
            print("✗ Test failed: \(error)")
        }
    }
}
#endif
```

## Platform Differences

### iOS
- ASWebAuthenticationSession with ephemeral session
- Automatic callback handling
- Clean presentation from view controller
- Uses modern scene-based API for presentation context
- Finds foreground active scene (activationState == .foregroundActive)
- Prefers key window, falls back to first window in scene
- Fatal error if no foreground window available (prevents silent failures)
- Ensures compatibility with multi-scene apps

### macOS
- ASWebAuthenticationSession only (no fallback)
- If ASWebAuthenticationSession fails, show error to user
- No NSWorkspace.open fallback (loses OAuth context)

## Security Measures

1. **PKCE with S256**: Protects against authorization code interception
2. **State Parameter Verification**: Stored and verified to prevent CSRF attacks
3. **Ephemeral Sessions**: No persistent cookies
4. **HTTPS Only**: All OAuth endpoints use HTTPS
5. **Full JWT Verification**:
   - Fetch Google's public keys
   - Verify signature with correct key
   - Validate issuer (accounts.google.com)
   - Validate audience (must match the client ID used in auth request, not web client ID)
   - Check expiration and issued-at times
6. **Robust RSA Key Handling**:
   - Proper ASN.1 DER encoding with sign bit padding
   - Handles variable-length modulus (including when MSB is set)
   - Correct length encoding for all ASN.1 structures
7. **Flexible Token Response Parsing**:
   - Handles expires_in as Int, Double, or NSNumber
   - Prevents rejection of valid responses with floating-point values
8. **Session Lifecycle Management**:
   - Stores ASWebAuthenticationSession reference on MainActor (required for MainActor-isolated class)
   - Prevents premature deallocation during authentication
   - Stores continuation synchronously on actor before starting session (prevents race condition)
   - Centralized finishAuthSession method ensures single resume point
   - Clears continuation before resuming to guarantee single-use
   - Cleans up both session and continuation references after completion
9. **Concurrency Safety**: Network operations off MainActor
10. **No Fallbacks**: Fail securely rather than degrading to browser

## Error Handling

```swift
enum GoogleSignInError: LocalizedError {
    case invalidAuthorizationResponse
    case tokenExchangeFailed(String)
    case invalidIDToken
    case userCancelled
    case stateMismatch
    case noAuthorizationCode
    case missingKeyID
    case unknownKeyID
    case invalidSignature
    case invalidIssuer
    case invalidAudience
    case tokenExpired
    case invalidIssuedAt
    case webAuthenticationUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationResponse:
            return "Invalid authorization response from Google"
        case .tokenExchangeFailed(let reason):
            return "Token exchange failed: \(reason)"
        case .invalidIDToken:
            return "Invalid ID token received"
        case .userCancelled:
            return "Sign-in cancelled by user"
        case .stateMismatch:
            return "Security error: OAuth state mismatch"
        case .noAuthorizationCode:
            return "No authorization code in response"
        case .missingKeyID:
            return "Token missing key identifier"
        case .unknownKeyID:
            return "Token signed with unknown key"
        case .invalidSignature:
            return "Token signature verification failed"
        case .invalidIssuer:
            return "Token from invalid issuer"
        case .invalidAudience:
            return "Token not intended for this app"
        case .tokenExpired:
            return "Token has expired"
        case .invalidIssuedAt:
            return "Token issued at invalid time"
        case .webAuthenticationUnavailable:
            return "Web authentication not available on this platform"
        }
    }
}
```

## Testing Strategy

### Unit Tests
- Mock OAuth responses
- Test PKCE generation
- Test JWT decoding
- Test error cases

### Integration Tests
- Real OAuth flow (dev environment)
- Lambda integration
- Credential storage

### Manual Testing
- Developer menu test command
- Different Google accounts
- Error scenarios (cancel, network failure)

## Implementation Steps

### Day 1: Core OAuth Flow
1. Create GoogleSignInCoordinator.swift
2. Implement PKCE generation
3. Build authorization URL
4. Present ASWebAuthenticationSession

### Day 2: Token Exchange
1. Implement authorization code extraction
2. Exchange code for tokens
3. Decode JWT for user info
4. Handle errors

### Day 3: AccountManager Integration
1. Add signInWithGoogle() method
2. Lambda integration
3. Credential storage
4. Session management

### Day 4: Testing & Polish
1. Add developer menu test command
2. Test on both platforms
3. Error handling refinement
4. Documentation

## Configuration Requirements

### Already Complete
- GoogleOAuthConfiguration.swift exists
- Info.plist configured with URL scheme
- GoogleSignIn SDK in project (though we won't use it)

### Still Needed
- Make GoogleSignInCoordinator internal (for test access)
- Add test method to AccountManager
- Update developer menu

## Comparison with Photolala1

### What We're Keeping
- OAuth configuration (client IDs, endpoints)
- URL scheme handling
- JWT decoding approach

### What We're Changing
- No GoogleSignIn SDK dependency
- No separate GoogleAuthProvider actor
- Integrated into AccountManager
- Simplified error handling
- Better test support

### What We're Adding
- PKCE for enhanced security
- Developer menu integration
- Consistent with Apple Sign-In patterns

## Success Criteria

1. ✅ User can sign in with Google account
2. ✅ Receives STS credentials from Lambda
3. ✅ Session persists across app launches
4. ✅ Works on both macOS and iOS
5. ✅ Isolated test flow available
6. ✅ No external SDK dependencies

## Future Enhancements (Phase 3)

- Provider linking (link Google to existing Apple account)
- Account switching
- Refresh token handling
- Silent sign-in

---

*Last Updated: September 2024*
*Phase: 2 - Google Sign-In*
*Dependencies: Phase 1 (Apple Sign-In) must be complete*