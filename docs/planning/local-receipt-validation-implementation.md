# Local Receipt Validation Implementation

## Overview

This document describes how to implement local receipt validation for development and testing purposes. This is useful for understanding how receipt validation works before implementing server-side validation for production.

## Implementation

### 1. LocalReceiptValidator.swift

Created a local receipt validator that:
- Uses StoreKit 2's `Transaction.currentEntitlements` for modern validation
- Optionally validates with Apple's sandbox server
- Returns subscription status and active products

Key features:
- **StoreKit 2 validation**: Uses Apple's built-in transaction verification
- **Sandbox server validation**: Optional validation with Apple's servers
- **Subscription hierarchy**: Automatically selects highest tier subscription

### 2. ReceiptValidationTestView.swift

A test UI that shows:
- Receipt existence and size
- StoreKit 2 validation results
- Active subscription details
- Sandbox server validation (optional)

### 3. Integration with IAP Developer Tools

To add the Receipt Validation Test button to IAPDeveloperView:

```swift
// In the Debug Actions section, after "View Receipt" button:
#if os(macOS)
Button("Receipt Validation Test") {
    openReceiptValidationWindow()
}
.frame(maxWidth: .infinity)
#endif

// Add this method at the end of the macOS section:
private func openReceiptValidationWindow() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false
    )
    
    window.title = "Receipt Validation Test"
    window.center()
    window.contentView = NSHostingView(rootView: ReceiptValidationTestView())
    window.makeKeyAndOrderFront(nil)
    
    window.level = .normal
    window.isReleasedWhenClosed = false
}
```

## How It Works

### StoreKit 2 Validation (Recommended)

1. Uses `Transaction.currentEntitlements` to get verified transactions
2. Filters for subscription products
3. Checks expiration dates
4. Returns active subscription status

### Sandbox Server Validation

1. Reads receipt from `Bundle.main.appStoreReceiptURL`
2. Base64 encodes the receipt data
3. Sends to Apple's sandbox validation endpoint
4. Parses response for subscription status

## Security Considerations

**IMPORTANT**: Local receipt validation is for development only!

For production:
1. **Never validate receipts on device** - Can be bypassed
2. **Use server-side validation** - Send receipt to your server
3. **Server validates with Apple** - Your server talks to Apple
4. **Store subscription status** - Track in your database
5. **Use shared secret** - Store securely on server, not in app

## Testing Receipt Validation

1. Make a sandbox purchase in the app
2. Open IAP Developer Tools
3. Click "Receipt Validation Test"
4. View validation results

The validation will show:
- Whether a receipt exists
- Active subscription details
- All purchased products
- Validation errors (if any)

## Next Steps for Production

1. **Set up server endpoint** (AWS Lambda recommended)
2. **Implement server-side validation** with Apple's production URL
3. **Store subscription status** in database (DynamoDB)
4. **Add receipt refresh** logic for expired subscriptions
5. **Implement webhook handling** for subscription events

## Benefits of Local Testing

- Understand receipt structure
- Test validation logic
- Debug subscription issues
- Verify StoreKit 2 integration
- No server setup required for development