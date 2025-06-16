import SwiftUI
import PhotosUI

struct S3BackupTestView: View {
	@State private var selectedPhoto: PhotosPickerItem?
	@State private var uploadStatus = ""
	@State private var isUploading = false
	@State private var uploadedPhotos: [PhotoEntry] = []
	@State private var s3Service: S3BackupService?
	@State private var initError: String?
	@State private var credentialsInfo: String = ""
	
	private let testUserId = "test-user-123"
	
	var body: some View {
		VStack(spacing: 20) {
			Text("S3 Backup POC")
				.font(.largeTitle)
			
			// Credentials info section
			if !credentialsInfo.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					Text("AWS Credentials Check:")
						.font(.headline)
					
					#if os(macOS)
					Text(credentialsInfo)
						.textSelection(.enabled)
						.font(.system(.body, design: .monospaced))
						.padding(8)
						.background(Color.blue.opacity(0.1))
						.cornerRadius(4)
						.frame(maxWidth: .infinity, alignment: .leading)
					#else
					TextEditor(text: .constant(credentialsInfo))
						.font(.system(.body, design: .monospaced))
						.foregroundColor(.primary)
						.scrollDisabled(true)
						.padding(4)
						.background(Color.blue.opacity(0.1))
						.cornerRadius(4)
						.frame(minHeight: 60, maxHeight: 120)
					#endif
				}
				.padding()
			}
			
			if let error = initError {
				VStack(alignment: .leading, spacing: 8) {
					Text("Error:")
						.font(.headline)
						.foregroundColor(.red)
					
					// Selectable error text
					#if os(macOS)
					Text(error)
						.textSelection(.enabled)
						.font(.system(.body, design: .monospaced))
						.padding(8)
						.background(Color.gray.opacity(0.1))
						.cornerRadius(4)
						.frame(maxWidth: .infinity, alignment: .leading)
					#else
					TextEditor(text: .constant(error))
						.font(.system(.body, design: .monospaced))
						.foregroundColor(.primary)
						.scrollDisabled(true)
						.padding(4)
						.background(Color.gray.opacity(0.1))
						.cornerRadius(4)
						.frame(minHeight: 60, maxHeight: 120)
					#endif
				}
				.padding()
			}
			
			// Upload Section
			VStack {
				HStack(spacing: 20) {
					Button("Check AWS Credentials") {
						checkCredentials()
					}
					.buttonStyle(.bordered)
					
					PhotosPicker(selection: $selectedPhoto,
								matching: .images) {
						Label("Select Photo", systemImage: "photo")
							.frame(width: 200, height: 50)
							.background(Color.blue)
							.foregroundColor(.white)
							.cornerRadius(10)
					}
					.disabled(isUploading || s3Service == nil)
					.onChange(of: selectedPhoto) { oldValue, newValue in
						Task {
							await uploadPhoto()
						}
					}
				}
				
				if isUploading {
					ProgressView()
						.progressViewStyle(CircularProgressViewStyle())
				}
				
				Text(uploadStatus)
					.font(.caption)
					.foregroundColor(uploadStatus.contains("❌") ? .red : .secondary)
					#if os(macOS)
					.textSelection(.enabled)
					#endif
			}
			
			Divider()
			
			// List Uploaded Photos
			VStack(alignment: .leading) {
				HStack {
					Text("Uploaded Photos")
						.font(.headline)
					Spacer()
					Button("Refresh") {
						Task {
							await loadPhotos()
						}
					}
					.disabled(s3Service == nil)
				}
				
				List(uploadedPhotos, id: \.md5) { photo in
					VStack(alignment: .leading, spacing: 4) {
						Text("MD5: \(photo.md5)")
							.font(.caption.monospaced())
						HStack {
							Text("Size: \(formatBytes(photo.size))")
							Text("•")
							Text("Storage: \(photo.storageClass)")
							Text("•")
							Text(photo.lastModified, style: .relative)
						}
						.font(.caption2)
						.foregroundColor(.secondary)
					}
					.padding(.vertical, 4)
				}
				.frame(maxHeight: 300)
			}
			.padding()
			
