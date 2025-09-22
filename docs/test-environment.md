# Test Environment Capabilities

## Overview
This document outlines what can and cannot be tested in different Xcode test environments (Unit Tests, UI Tests, and Test Targets).

## Test Environment Types

### 1. Unit Tests (XCTest)
- **Runs in**: Simulator/Device sandbox
- **Network**: ✅ Can access internet
- **File System**: ⚠️ Limited to test bundle sandbox
- **Duration**: Should be fast (< 1 second each)

### 2. UI Tests (XCUITest)
- **Runs in**: Separate process from app
- **Network**: ✅ Can access internet (through app)
- **File System**: ❌ No direct file access
- **Duration**: Slower (launches full app)

### 3. Test Target (Separate App Target)
- **Runs in**: Full app sandbox
- **Network**: ✅ Full internet access
- **File System**: ✅ Full sandbox access
- **Duration**: Manual testing

## Feature Testability Matrix

| Feature | Unit Test | UI Test | Test Target | Real Device | Notes |
|---------|-----------|---------|-------------|-------------|-------|
| **Local File System** |||||
| Scan sandbox directories | ⚠️ | ❌ | ✅ | ✅ | Unit tests have limited sandbox |
| Read/write cache | ✅ | ❌ | ✅ | ✅ | Can mock in unit tests |
| Access Photos Library | ❌ | ⚠️ | ✅ | ✅ | Requires user permission |
| Access external volumes | ❌ | ❌ | ❌ | ⚠️ | macOS only, with permission |
| **AWS Services** |||||
| S3 List/Get/Put | ✅ | ⚠️ | ✅ | ✅ | Use dev bucket |
| Lambda calls | ✅ | ⚠️ | ✅ | ✅ | Use dev endpoints |
| Athena queries | ✅ | ⚠️ | ✅ | ✅ | Use dev database |
| CloudWatch logs | ✅ | ❌ | ✅ | ✅ | Through AWS SDK |
| **Authentication** |||||
| Apple Sign-In | ❌ | ⚠️ | ✅ | ✅ | Requires real UI |
| Google OAuth | ❌ | ⚠️ | ✅ | ✅ | Requires web view |
| Keychain access | ⚠️ | ❌ | ✅ | ✅ | Limited in tests |
| Biometric auth | ❌ | ❌ | ⚠️ | ✅ | Device only |
| **Image Processing** |||||
| Thumbnail generation | ✅ | ❌ | ✅ | ✅ | Can use test images |
| EXIF data reading | ✅ | ❌ | ✅ | ✅ | Can use test images |
| Image caching | ✅ | ❌ | ✅ | ✅ | In-memory for tests |
| **Catalog System** |||||
| SQLite operations | ✅ | ❌ | ✅ | ✅ | In-memory DB for tests |
| MD5 computation | ✅ | ❌ | ✅ | ✅ | Pure computation |
| Fast-photo-key | ✅ | ❌ | ✅ | ✅ | Pure computation |

## Detailed Test Scenarios

### 1. Local Directory Scanning

#### What CAN be tested:
```swift
// Unit Test - Mock file system
func testDirectoryScan() {
    let mockFS = MockFileSystem()
    mockFS.addFile("/test/photo1.jpg", size: 1024)

    let scanner = DirectoryScanner(fileSystem: mockFS)
    let results = scanner.scan("/test")

    XCTAssertEqual(results.count, 1)
}

// Test Target - Real sandbox scanning
func testRealSandboxScan() {
    let documentsPath = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
    // Create test files in sandbox
    // Scan and verify
}
```

#### What CANNOT be tested:
- Scanning user's actual photo directories
- Accessing files outside sandbox (without permission)
- Network volumes (in unit tests)
- External drives (in iOS)

### 2. AWS S3 Access

#### What CAN be tested:
```swift
// Unit Test - Use dev credentials
func testS3ListObjects() async {
    let s3 = S3Service()
    s3.useBucket("photolala-dev")

    let objects = try await s3.listObjects(prefix: "test/")
    XCTAssertNotNil(objects)
}

// Test Target - Full S3 operations
func testS3Upload() async {
    let s3 = S3Service()
    let testData = "test".data(using: .utf8)!

    try await s3.putObject(key: "test/file.txt", data: testData)
    let retrieved = try await s3.getObject(key: "test/file.txt")

    XCTAssertEqual(retrieved, testData)
}
```

#### Best Practices for S3 Testing:
- Always use `photolala-dev` bucket
- Create test prefixes like `test/` or `unittest/`
- Clean up after tests
- Use mock S3 service for unit tests when possible

### 3. Authentication Testing

