# S3 Backup Service API Design

## Service Protocol

```swift
protocol S3BackupService {
    // Service lifecycle
    func start() async throws
    func stop() async
    func pause()
    func resume()
    
    // Configuration
    func configure(provider: S3Provider) async throws
    func updateSettings(_ settings: BackupSettings) async
    
    // Backup operations
    func backupFolder(_ folder: URL) async throws
    func backupFiles(_ files: [URL]) async throws
    func cancelBackup(for files: [URL])
    
    // Status
    var status: BackupServiceStatus { get }
    var currentActivity: BackupActivity? { get }
    func statistics() async -> BackupStatistics
}
```

## Core Data Types

### Provider Configuration

```swift
struct S3Provider {
    enum ProviderType {
        case aws
        case backblaze
        case wasabi
        case minio
        case custom(endpoint: URL)
    }
    
    let id: UUID
    let name: String
    let type: ProviderType
    let credentials: S3Credentials
    let bucket: String
    let region: String?
    let storageClass: StorageClass?
    
    struct S3Credentials {
        let accessKeyId: String
        let secretAccessKey: String
        let sessionToken: String? // For temporary credentials
    }
    
    enum StorageClass: String {
        case standard = "STANDARD"
        case standardIA = "STANDARD_IA"
        case glacier = "GLACIER"
        case deepArchive = "DEEP_ARCHIVE"
    }
}
```

### Backup Settings

```swift
struct BackupSettings {
    // Folders
    var includedFolders: Set<URL>
    var excludedFolders: Set<URL>
    
    // File filters
    var excludePatterns: [String]
    var maxFileSize: Int64?
    var includeHiddenFiles: Bool
    
    // Schedule
    var backupMode: BackupMode
    var scheduleInterval: TimeInterval?
    
    // Performance
    var maxConcurrentUploads: Int
    var maxBandwidth: Int? // Bytes per second
    var chunkSize: Int // For multipart uploads
    
    // Behavior
    var deleteOrphanedFiles: Bool
    var preserveMetadata: Bool
    var clientSideEncryption: EncryptionSettings?
    
    enum BackupMode {
        case manual
        case automatic
        case scheduled
    }
    
    struct EncryptionSettings {
        let enabled: Bool
        let algorithm: String // "AES256-GCM"
        // Key derivation handled separately
    }
}
```

### Service Status

```swift
enum BackupServiceStatus {
    case idle
    case scanning
    case uploading(progress: UploadProgress)
    case paused
    case error(Error)
    
    struct UploadProgress {
        let totalFiles: Int
        let completedFiles: Int
        let totalBytes: Int64
        let uploadedBytes: Int64
        let currentFile: String?
        let uploadRate: Double // Bytes per second
        let estimatedTimeRemaining: TimeInterval?
    }
}

struct BackupActivity {
    let startTime: Date
    let filesProcessed: Int
    let bytesUploaded: Int64
    let errors: [BackupError]
    let currentOperations: [UploadOperation]
}

struct BackupStatistics {
    let totalFilesBackedUp: Int
    let totalSizeBackedUp: Int64
    let lastBackupDate: Date?
    let averageUploadSpeed: Double
    let successRate: Double
    let storageUsed: Int64
}
```

## Upload Management

```swift
protocol UploadQueueManager {
    func enqueue(_ items: [BackupItem]) async
    func dequeue(count: Int) async -> [BackupItem]
    func prioritize(_ items: [BackupItem]) async
    func remove(_ items: [BackupItem]) async
    func clear() async
    var pendingCount: Int { get async }
}

struct BackupItem {
    let id: UUID
    let localURL: URL
    let remoteKey: String
    let size: Int64
    let metadata: PhotoMetadata?
    let priority: Int
    let retryCount: Int
    let lastError: Error?
    
    struct PhotoMetadata {
        let creationDate: Date?
        let modificationDate: Date
        let cameraInfo: CameraInfo?
        let location: Location?
        let tags: [String]
        let customMetadata: [String: String]
    }
}
```

## S3 Client Protocol

