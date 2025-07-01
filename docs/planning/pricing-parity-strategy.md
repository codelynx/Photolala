# Pricing Parity Strategy - iOS and Android

## Overview

Photolala maintains identical pricing across iOS and Android platforms to ensure fairness and simplicity for users. This document defines the pricing structure that MUST be implemented on both platforms.

## Core Principle

**Same Service, Same Price** - Users get identical features and storage at the same price point, regardless of platform.

## Subscription Tiers

### Official Pricing Structure

| Tier | Monthly Price | Storage | Max Accounts | Features |
|------|--------------|---------|--------------|----------|
| **Free** | $0 | 5 GB | 1 | - Basic photo backup<br>- Limited features |
| **Basic** | $2.99 | 100 GB | 1 | - Full photo backup<br>- All features |
| **Standard** | $9.99 | 1 TB | 1 | - Full photo backup<br>- All features |
| **Pro** | $39.99 | 5 TB | 1 | - Full photo backup<br>- All features |
| **Family** | $69.99 | 10 TB | 5 | - Shared storage<br>- Family sharing |

## Implementation Requirements

### iOS (Already Implemented)
```swift
enum SubscriptionTier: String {
    case free = "com.photolala.free"
    case basic = "com.photolala.basic.monthly"      // $2.99
    case standard = "com.photolala.standard.monthly" // $9.99
    case pro = "com.photolala.pro.monthly"          // $39.99
    case family = "com.photolala.family.monthly"     // $69.99
}
```

### Android (Must Match)
```kotlin
enum class SubscriptionTier(val sku: String, val price: String) {
    FREE("com.electricwoods.photolala.free", "$0"),
    BASIC("com.electricwoods.photolala.basic.monthly", "$2.99"),
    STANDARD("com.electricwoods.photolala.standard.monthly", "$9.99"),
    PRO("com.electricwoods.photolala.pro.monthly", "$39.99"),
    FAMILY("com.electricwoods.photolala.family.monthly", "$69.99")
}
```

## Storage Limits (Exact Match Required)

| Tier | Storage Limit | In Bytes |
|------|---------------|----------|
| Free | 5 GB | 5,368,709,120 |
| Basic | 100 GB | 107,374,182,400 |
| Standard | 1 TB | 1,099,511,627,776 |
| Pro | 5 TB | 5,497,558,138,880 |
| Family | 10 TB | 10,995,116,277,760 |

## Payment Processing

### Phase 1: Platform Payment Systems
- **iOS**: Apple In-App Purchase (30% fee)
- **Android**: Google Play Billing (30% fee)
- **User Experience**: Native, trusted payment flow

### Phase 2: Web Payments (Future)
- **Both Platforms**: Stripe web payments
- **Discount**: 20% off for direct payments
- **Pricing**: 
  - Basic: $2.39 (was $2.99)
  - Standard: $7.99 (was $9.99)
  - Pro: $31.99 (was $39.99)
  - Family: $55.99 (was $69.99)

## Localization

### Currency Support
- **Primary**: USD ($)
- **Automatic**: Platform handles local currency conversion
- **Display**: Always show USD equivalent

### Regional Pricing
- **Current**: US pricing only
- **Future**: May add regional pricing tiers
- **Requirement**: Must maintain parity between platforms

## Marketing Messages

### Approved Messages
✅ "Same price on iOS and Android"
✅ "5 GB free storage on all platforms"
✅ "Upgrade anytime, cancel anytime"
✅ "Family plan supports up to 5 accounts"

### Never Use
❌ "Cheaper than competitor X"
❌ "Platform-exclusive pricing"
❌ "Limited time pricing"
❌ Different prices on different platforms

## Technical Implementation

### Price Validation
Both platforms must validate that displayed prices match this document:

```kotlin
// Android example
fun validatePricing(tier: SubscriptionTier, displayPrice: String): Boolean {
    return when(tier) {
        SubscriptionTier.FREE -> displayPrice == "$0"
        SubscriptionTier.BASIC -> displayPrice == "$2.99"
        SubscriptionTier.STANDARD -> displayPrice == "$9.99"
        SubscriptionTier.PRO -> displayPrice == "$39.99"
        SubscriptionTier.FAMILY -> displayPrice == "$69.99"
    }
}
```

## Update Process

### If Prices Change:
1. Update this document FIRST
2. Update iOS app
3. Update Android app
4. Update marketing materials
5. Deploy both apps simultaneously

### Version Control
- Document version: 1.0
- Last updated: 2024-01-07
- Approved by: Product Team

## Compliance

### App Store Requirements
- Apple requires IAP for digital goods ✅
- Google requires Play Billing for digital goods ✅
- Both allow showing same prices ✅

### Legal Requirements
- Prices include all fees
- No hidden charges
- Clear subscription terms
- Easy cancellation

## FAQs

**Q: Can we have Android-only promotions?**
A: No. All promotions must be available on both platforms.

**Q: What if exchange rates change?**
A: USD prices remain fixed. Local currency handled by platforms.

**Q: Can we test different prices?**
A: Only in separate test environments, never in production.

## Conclusion

Pricing parity is non-negotiable. Users must see the same prices and get the same value regardless of their chosen platform. This builds trust and simplifies our pricing strategy.