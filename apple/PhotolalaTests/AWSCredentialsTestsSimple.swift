//
//  AWSCredentialsTestsSimple.swift
//  PhotolalaTests
//
//  Simplified test for AWS S3 with explicit environment configuration
//

import XCTest
import AWSS3
@testable import Photolala

final class AWSCredentialsTestsSimple: XCTestCase {

	// Test S3 connections with explicit environment initialization
	func testS3ConnectionsWithExplicitEnvironments() async throws {
		// Test Development Environment
		do {
			let devService = try await S3Service.forEnvironment(.development)
			let devBucket = await devService.getBucketName()
			XCTAssertEqual(devBucket, "photolala-dev")

			// Test connection
			let objects = try await devService.listObjects(prefix: "__test__/", maxKeys: 1)
			XCTAssertNotNil(objects)
			print("✅ Development S3 connected successfully to \(devBucket)")
		} catch {
			XCTFail("Development S3 connection failed: \(error)")
		}

		// Test Staging Environment
		do {
			let stageService = try await S3Service.forEnvironment(.staging)
			let stageBucket = await stageService.getBucketName()
			XCTAssertEqual(stageBucket, "photolala-stage")

			// Test connection
			let objects = try await stageService.listObjects(prefix: "__test__/", maxKeys: 1)
			XCTAssertNotNil(objects)
			print("✅ Staging S3 connected successfully to \(stageBucket)")
		} catch {
			XCTFail("Staging S3 connection failed: \(error)")
		}

		// Test Production Environment
		do {
			let prodService = try await S3Service.forEnvironment(.production)
			let prodBucket = await prodService.getBucketName()
			XCTAssertEqual(prodBucket, "photolala-prod")

			// Test connection
			let objects = try await prodService.listObjects(prefix: "__test__/", maxKeys: 1)
			XCTAssertNotNil(objects)
			print("✅ Production S3 connected successfully to \(prodBucket)")
		} catch {
			XCTFail("Production S3 connection failed: \(error)")
		}
	}

	// Test that services are independent of UserDefaults
	func testS3IndependentOfUserDefaults() async throws {
		// Set UserDefaults to production
		UserDefaults.standard.set("production", forKey: "selectedEnvironment")

		// Create a dev service - should still connect to dev
		let devService = try await S3Service.forEnvironment(.development)
		let bucket = await devService.getBucketName()
		XCTAssertEqual(bucket, "photolala-dev", "Service should use explicit environment, not UserDefaults")

		// Verify connection works
		let objects = try await devService.listObjects(prefix: "__test__/", maxKeys: 1)
		XCTAssertNotNil(objects)
		print("✅ S3Service correctly ignores UserDefaults and uses explicit environment")
	}
}