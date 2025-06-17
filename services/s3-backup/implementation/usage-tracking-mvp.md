# Usage Tracking MVP Implementation

## Simplified Approach for Initial Release

Instead of building a full backend service immediately, we'll use AWS SDK for Swift directly from the iOS app to calculate usage. This eliminates the need for Lambda functions or any backend infrastructure.

## Phase 1: Client-Side Usage Tracking (MVP)

### Implementation Strategy

1. **Local Usage Calculation**
   - Calculate usage from S3 ListObjects API
   - Cache results locally with timestamp
   - Refresh every 24 hours or on-demand

2. **Soft Limits**
   - Warn users at 80% and 95% of limit
   - Allow slight overages (10% buffer)
   - No hard blocking initially

3. **Simple Storage**
   - Store usage in UserDefaults/Keychain
   - Sync across devices via iCloud (optional)

### Swift Implementation

```swift
// Models/StorageUsage.swift
struct StorageUsage: Codable {
    let totalBytes: Int64
    let standardBytes: Int64
    let deepArchiveBytes: Int64
    let fileCount: Int
    let lastUpdated: Date
    
    var totalGB: Double {
        Double(totalBytes) / 1_000_000_000
    }
    
    var percentageUsed: Double {
        guard let limit = SubscriptionManager.shared.currentStorageLimit else { return 0 }
        return Double(totalBytes) / Double(limit) * 100
    }
}

// Services/UsageTrackingService.swift
class UsageTrackingService {
    static let shared = UsageTrackingService()
    
    private let cacheKey = "com.photolala.usage.cache"
    private let cacheExpiration: TimeInterval = 86400 // 24 hours
    
    @Published var currentUsage: StorageUsage?
    @Published var isCalculating = false
    
    func checkUsage(forceRefresh: Bool = false) async throws -> StorageUsage {
        // Check cache first
        if !forceRefresh, let cached = getCachedUsage() {
            currentUsage = cached
            return cached
        }
        
        // Calculate from S3
        isCalculating = true
        defer { isCalculating = false }
        
        let usage = try await calculateUsageFromS3()
        cacheUsage(usage)
        currentUsage = usage
        
        return usage
    }
    
    private func calculateUsageFromS3() async throws -> StorageUsage {
        let s3 = S3BackupManager.shared
        var totalBytes: Int64 = 0
        var standardBytes: Int64 = 0
        var deepArchiveBytes: Int64 = 0
        var fileCount = 0
        
        // List all objects for current user
        let prefix = "users/\(s3.currentUserId)/photos/"
        
        var continuationToken: String?
        repeat {
            let response = try await s3.s3Client.listObjectsV2(
                bucket: s3.bucketName,
                prefix: prefix,
                continuationToken: continuationToken
            )
            
            for object in response.contents ?? [] {
                fileCount += 1
                let size = object.size ?? 0
                totalBytes += size
                
                if object.storageClass == .deepArchive {
                    deepArchiveBytes += size
                } else {
                    standardBytes += size
                }
            }
            
            continuationToken = response.nextContinuationToken
        } while continuationToken != nil
        
        return StorageUsage(
            totalBytes: totalBytes,
            standardBytes: standardBytes,
            deepArchiveBytes: deepArchiveBytes,
            fileCount: fileCount,
            lastUpdated: Date()
        )
    }
    
    func canUploadFile(sizeBytes: Int64) async -> (allowed: Bool, message: String?) {
        do {
            let usage = try await checkUsage()
            let limit = SubscriptionManager.shared.currentStorageLimit ?? 0
            let projectedUsage = usage.totalBytes + sizeBytes
            
            if projectedUsage > limit {
                let overagePercent = Double(projectedUsage - limit) / Double(limit) * 100
                
                if overagePercent <= 10 {
                    // Allow with warning
                    return (true, "Warning: This upload will exceed your storage limit.")
                } else {
                    // Block upload
                    return (false, "Storage limit exceeded. Please upgrade your plan or delete some photos.")
                }
            }
            
            // Check warning thresholds
            let usagePercent = Double(projectedUsage) / Double(limit) * 100
            if usagePercent >= 95 {
                return (true, "You're at \(Int(usagePercent))% of your storage limit.")
            } else if usagePercent >= 80 {
                return (true, "You're approaching your storage limit (\(Int(usagePercent))%).")
            }
            
            return (true, nil)
        } catch {
            // If we can't check usage, allow upload but log error
            print("Failed to check usage: \(error)")
            return (true, nil)
        }
    }
}

// Views/StorageUsageView.swift
struct StorageUsageView: View {
    @StateObject private var usageService = UsageTrackingService.shared
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let usage = usageService.currentUsage {
                // Usage summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Storage Usage")
                        .font(.headline)
                    
                    ProgressView(value: usage.percentageUsed, total: 100)
                        .tint(progressColor(for: usage.percentageUsed))
                    
                    HStack {
                        Text("\(usage.totalGB, specifier: "%.1f") GB used")
                        Spacer()
                        if let limit = SubscriptionManager.shared.currentStorageLimit {
                            Text("of \(Double(limit) / 1_000_000_000, specifier: "%.0f") GB")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // Breakdown
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(usage.fileCount) photos", systemImage: "photo")
                    Label("Standard: \(formatBytes(usage.standardBytes))", systemImage: "internaldrive")
                    Label("Archive: \(formatBytes(usage.deepArchiveBytes))", systemImage: "archivebox")
                }
                .font(.footnote)
                
                // Last updated
                Text("Updated \(usage.lastUpdated, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else if usageService.isCalculating {
                ProgressView("Calculating usage...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Button("Calculate Usage") {
                    Task {
                        try? await usageService.checkUsage(forceRefresh: true)
                    }
                }
            }
            
            // Refresh button
            Button(action: refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)
        }
        .padding()
        .task {
            try? await usageService.checkUsage()
        }
    }
    
    private func refresh() {
        Task {
            isRefreshing = true
            try? await usageService.checkUsage(forceRefresh: true)
            isRefreshing = false
        }
    }
    
    private func progressColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<80: return .green
        case 80..<95: return .orange
        default: return .red
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
```

