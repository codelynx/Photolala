# Identity Provider Testing Interface Plan

## Overview
Create a comprehensive diagnostic interface for testing the complete Photolala authentication flow, replacing the current basic `TestSignInView` with a more robust `IdentityProviderDiagnosticsView` that provides full visibility into the sign-in/sign-up process and backend interactions.

## Goals
1. **Complete Flow Testing**: Test the entire authentication pipeline from OAuth to backend account creation
2. **Environment Flexibility**: Switch between dev/stage/prod environments without rebuilding
3. **Process Visibility**: Show intermediate steps and backend responses
4. **Account Management**: Test both new account creation and existing account sign-in
5. **Debug Information**: Display user UUIDs, email mappings, and account metadata

## Current Architecture Analysis

### Authentication Flow
1. **OAuth Provider Authentication**
   - Apple Sign-In via ASAuthorizationController
   - Google Sign-In via browser-based OAuth with PKCE

2. **Backend Integration**
   - Lambda functions: `photolala-auth-signin`, `photolala-web-auth`, `photolala-auth-refresh`
   - Returns `AuthResult` with:
     - `PhotolalaUser` (UUID, provider IDs, email, display name)
     - `STSCredentials` (temporary AWS credentials)
     - `isNewUser` flag

3. **Environment Management**
   - Environments: Development, Staging, Production
   - Credentials embedded in binary via credential-code encryption
   - Environment selection via UserDefaults

## Proposed Solution

### 1. Rename and Refactor
- Rename `TestSignInView` → `IdentityProviderDiagnosticsView`
- Rename `TestSignInWindowController` → `IdentityProviderDiagnosticsController`
- Move from simple OAuth testing to full authentication flow testing

### 2. UI Components

#### Main Interface Structure
```
┌─────────────────────────────────────────────┐
│  Identity Provider Diagnostics              │
├─────────────────────────────────────────────┤
│ Environment: [Dev ▼] [Stage] [Prod]         │
├─────────────────────────────────────────────┤
│ Provider Selection:                         │
│  ◉ Apple ID    ○ Google ID                 │
├─────────────────────────────────────────────┤
│ Options:                                    │
│  ☐ Force new account creation              │
│  ☐ Show detailed network logs              │
│  ☐ Simulate first-time user                │
├─────────────────────────────────────────────┤
│ [Begin Authentication Test]                 │
├─────────────────────────────────────────────┤
│ Process Flow:                               │
│ ┌─────────────────────────────────────────┐│
│ │ 1. OAuth Provider Authentication  ✓     ││
│ │ 2. Token Validation              ✓     ││
│ │ 3. Lambda Function Call          ⏳    ││
│ │ 4. Account Creation/Retrieval    ⏳    ││
│ │ 5. STS Credentials Generation    ⏳    ││
│ └─────────────────────────────────────────┘│
├─────────────────────────────────────────────┤
│ Account Information:                        │
│ ┌─────────────────────────────────────────┐│
│ │ User UUID: 123e4567-e89b-12d3...       ││
│ │ Email: user@example.com                 ││
│ │ Display Name: John Doe                   ││
│ │ Apple ID: apple_xxxxx                    ││
│ │ Google ID: (not linked)                  ││
│ │ Account Created: 2024-09-22              ││
│ │ Is New User: false                       ││
│ └─────────────────────────────────────────┘│
├─────────────────────────────────────────────┤
│ Debug Log:                                  │
│ ┌─────────────────────────────────────────┐│
│ │ [17:45:23] Starting Apple Sign-In...    ││
│ │ [17:45:24] Received OAuth token         ││
│ │ [17:45:24] Calling Lambda: photolala... ││
│ │ [17:45:25] Lambda response received     ││
│ │ [17:45:25] User account retrieved       ││
│ └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

### 3. Feature Implementation

#### A. Environment Switching
```swift
enum TestEnvironment: String, CaseIterable {
    case development = "Development"
    case staging = "Staging"
    case production = "Production"

    var userDefaultsValue: String {
        switch self {
        case .development: return "dev"
        case .staging: return "stage"
        case .production: return "prod"
        }
    }
}

// Allow temporary environment override for testing
func setTestEnvironment(_ environment: TestEnvironment) {
    UserDefaults.standard.set(environment.userDefaultsValue,
                              forKey: "PhotolalaEnvironment")
}
```

#### B. Process Flow Visualization
```swift
enum AuthenticationStep {
    case idle
    case oauthInProgress
    case oauthComplete(token: String)
    case tokenValidation
    case lambdaCall(function: String)
    case accountProcessing
    case credentialsGenerated
    case complete(user: PhotolalaUser)
    case failed(error: Error)
}

@Observable
class AuthenticationFlowState {
    var currentStep: AuthenticationStep = .idle
    var stepHistory: [(Date, String)] = []
    var networkLogs: [NetworkLogEntry] = []
}
```

#### C. Account Information Display
```swift
struct AccountInfoView: View {
    let authResult: AuthResult?

