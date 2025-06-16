# Pricing Changes Summary

## What We Changed

### Storage Tiers - Updated to Profitable Model
| Tier | Old Storage | New Storage | Price | Change |
|------|-------------|-------------|-------|---------|
| Free | 5GB | **200MB** | $0 | -96% |
| Starter | 200GB | **500GB** | $0.99 | +150% |
| Essential | 2TB | **1TB** | $1.99 | -50% |
| Plus | 6TB | **1.5TB** | $2.99 | -75% |
| Family | 12TB | **1.5TB** | $5.99 | -87.5% |

### Why These Changes?

1. **Profitability**: With Apple's 30% cut, we need margins
   - Old model would lose money on every user
   - New model maintains 20% profit margin

2. **Smart Storage Strategy**:
   - Photos: 2 days hot → Glacier Instant ($0.004/GB)
   - Thumbnails: 7 days hot → Standard-IA ($0.0125/GB)
   - Metadata: Always Standard-IA

3. **User Experience**:
   - Users have local copies, don't need instant access to old photos
   - Thumbnails always browsable
   - 12-24 hour retrieval is acceptable for old photos

## Files Updated

1. **IdentityManager.swift**: Storage limits
2. **SubscriptionView.swift**: Display strings
3. **SignInPromptView.swift**: Free tier description
4. **PhotolalaProducts.storekit**: Product descriptions
5. **iap-testing-guide.md**: Documentation

## Key Marketing Messages

- **Starter ($0.99)**: "Store 100,000 photos"
- **Essential ($1.99)**: "Store 200,000 photos" 
- **Plus ($2.99)**: "Store 300,000 photos"
- **Family ($5.99)**: "Share 300,000 photos with family"

## Next Steps

1. Test the new limits thoroughly
2. Update any remaining UI strings
3. Implement S3 lifecycle policies for different data types
4. Consider removing Family tier price if keeping at $5.99 (currently shows as option)