## Phase 2: Upload Integration

```swift
// In S3BackupManager
func uploadPhoto(_ photo: PhotoReference) async throws {
    // Check usage before upload
    let fileSize = try await getFileSize(for: photo)
    let (allowed, message) = await UsageTrackingService.shared.canUploadFile(sizeBytes: fileSize)
    
    if !allowed {
        throw S3BackupError.storageLimitExceeded(message ?? "Storage limit exceeded")
    }
    
    // Show warning if needed
    if let message = message {
        await MainActor.run {
            // Show alert or notification
            NotificationCenter.default.post(
                name: .storageWarning,
                object: nil,
                userInfo: ["message": message]
            )
        }
    }
    
    // Proceed with upload
    try await performUpload(photo)
    
    // Refresh usage after upload (in background)
    Task {
        try? await UsageTrackingService.shared.checkUsage(forceRefresh: true)
    }
}
```

## Why No Lambda Required

For the MVP, we don't need Lambda or any backend services because:

1. **S3 ListObjectsV2 API** - The AWS SDK for Swift can call this directly
2. **STS Credentials** - We already have temporary credentials from Sign in with Apple
3. **Simple Calculation** - Just summing file sizes, no complex processing
4. **Caching** - Local caching on device is sufficient for MVP
5. **No Real-time Sync** - Initial version doesn't need instant multi-device sync

## Phase 3: Future Backend Integration (Optional)

When ready to move to server-side tracking:

1. **Add API Endpoints**
   - Replace `calculateUsageFromS3()` with API call
   - Server calculates and caches usage
   - More efficient and accurate

2. **Real-time Updates**
   - WebSocket or push notifications for usage updates
   - Sync across devices instantly
   - Admin ability to adjust limits

3. **Enhanced Features**
   - Usage history and trends
   - Predictive warnings
   - Automated archiving suggestions

## Benefits of This Approach

1. **Quick to Implement**: Can ship with initial release
2. **No Backend Required**: No Lambda, DynamoDB, or API Gateway needed
3. **Direct S3 Access**: Uses existing S3 client with STS credentials
4. **User Privacy**: Usage data stays on device
5. **Progressive Enhancement**: Easy to add backend later
6. **Cost Effective**: No server costs, only S3 API calls
7. **Same Security Model**: Uses the same STS authentication as uploads

## Implementation Steps

1. Add `StorageUsage` model
2. Create `UsageTrackingService`
3. Integrate with `S3BackupManager`
4. Add `StorageUsageView` to subscription UI
5. Test with various usage scenarios
6. Add proper error handling
7. Optimize S3 list performance (pagination, caching)

This MVP approach gives us usage tracking functionality without the complexity of a full backend service, and can be enhanced later as needed.