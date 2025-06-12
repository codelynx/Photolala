//
//  ResourceTestView.swift
//  Photolala
//
//  Created by Kaz Yoshikawa on 2025/06/12.
//

import SwiftUI

struct ResourceTestView: View {
	@State private var testResults: [String] = []
	
	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Resource Test Results")
				.font(.title2)
				.fontWeight(.bold)
			
			ScrollView {
				VStack(alignment: .leading, spacing: 5) {
					ForEach(testResults, id: \.self) { result in
						Text(result)
							.font(.system(.caption, design: .monospaced))
							.foregroundColor(result.contains("✅") ? .green : 
										   result.contains("❌") ? .red : 
										   result.contains("⚠️") ? .orange : .primary)
					}
				}
				.padding()
			}
			
			Button("Run Tests") {
				runResourceTests()
			}
			.buttonStyle(.borderedProminent)
		}
		.padding()
		.frame(minWidth: 600, minHeight: 400)
		.onAppear {
			runResourceTests()
		}
	}
	
	private func runResourceTests() {
		testResults = []
		
		// Test 1: Check for Photos folder reference
		testResults.append("=== Testing Folder Reference ===")
		if let photosURL = Bundle.main.url(forResource: "Photos", withExtension: nil) {
			testResults.append("✅ Found Photos folder at: \(photosURL.path)")
			
			// Check if it's a directory
			var isDirectory: ObjCBool = false
			if FileManager.default.fileExists(atPath: photosURL.path, isDirectory: &isDirectory) {
				if isDirectory.boolValue {
					testResults.append("✅ Photos is a directory (folder reference)")
					
					// List contents
					do {
						let contents = try FileManager.default.contentsOfDirectory(at: photosURL, includingPropertiesForKeys: nil)
						testResults.append("✅ Found \(contents.count) items in Photos folder:")
						for item in contents {
							testResults.append("   - \(item.lastPathComponent)")
						}
					} catch {
						testResults.append("❌ Error listing folder contents: \(error)")
					}
				} else {
					testResults.append("❌ Photos exists but is not a directory")
				}
			}
		} else {
			testResults.append("❌ Photos folder not found as folder reference")
		}
		
		// Test 2: Check for individual files (flat structure)
		testResults.append("\n=== Testing Individual Files ===")
		let testFiles = ["IMG_0023", "IMG_0025", "IMG_0030", "IMG_0032_1"]
		var foundCount = 0
		
		for fileName in testFiles {
			if let fileURL = Bundle.main.url(forResource: fileName, withExtension: "HEIC") {
				testResults.append("✅ Found \(fileName).HEIC at: \(fileURL.lastPathComponent)")
				foundCount += 1
			} else {
				testResults.append("❌ \(fileName).HEIC not found")
			}
		}
		
		if foundCount > 0 && foundCount == testFiles.count {
			testResults.append("⚠️  All files found as flat resources (not in folder)")
		}
		
		// Test 3: List all bundle resources
		testResults.append("\n=== All Bundle Resources ===")
		if let resourcePath = Bundle.main.resourcePath {
			do {
				let resourceURL = URL(fileURLWithPath: resourcePath)
				let allFiles = try FileManager.default.contentsOfDirectory(at: resourceURL, includingPropertiesForKeys: nil)
				let imageFiles = allFiles.filter { url in
					["jpg", "jpeg", "png", "heic", "heif"].contains(url.pathExtension.lowercased())
				}
				testResults.append("Found \(imageFiles.count) image files in bundle:")
				for file in imageFiles.prefix(10) {
					testResults.append("   - \(file.lastPathComponent)")
				}
				if imageFiles.count > 10 {
					testResults.append("   ... and \(imageFiles.count - 10) more")
				}
			} catch {
				testResults.append("❌ Error scanning bundle: \(error)")
			}
		}
		
		// Test 4: Check ResourceHelper
		testResults.append("\n=== Testing ResourceHelper ===")
		ResourceHelper.checkPhotosResource()
		// The output from checkPhotosResource will be in console
		testResults.append("ℹ️  Check console for ResourceHelper output")
	}
}

#Preview {
	ResourceTestView()
}