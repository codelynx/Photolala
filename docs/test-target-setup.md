# Test Target Setup Guide

## Creating a Test Target in Xcode

### Step 1: Add New Target
1. Select project in navigator
2. Click "+" under targets
3. Choose "App" (not "Unit Test Bundle")
4. Name: "PhotolalaTests"
5. Bundle ID: `com.electricwoods.photolala.tests`

### Step 2: Configure Test Target

#### Info.plist Changes
```xml
<key>CFBundleDisplayName</key>
<string>Photolala Tests</string>

<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
</dict>

<!-- Add test indicator -->
<key>IsTestTarget</key>
<true/>
```

#### Build Settings
```
PRODUCT_NAME = PhotolalaTests
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG TESTING
PRODUCT_BUNDLE_IDENTIFIER = com.electricwoods.photolala.tests
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon-Test
```

### Step 3: Create Test-Specific Entry Point

```swift
// PhotolalaTestApp.swift
import SwiftUI

@main
struct PhotolalaTestApp: App {
    init() {
        // Force test environment
        UserDefaults.standard.set("development", forKey: "environment_preference")

        // Enable test mode flags
        UserDefaults.standard.set(true, forKey: "test_mode_enabled")

        print("🧪 Test Target Launched")
        print("📦 Using bucket: \(EnvironmentHelper.getCurrentBucket())")
    }

    var body: some Scene {
        WindowGroup {
            TestMenuView()
        }
    }
}
```

### Step 4: Create Test Menu View

```swift
// TestMenuView.swift
import SwiftUI

struct TestMenuView: View {
    @State private var testResults: [String: TestResult] = [:]
    @State private var isRunning = false

    var body: some View {
        NavigationView {
            List {
                Section("Local File System") {
                    TestRow(
                        title: "Sandbox Directory Scan",
                        test: testSandboxScan
                    )
                    TestRow(
                        title: "Cache Read/Write",
                        test: testCacheOperations
                    )
                    TestRow(
                        title: "SQLite Catalog",
                        test: testSQLiteCatalog
                    )
                }

                Section("AWS Services") {
                    TestRow(
                        title: "S3 List Objects",
                        test: testS3List
                    )
                    TestRow(
                        title: "S3 Upload/Download",
                        test: testS3UploadDownload
                    )
                    TestRow(
                        title: "Lambda Invocation",
                        test: testLambdaInvoke
                    )
                    TestRow(
                        title: "Athena Query",
                        test: testAthenaQuery
                    )
                }

                Section("Authentication") {
                    TestRow(
                        title: "Apple Sign-In",
                        test: testAppleSignIn,
                        requiresUI: true
                    )
                    TestRow(
                        title: "Google OAuth",
                        test: testGoogleOAuth,
                        requiresUI: true
                    )
                    TestRow(
                        title: "Keychain Access",
                        test: testKeychainAccess
                    )
                }

                Section("Image Processing") {
                    TestRow(
                        title: "Thumbnail Generation",
                        test: testThumbnailGeneration
                    )
                    TestRow(
                        title: "EXIF Data Reading",
                        test: testEXIFReading
                    )
                    TestRow(
                        title: "MD5 Computation",
                        test: testMD5Computation
                    )
                }

                Section("Permissions") {
                    TestRow(
                        title: "Photos Library Access",
                        test: testPhotosLibraryAccess,
                        requiresPermission: true
                    )
                    TestRow(
                        title: "Camera Access",
                        test: testCameraAccess,
                        requiresPermission: true
                    )
                }
            }
            .navigationTitle("Photolala Test Suite")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Run All") {
                        runAllTests()
                    }
                    .disabled(isRunning)
                }
            }
        }
    }
}

struct TestRow: View {
    let title: String
    let test: () async -> TestResult
    var requiresUI: Bool = false
    var requiresPermission: Bool = false

    @State private var result: TestResult?
    @State private var isRunning = false

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                if requiresUI {
                    Text("Requires UI")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                if requiresPermission {
                    Text("Requires Permission")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }

            Spacer()

            if isRunning {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            } else if let result = result {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
            }

            Button("Run") {
                Task {
                    isRunning = true
                    result = await test()
                    isRunning = false
                }
            }
            .disabled(isRunning)
        }
    }
}

struct TestResult {
    let success: Bool
    let message: String
    let duration: TimeInterval
}
```

### Step 5: Implement Test Functions

