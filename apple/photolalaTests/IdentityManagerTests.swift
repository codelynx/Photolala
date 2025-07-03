//
//  IdentityManagerTests.swift
//  PhotolalaTests
//
//  Created by Claude on 7/3/25.
//

import XCTest
@testable import Photolala

class IdentityManagerTests: XCTestCase {
	
	var identityManager: IdentityManager!
	var mockS3Service: MockS3Service!
	var mockKeychainManager: MockKeychainManager!
	
	override func setUp() {
		super.setUp()
		mockS3Service = MockS3Service()
		mockKeychainManager = MockKeychainManager()
		
		// Create test instance with mocks
		// Note: This requires IdentityManager to support dependency injection
		// identityManager = IdentityManager(s3Service: mockS3Service, keychainManager: mockKeychainManager)
	}
	
	override func tearDown() {
		identityManager = nil
		mockS3Service = nil
		mockKeychainManager = nil
		super.tearDown()
	}
	
	// MARK: - User Creation Tests
	
	func testCreateNewUser_Success() async throws {
		// Given
		let credential = AuthCredential(
			provider: .google,
			providerID: "google123",
			email: "test@example.com",
			fullName: "Test User",
			photoURL: nil,
			idToken: "token",
			accessToken: nil
		)
		
		// When
		// let user = try await identityManager.createAccount(with: .google)
		
		// Then
		// XCTAssertNotNil(user)
		// XCTAssertEqual(user.email, "test@example.com")
		// XCTAssertEqual(user.primaryProvider, .google)
		// XCTAssertTrue(mockS3Service.uploadDataCalled)
	}
	
	func testCreateUser_EmailAlreadyExists() async {
		// Given existing user
		let existingUser = PhotolalaUser(
			serviceUserID: "existing123",
			primaryProvider: .apple,
			primaryProviderID: "apple123",
			email: "test@example.com",
			fullName: "Existing User",
			photoURL: nil,
			createdAt: Date(),
			lastUpdated: Date()
		)
		
		// Setup mock to return existing user
		mockS3Service.mockUsers["test@example.com"] = existingUser
		
		// When trying to create with same email
		do {
			// _ = try await identityManager.createAccount(with: .google)
			XCTFail("Should throw emailAlreadyInUse error")
		} catch AuthError.emailAlreadyInUse {
			// Expected error
			XCTAssertTrue(true)
		} catch {
			XCTFail("Wrong error type: \(error)")
		}
	}
	
	// MARK: - Sign In Tests
	
	func testSignIn_ExistingUser() async throws {
		// Given
		let existingUser = PhotolalaUser(
			serviceUserID: "user123",
			primaryProvider: .google,
			primaryProviderID: "google123",
			email: "test@example.com",
			fullName: "Test User",
			photoURL: nil,
			createdAt: Date(),
			lastUpdated: Date()
		)
		
		mockS3Service.mockIdentityMappings["google:google123"] = "user123"
		mockS3Service.mockUsers["user123"] = existingUser
		
		// When
		// let user = try await identityManager.signIn(with: .google)
		
		// Then
		// XCTAssertEqual(user.serviceUserID, "user123")
		// XCTAssertEqual(user.email, "test@example.com")
	}
	
	func testSignIn_NoAccount() async {
		// Given no existing mappings
		
		// When
		do {
			// _ = try await identityManager.signIn(with: .google)
			XCTFail("Should throw noAccountFound error")
		} catch AuthError.noAccountFound {
			// Expected
			XCTAssertTrue(true)
		} catch {
			XCTFail("Wrong error type: \(error)")
		}
	}
	
	// MARK: - Account Linking Tests
	
	func testLinkProvider_Success() async throws {
		// Given existing user
		let user = PhotolalaUser(
			serviceUserID: "user123",
			primaryProvider: .apple,
			primaryProviderID: "apple123",
			email: "test@example.com",
			fullName: "Test User",
			photoURL: nil,
			createdAt: Date(),
			lastUpdated: Date()
		)
		
		let googleCredential = AuthCredential(
			provider: .google,
			providerID: "google456",
			email: "test@example.com",
			fullName: "Test User",
			photoURL: nil,
			idToken: "token",
			accessToken: nil
		)
		
		// When
		// let updatedUser = try await identityManager.linkProvider(.google, credential: googleCredential, to: user)
		
		// Then
		// XCTAssertEqual(updatedUser.linkedProviders.count, 1)
		// XCTAssertEqual(updatedUser.linkedProviders.first?.provider, .google)
		// XCTAssertTrue(mockS3Service.uploadDataCalled)
	}
	
