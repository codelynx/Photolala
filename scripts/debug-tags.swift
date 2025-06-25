#!/usr/bin/env swift

// Debug script to check tag functionality
// Run with: swift debug-tags.swift

import Foundation

print("🔍 Debugging Photolala Tags\n")

// Check Application Support directory
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let photolalaDir = appSupport.appendingPathComponent("Photolala")
let tagsURL = photolalaDir.appendingPathComponent("tags.csv")

print("Application Support: \(appSupport.path)")
print("Photolala directory: \(photolalaDir.path)")
print("Tags file: \(tagsURL.path)")

// Check if directories exist
print("\n📁 Directory Status:")
if FileManager.default.fileExists(atPath: appSupport.path) {
    print("✅ Application Support exists")
} else {
    print("❌ Application Support missing")
}

if FileManager.default.fileExists(atPath: photolalaDir.path) {
    print("✅ Photolala directory exists")
    
    // List contents
    if let contents = try? FileManager.default.contentsOfDirectory(at: photolalaDir, includingPropertiesForKeys: nil) {
        print("\nContents of Photolala directory:")
        for item in contents {
            print("  - \(item.lastPathComponent)")
        }
    }
} else {
    print("❌ Photolala directory missing")
    print("\nCreating directory...")
    do {
        try FileManager.default.createDirectory(at: photolalaDir, withIntermediateDirectories: true)
        print("✅ Directory created")
    } catch {
        print("❌ Failed to create directory: \(error)")
    }
}

if FileManager.default.fileExists(atPath: tagsURL.path) {
    print("\n✅ Tags file exists")
    
    // Show file info
    if let attributes = try? FileManager.default.attributesOfItem(atPath: tagsURL.path) {
        let size = attributes[.size] as? Int64 ?? 0
        let modified = attributes[.modificationDate] as? Date ?? Date()
        print("  Size: \(size) bytes")
        print("  Modified: \(modified)")
    }
    
    // Show contents
    if let contents = try? String(contentsOf: tagsURL, encoding: .utf8) {
        print("\n📄 File contents:")
        print("================")
        print(contents)
        print("================")
    }
} else {
    print("\n❌ Tags file missing")
    
    // Create a test tag file
    print("\nCreating test tag file...")
    let testCSV = """
    md5,emoji,note,modifiedDate
    test123,⭐,Debug test,\(Int(Date().timeIntervalSince1970))
    """
    
    do {
        try testCSV.write(to: tagsURL, atomically: true, encoding: .utf8)
        print("✅ Test file created")
        print("Run the test script again to verify it can be read")
    } catch {
        print("❌ Failed to create test file: \(error)")
    }
}

print("\n💡 Troubleshooting Tips:")
print("1. Make sure you clicked a flag in the Inspector (not just viewed it)")
print("2. The photo needs to have its MD5 calculated (may take a moment)")
print("3. Check Console.app for any Photolala or TagManager errors")
print("4. Try tagging a local photo file first (not Apple Photos)")
print("\n✅ Debug complete!")