			Spacer()
		}
		.padding()
		.frame(width: 600, height: 700)
		.task {
			await initializeService()
		}
	}
	
	private func uploadPhoto() async {
		guard let selectedPhoto,
			  let s3Service else { return }
		
		isUploading = true
		uploadStatus = "Loading photo..."
		
		do {
			// Load photo data
			guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
				uploadStatus = "Failed to load photo"
				isUploading = false
				return
			}
			
			uploadStatus = "Uploading to S3..."
			
			// Upload photo
			let md5 = try await s3Service.uploadPhoto(data: data, userId: testUserId)
			
			// Create thumbnail (simplified for POC)
			let thumbnailData = data // In real app, would resize
			try await s3Service.uploadThumbnail(data: thumbnailData, md5: md5, userId: testUserId)
			
			uploadStatus = "✅ Uploaded: \(md5)"
			
			// Refresh list
			await loadPhotos()
			
		} catch {
			uploadStatus = "❌ Error: \(error.localizedDescription)"
		}
		
		isUploading = false
	}
	
	private func loadPhotos() async {
		guard let s3Service else { return }
		
		do {
			uploadedPhotos = try await s3Service.listUserPhotos(userId: testUserId)
		} catch {
			print("Failed to load photos: \(error)")
			uploadStatus = "Failed to load photos: \(error.localizedDescription)"
		}
	}
	
	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
	
	private func initializeService() async {
		do {
			s3Service = try await S3BackupService()
			uploadStatus = "Ready to upload"
			await loadPhotos()
		} catch {
			initError = "Failed to initialize: \(error.localizedDescription)\n\nMake sure your AWS credentials are configured in ~/.aws/credentials"
		}
	}
	
	private func checkCredentials() {
		let fileManager = FileManager.default
		let homeDirectory = fileManager.homeDirectoryForCurrentUser
		let containerCredentialsPath = homeDirectory.appendingPathComponent(".aws/credentials").path
		let systemCredentialsPath = NSString(string: "~/.aws/credentials").expandingTildeInPath
		
		var info = "Checking AWS credentials...\n\n"
		
		// Check environment variables first
		if let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
		   let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] {
			info += "✅ Found AWS_ACCESS_KEY_ID in environment\n"
			info += "✅ Found AWS_SECRET_ACCESS_KEY in environment\n\n"
			info += "Environment variables are set correctly!\n"
		} else {
			info += "❌ No AWS environment variables found\n\n"
		}
		
		// Check container directory (sandboxed location)
		info += "📱 App Container Path:\n\(containerCredentialsPath)\n\n"
		
		if fileManager.fileExists(atPath: containerCredentialsPath) {
			info += "✅ Credentials file exists in app container\n"
			// Try to parse it
			if let credentialsData = try? String(contentsOfFile: containerCredentialsPath) {
				let lines = credentialsData.components(separatedBy: .newlines)
				info += "📄 File contains \(lines.count) lines\n"
			}
		} else {
			info += "❌ No credentials file in app container\n"
		}
		
		info += "\n"
		
		// Check system location
		info += "💻 System Path:\n\(systemCredentialsPath)\n\n"
		
		if fileManager.fileExists(atPath: systemCredentialsPath) {
			info += "✅ Credentials file exists at system location\n"
			info += "⚠️ Note: Sandboxed app cannot access this location\n"
		} else {
			info += "❌ No credentials file at system location\n"
		}
		
		info += "\n📝 Solutions for Sandboxed Apps:\n\n"
		info += "Option 1: Set environment variables in Xcode\n"
		info += "1. Edit scheme → Run → Arguments\n"
		info += "2. Add environment variables:\n"
		info += "   AWS_ACCESS_KEY_ID = your_key\n"
		info += "   AWS_SECRET_ACCESS_KEY = your_secret\n\n"
		
		info += "Option 2: Copy credentials to app container\n"
		info += "mkdir -p \"\(homeDirectory.path)/.aws\"\n"
		info += "cp ~/.aws/credentials \"\(homeDirectory.path)/.aws/\"\n\n"
		
		info += "Option 3: Disable App Sandbox (development only)\n"
		info += "Remove App Sandbox capability in project settings"
		
		credentialsInfo = info
	}
}

#Preview {
	S3BackupTestView()
}