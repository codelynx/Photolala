# Account Management Implementation Plan

## Overview

Phased implementation plan for account management in Photolala2, starting simple and scaling up. Begin with Apple Sign-In only, minimal Lambda usage, and gradually add features.

## Core Principle: Start Simple, Scale Later

### MVP Scope (Phase 1)
- Apple Sign-In only
- Single Lambda function for auth
- No provider linking
- Dev environment only
- iOS only

### Future Scaling
- Add Google Sign-In (Phase 2)
- Provider linking (Phase 3)
- Multi-platform (Phase 4)

## Phase 1: Minimal Viable Authentication (Week 1)

### Core Service: `AccountManager`

**Responsibilities:**
- Apple Sign-In
- Call one Lambda function
- Store user in Keychain
- Get STS tokens

**Implementation with AWS SDK Compatibility:**
```swift
// Use actor for state management, nonisolated for AWS SDK calls
actor AccountManager {
    private var currentUser: PhotolalaUser?
    private var stsCredentials: STSCredentials?

    var isSignedIn: Bool { currentUser != nil }

    func signInWithApple() async throws -> PhotolalaUser
    func signOut() async
    func getS3Credentials() async throws -> STSCredentials
    func getCurrentUser() async -> PhotolalaUser?

    // AWS SDK compatibility
    nonisolated func invokeLambda(functionName: String, payload: Data) async throws -> Data {
        // AWS SDK calls here - doesn't require actor isolation
        let lambda = try LambdaClient(region: .usEast1)
        return try await lambda.invoke(
            functionName: functionName,
            payload: payload
        ).payload
    }
}
```

**Note**: Using `nonisolated` for AWS SDK methods allows them to work with the current SDK while keeping state management safe with actor isolation.

**Option B: Observable for SwiftUI (If needed)**
```swift
// Only if directly driving UI
@MainActor
class SimpleAccountManager: ObservableObject {
    @Published var currentUser: PhotolalaUser?
    @Published var isSignedIn = false
    @Published var stsCredentials: STSCredentials?

    private let service: AccountService // Non-UI logic here

    func signInWithApple() async throws
    func signOut()
}
```

**Recommendation**: Start with Option A (actor) for business logic, add thin Observable wrapper only where needed for UI.

### Minimal User Model
```swift
struct PhotolalaUser: Codable {
    let id: UUID
    let appleUserID: String
    let email: String?
    let createdAt: Date
}
```

### Single Lambda Function
`photolala-auth-signin`
- Input: Apple ID token
- Output: User UUID + STS credentials
- Handles both new and existing users

### Implementation Steps

**Day 1-2: Apple Sign-In**
```swift
func signInWithApple() async throws {
    // 1. Show Apple Sign-In
    let appleCredential = try await ASAuthorizationController.performRequest()

    // 2. Call Lambda
    let result = try await callLambda("photolala-auth-signin",
                                      payload: ["idToken": appleCredential.idToken])

    // 3. Save to Keychain
    self.currentUser = result.user
    self.stsCredentials = result.credentials
    self.isSignedIn = true
}
```

**Day 3: Lambda Client**
```swift
func callLambda(_ functionName: String, payload: [String: Any]) async throws -> AuthResult {
    let lambda = try LambdaClient(region: "us-east-1")
    let response = try await lambda.invoke(
        functionName: functionName,
        payload: payload.jsonData()
    )
    return try JSONDecoder().decode(AuthResult.self, from: response)
}
```

**Day 4: Keychain Storage**
```swift
func saveSession() {
    KeychainAccess.save("user", currentUser)
    KeychainAccess.save("credentials", stsCredentials)
}

func loadSession() {
    currentUser = KeychainAccess.load("user", PhotolalaUser.self)
    stsCredentials = KeychainAccess.load("credentials", STSCredentials.self)
    isSignedIn = (currentUser != nil)
}
```

**Day 5: STS Refresh**
```swift
func getS3Credentials() async throws -> STSCredentials {
    // Check if expired
    if let creds = stsCredentials, !creds.isExpired {
        return creds
    }

    // Refresh
    let result = try await callLambda("photolala-auth-refresh",
                                      payload: ["userId": currentUser.id])
    self.stsCredentials = result.credentials
    return result.credentials
}
```

## Phase 2: Add Google Sign-In (Week 2)

### Extend AccountManager
```swift
extension AccountManager {
    func signInWithGoogle() async throws {
        // Similar flow to Apple
    }
}
```

### Update Lambda
- Accept both Apple and Google tokens
- Detect provider type from token

## Phase 3: Provider Linking (Week 3)

### Add Linking Support
```swift
extension AccountManager {
    func linkGoogleAccount() async throws {
        guard let user = currentUser else { throw AccountError.notSignedIn }

        // Get Google token
        let googleCredential = try await GoogleSignIn.shared.signIn()

        // Call linking Lambda
        let result = try await callLambda("photolala-auth-link",
                                          payload: [
                                              "userId": user.id,
                                              "googleToken": googleCredential.idToken
                                          ])

        if result.status == "already_linked" {
            throw AccountError.providerAlreadyLinked
        }
    }
}
```

## Phase 4: Full Implementation (Week 4+)

### Refactor to Multiple Managers
1. Split into specialized managers
2. Add abstraction layers
3. Implement all features from original plan

## Testing Strategy (Simple to Complex)

### Phase 1 Tests
- Mock Apple Sign-In
- Mock Lambda response
- Test Keychain save/load
- Test STS refresh

