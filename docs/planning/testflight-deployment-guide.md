# TestFlight Deployment Guide

This guide covers deploying Photolala to TestFlight for testing In-App Purchase subscriptions and the S3 backup service.

## Prerequisites

- [ ] Apple Developer Program membership ($99/year)
- [ ] Xcode 15.0 or later
- [ ] Valid signing certificates and provisioning profiles
- [ ] App Store Connect access

## Step 1: Configure App Store Connect

### 1.1 Create App in App Store Connect

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. Fill in the details:
   - **Platform**: iOS
   - **Name**: Photolala
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: com.electricwoods.Photolala
   - **SKU**: PHOTOLALA001

### 1.2 Configure In-App Purchases

Navigate to "My Apps" → "Photolala" → "Monetization" → "In-App Purchases"

The following subscriptions should already be configured (from PhotolalaProducts.storekit):
- `com.electricwoods.photolala.starter` - Starter (500GB) - $0.99/month
- `com.electricwoods.photolala.essential` - Essential (1TB) - $1.99/month  
- `com.electricwoods.photolala.plus` - Plus (2TB) - $2.99/month
- `com.electricwoods.photolala.family` - Family (5TB) - $5.99/month

For each subscription, ensure:
- Status is "Ready to Submit"
- Localization is complete
- Review screenshot is uploaded
- Subscription group is set

### 1.3 Create Sandbox Test Accounts

1. Go to "Users and Access" → "Sandbox Testers"
2. Create at least 3 test accounts:
   - One for testing new subscriptions
   - One for testing upgrades/downgrades
   - One for testing cancellations

## Step 2: Prepare Build for TestFlight

### 2.1 Update Build Settings

In Xcode:

1. Select the Photolala project
2. Select the Photolala target
3. Go to "Signing & Capabilities"
4. Ensure:
   - [ ] Team is set to your developer account
   - [ ] Automatically manage signing is enabled
   - [ ] Bundle identifier matches App Store Connect

### 2.2 Configure Entitlements

Verify these capabilities are enabled:
- [ ] In-App Purchase
- [ ] iCloud (if using CloudKit)
- [ ] Access WiFi Information (for S3 uploads)
- [ ] Background Modes → Background fetch (for backup)

### 2.3 Increment Build Number

1. Select project → Photolala target → General
2. Update version (e.g., 1.0.0)
3. Increment build number (e.g., 1, 2, 3...)

### 2.4 Add Export Compliance Information

In Info.plist, add:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

## Step 3: Archive and Upload

### 3.1 Create Archive

1. Select target device: "Any iOS Device (arm64)"
2. Product → Archive
3. Wait for archive to complete

### 3.2 Upload to App Store Connect

1. In Organizer, select your archive
2. Click "Distribute App"
3. Select "App Store Connect" → Next
4. Select "Upload" → Next
5. Check options:
   - [ ] Include bitcode (optional)
   - [ ] Upload symbols
6. Click "Next" → "Upload"

### 3.3 Configure TestFlight Build

After upload completes (5-30 minutes):

1. Go to App Store Connect → TestFlight
2. Wait for "Processing" to complete
3. Add build notes:
   ```
   What to Test:
   - In-App Purchase subscriptions
   - Photo backup to S3
   - Archive retrieval (photos older than 6 months)
   - Subscription upgrade/downgrade
   ```
4. Add test groups

## Step 4: TestFlight Testing Checklist

### 4.1 Subscription Testing

- [ ] **Initial Purchase**
  - Launch app as new user
  - Navigate to subscription view
  - Purchase each tier
  - Verify UI updates correctly
  - Check receipt validation

- [ ] **Restore Purchases**
  - Delete and reinstall app
  - Tap "Restore Purchases"
  - Verify subscription restored

- [ ] **Upgrade/Downgrade**
  - Start with Starter tier
  - Upgrade to Essential
  - Verify prorated pricing
  - Downgrade back to Starter
  - Check effective dates

- [ ] **Cancellation**
  - Cancel subscription in Settings
  - Verify grace period handling
  - Test resubscription

### 4.2 S3 Backup Testing

- [ ] **Upload Photos**
  - Select folder with test photos
  - Monitor upload progress
  - Verify S3 storage (check AWS Console)
  - Check quota enforcement

- [ ] **Archive Retrieval**
  - Find photos marked as archived
  - Test single photo retrieval
  - Test batch retrieval
  - Verify cost calculations

- [ ] **Storage Stats**
  - Check storage usage display
  - Verify quota calculations
  - Test near-quota warnings

### 4.3 Edge Cases

- [ ] **Network Issues**
  - Test with airplane mode
  - Test with slow connection
  - Verify retry logic

- [ ] **Subscription States**
  - Expired subscription
  - Payment failed
  - Free tier limits

## Step 5: Common Issues and Solutions

### Issue: "Invalid Product IDs"
**Solution**: Ensure agreements are signed in App Store Connect

### Issue: "Cannot connect to iTunes Store"
**Solution**: 
- Check sandbox environment
- Verify test account is signed out of production App Store
- Ensure device date/time is correct

### Issue: Subscription not showing after purchase
**Solution**:
- Check receipt validation
- Verify Transaction.currentEntitlements
- Ensure IAPManager is observing transactions

### Issue: S3 upload fails
**Solution**:
- Verify AWS credentials in Keychain
- Check IAM permissions
- Ensure S3 bucket exists
- Check lifecycle policies

## Step 6: TestFlight Beta Review

### 6.1 Beta App Review Information

Provide:
- Demo account credentials (if needed)
- Instructions for testing IAP
- Contact information
- Notes about S3 backup (external service)

### 6.2 Export Compliance

Since we use HTTPS/TLS:
- Select "Yes" for encryption
- Select "HTTPS only" exemption

## Step 7: Monitoring and Metrics

### 7.1 TestFlight Metrics

Monitor:
- Crash reports
- User feedback
- Session data
- Installation stats

### 7.2 AWS Monitoring

Check:
- S3 bucket metrics
- STS token generation
- Error rates
- Data transfer costs

## Step 8: Test Account Management

### Managing Sandbox Subscriptions

To clear sandbox purchases:
1. Settings → App Store → Sandbox Account
2. Manage → View subscriptions
3. Clear purchase history (iOS 15.2+)

### Sandbox Testing Tips

- Subscriptions renew every 5 minutes (monthly)
- Maximum 6 renewals per subscription
- Clear purchase history between major tests
- Use different sandbox accounts for different scenarios

## Pre-Launch Checklist

Before wide release:

- [ ] All subscription tiers tested
- [ ] Receipt validation working
- [ ] S3 uploads successful
- [ ] Archive retrieval tested
- [ ] Crash-free for 100+ sessions
- [ ] Performance acceptable
- [ ] Quota enforcement working
- [ ] Error handling verified
- [ ] Privacy policy updated
- [ ] Terms of service updated

## Next Steps

After successful TestFlight testing:

1. Implement receipt validation endpoint
2. Set up production monitoring
3. Prepare for App Store submission
4. Create user documentation
5. Plan launch marketing