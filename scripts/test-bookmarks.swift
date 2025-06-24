#!/usr/bin/env swift

// Test script for Photolala bookmark feature
// Run with: swift test-bookmarks.swift

import Foundation

// Test bookmark CSV operations
func testBookmarkCSV() {
    print("=== Testing Bookmark CSV Operations ===\n")
    
    // Test CSV file location
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let bookmarksURL = appSupport.appendingPathComponent("Photolala/bookmarks.csv")
    
    // Check if app is sandboxed (look in container)
    let containerPath = NSHomeDirectory().replacingOccurrences(of: "/Users/\(NSUserName())", with: "/Users/\(NSUserName())/Library/Containers/com.electricwoods.photolala/Data")
    let containerBookmarksURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Library/Application Support/Photolala/bookmarks.csv")
    
    // Try container path first (for sandboxed app)
    let actualBookmarksURL = FileManager.default.fileExists(atPath: containerBookmarksURL.path) ? containerBookmarksURL : bookmarksURL
    
    print("Bookmarks file location: \(actualBookmarksURL.path)")
    
    // Check if file exists
    if FileManager.default.fileExists(atPath: actualBookmarksURL.path) {
        print("✅ Bookmarks file exists")
        
        // Read and display contents
        if let contents = try? String(contentsOf: actualBookmarksURL, encoding: .utf8) {
            print("\nCurrent bookmarks:")
            print("------------------")
            print(contents)
            print("------------------")
            
            // Count bookmarks
            let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let bookmarkCount = lines.count > 1 ? lines.count - 1 : 0 // Subtract header
            print("\n📊 Total bookmarks: \(bookmarkCount)")
            
            // Parse emojis
            if bookmarkCount > 0 {
                var emojiCounts: [String: Int] = [:]
                for i in 1..<lines.count {
                    let components = lines[i].split(separator: ",")
                    if components.count >= 2 {
                        let emoji = String(components[1])
                        emojiCounts[emoji, default: 0] += 1
                    }
                }
                
                print("\n📈 Emoji distribution:")
                for (emoji, count) in emojiCounts.sorted(by: { $0.value > $1.value }) {
                    print("   \(emoji): \(count) photo(s)")
                }
            }
        }
    } else {
        print("❌ No bookmarks file found (this is normal if no bookmarks have been created yet)")
    }
}

// Test bookmark data model
func testBookmarkModel() {
    print("\n\n=== Testing Bookmark Data Model ===\n")
    
    // Test creating bookmarks
    let testMD5 = "5d41402abc4b2a76b9719d911017c592"
    let testEmoji = "⭐"
    let testNote = "Test bookmark"
    
    // Test CSV row generation
    print("Test bookmark data:")
    print("  MD5: \(testMD5)")
    print("  Emoji: \(testEmoji)")
    print("  Note: \(testNote)")
    
    let timestamp = Int(Date().timeIntervalSince1970)
    let csvRow = "\(testMD5),\(testEmoji),\(testNote),\(timestamp)"
    print("\nGenerated CSV row:")
    print("  \(csvRow)")
    
    // Test parsing CSV row
    let components = csvRow.split(separator: ",").map { String($0) }
    if components.count >= 4 {
        print("\n✅ CSV parsing successful:")
        print("  MD5: \(components[0])")
        print("  Emoji: \(components[1])")
        print("  Note: \(components[2])")
        print("  Timestamp: \(components[3])")
        
        if let ts = Double(components[3]) {
            let date = Date(timeIntervalSince1970: ts)
            print("  Date: \(date)")
        }
    }
}

// Manual test checklist
func printManualTests() {
    print("\n\n=== Manual Test Checklist ===\n")
    print("1. Launch Photolala and open a folder with photos")
    print("2. Select a photo and open the Inspector (Cmd+I)")
    print("3. In the Bookmark section:")
    print("   - Verify 'Current: None' is shown initially")
    print("   - Click an emoji (e.g., ⭐) to bookmark the photo")
    print("   - Verify 'Current: ⭐' is now shown")
    print("   - Verify the emoji badge appears on the thumbnail")
    print("4. Test toggling:")
    print("   - Click the same emoji again to remove the bookmark")
    print("   - Click a different emoji to change the bookmark")
    print("   - Click 'Clear' to remove the bookmark")
    print("5. Select multiple photos:")
    print("   - Bookmark them with different emojis")
    print("   - Verify all badges display correctly")
    print("6. Close and reopen Photolala:")
    print("   - Verify bookmarks persist after restart")
    print("   - Check that emoji badges still appear on thumbnails")
    print("7. Test with different photo sources:")
    print("   - Local files (PhotoFile)")
    print("   - Apple Photos Library (PhotoApple)")
    print("   - Cloud photos (PhotoS3)")
    print("\n📝 Available emojis: ⭐ ❤️ 👍 👎 ✏️ 🗑️ 📤 🖨️ ✅ 🔴 📌 💡")
}

// Run all tests
print("🧪 Photolala Bookmark Feature Test\n")
testBookmarkCSV()
testBookmarkModel()
printManualTests()

print("\n\n✅ Test script completed!")