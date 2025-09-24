# Cloud S3 Browser Implementation Plan

## Overview
Implement a cloud photo browser that integrates with AWS S3 for browsing photos stored in the Photolala cloud. This includes authentication flow, S3 integration, and seamless switching between local and cloud photo sources.

## Phase 1: Authentication & Account Management (Week 1)

### 1.1 Sign-In Flow Integration
- **Goal**: Seamless authentication flow for cloud access
- **Components**:
  - Sign-in button/state in HomeView
  - Account status indicator in navigation bar
  - Sign-in sheet/modal presentation
  - Sign-out confirmation dialog

### 1.2 Authentication State Management
- **Current State**: AccountManager handles Google/Apple Sign-In
- **Enhancements Needed**:
  - Add sign-in status to PhotoBrowserEnvironment
  - Create CloudAuthenticationView for sign-in UI
  - Handle authentication errors gracefully
  - Persist authentication state across app launches

### 1.3 Credential Management
- **STS Credentials Flow**:
  ```
  User Sign-In → ID Token → Lambda Exchange → STS Credentials → SigV4 Signing → S3 Access
  ```
- **Implementation**:
  - Automatic credential refresh before expiration
  - Secure credential storage in Keychain
  - Credential validation before S3 operations
  - **AWS SigV4 Request Signing**:
    - S3Service internally uses AWSClientRuntime for automatic SigV4 signing
    - AccountManager provides credentials via getSTSCredentials()
    - S3Service configures AWS SDK client with temporary credentials:
      ```swift
      let config = try await S3Client.S3ClientConfiguration(
          region: environment.region,
          credentialsProvider: AWSCredentialsProvider.fromClosure {
              try await accountManager.getSTSCredentials()
          }
      )
      ```
    - All S3 API calls automatically include SigV4 headers

## Phase 2: Cloud Photo Source Implementation (Week 1-2)

### 2.1 S3PhotoSource Class
```swift
import Combine
import Foundation

@MainActor
class S3PhotoSource: PhotoSourceProtocol {
    // Properties
    private let s3Service: S3Service
    private let cloudBrowsingService: S3CloudBrowsingService
    private let accountManager: AccountManager
    private let photosSubject = PassthroughSubject<[PhotoBrowserItem], Never>()
    private let isLoadingSubject = PassthroughSubject<Bool, Never>()
    private var authStateSubscription: AnyCancellable?

    // Cache and state
    private var catalogDatabase: SQLiteDatabase? // From S3CloudBrowsingService.loadCloudCatalog()
    private var thumbnailCache: [String: PlatformImage] = [:] // In-memory LRU cache
    private var currentUserID: String? {
        // Returns nil if not signed in, forcing proper error handling
        guard let user = accountManager.getCurrentUser() else { return nil }
        return user.email ?? user.id.uuidString
    }

    // Authentication state for cloud access
    @Published private(set) var authenticationState: PhotoBrowserEnvironment.AuthenticationState = .notSignedIn

    init(s3Service: S3Service,
         cloudBrowsingService: S3CloudBrowsingService,
         accountManager: AccountManager) {
        self.s3Service = s3Service
        self.cloudBrowsingService = cloudBrowsingService
        self.accountManager = accountManager

        // Set initial auth state
        updateAuthenticationState()

        // Subscribe to AccountManager changes
        authStateSubscription = accountManager.$isSignedIn
            .sink { [weak self] _ in
                self?.updateAuthenticationState()
            }
    }

    // Required Protocol Methods (PhotoSourceProtocol)
    func loadPhotos() async throws -> [PhotoBrowserItem] {
        isLoadingSubject.send(true)  // Start loading spinner
        defer { isLoadingSubject.send(false) }  // Stop spinner

        guard let userID = currentUserID else {
            throw PhotoSourceError.notAuthorized
        }

        do {
            // Load cloud catalog database
            catalogDatabase = try await cloudBrowsingService.loadCloudCatalog(userID: userID)

            // TODO: Query catalog database for photos
            // let photos = try catalogDatabase.queryPhotos()
            let photos: [PhotoBrowserItem] = [] // Stub until catalog query implemented

            photosSubject.send(photos)  // Update UI via publisher
            return photos
        } catch {
            photosSubject.send([])  // Clear on error
            throw error
        }
    }

    func loadMetadata(for itemId: String) async throws -> PhotoBrowserMetadata {
        // TODO: Query catalog database for photo metadata
        guard let catalog = catalogDatabase else {
            throw PhotoSourceError.itemNotFound
        }

        // Stub implementation - will query catalog for actual metadata
        return PhotoBrowserMetadata(
            fileSize: nil,
            creationDate: nil,
            modificationDate: nil,
            width: nil,
            height: nil,
            mimeType: nil
        )
    }

    func loadThumbnail(for itemId: String) async throws -> PlatformImage? {
        // Check cache first
        if let cached = thumbnailCache[itemId] {
            return cached
        }

        guard let userID = currentUserID else {
            throw PhotoSourceError.notAuthorized
        }

        // Load from S3 via cloudBrowsingService
        guard let data = await cloudBrowsingService.loadThumbnail(
            photoMD5: itemId,
            userID: userID
        ) else {
            return nil
        }

        // Convert and cache
        let image = PlatformImage(data: data)
        thumbnailCache[itemId] = image
        return image
    }

    func loadFullImage(for itemId: String) async throws -> Data {
        guard let userID = currentUserID else {
            throw PhotoSourceError.notAuthorized
        }

        // Use S3Service directly for full-size images
        return try await s3Service.downloadPhoto(
            md5: itemId,
            userID: userID
        )
    }

    // Required Protocol Publishers
    var photosPublisher: AnyPublisher<[PhotoBrowserItem], Never> {
        photosSubject.eraseToAnyPublisher()
    }
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    var capabilities: PhotoSourceCapabilities {
        .readOnly // Cloud is read-only for MVP
    }

    // Cloud-Specific Methods
    func downloadForOfflineViewing(ids: [String]) async throws
    func syncWithCloud() async throws

    // Update auth state based on AccountManager (MainActor context)
    private func updateAuthenticationState() {
        if let user = accountManager.getCurrentUser() {
            authenticationState = .signedIn(user: user)
        } else {
            authenticationState = .notSignedIn
        }
    }
}
```

