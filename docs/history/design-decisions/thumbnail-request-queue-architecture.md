# Thumbnail Request Queue Architecture

## Problem Statement

When ThumbnailService receives 100K+ requests:
- Views may close before thumbnails are generated
- Network drives may disconnect during processing
- Resources are wasted generating thumbnails nobody will see
- No cancellation mechanism for obsolete requests

## Proposed Architecture

### 1. Request Queue with Cancellation

```swift
actor ThumbnailRequestQueue {
	struct Request: Identifiable {
		let id = UUID()
		let photoID: UniversalPhotoIdentifier
		let priority: LoadingPriority
		let continuation: CheckedContinuation<XImage?, Error>?
		weak var observer: ThumbnailObserver?
	}
	
	private var queue: [Request] = []
	private var processing = Set<UniversalPhotoIdentifier>()
	private let maxConcurrent = 4
	
	func enqueue(
		photoID: UniversalPhotoIdentifier,
		priority: LoadingPriority,
		observer: ThumbnailObserver
	) async -> XImage? {
		// Check if already processing
		if processing.contains(photoID) {
			// Wait for existing request
			return await waitForExisting(photoID)
		}
		
		// Add to queue
		return await withCheckedContinuation { continuation in
			let request = Request(
				photoID: photoID,
				priority: priority,
				continuation: continuation,
				observer: observer
			)
			queue.append(request)
			queue.sort { $0.priority.rawValue > $1.priority.rawValue }
			
			Task {
				await processNext()
			}
		}
	}
	
	private func processNext() async {
		guard processing.count < maxConcurrent else { return }
		
		// Find next valid request
		while let request = queue.first {
			queue.removeFirst()
			
			// Skip if observer is gone
			if request.observer == nil {
				request.continuation?.resume(returning: nil)
				continue
			}
			
			// Process this request
			processing.insert(request.photoID)
			
			Task {
				do {
					let thumbnail = try await generateThumbnail(request.photoID)
					request.continuation?.resume(returning: thumbnail)
					
					// Notify observer if still alive
					if let observer = request.observer {
						await observer.thumbnailReady(request.photoID, thumbnail)
					}
				} catch {
					request.continuation?.resume(throwing: error)
				}
				
				processing.remove(request.photoID)
				await processNext()
			}
			
			break
		}
	}
}
```

### 2. Weak Observer Pattern

```swift
protocol ThumbnailObserver: AnyObject {
	func thumbnailReady(_ photoID: UniversalPhotoIdentifier, _ image: XImage?) async
}

class PhotoGridViewModel: ObservableObject, ThumbnailObserver {
	@Published var thumbnails: [UniversalPhotoIdentifier: XImage] = [:]
	
	func loadThumbnail(for photo: PhotoReference) {
		guard let photoID = photo.universalPhotoID else { return }
		
		Task {
			// Request with self as weak observer
			let thumbnail = await ThumbnailService.shared.requestThumbnail(
				photoID: photoID,
				priority: .high,
				observer: self
			)
			
			// May be nil if we were deallocated
			if let thumbnail {
				await MainActor.run {
					thumbnails[photoID] = thumbnail
				}
			}
		}
	}
	
	func thumbnailReady(_ photoID: UniversalPhotoIdentifier, _ image: XImage?) async {
		await MainActor.run {
			thumbnails[photoID] = image
		}
	}
}
```

### 3. Error Handling for Network Drives

```swift
extension ThumbnailRequestQueue {
	private func generateThumbnail(_ photoID: UniversalPhotoIdentifier) async throws -> XImage? {
		do {
			// Check if file is still accessible
			guard let fileURL = await resolveFileURL(for: photoID) else {
				print("File not found for \(photoID)")
				return nil
			}
			
			// Check if file is reachable (handles network drives)
			guard fileURL.isFileReachable else {
				print("File not reachable: \(fileURL)")
				return nil
			}
			
			// Generate thumbnail
			return try await ImageProcessor.generateThumbnail(from: fileURL)
			
		} catch CocoaError.fileReadNoSuchFile {
			print("File disappeared: \(photoID)")
			return nil
		} catch CocoaError.fileReadUnknown {
			print("Network drive disconnected: \(photoID)")
			return nil
		} catch {
			// Log but don't crash
			print("Thumbnail generation failed: \(error)")
			return nil
		}
	}
}

extension URL {
	var isFileReachable: Bool {
		do {
			_ = try self.checkResourceIsReachable()
			return true
		} catch {
			return false
		}
	}
}
```