```swift
// TestFunctions.swift
import Foundation
import Photos
import AWSS3

// MARK: - Local File System Tests

func testSandboxScan() async -> TestResult {
    let start = Date()

    do {
        let documentsURL = FileManager.default.urls(for: .documentDirectory,
                                                    in: .userDomainMask).first!

        // Create test files
        for i in 1...10 {
            let testFile = documentsURL.appendingPathComponent("test\(i).txt")
            try "Test content \(i)".write(to: testFile, atomically: true, encoding: .utf8)
        }

        // Scan directory
        let files = try FileManager.default.contentsOfDirectory(at: documentsURL,
                                                               includingPropertiesForKeys: [.fileSizeKey])

        // Cleanup
        for file in files where file.lastPathComponent.hasPrefix("test") {
            try FileManager.default.removeItem(at: file)
        }

        return TestResult(
            success: files.count >= 10,
            message: "Scanned \(files.count) files",
            duration: Date().timeIntervalSince(start)
        )
    } catch {
        return TestResult(
            success: false,
            message: error.localizedDescription,
            duration: Date().timeIntervalSince(start)
        )
    }
}

// MARK: - AWS S3 Tests

func testS3List() async -> TestResult {
    let start = Date()

    do {
        let s3Service = S3Service.shared
        try await s3Service.initialize()

        let objects = try await s3Service.listObjects(prefix: "test/", maxKeys: 10)

        return TestResult(
            success: true,
            message: "Listed \(objects.count) objects",
            duration: Date().timeIntervalSince(start)
        )
    } catch {
        return TestResult(
            success: false,
            message: error.localizedDescription,
            duration: Date().timeIntervalSince(start)
        )
    }
}

func testS3UploadDownload() async -> TestResult {
    let start = Date()

    do {
        let s3Service = S3Service.shared
        try await s3Service.initialize()

        // Upload test
        let testKey = "test/photolala-test-\(UUID().uuidString).txt"
        let testData = "Test upload at \(Date())".data(using: .utf8)!

        try await s3Service.putObject(key: testKey, data: testData)

        // Download test
        let downloadedData = try await s3Service.getObject(key: testKey)

        // Cleanup
        try await s3Service.deleteObject(key: testKey)

        let success = downloadedData == testData

        return TestResult(
            success: success,
            message: success ? "Upload/Download successful" : "Data mismatch",
            duration: Date().timeIntervalSince(start)
        )
    } catch {
        return TestResult(
            success: false,
            message: error.localizedDescription,
            duration: Date().timeIntervalSince(start)
        )
    }
}

// MARK: - Authentication Tests

func testAppleSignIn() async -> TestResult {
    // This requires UI interaction
    // In a real test, you'd present the sign-in flow

    return TestResult(
        success: false,
        message: "Requires manual UI interaction",
        duration: 0
    )
}

func testKeychainAccess() async -> TestResult {
    let start = Date()

    // Test keychain read/write
    let testKey = "test_credential"
    let testValue = "test_value_\(UUID().uuidString)"

    // Write to keychain
    let writeQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: testKey,
        kSecValueData as String: testValue.data(using: .utf8)!
    ]

    SecItemDelete(writeQuery as CFDictionary) // Clear any existing
    let writeStatus = SecItemAdd(writeQuery as CFDictionary, nil)

    // Read from keychain
    let readQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: testKey,
        kSecReturnData as String: true
    ]

    var result: AnyObject?
    let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &result)

    // Cleanup
    SecItemDelete(writeQuery as CFDictionary)

    let success = writeStatus == errSecSuccess && readStatus == errSecSuccess

    return TestResult(
        success: success,
        message: success ? "Keychain access working" : "Keychain access failed",
        duration: Date().timeIntervalSince(start)
    )
}

// MARK: - Photos Library Test

func testPhotosLibraryAccess() async -> TestResult {
    let start = Date()

    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    switch status {
    case .authorized, .limited:
        // Try to fetch photos
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 10
        let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        return TestResult(
            success: true,
            message: "Access granted. Found \(results.count) photos",
            duration: Date().timeIntervalSince(start)
        )

    case .denied, .restricted:
        return TestResult(
            success: false,
            message: "Photos access denied",
            duration: Date().timeIntervalSince(start)
        )

    case .notDetermined:
        // Request permission
        let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized

        return TestResult(
            success: granted,
            message: granted ? "Permission granted" : "Permission denied",
            duration: Date().timeIntervalSince(start)
        )

    @unknown default:
        return TestResult(
            success: false,
            message: "Unknown authorization status",
            duration: Date().timeIntervalSince(start)
        )
    }
}
```

### Step 6: Add Test Data Bundle

Create a separate bundle for test images and data:

1. Add "TestData" folder to project
2. Include sample images (various formats)
3. Include test JSON files
4. Mark as resources for test target only

### Step 7: Environment Configuration for Tests

```swift
// EnvironmentHelper+Tests.swift
extension EnvironmentHelper {
    static var isTestTarget: Bool {
        #if TESTING
        return true
        #else
        return Bundle.main.bundleIdentifier?.contains(".tests") == true
        #endif
    }

    static var testBucket: String {
        return "photolala-dev"  // Always use dev for tests
    }

    static func configureForTesting() {
        UserDefaults.standard.set("development", forKey: "environment_preference")
        UserDefaults.standard.set(true, forKey: "test_mode_enabled")

        // Clear any cached credentials
        CredentialManager.clearCache()

        // Set test-specific flags
        UserDefaults.standard.set(true, forKey: "skip_analytics")
        UserDefaults.standard.set(true, forKey: "verbose_logging")
    }
}
```

## Summary

With this test target setup, you can:

### ✅ CAN Test:
1. **Sandbox file operations** - Full access to app sandbox
2. **AWS S3 operations** - Using dev bucket with real credentials
3. **Lambda invocations** - Using dev endpoints
4. **Athena queries** - Using dev database
5. **SQLite operations** - Local database in sandbox
6. **Image processing** - Using test images
7. **Keychain access** - Limited but functional
8. **UserDefaults** - Full access
9. **Network requests** - Real network calls

### ⚠️ LIMITED Testing:
1. **Photos Library** - Requires permission, simulator has limited photos
2. **Apple/Google Sign-In** - Can show UI but needs manual interaction
3. **Push notifications** - Can register but won't receive
4. **Camera** - Simulator has no camera

### ❌ CANNOT Test:
1. **Files outside sandbox** - iOS restriction
2. **Biometric authentication** - Simulator limitation
3. **External volumes** - iOS doesn't support
4. **Real device features** - Accelerometer, GPS accuracy, etc.

The test target gives you a real app environment for integration testing while keeping tests isolated from production data.