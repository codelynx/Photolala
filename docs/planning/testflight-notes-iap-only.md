# TestFlight Build Notes - IAP Testing Focus

## What's New
- In-App Purchase subscriptions for upcoming backup service
- Four subscription tiers: Starter, Essential, Plus, and Family
- Subscription management and restore functionality
- Family sharing support for Family tier

## Test Focus Areas

### 1. Purchase Flow
- Tap Settings → Subscriptions
- Browse the four available plans
- Complete a purchase with your sandbox account
- Verify the subscription shows as active

### 2. Subscription Management
- View current subscription status
- Test "Manage Subscription" to see App Store options
- Verify expiration date displays correctly

### 3. Restore Purchases
- Delete and reinstall the app
- Tap "Restore Purchases" button
- Confirm subscription is restored

### 4. Upgrade/Downgrade
- Start with Starter tier ($0.99)
- Upgrade to Essential ($1.99)
- Verify the upgrade process
- Try downgrading back

### 5. Family Sharing (Family Tier Only)
- Purchase Family tier ($5.99)
- Have family member install app
- Verify they can access the subscription

## Important Notes

- **Sandbox Testing**: Subscriptions renew every 5 minutes in sandbox
- **Coming Soon**: Features marked "Coming Soon" will be available in future updates
- **Photo Browsing**: Current functionality includes photo browsing and organization
- **No Backup Yet**: Cloud backup features are not active in this build

## Known Issues
- Receipt validation is performed locally (server validation coming soon)
- "Coming Soon" badges indicate features under development

## How to Report Issues
Please use TestFlight's feedback feature to report any issues with:
- Purchase failures
- Subscription status not updating
- UI/UX problems
- Crashes or freezes

Thank you for testing Photolala!