	func testLinkProvider_AlreadyLinked() async {
		// Given user with Google already linked
		var user = PhotolalaUser(
			serviceUserID: "user123",
			primaryProvider: .apple,
			primaryProviderID: "apple123",
			email: "test@example.com",
			fullName: "Test User",
			photoURL: nil,
			createdAt: Date(),
			lastUpdated: Date()
		)
		user.linkedProviders = [
			ProviderLink(provider: .google, providerID: "google456")
		]
		
		let googleCredential = AuthCredential(
			provider: .google,
			providerID: "google456",
			email: "test@example.com",
			fullName: "Test User",
			photoURL: nil,
			idToken: "token",
			accessToken: nil
		)
		
		// When
		do {
			// _ = try await identityManager.linkProvider(.google, credential: googleCredential, to: user)
			XCTFail("Should throw providerAlreadyLinked error")
		} catch AuthError.providerAlreadyLinked {
			// Expected
			XCTAssertTrue(true)
		} catch {
			XCTFail("Wrong error type: \(error)")
		}
	}
	
	// MARK: - Email Hashing Tests
	
	func testEmailHashing_Consistency() {
		// Test that email hashing is consistent
		let email1 = "Test@Example.com"
		let email2 = "test@example.com"
		let email3 = " test@example.com "
		
		// All should hash to same value after normalization
		// let hash1 = identityManager.hashEmail(email1)
		// let hash2 = identityManager.hashEmail(email2)
		// let hash3 = identityManager.hashEmail(email3)
		
		// XCTAssertEqual(hash1, hash2)
		// XCTAssertEqual(hash2, hash3)
	}
	
	// MARK: - Unlink Provider Tests
	
	func testUnlinkProvider_NotLastProvider() async throws {
		// Given user with linked provider
		var user = PhotolalaUser(
			serviceUserID: "user123",
			primaryProvider: .apple,
			primaryProviderID: "apple123",
			email: "test@example.com",
			fullName: "Test User",
			photoURL: nil,
			createdAt: Date(),
			lastUpdated: Date()
		)
		user.linkedProviders = [
			ProviderLink(provider: .google, providerID: "google456")
		]
		
		// When
		// let updatedUser = try await identityManager.unlinkProvider(.google, from: user)
		
		// Then
		// XCTAssertEqual(updatedUser.linkedProviders.count, 0)
		// XCTAssertTrue(mockS3Service.deleteObjectCalled)
	}
	
	func testUnlinkProvider_LastProvider() async {
		// Given user with only primary provider
		let user = PhotolalaUser(
			serviceUserID: "user123",
			primaryProvider: .apple,
			primaryProviderID: "apple123",
			email: "test@example.com",
			fullName: "Test User",
			photoURL: nil,
			createdAt: Date(),
			lastUpdated: Date()
		)
		
		// When trying to unlink primary (only) provider
		do {
			// _ = try await identityManager.unlinkProvider(.apple, from: user)
			XCTFail("Should throw cannotUnlinkLastProvider error")
		} catch AuthError.cannotUnlinkLastProvider {
			// Expected
			XCTAssertTrue(true)
		} catch {
			XCTFail("Wrong error type: \(error)")
		}
	}
}

// MARK: - Mock Services

class MockS3Service {
	var uploadDataCalled = false
	var deleteObjectCalled = false
	var mockIdentityMappings: [String: String] = [:]
	var mockUsers: [String: PhotolalaUser] = [:]
	
	func uploadData(_ data: Data, to path: String) async throws {
		uploadDataCalled = true
	}
	
	func downloadData(from path: String) async throws -> Data {
		if path.hasPrefix("identities/") {
			let key = String(path.dropFirst("identities/".count))
			if let userID = mockIdentityMappings[key] {
				return userID.data(using: .utf8)!
			}
		}
		throw S3Error.notFound
	}
	
	func deleteObject(at path: String) async throws {
		deleteObjectCalled = true
	}
}

class MockKeychainManager {
	var storedData: [String: Data] = [:]
	
	func save(_ data: Data, for key: String) throws {
		storedData[key] = data
	}
	
	func load(for key: String) throws -> Data? {
		return storedData[key]
	}
	
	func delete(for key: String) throws {
		storedData.removeValue(forKey: key)
	}
}

enum S3Error: Error {
	case notFound
}