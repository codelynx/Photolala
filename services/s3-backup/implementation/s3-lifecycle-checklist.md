# S3 Lifecycle Configuration Checklist

## Pre-Configuration

- [ ] **Verify S3 Bucket**
  - Bucket name: `photolala`
  - Region: Document which region is used
  - Ensure bucket has proper IAM permissions

- [ ] **Review Current Storage Usage**
  - Check current storage class distribution
  - Note total storage size
  - Identify any test data that should be excluded

- [ ] **Backup Current Configuration**
  - Export current bucket policy
  - Document any existing lifecycle rules
  - Save current cost baseline

## Configuration Steps

### 1. Basic Lifecycle Rules

- [ ] **Photo Archive Rule**
  - Name: `archive-user-photos`
  - Prefix: `users/*/photos/`
  - Transition: 180 days → DEEP_ARCHIVE
  - Status: Enabled

- [ ] **Thumbnail Optimization Rule**
  - Name: `optimize-thumbnails`
  - Prefix: `users/*/thumbnails/`
  - Transition: 0 days → INTELLIGENT_TIERING
  - Status: Enabled

- [ ] **Metadata Preservation**
  - Verify NO rules affect `users/*/metadata/`
  - Metadata must remain in STANDARD

### 2. Cleanup Rules

- [ ] **Incomplete Uploads**
  - Rule name: `cleanup-incomplete-uploads`
  - Action: Abort incomplete multipart uploads
  - Days: 7
  - Apply to entire bucket

### 3. Advanced Configuration

- [ ] **Intelligent Tiering for Thumbnails**
  - Archive Access: 90 days
  - Deep Archive Access: 180 days
  - Configure in Intelligent-Tiering settings

- [ ] **Storage Class Analysis**
  - Enable for the bucket
  - Configure daily export to S3
  - Set up 30-day analysis period

## Verification

- [ ] **Test Rules**
  - Upload test file with photo prefix
  - Verify lifecycle rules are attached
  - Check rule evaluation in S3 console

- [ ] **Monitor Initial Transition**
  - Set CloudWatch alarm for storage class changes
  - Monitor first transition event (day 180)
  - Verify cost reduction

- [ ] **Check App Compatibility**
  - Test app with archived photos
  - Verify retrieval UI works correctly
  - Confirm metadata remains accessible

## Cost Monitoring

- [ ] **Set Up Alerts**
  - Deep Archive storage growth
  - Retrieval request costs
  - Early deletion charges

- [ ] **Create Dashboard**
  - Storage by class over time
  - Retrieval frequency
  - Cost trends

## Documentation

- [ ] **Update User Documentation**
  - Explain 6-month archive policy
  - Document retrieval process
  - Include cost expectations

- [ ] **Update Technical Docs**
  - Document lifecycle rules
  - Include rollback procedures
  - Add troubleshooting guide

## Communication

- [ ] **Notify Users**
  - Email about upcoming change
  - In-app notification
  - FAQ updates

- [ ] **Support Preparation**
  - Train support on archive/retrieval
  - Create response templates
  - Document common issues

## Post-Implementation

### Week 1
- [ ] Monitor for any issues
- [ ] Check CloudWatch metrics
- [ ] Review any user feedback

### Month 1
- [ ] Analyze storage class distribution
- [ ] Review cost savings
- [ ] Optimize rules if needed

### Month 6
- [ ] Verify first archive transition
- [ ] Test retrieval process
- [ ] Calculate actual cost savings

## Rollback Plan

If issues arise:

1. **Immediate Actions**
   - [ ] Disable lifecycle rules
   - [ ] Document issue details
   - [ ] Notify stakeholders

2. **Recovery Steps**
   - [ ] Assess impact
   - [ ] Plan remediation
   - [ ] Execute fixes

3. **Post-Mortem**
   - [ ] Document lessons learned
   - [ ] Update procedures
   - [ ] Implement safeguards

## Sign-Off

- [ ] Technical Lead: _________________ Date: _______
- [ ] Product Manager: _______________ Date: _______
- [ ] DevOps Engineer: _______________ Date: _______

## Notes

_Add any specific notes or concerns here:_

_______________________________________________
_______________________________________________
_______________________________________________