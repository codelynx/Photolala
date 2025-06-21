//
//  PhotoProviderCapabilitiesTests.swift
//  PhotolalaTests
//
//  Created by Kaz Yoshikawa on 2025/06/21.
//

import XCTest
@testable import Photolala

final class PhotoProviderCapabilitiesTests: XCTestCase {
	
	func testEnhancedLocalPhotoProviderCapabilities() async {
		let provider = await EnhancedLocalPhotoProvider(directoryPath: "/tmp")
		let caps = await provider.capabilities
		
		// Local provider should have these capabilities
		XCTAssertTrue(caps.contains(.hierarchicalNavigation))
		XCTAssertTrue(caps.contains(.backup))
		XCTAssertTrue(caps.contains(.sorting))
		XCTAssertTrue(caps.contains(.grouping))
		XCTAssertTrue(caps.contains(.preview))
		XCTAssertTrue(caps.contains(.star))
		
		// Should NOT have these
		XCTAssertFalse(caps.contains(.download))
		XCTAssertFalse(caps.contains(.albums))
		XCTAssertFalse(caps.contains(.search))
	}
	
	func testS3PhotoProviderCapabilities() async {
		let provider = await S3PhotoProvider(userId: "test-user")
		let caps = await provider.capabilities
		
		// S3 provider should have these capabilities
		XCTAssertTrue(caps.contains(.download))
		XCTAssertTrue(caps.contains(.search))
		
		// Should NOT have these
		XCTAssertFalse(caps.contains(.hierarchicalNavigation))
		XCTAssertFalse(caps.contains(.backup))
		XCTAssertFalse(caps.contains(.star))
		XCTAssertFalse(caps.contains(.albums))
		
		// Default base capabilities (via supportsGrouping/supportsSorting)
		// Note: S3 overrides capabilities, so these defaults don't apply
		XCTAssertFalse(caps.contains(.sorting))
		XCTAssertFalse(caps.contains(.grouping))
	}
	
	func testCapabilitiesOptionSet() {
		var caps: PhotoProviderCapabilities = []
		
		// Test insert
		caps.insert(.sorting)
		XCTAssertTrue(caps.contains(.sorting))
		
		// Test multiple
		caps = [.sorting, .grouping, .backup]
		XCTAssertTrue(caps.contains(.sorting))
		XCTAssertTrue(caps.contains(.grouping))
		XCTAssertTrue(caps.contains(.backup))
		XCTAssertFalse(caps.contains(.download))
		
		// Test remove
		caps.remove(.sorting)
		XCTAssertFalse(caps.contains(.sorting))
		XCTAssertTrue(caps.contains(.grouping))
	}
}