# Local IAP Testing Guide (macOS)

This guide explains how to test In-App Purchases locally on macOS without creating an archive.

## Method 1: StoreKit Configuration (Recommended) ✅

This is the easiest and fastest method using the existing `PhotolalaProducts.storekit` file.

### Setup:
1. Open `Photolala.xcodeproj` in Xcode
2. Edit Scheme (⌘<):
   - Run → Options
   - StoreKit Configuration: Select `PhotolalaProducts.storekit`
3. Build and run (⌘R)

### Testing:
- All purchases are simulated locally
- No sandbox account needed
- Instant purchase completion
- Can test all scenarios immediately

### Debug Tools:
- **Debug Menu**: Debug → IAP Test Panel (⇧⌘T)
- **Console Output**: Debug → Print IAP Status

## Method 2: Xcode StoreKit Testing

### Transaction Manager:
1. Open Xcode
2. Window → StoreKit Transaction Manager
3. You can:
   - View all transactions
   - Delete transactions to test restore
   - Simulate failures
   - Speed up subscription renewals

### Testing Scenarios:

#### New Purchase:
1. Run app with StoreKit configuration
2. Go to Settings → Subscriptions
3. Select a tier and purchase
4. Transaction completes instantly

#### Restore Purchases:
1. Delete app data (if needed)
2. Click "Restore Purchases"
3. Previous purchases restore instantly

#### Subscription Management:
1. Purchase a subscription
2. Use Transaction Manager to:
   - Expire subscription
   - Cancel subscription
   - Upgrade/downgrade

## Method 3: Sandbox Testing (Without Archive)

### Setup:
1. Create sandbox tester in App Store Connect
2. Sign out of Mac App Store
3. Run app from Xcode (⌘R)
4. Sign in with sandbox account when prompted

### Notes:
- Slower than StoreKit configuration
- Requires internet connection
- More realistic testing

## Debug Panel Features

The IAP Debug Panel (⇧⌘T) shows:
- Product loading status
- Active subscription
- Purchased product IDs
- Quick actions:
  - Open subscription view
  - Refresh products
  - Restore purchases
  - Print debug info

## Common Issues

### Products Not Loading:
- Ensure StoreKit configuration is selected
- Check bundle ID matches
- Verify product IDs match configuration

### Purchases Not Persisting:
- StoreKit configuration resets on app restart
- Use Transaction Manager to persist state
- Or use sandbox testing for persistence

### Debug Menu Not Showing:
- Only available in Debug builds
- Ensure you're running Debug scheme
- Check that `#if DEBUG` is working

## Quick Test Checklist

- [ ] Products load and display prices
- [ ] Can purchase each tier
- [ ] Subscription status updates after purchase
- [ ] Restore purchases works
- [ ] Manage subscription button works
- [ ] Family sharing option visible on Family tier
- [ ] UI updates correctly after purchase
- [ ] "Coming Soon" badges display correctly

## Tips

1. **Fast Testing**: Use StoreKit configuration for rapid iteration
2. **Realistic Testing**: Use sandbox for final validation
3. **Debug Output**: Enable console output to see transaction flow
4. **Reset State**: Use Transaction Manager to clear all transactions

The StoreKit configuration method is perfect for development and debugging IAP flows without the complexity of sandbox testing or archiving!