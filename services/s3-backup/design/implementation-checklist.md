# Implementation Checklist - New Pricing Strategy

## 1. Update Storage Limits ✅ DONE
- Free: 200MB ✓
- Starter: 500GB ✓
- Essential: 1TB ✓
- Plus: 2TB ✓ (Updated from 1.5TB)
- Family: 5TB ✓ (Updated from 1.5TB)

## 2. Update Quota Logic ✅ DONE
- Only count photos against quota ✓
- Thumbnails/metadata don't count ✓
- BackupStats.quotaUsed only returns photoSize ✓

## 3. Update UI Strings ✅ DONE
- Change "1TB storage" → "1TB for photos" ✓ (Already says "1TB Photos")
- Bonus storage tracked separately ✓ (bonusSizeFormatted)
- SubscriptionView uses "Photos" terminology ✓

## 4. S3 Storage Classes ✅ PARTIALLY DONE
- Photos: Uploaded directly to Deep Archive ✓
- Thumbnails: Uploaded to Standard ✓
- Metadata: Not yet implemented ❌
- S3 Lifecycle Rules: Must be configured in AWS Console ❌

## 5. Retrieval UX ❌ TODO
- Show "archived" badge on old photos
- Add restore button with 24-48hr warning
- Track restore requests

## 6. Update Documentation ✅ DONE
- Created current-status.md with implementation details ✓
- Technical documentation updated ✓
- User-facing docs still needed for production

## Summary
- Storage limits: ✅ Updated to new pricing (2TB Plus, 5TB Family)
- Quota logic: ✅ Only photos count, bonus storage free
- UI strings: ✅ Already using "Photos" terminology
- Storage classes: ✅ Deep Archive for photos, Standard for thumbnails
- Documentation: ✅ Technical docs updated

Remaining work focuses on production deployment and archive retrieval UX.