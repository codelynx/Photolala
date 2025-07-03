# Existing User Migration Guide

## Overview
This guide covers the migration process for users upgrading from the Apple-only authentication system to the new multi-provider system.

## Migration Scenarios

### Scenario 1: Apple Sign-In User (Most Common)

#### Before Migration
```swift
PhotolalaUser {
    appleUserID: "001234.abc.def"
    email: "user@icloud.com"
    subscription: Subscription
}
```

#### After Migration
```swift
PhotolalaUser {
    serviceUserID: "uuid-1234"              // New UUID
    primaryProvider: .apple                 // Set from context
    primaryProviderID: "001234.abc.def"     // Moved from appleUserID
    email: "user@icloud.com"               // Preserved
    linkedProviders: []                     // Empty, can add Google later
    subscription: Subscription              // Preserved
}
```

### Migration Code

```swift
extension IdentityManager {
    func migrateExistingUserIfNeeded() async throws {
        // Check for old format user data
        if let oldUserData = try? loadLegacyUser() {
            print("[Migration] Found legacy user data")
            
            // Convert to new format
            let migratedUser = PhotolalaUser(
                serviceUserID: UUID().uuidString.lowercased(),
                primaryProvider: .apple,
                primaryProviderID: oldUserData.appleUserID,
                email: oldUserData.email,
                fullName: oldUserData.fullName,
                photoURL: oldUserData.photoURL,
                createdAt: oldUserData.createdAt ?? Date(),
                lastUpdated: Date(),
                linkedProviders: [],
                subscription: oldUserData.subscription
            )
            
            // Save in new format
            try await saveUser(migratedUser)
            
            // Create S3 identity mapping
            try await createIdentityMapping(
                provider: .apple,
                providerID: oldUserData.appleUserID,
                serviceUserID: migratedUser.serviceUserID
            )
            
            // Create email mapping if available
            if let email = migratedUser.email {
                try await updateEmailMapping(
                    email: email,
                    serviceUserID: migratedUser.serviceUserID
                )
            }
            
            // Clean up old data
            try? deleteLegacyUserData()
            
            print("[Migration] Successfully migrated user")
        }
    }
}
```

## S3 Data Migration

### Old Structure
```
/users/{appleUserID}/
    photos/
    metadata/
    thumbnails/
```

### New Structure
```
/users/{serviceUserID}/
    photos/
    metadata/
    thumbnails/
/identities/apple:{appleUserID} → serviceUserID
/emails/{hashedEmail} → serviceUserID
```

### Migration Strategy

#### Option 1: Lazy Migration (Recommended)
- Keep old S3 structure
- Create identity mappings pointing to old folders
- Migrate data on next backup

```swift
func createLegacyMapping(appleUserID: String) async throws {
    // Point new identity to old folder structure
    let identityPath = "identities/apple:\(appleUserID)"
    let mappingData = appleUserID.data(using: .utf8)!
    try await s3Service.uploadData(mappingData, to: identityPath)
}
```

#### Option 2: Active Migration
- Copy all data to new structure
- Update mappings
- Delete old data after verification

```swift
func migrateS3Data(from oldID: String, to newID: String) async throws {
    let oldPrefix = "users/\(oldID)/"
    let newPrefix = "users/\(newID)/"
    
    // List all objects
    let objects = try await s3Service.listObjects(prefix: oldPrefix)
    
    // Copy each object
    for object in objects {
        let relativePath = object.key.replacingOccurrences(of: oldPrefix, with: "")
        let newKey = newPrefix + relativePath
        try await s3Service.copyObject(from: object.key, to: newKey)
    }
}
```

## Testing Migration

### Test Cases

1. **Fresh Install After Update**
   - User updates app
   - Opens app
   - Should auto-migrate on launch
   - Can still access all photos

2. **Add Google to Existing Apple Account**
   - Migrated user
   - Goes to settings
   - Links Google account
   - Both providers work

3. **Backup Continuity**
   - Start backup on old version
   - Update app mid-backup
   - Backup should resume correctly

### Verification Steps

```swift
func verifyMigration(for user: PhotolalaUser) async -> MigrationStatus {
    var status = MigrationStatus()
    
    // Check identity mapping exists
    let identityKey = "\(user.primaryProvider.rawValue):\(user.primaryProviderID)"
    status.identityMapped = await s3Service.objectExists(
        at: "identities/\(identityKey)"
    )
    
    // Check user data accessible
    status.userDataAccessible = await s3Service.objectExists(
        at: "users/\(user.serviceUserID)/metadata.json"
    )
    
    // Check photos accessible
    let photos = try? await s3Service.listObjects(
        prefix: "users/\(user.serviceUserID)/photos/"
    )
    status.photosAccessible = (photos?.count ?? 0) > 0
    
    // Check subscription preserved
    status.subscriptionValid = user.subscription?.isActive ?? false
    
    return status
}
```

## User Communication

### In-App Migration Notice

```swift
struct MigrationNoticeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("Account Update")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("We're updating your account to support multiple sign-in methods. This is a one-time process.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            ProgressView()
                .progressViewStyle(.linear)
            
            Text("Migrating your data...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
```

### Email Template

```
Subject: Photolala Account Update - Action May Be Required

Hi [Name],

We've updated Photolala to support multiple sign-in methods! 

What's New:
✓ Sign in with Apple OR Google
✓ Link multiple accounts for flexibility
✓ Enhanced security

Your Account:
- All your photos are safe
- Your subscription continues unchanged
- You can now add Google sign-in if desired

Next Steps:
1. Update to the latest version
2. Sign in as usual with Apple
3. Optionally link Google account in Settings

Questions? support@photolala.com

Best,
The Photolala Team
```

## Rollback Plan

### If Migration Fails

```swift
func rollbackMigration() async throws {
    // Restore legacy user data
    if let backupData = try? loadMigrationBackup() {
        try saveLegacyUser(backupData)
    }
    
    // Remove new mappings
    try? await removeIdentityMappings()
    
    // Flag for support
    await flagAccountForSupport(reason: .migrationFailed)
    
    // Use legacy auth flow
    AppConfig.useLegacyAuth = true
}
```

### Support Tools

```swift
// Admin tool to manually fix accounts
func manualAccountFix(email: String) async throws {
    // Find all related data
    let accounts = try await findAllAccounts(email: email)
    
    // Merge if needed
    if accounts.count > 1 {
        let primary = selectPrimaryAccount(accounts)
        try await mergeAccounts(accounts, into: primary)
    }
    
    // Verify integrity
    try await verifyAccountIntegrity(primary)
}
```

## Success Metrics

### Migration KPIs
- Migration success rate: > 99.9%
- Average migration time: < 5 seconds
- Zero data loss incidents
- Support ticket rate: < 0.1%

### Monitoring

```swift
Analytics.track("migration_started", properties: [
    "user_type": "existing_apple",
    "data_size": dataSizeMB,
    "app_version": oldVersion
])

Analytics.track("migration_completed", properties: [
    "success": true,
    "duration": migrationTime,
    "errors": errorCount
])
```

## FAQ

**Q: Will I lose my photos during migration?**
A: No, all photos remain safely stored. Migration only updates account structure.

**Q: Do I need to sign in again?**
A: No, you'll remain signed in after updating.

**Q: Can I still use only Apple Sign-In?**
A: Yes, adding Google is optional. Apple Sign-In continues to work.

**Q: What if I have multiple Apple IDs?**
A: Each Apple ID maintains its own account. You can link them later if desired.