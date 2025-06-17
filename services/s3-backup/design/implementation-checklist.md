# Implementation Checklist - V5 Pricing Strategy

Last Updated: January 17, 2025

## 1. Update Storage Limits ✅ DONE
- Free: 5GB ✓ (Updated from 200MB)
- Starter: 500GB ✓
- Essential: 1TB ✓
- Plus: 2TB ✓
- Family: 5TB ✓

## 2. Update Quota Logic ✅ DONE
- Only count photos against quota ✓
- Thumbnails/metadata don't count ✓
- BackupStats.quotaUsed only returns photoSize ✓

## 3. Update UI Strings ✅ DONE
- Change "1TB storage" → "1TB for photos" ✓ (Already says "1TB Photos")
- Bonus storage tracked separately ✓ (bonusSizeFormatted)
- SubscriptionView uses "Photos" terminology ✓

## 4. S3 Path Structure ✅ DONE
- Current: users/{userId}/photos/, users/{userId}/thumbs/, users/{userId}/metadata/
- New: photos/{userId}/, thumbnails/{userId}/, metadata/{userId}/
- Updated S3BackupService paths ✓

## 5. S3 Storage Classes & Lifecycle ✅ DESIGNED
- Photos: Standard → Deep Archive after 180 days ✓
- Thumbnails: Intelligent-Tiering immediately ✓
- Metadata: Always Standard ✓
- S3 Lifecycle Rules: Script ready (configure-s3-lifecycle-final.sh) ✓

## 6. Retrieval UX ✅ DONE
- Show "archived" badge on old photos ✓
- PhotoRetrievalView with restore options ✓
- Batch photo selection support ✓
- Track restore requests ✓

## 7. Update Documentation ✅ DONE
- CURRENT-pricing-strategy.md ✅ Updated to V5
- s3-lifecycle-configuration.md ✅ Updated paths
- key-decisions.md ✅ Updated with universal policy
- implementation-checklist.md ✅ This file
- Obsolete scripts archived ✅

## 8. IAP Integration ✅ DONE
- StoreKit 2 configuration ✅
- PhotolalaProducts.storekit file ✅
- IAPManager service ✅
- Subscription UI ✅
- Local receipt validation ✅
- IAP Developer Tools ✅

## 9. Usage Tracking 🚧 IN PROGRESS
- Design completed ✅
- Client-side approach documented ✅
- StorageUsage model created ✅
- UsageTrackingService created ✅
- UI implementation pending ⏳
- Upload integration pending ⏳

## 10. Monitoring Setup ✅ DESIGNED
- CloudWatch monitoring design ✅
- Setup checklist created ✅
- No Lambda required ✅
- Manual AWS Console setup ✅
- Cost: ~$10-50/month ✅

## Summary
- Storage limits: ✅ Free tier now 5GB, all tiers updated
- Quota logic: ✅ Only photos count, thumbnails/metadata free
- Path structure: ✅ New structure implemented in code
- Lifecycle policy: ✅ Universal 180-day archive designed
- IAP system: ✅ Complete with developer tools
- Usage tracking: 🚧 Designed, implementation in progress
- Monitoring: ✅ Ready for AWS Console setup
- Retrieval UX: ✅ Fully implemented
- Documentation: ✅ All core docs updated

Next Steps:
1. Run configure-s3-lifecycle-final.sh in production
2. Set up AWS infrastructure (STS, IAM roles)
3. Test IAP subscriptions with TestFlight
4. Build backend services for usage tracking