### 2.2 Cloud Catalog Integration
- **Catalog Loading**:
  - Download catalog pointer from S3
  - Fetch catalog CSV/SQLite database
  - Parse and cache catalog locally
  - Handle catalog versioning

- **Photo Metadata Structure**:
  - Photo ID (MD5 hash)
  - File path in S3
  - Thumbnail S3 path
  - File size, dimensions
  - Creation/modification dates
  - EXIF data

### 2.3 Progressive Loading Strategy
1. **Initial Load**: Show loading state
2. **Catalog Fetch**: Download and parse catalog
3. **Thumbnail Grid**: Display placeholders
4. **Progressive Thumbnails**: Load visible thumbnails first
5. **Background Prefetch**: Preload adjacent thumbnails
6. **Full Image**: Load on-demand when selected

## Phase 3: UI/UX Implementation (Week 2)

### 3.1 Source Selector UI
- **Navigation Bar Enhancement**:
  ```
  [Local ▼] | S|M|L | [🔲/🔳] | [☐] | [Cloud Status]
  ```
- **Source Menu**:
  - Local Photos
  - Apple Photos
  - Cloud Photos (requires sign-in)
  - Recent Downloads

### 3.2 Cloud-Specific UI States
- **Not Signed In**:
  - Empty state with sign-in prompt
  - "Sign in to access your cloud photos"
  - Sign-in button

- **Loading**:
  - Skeleton grid while fetching catalog
  - Progress indicator for catalog download
  - "Loading X photos from cloud..."

- **Error States**:
  - Network connection issues
  - Authentication expired
  - S3 access errors
  - Retry mechanisms

### 3.3 Cloud Browser Features (Phase 2 - Enhanced)
- **Smart Caching**:
  - LRU cache for thumbnails
  - Disk cache for recent full images
  - Cache size management

- **Network Awareness**:
  - Pause downloads on poor connection
  - Resume capability
  - Bandwidth optimization

### 3.4 Advanced Actions (Phase 3 - Future)
- **Selection & Actions**:
  - Multi-select for batch download
  - Share from cloud
  - Save to local photos
  - NOTE: These are Phase 3 deliverables, not MVP

## Phase 4: Integration & Polish (Week 2-3)

### 4.1 Environment Integration
```swift
// Extend existing PhotoBrowserEnvironment without breaking changes
extension PhotoBrowserEnvironment {
    // Nested enum to avoid namespace collisions
    enum AuthenticationState {
        case notApplicable  // For local/Apple Photos sources
        case notSignedIn
        case signedIn(user: PhotolalaUser)
        case refreshingCredentials
    }

    // Add computed property for auth state
    var authenticationState: AuthenticationState {
        // Check if source is S3PhotoSource and get its auth state
        if let cloudSource = source as? S3PhotoSource {
            return cloudSource.authenticationState
        }
        return .notApplicable
    }
}
```

### 4.2 Source Switching Logic
- **Seamless Transitions**:
  - Preserve selection when possible
  - Clear cache on source change
  - Update toolbar state
  - Refresh collection view