```swift
protocol S3Client {
    // Bucket operations
    func listBuckets() async throws -> [S3Bucket]
    func createBucket(name: String, region: String?) async throws
    func bucketExists(name: String) async throws -> Bool
    
    // Object operations
    func uploadFile(_ file: URL, to key: String, metadata: [String: String]?) async throws -> S3Object
    func uploadData(_ data: Data, to key: String, metadata: [String: String]?) async throws -> S3Object
    func initiateMultipartUpload(for key: String) async throws -> String // uploadId
    func uploadPart(data: Data, key: String, uploadId: String, partNumber: Int) async throws -> S3Part
    func completeMultipartUpload(key: String, uploadId: String, parts: [S3Part]) async throws -> S3Object
    func abortMultipartUpload(key: String, uploadId: String) async throws
    
    func objectExists(key: String) async throws -> Bool
    func getObjectMetadata(key: String) async throws -> S3ObjectMetadata
    func listObjects(prefix: String?, maxKeys: Int?) async throws -> S3ListResult
    func deleteObject(key: String) async throws
    
    // Download (future)
    func downloadObject(key: String, to url: URL) async throws
    func getObject(key: String) async throws -> Data
}

struct S3Bucket {
    let name: String
    let creationDate: Date
    let region: String?
}

struct S3Object {
    let key: String
    let etag: String
    let size: Int64
    let lastModified: Date
    let storageClass: String?
}

struct S3Part {
    let partNumber: Int
    let etag: String
}
```

## Event System

```swift
protocol BackupServiceDelegate: AnyObject {
    func backupService(_ service: S3BackupService, didChangeStatus status: BackupServiceStatus)
    func backupService(_ service: S3BackupService, didStartUpload item: BackupItem)
    func backupService(_ service: S3BackupService, didCompleteUpload item: BackupItem)
    func backupService(_ service: S3BackupService, didFailUpload item: BackupItem, error: Error)
    func backupService(_ service: S3BackupService, didUpdateProgress progress: UploadProgress)
}

// Alternative: Combine publishers
extension S3BackupService {
    var statusPublisher: AnyPublisher<BackupServiceStatus, Never> { get }
    var progressPublisher: AnyPublisher<UploadProgress, Never> { get }
    var eventsPublisher: AnyPublisher<BackupEvent, Never> { get }
}

enum BackupEvent {
    case uploadStarted(BackupItem)
    case uploadCompleted(BackupItem)
    case uploadFailed(BackupItem, Error)
    case scanStarted(URL)
    case scanCompleted(URL, fileCount: Int)
    case queueUpdated(pendingCount: Int)
}
```

## Error Handling

```swift
enum BackupError: Error {
    case providerNotConfigured
    case authenticationFailed(underlying: Error)
    case networkError(underlying: Error)
    case quotaExceeded(limit: Int64)
    case fileTooLarge(size: Int64, limit: Int64)
    case checksumMismatch(expected: String, actual: String)
    case uploadFailed(key: String, underlying: Error)
    case scanFailed(path: URL, underlying: Error)
    
    var isRecoverable: Bool { get }
    var userMessage: String { get }
    var technicalDetails: String { get }
}
```

## Manager Interface

```swift
class S3BackupManager {
    static let shared = S3BackupManager()
    
    // Service management
    func service(for provider: S3Provider) -> S3BackupService
    func removeService(for provider: S3Provider)
    var activeServices: [S3BackupService] { get }
    
    // Global operations
    func pauseAll()
    func resumeAll()
    func stopAll() async
    
    // Monitoring
    func combinedStatistics() async -> BackupStatistics
    func exportLogs(to url: URL) async throws
}
```

## Usage Examples

### Initial Setup
```swift
// Configure provider
let provider = S3Provider(
    id: UUID(),
    name: "My Backblaze Account",
    type: .backblaze,
    credentials: .init(
        accessKeyId: "key",
        secretAccessKey: "secret",
        sessionToken: nil
    ),
    bucket: "my-photos",
    region: "us-west-002",
    storageClass: .standard
)

// Create service
let service = S3BackupManager.shared.service(for: provider)

// Configure settings
let settings = BackupSettings(
    includedFolders: [photosFolder],
    excludedFolders: [],
    excludePatterns: ["*.tmp", ".*"],
    maxFileSize: 5_000_000_000, // 5GB
    includeHiddenFiles: false,
    backupMode: .automatic,
    scheduleInterval: nil,
    maxConcurrentUploads: 3,
    maxBandwidth: 10_000_000, // 10MB/s
    chunkSize: 10_000_000, // 10MB chunks
    deleteOrphanedFiles: false,
    preserveMetadata: true,
    clientSideEncryption: nil
)

await service.updateSettings(settings)

// Start backup
try await service.start()
```

### Monitoring Progress
```swift
// Subscribe to updates
service.progressPublisher
    .sink { progress in
        print("Uploaded \(progress.completedFiles) of \(progress.totalFiles)")
        print("Speed: \(progress.uploadRate / 1_000_000) MB/s")
    }
    .store(in: &cancellables)

// Check status
switch service.status {
case .uploading(let progress):
    showProgress(progress)
case .error(let error):
    showError(error)
default:
    break
}
```

### Manual Backup
```swift
// Backup specific files
let photos = selectedPhotos.map { $0.fileURL }
try await service.backupFiles(photos)

// Backup new folder
try await service.backupFolder(newFolder)
```