### 4. Batch Cancellation

```swift
extension ThumbnailRequestQueue {
	/// Cancel all requests from a specific observer
	func cancelRequests(from observer: ThumbnailObserver) async {
		queue.removeAll { request in
			if request.observer === observer {
				request.continuation?.resume(returning: nil)
				return true
			}
			return false
		}
	}
	
	/// Cancel requests for photos no longer visible
	func cancelInvisibleRequests(visiblePhotoIDs: Set<UniversalPhotoIdentifier>) async {
		queue.removeAll { request in
			if !visiblePhotoIDs.contains(request.photoID) {
				request.continuation?.resume(returning: nil)
				return true
			}
			return false
		}
	}
}
```

### 5. Integration with LoadingManager

```swift
actor ThumbnailService {
	private let requestQueue = ThumbnailRequestQueue()
	private let loadingManager = LoadingManager()
	
	func requestThumbnail(
		photoID: UniversalPhotoIdentifier,
		priority: LoadingPriority,
		observer: ThumbnailObserver
	) async -> XImage? {
		// Check cache first
		if let cached = getCachedThumbnail(for: photoID) {
			return cached
		}
		
		// Update loading priority
		await loadingManager.updatePriority(for: photoID, priority: priority)
		
		// Enqueue request
		return await requestQueue.enqueue(
			photoID: photoID,
			priority: priority,
			observer: observer
		)
	}
	
	func updateVisiblePhotos(_ photoIDs: Set<UniversalPhotoIdentifier>) async {
		// Cancel non-visible requests
		await requestQueue.cancelInvisibleRequests(visiblePhotoIDs: photoIDs)
		
		// Update priorities
		await loadingManager.updateVisibleItems(photoIDs)
	}
}
```

### 6. View Integration

```swift
struct PhotoGridView: View {
	@StateObject private var viewModel = PhotoGridViewModel()
	@State private var visiblePhotoIDs = Set<UniversalPhotoIdentifier>()
	
	var body: some View {
		ScrollView {
			LazyVGrid(columns: columns) {
				ForEach(photos) { photo in
					ThumbnailView(
						photo: photo,
						thumbnail: viewModel.thumbnails[photo.universalPhotoID]
					)
					.onAppear {
						visiblePhotoIDs.insert(photo.universalPhotoID)
						viewModel.loadThumbnail(for: photo)
					}
					.onDisappear {
						visiblePhotoIDs.remove(photo.universalPhotoID)
					}
				}
			}
		}
		.onDisappear {
			// Cancel all pending requests when view closes
			Task {
				await ThumbnailService.shared.cancelRequests(from: viewModel)
			}
		}
		.task {
			// Periodically update visible items
			for await _ in Timer.publish(every: 0.5, on: .main, in: .common).autoconnect().values {
				await ThumbnailService.shared.updateVisiblePhotos(visiblePhotoIDs)
			}
		}
	}
}
```

## Benefits

1. **Resource Efficiency**: Don't generate thumbnails for closed views
2. **Graceful Degradation**: Handle network disconnections without crashing
3. **Priority Management**: Process visible items first
4. **Memory Safety**: Weak references prevent retain cycles
5. **Cancellation Support**: Stop work when no longer needed

## Implementation Phases

### Phase 1: Basic Queue
- Implement ThumbnailRequestQueue
- Add observer pattern
- Basic error handling

### Phase 2: Optimization
- Add batch cancellation
- Integrate with LoadingManager
- Add visibility tracking

### Phase 3: Polish
- Add retry logic for transient failures
- Add telemetry for monitoring
- Optimize queue processing

## Key Design Decisions

1. **Weak Observer References**: Prevents memory leaks and auto-cancels when views deallocate
2. **Continuation-based API**: Allows proper async/await integration
3. **Silent Failure**: Network errors return nil instead of throwing
4. **Priority Queue**: Most important thumbnails generate first
5. **Concurrent Limit**: Prevents resource exhaustion

This architecture ensures efficient resource usage even with massive request volumes!