import Foundation
import AWSS3
import AWSClientRuntime
import AWSSDKIdentity
import SmithyIdentity
import CryptoKit

class S3BackupService {
	private let client: S3Client
	private let bucketName = "photolala"
	private let region = "us-east-1"
	
	init(accessKey: String, secretKey: String) async throws {
		// Create static credentials
		let credentialIdentity = AWSCredentialIdentity(accessKey: accessKey, secret: secretKey)
		let credentialIdentityResolver = try StaticAWSCredentialIdentityResolver(credentialIdentity)
		
		// Create S3 configuration with static credentials
		let configuration = try await S3Client.S3ClientConfiguration(
			awsCredentialIdentityResolver: credentialIdentityResolver,
			region: region
		)
		
		self.client = S3Client(config: configuration)
	}
	
	// Convenience init that reads from Keychain, environment, or credentials file
	convenience init() async throws {
		// First, try Keychain (production)
		if let credentials = try? KeychainManager.shared.loadAWSCredentials() {
			print("Using AWS credentials from Keychain")
			try await self.init(accessKey: credentials.accessKey, secretKey: credentials.secretKey)
			return
		}
		
		// Second, try environment variables (development)
		if let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"],
		   let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"],
		   !accessKey.isEmpty, !secretKey.isEmpty {
			print("Using AWS credentials from environment variables")
			try await self.init(accessKey: accessKey, secretKey: secretKey)
			return
		}
		
		// Third, try the credentials file (fallback)
		// For sandboxed apps, this will be in the container directory
		let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
		let credentialsPath = homeDirectory.appendingPathComponent(".aws/credentials").path
		print("Looking for credentials at: \(credentialsPath)")
		
		// Check if file exists
		let fileManager = FileManager.default
		guard fileManager.fileExists(atPath: credentialsPath) else {
			print("Credentials file does not exist at: \(credentialsPath)")
			print("For sandboxed apps, you can:")
			print("1. Set environment variables AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY")
			print("2. Copy your credentials to: \(credentialsPath)")
			throw S3BackupError.credentialsNotFound
		}
		
		// Try to read the file
		let credentialsData: String
		do {
			credentialsData = try String(contentsOfFile: credentialsPath)
			print("Successfully read credentials file, length: \(credentialsData.count)")
		} catch {
			print("Failed to read credentials file: \(error)")
			throw S3BackupError.credentialsNotFound
		}
		
		var accessKey: String?
		var secretKey: String?
		
		// Parse the credentials file
		let lines = credentialsData.components(separatedBy: .newlines)
		var inDefaultSection = false
		
		print("Parsing \(lines.count) lines from credentials file")
		
		for (index, line) in lines.enumerated() {
			let trimmed = line.trimmingCharacters(in: .whitespaces)
			
			if trimmed == "[default]" {
				print("Found [default] section at line \(index + 1)")
				inDefaultSection = true
			} else if trimmed.hasPrefix("[") {
				print("Found new section at line \(index + 1): \(trimmed)")
				inDefaultSection = false
			} else if inDefaultSection && !trimmed.isEmpty {
				if trimmed.hasPrefix("aws_access_key_id") {
					let parts = trimmed.components(separatedBy: "=")
					if parts.count >= 2 {
						accessKey = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
						print("Found access key: \(String(repeating: "*", count: accessKey?.count ?? 0))")
					}
				} else if trimmed.hasPrefix("aws_secret_access_key") {
					let parts = trimmed.components(separatedBy: "=")
					if parts.count >= 2 {
						secretKey = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
						print("Found secret key: \(String(repeating: "*", count: secretKey?.count ?? 0))")
					}
				}
			}
		}
		
		guard let accessKey = accessKey, !accessKey.isEmpty else {
			print("Access key not found or empty")
			throw S3BackupError.credentialsNotFound
		}
		
		guard let secretKey = secretKey, !secretKey.isEmpty else {
			print("Secret key not found or empty")
			throw S3BackupError.credentialsNotFound
		}
		
		print("Credentials parsed successfully, initializing S3 client...")
		try await self.init(accessKey: accessKey, secretKey: secretKey)
	}
	
	// MARK: - MD5 Calculation
	private func calculateMD5(for data: Data) -> String {
		let digest = Insecure.MD5.hash(data: data)
		return digest.map { String(format: "%02hhx", $0) }.joined()
	}
	
	// MARK: - Upload Photo
	func uploadPhoto(data: Data, userId: String) async throws -> String {
		let md5 = calculateMD5(for: data)
		let key = "users/\(userId)/photos/\(md5).dat"
		
		// Check if already exists
		do {
			_ = try await client.headObject(input: HeadObjectInput(
				bucket: bucketName,
				key: key
			))
			print("Photo already exists: \(md5)")
			return md5
		} catch {
			// Photo doesn't exist, proceed with upload
		}
		
		// Upload photo
		let putObjectInput = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "image/jpeg",
			key: key,
			metadata: ["original-md5": md5]
		)
		
		_ = try await client.putObject(input: putObjectInput)
		print("Uploaded photo: \(md5)")
		
		return md5
	}
	
	// MARK: - Upload Thumbnail
	func uploadThumbnail(data: Data, md5: String, userId: String) async throws {
		let key = "users/\(userId)/thumbs/\(md5).dat"
		
		let putObjectInput = PutObjectInput(
			body: .data(data),
			bucket: bucketName,
			contentType: "image/jpeg",
			key: key
		)
		
		_ = try await client.putObject(input: putObjectInput)
		print("Uploaded thumbnail for: \(md5)")
	}
	
	// MARK: - Get Photo Info
	func getPhotoInfo(md5: String, userId: String) async throws -> (size: Int64, storageClass: String) {
		let key = "users/\(userId)/photos/\(md5).dat"
		
		let response = try await client.headObject(input: HeadObjectInput(
			bucket: bucketName,
			key: key
		))
		
		let size = response.contentLength ?? 0
		let storageClass = response.storageClass?.rawValue ?? "STANDARD"
		
		return (size: Int64(size), storageClass: storageClass)
	}
	
	// MARK: - List User Photos
	func listUserPhotos(userId: String) async throws -> [PhotoEntry] {
		let prefix = "users/\(userId)/photos/"
		
		let listObjectsInput = ListObjectsV2Input(
			bucket: bucketName,
			prefix: prefix
		)
		
		let response = try await client.listObjectsV2(input: listObjectsInput)
		
		var photos: [PhotoEntry] = []
		
		for object in response.contents ?? [] {
			guard let key = object.key,
				  let lastModified = object.lastModified,
				  let size = object.size else { continue }
			
			// Extract MD5 from key
			let md5 = key
				.replacingOccurrences(of: prefix, with: "")
				.replacingOccurrences(of: ".dat", with: "")
			
			photos.append(PhotoEntry(
				md5: md5,
				size: Int64(size),
				lastModified: Date(timeIntervalSince1970: lastModified.timeIntervalSince1970),
				storageClass: object.storageClass?.rawValue ?? "STANDARD"
			))
		}
		
		return photos
	}
}

// MARK: - Supporting Types
struct PhotoEntry {
	let md5: String
	let size: Int64
	let lastModified: Date
	let storageClass: String
}

enum S3BackupError: Error, LocalizedError {
	case credentialsNotFound
	case uploadFailed
	case photoNotFound
	
	var errorDescription: String? {
		switch self {
		case .credentialsNotFound:
			return "AWS credentials not found. Please configure your AWS credentials in Settings."
		case .uploadFailed:
			return "Failed to upload file to S3"
		case .photoNotFound:
			return "Photo not found in S3"
		}
	}
}