### Phase 2 Tests
- Add Google Sign-In mocks
- Test provider detection

### Phase 3 Tests
- Test linking scenarios
- Test conflict detection

## Benefits of This Approach

1. **Faster Initial Implementation** - Working auth in 1 week
2. **Early Testing** - Can test core flow immediately
3. **Reduced Complexity** - One manager, one Lambda
4. **Easy Debugging** - Fewer moving parts
5. **Incremental Validation** - Prove concept before scaling

## Migration Path

### From Simple to Full
1. AccountManager → AccountManager + AuthProviderManager
2. Single Lambda → Multiple specialized Lambdas
3. Basic error handling → Comprehensive error recovery
4. iOS only → iOS + macOS + visionOS

## Key Decisions

### Start With
- ✅ Apple Sign-In only
- ✅ One Lambda function
- ✅ Simple error handling
- ✅ Dev environment only
- ✅ iOS only

### Defer Until Later
- ❌ Google Sign-In
- ❌ Provider linking
- ❌ Complex error recovery
- ❌ Multi-platform
- ❌ Auto-refresh timers

## Success Criteria for Phase 1

1. User can sign in with Apple ID
2. User receives STS credentials
3. User can access their S3 data
4. Session persists across app launches
5. Basic error messages work

## AWS SDK Concurrency Considerations

### Current AWS SDK Limitations
- AWS SDK for Swift is not fully Swift Concurrency compliant yet
- Some operations may require bridging from completion handlers
- Use `nonisolated` for AWS SDK calls to avoid actor isolation issues

### Hybrid Approach
```swift
actor AccountManager {
    // Actor-isolated state
    private var currentUser: PhotolalaUser?
    private var stsCredentials: STSCredentials?

    // Actor-isolated methods for state management
    func updateUser(_ user: PhotolalaUser) async {
        self.currentUser = user
    }

    // Nonisolated for AWS SDK compatibility
    nonisolated func callLambda(_ name: String, _ payload: Data) async throws -> Data {
        let lambda = try LambdaClient(region: .usEast1)
        let response = try await lambda.invoke(
            functionName: name,
            payload: payload
        )
        return response.payload ?? Data()
    }

    // Main auth flow coordinates both
    func signIn() async throws -> PhotolalaUser {
        let token = try await getAppleToken()
        let data = try await callLambda("auth", token.data)  // nonisolated call
        let user = try JSONDecoder().decode(PhotolalaUser.self, from: data)
        await updateUser(user)  // actor-isolated update
        return user
    }
}
```

## Architecture: Service Layer vs UI Layer

### Clean Separation Approach

**Service Layer (Non-UI)**
```
Services/
├── AccountService.swift         // actor, pure business logic
├── LambdaClient.swift          // actor, network operations
└── KeychainService.swift       // actor, secure storage
```

**UI Layer (SwiftUI Views)**
```
Views/
├── SignInView.swift            // SwiftUI view
└── SignInView+Model.swift     // @Observable view model
```

**Example Integration:**
```swift
// Service Layer - No UI coupling
actor AccountService {
    func signIn(with token: String) async throws -> PhotolalaUser {
        // Pure business logic
        let result = try await lambdaClient.authenticate(token)
        try await keychainService.save(result.user)
        return result.user
    }
}

// UI Layer - Thin wrapper for SwiftUI
extension SignInView {
    @Observable
    class Model {
        private let accountService = AccountService()
        var user: PhotolalaUser?
        var isLoading = false

        func signIn() async {
            isLoading = true
            defer { isLoading = false }

            do {
                let token = try await showAppleSignIn()
                user = try await accountService.signIn(with: token)
            } catch {
                // Handle UI error
            }
        }
    }
}
```

### Benefits of Separation

1. **Testability** - Service layer can be tested without UI
2. **Reusability** - Same service for iOS, macOS, visionOS
3. **Concurrency** - Actors prevent data races
4. **No UI pollution** - Business logic stays pure
5. **SwiftUI friendly** - Views only see what they need

## Code Structure for Phase 1

```
Photolala/
├── Services/               // Non-UI business logic
│   ├── AccountService.swift       // actor
│   ├── LambdaClient.swift        // actor
│   └── KeychainService.swift     // actor
├── Models/                 // Data models
│   ├── PhotolalaUser.swift
│   └── STSCredentials.swift
└── Account/                // UI components
    ├── SignInView.swift
    └── SignInView+Model.swift     // @Observable
```

## Lambda Function for Phase 1

### `photolala-auth-signin`

**Input:**
```json
{
    "idToken": "eyJhbGc...",
    "provider": "apple"
}
```

**Output:**
```json
{
    "user": {
        "id": "uuid",
        "appleUserID": "001234.xxx",
        "email": "user@example.com",
        "createdAt": "2024-09-22T10:00:00Z"
    },
    "credentials": {
        "accessKeyId": "ASIA...",
        "secretAccessKey": "xxx",
        "sessionToken": "xxx",
        "expiration": "2024-09-22T11:00:00Z"
    },
    "isNewUser": true
}
```

## Next Steps

1. **Week 1**: Implement Phase 1 completely
2. **Test**: Verify Phase 1 works end-to-end
3. **Evaluate**: Decide if/when to proceed to Phase 2
4. **Iterate**: Add features based on user feedback

---

*Last Updated: September 2024*
*Approach: Simple First, Scale Later*
*Initial Target: Apple Sign-In MVP*