#### Sign-In Diagnostics Panel (macOS debug builds):
The app includes a visual Sign-In Diagnostics panel accessible via the Developer menu:
- **Test Sign-In with Apple** (Cmd+Shift+T) - Opens diagnostics and starts Apple OAuth
- **Test Sign-In with Google** (Cmd+Shift+G) - Opens diagnostics and starts Google OAuth
- **Open Sign-In Test Panel** - Opens diagnostics window without starting a flow

Features:
- Real-time visual logging in a dedicated window
- Full OAuth flow testing without backend dependencies
- Secure token verification with redacted sensitive data
- Selectable/copyable log output for debugging
- No side effects on app state

#### Apple Sign-In:
```swift
// Test Target Only - Requires UI
func testAppleSignIn() {
    // Can test via Sign-In Diagnostics panel or mock in unit tests
    // Unit tests can mock the authentication service

    let mockAuth = MockAppleAuth()
    mockAuth.signInResult = .success(userID: "test123")
}
```

#### Google OAuth:
```swift
// Similar to Apple - UI required for real auth
// Mock for unit tests
```

### 4. Sandbox Limitations

#### iOS Sandbox:
```
App Sandbox/
├── Documents/       # ✅ Full access
├── Library/
│   ├── Caches/     # ✅ Full access
│   └── Preferences/ # ✅ UserDefaults
├── tmp/            # ✅ Temporary files
└── [No access outside without permission]
```

#### macOS Sandbox (with App Sandbox enabled):
```
~/Library/Containers/com.electricwoods.photolala/
├── Data/
│   ├── Documents/   # ✅ Full access
│   ├── Library/     # ✅ Full access
│   └── tmp/         # ✅ Temporary files
└── [Need permission for ~/Pictures, etc.]
```

## Test Target Setup Recommendations

### 1. Create "PhotolalaTests" Target
```xml
<!-- In Xcode project -->
<Target name="PhotolalaTests">
    <BuildConfiguration>
        <Setting name="PRODUCT_BUNDLE_IDENTIFIER">com.electricwoods.photolala.tests</Setting>
        <Setting name="SWIFT_ACTIVE_COMPILATION_CONDITIONS">DEBUG TESTING</Setting>
    </BuildConfiguration>
</Target>
```

### 2. Test-Specific Configuration
```swift
// EnvironmentHelper.swift
static func getCurrentBucket() -> String {
    #if TESTING
    return "photolala-dev"  // Always use dev for tests
    #else
    // Normal environment selection
    #endif
}
```

### 3. Test Data Management
```swift
struct TestDataManager {
    static let testPhotosBundle = Bundle(named: "TestPhotos")

    static func copyTestPhotosToSandbox() {
        // Copy test images to Documents for testing
    }

    static func cleanupTestData() {
        // Remove test data after tests
    }
}
```

## Test Categories

### ✅ Fully Testable (All Environments)
- Data models and business logic
- Credential decryption
- Image processing algorithms
- SQLite operations
- JSON parsing
- MD5/SHA calculations
- Date/time operations

### ⚠️ Partially Testable (With Mocks/Stubs)
- Network requests (mock in unit, real in test target)
- File system operations (sandbox only)
- UserDefaults/Keychain (limited in unit tests)
- Notifications (can test posting, not receiving)

### ❌ Not Testable (Need Real Device/User)
- Photos Library access (need permission)
- Camera access
- Real Apple/Google sign-in flow
- Push notifications (receiving)
- Biometric authentication
- App Store receipt validation
- External volumes/drives

## Recommended Test Strategy

### 1. Unit Tests (Fast, Isolated)
- Mock external dependencies
- Test business logic
- Test data transformations
- Run on every commit

### 2. Integration Tests (Test Target)
- Test real AWS services with dev environment
- Test file system operations in sandbox
- Test full authentication flow
- Run before releases

### 3. Manual Testing (Real Device)
- Test Photos Library access
- Test authentication flows
- Test with real user data
- Performance testing

## Environment-Specific Test Flags

```swift
// In your test code
#if TESTING
    // Test-specific code
    let testMode = true
#endif

// Check at runtime
if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
    // Running in test environment
}

// For test target app
if Bundle.main.bundleIdentifier?.contains(".tests") == true {
    // Running test target app
}
```

## CI/CD Considerations

### What can run in CI:
- ✅ Unit tests
- ✅ Some UI tests (with simulator)
- ✅ AWS integration tests (with credentials)
- ❌ Photos Library tests
- ❌ Keychain tests (limited)
- ❌ Device-specific features

## Conclusion

For comprehensive testing:
1. **Unit Tests**: Mock everything, test logic
2. **Test Target**: Test real services with dev environment
3. **Manual Testing**: Test permission-based features

The test target approach is best for:
- AWS service integration testing
- Sandbox file system operations
- Authentication flow testing (with UI)
- Performance testing with real data
