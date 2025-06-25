# IAP-Only TestFlight Build Summary

## Changes Made for TestFlight

### 1. Feature Flags (`FeatureFlags.swift`)
Created feature flags to disable S3 features:
- `isS3BackupEnabled = false` - Hides backup functionality
- `isArchiveRetrievalEnabled = false` - Disables archive retrieval
- `showComingSoonBadges = true` - Shows "Coming Soon" indicators

### 2. UI Updates
- **PhotoBrowserView**: Backup button hidden when S3 is disabled
- **PhotoCollectionViewController**: Archive retrieval disabled
- **SubscriptionView**: Added "Coming Soon" badges to backup features

### 3. New Components
- **ComingSoonBadge.swift**: Visual indicator for upcoming features
- Displays orange "Coming Soon" badge on disabled features

## Build Checklist

### Before Creating Archive

1. **Update Build Settings**:
   ```
   Version: 1.0.0
   Build: 1 (increment for each upload)
   ```

2. **Add to Info.plist** (in Target Settings):
   ```xml
   ITSAppUsesNonExemptEncryption = NO
   NSPhotoLibraryUsageDescription = "Photolala needs access to your photos to organize and display them."
   ```

3. **Verify Bundle ID**:
   ```
   com.electricwoods.photolala
   ```

4. **Add New Files to Project**:
   - FeatureFlags.swift
   - ComingSoonBadge.swift

### TestFlight Submission

1. **Create Archive**:
   - Select "Any iOS Device (arm64)"
   - Product → Archive

2. **Upload to App Store Connect**:
   - Distribute App → App Store Connect → Upload

3. **In App Store Connect**:
   - Add build notes from `testflight-notes-iap-only.md`
   - Enable for internal testing first
   - Add external testers after initial validation

## Testing Priorities

### High Priority
1. All four subscription tiers purchase correctly
2. Restore purchases works after reinstall
3. Subscription status displays properly
4. Family sharing works for Family tier

### Medium Priority
1. UI/UX is intuitive
2. "Coming Soon" badges display correctly
3. No crashes during normal use

### Low Priority
1. Performance optimization
2. Edge case handling

## Success Criteria

- [ ] Can purchase all subscription tiers
- [ ] Subscriptions restore after app deletion
- [ ] UI clearly shows what's available vs coming soon
- [ ] No crashes in 100+ test sessions
- [ ] Family sharing works as expected

## Next Steps After TestFlight

1. Monitor crash reports and feedback
2. Fix any IAP issues discovered
3. Plan backend deployment for receipt validation
4. Schedule S3 feature development
5. Prepare for public App Store release