### 4.3 Performance Optimizations
- **Thumbnail Loading**:
  - Concurrent download limits (max 3-5)
  - Request coalescing
  - Priority queue for visible items
  - Cancel off-screen requests

- **Memory Management**:
  - Image downsampling
  - Memory warnings handling
  - Aggressive cache pruning

## Phase 5: Advanced Features (Week 3+)

### 5.1 Offline Support
- **Download Management**:
  - Queue for offline download
  - Progress tracking
  - Background downloads
  - Storage management

### 5.2 Sync Capabilities
- **Two-Way Sync**:
  - Upload local changes
  - Download cloud updates
  - Conflict resolution
  - Delta sync

### 5.3 Search & Filter
- **Cloud Search**:
  - Search by filename
  - Date range filters
  - Size filters
  - Tag/album support

## Technical Architecture

### Data Flow
```
User Action → PhotoBrowserView → PhotoBrowserEnvironment → S3PhotoSource
                                                         ↓
                                                   AccountManager
                                                         ↓
                                                    S3Service
                                                         ↓
                                                      AWS S3
```

### Key Classes & Responsibilities

1. **S3PhotoSource**: Implements PhotoSourceProtocol for cloud photos
2. **CloudAuthenticationView**: Handles sign-in UI/UX
3. **S3CloudBrowsingService**: Manages cloud catalog and caching
4. **S3Service**: Low-level S3 operations
5. **AccountManager**: Authentication and credential management
6. **CacheManager**: Local caching for cloud assets

## Implementation Priority

### Phase 1: MVP (Must Have) - Read-Only Cloud Browsing
1. 🟡 Basic authentication flow (AccountManager exists, needs CloudAuthenticationView)
2. 🟡 S3PhotoSource implementation (skeleton created, needs catalog integration)
3. ⬜ Catalog download and parsing
4. ⬜ Thumbnail loading from S3
5. ⬜ Basic error handling
6. 🟡 Source switching UI (UI done, needs S3 integration)

### Phase 2: Enhanced (Should Have) - Performance & UX
1. ⬜ Progressive thumbnail loading
2. ⬜ Smart LRU caching
3. ⬜ Network awareness & retry logic
4. ⬜ Loading states & skeletons

### Phase 3: Future (Nice to Have) - Advanced Features
1. ⬜ Multi-select batch operations
2. ⬜ Download for offline viewing
3. ⬜ Share from cloud
4. ⬜ Save to local photos
5. ⬜ Two-way sync
6. ⬜ Advanced search & filters
7. ⬜ Album organization

## Testing Strategy

### Unit Tests
- S3PhotoSource methods
- Catalog parsing
- Cache management
- Authentication flow

### Integration Tests
- End-to-end sign-in flow
- S3 download operations
- Source switching
- Error scenarios

### Performance Tests
- Thumbnail loading speed
- Memory usage
- Cache effectiveness
- Network efficiency

## Security Considerations

1. **Credential Security**:
   - Never store AWS credentials in code
   - Use STS temporary credentials
   - Implement credential rotation
   - Secure Keychain storage

2. **Data Protection**:
   - Encrypt cache on disk
   - Clear sensitive data on sign-out
   - Implement proper session management
   - Handle authentication timeouts

3. **Network Security**:
   - Use HTTPS for all requests
   - Validate SSL certificates
   - Implement request signing
   - Handle man-in-the-middle protection

## Success Metrics

1. **Performance**:
   - Catalog load < 2 seconds
   - Thumbnail display < 1 second
   - Full image load < 3 seconds
   - Memory usage < 200MB

2. **Reliability**:
   - 99.9% crash-free sessions
   - Graceful offline handling
   - Automatic retry on failure
   - Proper error messaging

3. **User Experience**:
   - Seamless source switching
   - Responsive scrolling
   - Clear loading states
   - Intuitive authentication

## Next Steps

1. **Immediate Actions**:
   - Create CloudAuthenticationView
   - Implement S3PhotoSource skeleton
   - Add source selector to navigation
   - Set up test S3 bucket

2. **Week 1 Goals**:
   - Complete authentication flow
   - Basic S3PhotoSource working
   - Catalog download functional
   - Initial UI integration

3. **Week 2 Goals**:
   - Progressive loading working
   - Caching implemented
   - Error handling complete
   - Performance optimization

## Notes & Considerations

- **Existing Infrastructure**: Leverage existing S3Service and S3CloudBrowsingService
- **Code Reuse**: Extend PhotoSourceProtocol pattern from LocalPhotoSource
- **Platform Parity**: Ensure feature works on both macOS and iOS
- **User Privacy**: Respect user's photo privacy settings and permissions
- **Cost Management**: Implement smart caching to minimize S3 transfer costs