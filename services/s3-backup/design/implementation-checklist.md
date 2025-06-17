# Implementation Checklist - V5 Pricing Strategy

Last Updated: June 16, 2025

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

## 4. S3 Path Structure 🔄 IN PROGRESS
- Current: users/{userId}/photos/, users/{userId}/thumbs/, users/{userId}/metadata/
- New: photos/{userId}/, thumbnails/{userId}/, metadata/{userId}/
- Need to update S3BackupService paths ❌

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

## 7. Update Documentation 🔄 IN PROGRESS
- CURRENT-pricing-strategy.md ✅ Updated to V5
- s3-backup-service-design.md ✅ Updated paths and lifecycle
- key-decisions.md ✅ Updated with universal policy
- implementation-checklist.md ✅ This file
- Other docs need updates ❌

## Summary
- Storage limits: ✅ Free tier now 5GB, all tiers updated
- Quota logic: ✅ Only photos count, thumbnails/metadata free
- Path structure: 🔄 Need to implement new structure in code
- Lifecycle policy: ✅ Universal 180-day archive designed
- Retrieval UX: ✅ Fully implemented
- Documentation: 🔄 Core docs updated, more to go

Next Steps:
1. Update S3BackupService to use new path structure
2. Run configure-s3-lifecycle-final.sh
3. Update remaining documentation
4. Test end-to-end with new structure