//
//  AuthenticationUITests.swift
//  PhotolalaUITests
//
//  Created by Claude on 7/3/25.
//

import XCTest

class AuthenticationUITests: XCTestCase {
	
	var app: XCUIApplication!
	
	override func setUpWithError() throws {
		continueAfterFailure = false
		app = XCUIApplication()
		app.launchArguments = ["UI_TESTING"]
		
		// Reset app state for testing
		app.launchArguments.append("RESET_STATE")
		
		app.launch()
	}
	
	override func tearDownWithError() throws {
		app = nil
	}
	
	// MARK: - Welcome Screen Tests
	
	func testWelcomeScreen_InitialState() {
		// Verify welcome screen elements
		XCTAssertTrue(app.staticTexts["Welcome to Photolala"].exists)
		XCTAssertTrue(app.buttons["Sign In"].exists)
		XCTAssertTrue(app.buttons["Create Account"].exists)
		XCTAssertTrue(app.buttons["Browse Photos"].exists)
	}
	
	// MARK: - Sign In Flow Tests
	
	func testSignIn_AppleProvider() {
		// Navigate to sign in
		app.buttons["Sign In"].tap()
		
		// Verify provider selection
		XCTAssertTrue(app.staticTexts["Choose how to sign in"].exists)
		XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
		XCTAssertTrue(app.buttons["Sign in with Google"].exists)
		
		// Tap Apple sign in
		app.buttons["Sign in with Apple"].tap()
		
		// Note: Actual Apple Sign In requires special test setup
		// This would normally show the Apple ID authentication sheet
	}
	
	func testSignIn_GoogleProvider() {
		// Navigate to sign in
		app.buttons["Sign In"].tap()
		
		// Tap Google sign in
		app.buttons["Sign in with Google"].tap()
		
		// Note: Google Sign In would open web view or Google app
		// For testing, we'd need to mock this flow
	}
	
	func testSignIn_Cancel() {
		// Navigate to sign in
		app.buttons["Sign In"].tap()
		
		// Tap cancel
		app.buttons["Cancel"].tap()
		
		// Should return to welcome screen
		XCTAssertTrue(app.staticTexts["Welcome to Photolala"].exists)
	}
	
	// MARK: - Create Account Flow Tests
	
	func testCreateAccount_Success() {
		// Navigate to create account
		app.buttons["Create Account"].tap()
		
		// Verify provider selection
		XCTAssertTrue(app.staticTexts["Choose how to create your account"].exists)
		
		// Select provider (mocked for testing)
		app.buttons["Sign up with Apple"].tap()
		
		// In real flow, this would complete authentication
		// For testing, we simulate success
		if app.buttons["Continue"].exists {
			app.buttons["Continue"].tap()
		}
	}
	
	func testCreateAccount_EmailConflict() {
		// This test requires a pre-existing account with same email
		// Launch with test data
		app.launchArguments.append("EXISTING_EMAIL_ACCOUNT")
		app.launch()
		
		// Navigate to create account
		app.buttons["Create Account"].tap()
		app.buttons["Sign up with Google"].tap()
		
		// Should show linking prompt
		let linkingPrompt = app.staticTexts["Account Found"]
		XCTAssertTrue(linkingPrompt.waitForExistence(timeout: 5))
		
		// Verify options
		XCTAssertTrue(app.buttons["Link to Existing Account"].exists)
		XCTAssertTrue(app.buttons["Create Separate Account"].exists)
		
		// Test linking
		app.buttons["Link to Existing Account"].tap()
		
		// Should complete linking and dismiss
	}
	
	// MARK: - Account Management Tests
	
	func testAccountSettings_LinkedProviders() {
		// Launch as signed in user
		app.launchArguments.append("SIGNED_IN_USER")
		app.launch()
		
		// Navigate to account settings
		if app.buttons["Account"].exists {
			app.buttons["Account"].tap()
		} else {
			// Alternative navigation
			app.buttons["Settings"].tap()
			app.buttons["Account"].tap()
		}
		
		// Verify linked providers section
		XCTAssertTrue(app.staticTexts["Sign-In Methods"].exists)
		
		// Should show primary provider
		XCTAssertTrue(app.staticTexts["Primary"].exists)
		
		// Test add provider
		if app.buttons["Link Another Sign-In Method"].exists {
			app.buttons["Link Another Sign-In Method"].tap()
			
			// Verify provider options
			XCTAssertTrue(app.staticTexts["Link Sign-In Method"].exists)
		}
	}
	
	func testSignOut() {
		// Launch as signed in user
		app.launchArguments.append("SIGNED_IN_USER")
		app.launch()
		
		// Navigate to account
		app.buttons["Account"].tap()
		
		// Sign out
		app.buttons["Sign Out"].tap()
		
		// Confirm if needed
		if app.buttons["Sign Out"].exists {
			app.buttons["Sign Out"].tap()
		}
		
		// Should return to welcome screen
		XCTAssertTrue(app.staticTexts["Welcome to Photolala"].waitForExistence(timeout: 5))
	}
	
	// MARK: - Error Handling Tests
	
	func testAuthError_NoAccount() {
		app.buttons["Sign In"].tap()
		app.buttons["Sign in with Apple"].tap()
		
		// Simulate no account error
		app.launchArguments.append("SIMULATE_NO_ACCOUNT")
		
		// Should show error
		let errorAlert = app.alerts["Authentication Error"]
		XCTAssertTrue(errorAlert.waitForExistence(timeout: 5))
		XCTAssertTrue(errorAlert.staticTexts["No account found"].exists)
		
		errorAlert.buttons["OK"].tap()
	}
	
	// MARK: - Accessibility Tests
	
	func testAccessibility_VoiceOver() {
		// Enable accessibility testing
		app.launchArguments.append("ACCESSIBILITY_TESTING")
		app.launch()
		
		// Check accessibility labels
		let signInButton = app.buttons["Sign In"]
		XCTAssertNotNil(signInButton.label)
		XCTAssertNotEqual(signInButton.label, "")
		
		let createAccountButton = app.buttons["Create Account"]
		XCTAssertNotNil(createAccountButton.label)
		XCTAssertNotEqual(createAccountButton.label, "")
	}
	
	// MARK: - Performance Tests
	
	func testLaunchPerformance() throws {
		if #available(iOS 15.0, *) {
			measure(metrics: [XCTApplicationLaunchMetric()]) {
				XCUIApplication().launch()
			}
		}
	}
}

// MARK: - Helper Extensions

extension XCUIElement {
	func waitForExistence(timeout: TimeInterval) -> Bool {
		let predicate = NSPredicate(format: "exists == true")
		let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
		let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
		return result == .completed
	}
}