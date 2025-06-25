# Next Steps for S3 Backup Service

Last Updated: January 17, 2025

## Immediate Priorities (Before TestFlight)

### 1. Complete Usage Tracking UI
**Status**: Code written, needs integration
**Tasks**:
- [ ] Add files to Xcode project (StorageUsage.swift, UsageTrackingService.swift)
- [ ] Create StorageUsageView for subscription screen
- [ ] Integrate usage check before uploads
- [ ] Test with various photo library sizes
- [ ] Add refresh button and loading states

### 2. AWS Infrastructure Setup
**Status**: Design complete, needs execution
**Tasks**:
- [ ] Configure S3 lifecycle rules (use configure-s3-lifecycle-final.sh)
- [ ] Set up CloudWatch monitoring (follow monitoring-setup-checklist.md)
- [ ] Create IAM roles for STS
- [ ] Test with production credentials
- [ ] Verify cost controls are in place

### 3. Complete IAP Integration
**Status**: Mostly complete, needs polish
**Tasks**:
- [ ] Add IAPDeveloperView.swift to Xcode
- [ ] Test subscription flow end-to-end
- [ ] Verify receipt validation works
- [ ] Test upgrade/downgrade scenarios
- [ ] Add restore purchases flow

## Before App Store Release

### 4. Production Receipt Validation
**Status**: Local validation only
**Options**:
1. AWS Lambda endpoint
2. Third-party service (RevenueCat)
3. Simple webhook receiver

### 5. User Documentation
**Status**: Not started
**Needed**:
- How backup works
- Understanding storage limits
- Archive retrieval process
- Pricing explanation
- FAQ section

### 6. Error Handling & Recovery
**Status**: Basic implementation
**Improvements needed**:
- Network error retry logic
- Partial upload recovery
- Clear error messages
- Offline mode handling

## Post-Launch Enhancements

### 7. Performance Optimizations
- Parallel uploads
- Smart chunking for large files
- Background upload support
- Incremental usage calculation

### 8. Advanced Features
- Family sharing implementation
- Usage trends and analytics
- Automated archive suggestions
- Multi-device sync

## Technical Debt to Address

1. **Add all new files to Xcode project**
2. **Remove duplicate/obsolete code**
3. **Consolidate error handling**
4. **Add comprehensive logging**
5. **Write unit tests for critical paths**

## MVP Definition

For the initial TestFlight release, we need:
- ✅ Sign in with Apple
- ✅ S3 upload/download
- ✅ Archive retrieval UI
- ✅ IAP subscriptions
- ✅ Local receipt validation
- 🚧 Usage tracking UI
- 🚧 CloudWatch monitoring
- ❌ Production receipt validation (can wait)
- ❌ User documentation (can be minimal)

## Risk Mitigation

1. **Cost Overrun**: CloudWatch alerts at $100/day
2. **Abuse**: Usage tracking prevents massive uploads
3. **Data Loss**: S3 versioning enabled
4. **Security**: STS temporary credentials only
5. **Scaling**: Start with invite-only TestFlight

## Questions to Resolve

1. Should we implement server-side receipt validation before TestFlight?
2. Do we need Terms of Service for backup feature?
3. How do we handle users who cancel with data still in S3?
4. Should we add a "delete all backups" option?
5. What's our support strategy for backup issues?