    var body: some View {
        if let result = authResult {
            VStack(alignment: .leading) {
                LabeledContent("User UUID", value: result.user.id.uuidString)
                LabeledContent("Email", value: result.user.email ?? "N/A")
                LabeledContent("Display Name", value: result.user.displayName)

                // Provider Status
                HStack {
                    ProviderStatusBadge(
                        provider: "Apple",
                        isLinked: result.user.hasAppleProvider,
                        id: result.user.appleUserID
                    )
                    ProviderStatusBadge(
                        provider: "Google",
                        isLinked: result.user.hasGoogleProvider,
                        id: result.user.googleUserID
                    )
                }

                LabeledContent("Account Type",
                              value: result.isNewUser ? "New User" : "Existing User")
                LabeledContent("Created",
                              value: result.user.createdAt.formatted())

                // STS Credentials Info
                if let expiration = result.credentials.expiration {
                    LabeledContent("Credentials Expire",
                                  value: expiration.formatted())
                }
            }
        }
    }
}
```

#### D. Network Request Logging
```swift
struct NetworkLogEntry {
    let timestamp: Date
    let type: LogType
    let message: String
    let details: [String: Any]?

    enum LogType {
        case request
        case response
        case error
        case info
    }
}

// Hook into AccountManager to capture Lambda calls
extension AccountManager {
    func testSignInWithLogging(
        provider: AuthProvider,
        onLogEntry: @escaping (NetworkLogEntry) -> Void
    ) async throws -> AuthResult {
        // Log OAuth start
        onLogEntry(.init(type: .info,
                        message: "Starting \(provider) authentication"))

        // Perform OAuth
        let token = try await performOAuth(provider: provider)
        onLogEntry(.init(type: .response,
                        message: "OAuth token received",
                        details: ["tokenLength": token.count]))

        // Log Lambda call
        let lambdaFunction = getLambdaFunction(for: provider)
        onLogEntry(.init(type: .request,
                        message: "Calling Lambda: \(lambdaFunction)"))

        // Make Lambda call with logging
        let result = try await callAuthLambda(token: token,
                                              provider: provider)

        onLogEntry(.init(type: .response,
                        message: "Account \(result.isNewUser ? "created" : "retrieved")",
                        details: ["userId": result.user.id.uuidString]))

        return result
    }
}
```

### 4. Testing Scenarios

#### Supported Test Cases
1. **New User Registration**
   - First-time sign-in with Apple/Google
   - Verify account creation in backend
   - Check UUID generation

2. **Existing User Sign-In**
   - Returning user authentication
   - Verify account retrieval
   - Check credential refresh

3. **Provider Linking**
   - Add Google to Apple account
   - Add Apple to Google account
   - Verify merged account state

4. **Environment Switching**
   - Test same provider across dev/stage/prod
   - Verify different user pools
   - Check environment-specific configurations

5. **Error Scenarios**
   - Network timeouts
   - Invalid tokens
   - Lambda errors
   - Expired credentials

### 5. Implementation Phases

#### Phase 1: Basic Refactoring (Week 1)
- [ ] Rename existing TestSignInView components
- [ ] Add environment switching UI
- [ ] Create basic process flow visualization

#### Phase 2: Full Integration (Week 2)
- [ ] Connect to actual AccountManager sign-in flow
- [ ] Add Lambda call logging
- [ ] Implement account information display
- [ ] Add network request logging

#### Phase 3: Advanced Features (Week 3)
- [ ] Add force new account option
- [ ] Implement provider linking tests
- [ ] Add credential expiration monitoring
- [ ] Create exportable test reports

#### Phase 4: Polish & Documentation (Week 4)
- [ ] Improve UI/UX design
- [ ] Add inline help documentation
- [ ] Create test scenario templates
- [ ] Write developer documentation

### 6. Technical Considerations

#### Security
- Only available in DEVELOPER builds
- No production credentials in logs
- Sensitive data redaction in UI
- Temporary environment switching (resets on app restart)

#### State Management
```swift
@Observable
final class IdentityProviderDiagnosticsModel {
    // Environment
    var selectedEnvironment: TestEnvironment = .development
    var originalEnvironment: String?

    // Provider
    var selectedProvider: AuthProvider = .apple

    // Options
    var forceNewAccount = false
    var showDetailedLogs = false
    var simulateFirstTimeUser = false

    // State
    var isTestRunning = false
    var authenticationFlow = AuthenticationFlowState()
    var lastAuthResult: AuthResult?
    var errorMessage: String?

    // Logs
    var logEntries: [NetworkLogEntry] = []
    var debugMessages: [String] = []
}
```

#### Integration Points
1. **AccountManager Extensions**
   - Add test-specific methods with logging hooks
   - Preserve production code integrity
   - Use dependency injection for test scenarios

2. **Lambda Client Instrumentation**
   - Log requests/responses without modification
   - Capture timing information
   - Record error details

3. **OAuth Provider Wrappers**
   - Intercept OAuth callbacks
   - Log token exchanges
   - Capture user consent states

### 7. Success Metrics
- Complete visibility into authentication flow
- Ability to test all authentication scenarios
- Quick environment switching without rebuild
- Clear error diagnosis capabilities
- Reproducible test scenarios

### 8. Future Enhancements
- Export test results as JSON/CSV
- Automated test suite integration
- Performance benchmarking
- Multi-account testing support
- Session management testing
- Token refresh simulation

---

## Summary
This plan transforms the basic OAuth testing view into a comprehensive identity provider diagnostics interface that provides full visibility into Photolala's authentication system, enabling thorough testing across all environments and scenarios while maintaining security and code organization.

The new `IdentityProviderDiagnosticsView` will be an essential tool for:
- Development debugging
- QA testing
- Production issue diagnosis
- Onboarding new developers
- Documenting authentication flow

Implementation prioritizes developer experience while maintaining production code safety through clear separation of test and production code paths.