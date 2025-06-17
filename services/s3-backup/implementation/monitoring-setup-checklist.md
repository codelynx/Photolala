# CloudWatch Monitoring Setup Checklist

This checklist guides you through setting up basic monitoring for the Photolala S3 backup service using the AWS Console. No scripts or Lambda functions required.

## Prerequisites
- [ ] AWS account with admin access
- [ ] S3 bucket created (photolala-backup)
- [ ] Email address for alerts

## Step 1: Enable S3 Metrics (5 minutes)
1. [ ] Go to S3 Console → Select bucket
2. [ ] Metrics tab → Request metrics → Create filter
3. [ ] Filter name: "all-requests"
4. [ ] Prefix: leave empty (monitor all)
5. [ ] Save

## Step 2: Create Cost Alert (5 minutes)
1. [ ] Go to CloudWatch Console → Alarms → Create Alarm
2. [ ] Select metric → Billing → Total Estimated Charges
3. [ ] Currency: USD
4. [ ] Period: 1 day
5. [ ] Threshold: Static → Greater than → $100
6. [ ] Configure actions → Create new SNS topic
7. [ ] Topic name: "photolala-cost-alerts"
8. [ ] Email endpoint: your-email@example.com
9. [ ] Create topic → Confirm subscription via email
10. [ ] Alarm name: "Photolala High Daily Cost"
11. [ ] Create alarm

## Step 3: Create Storage Size Alert (5 minutes)
1. [ ] CloudWatch Console → Alarms → Create Alarm
2. [ ] Select metric → S3 → Storage Metrics
3. [ ] Find your bucket → BucketSizeBytes → StandardStorage
4. [ ] Period: 1 day
5. [ ] Threshold: Static → Greater than → 50,000,000,000,000 (50TB)
6. [ ] Use existing SNS topic: "photolala-cost-alerts"
7. [ ] Alarm name: "Photolala Storage Exceeds 50TB"
8. [ ] Create alarm

## Step 4: Create Request Rate Alert (5 minutes)
1. [ ] CloudWatch Console → Alarms → Create Alarm
2. [ ] Select metric → S3 → Request Metrics
3. [ ] Find filter "all-requests" → AllRequests
4. [ ] Statistic: Sum
5. [ ] Period: 1 hour
6. [ ] Threshold: Static → Greater than → 1,000,000
7. [ ] Use existing SNS topic: "photolala-cost-alerts"
8. [ ] Alarm name: "Photolala High Request Rate"
9. [ ] Create alarm

## Step 5: Create Basic Dashboard (10 minutes)
1. [ ] CloudWatch Console → Dashboards → Create Dashboard
2. [ ] Name: "Photolala-S3-Backup"
3. [ ] Add widget → Line → S3 BucketSizeBytes
4. [ ] Add widget → Number → Current storage size
5. [ ] Add widget → Line → S3 AllRequests
6. [ ] Add widget → Number → Today's request count
7. [ ] Add widget → Line → Billing EstimatedCharges
8. [ ] Save dashboard

## Step 6: Enable S3 Inventory (Optional - 5 minutes)
For detailed per-user analysis:
1. [ ] S3 Console → Bucket → Management → Inventory
2. [ ] Add inventory configuration
3. [ ] Name: "daily-inventory"
4. [ ] Destination bucket: create "photolala-analytics"
5. [ ] Frequency: Daily
6. [ ] Output format: Apache Parquet (for Athena)
7. [ ] Fields: Size, Last modified, Storage class, ETag
8. [ ] Save

## Step 7: Set Up Budget Alert (5 minutes)
1. [ ] AWS Console → AWS Budgets
2. [ ] Create budget → Cost budget
3. [ ] Name: "Photolala Monthly Budget"
4. [ ] Period: Monthly
5. [ ] Budget amount: $200
6. [ ] Alert threshold: 80% ($160)
7. [ ] Email: your-email@example.com
8. [ ] Create budget

## Verification
- [ ] Send test file to S3, verify it appears in dashboard
- [ ] Check email for SNS subscription confirmations
- [ ] Verify alarms show as "OK" state
- [ ] Dashboard loads and shows data

## Monthly Tasks
- [ ] Review CloudWatch dashboard for trends
- [ ] Check AWS Cost Explorer for per-user costs
- [ ] Analyze any triggered alarms
- [ ] Adjust thresholds if needed

## Total Setup Time: ~35 minutes

## Notes
- First month of CloudWatch is free tier eligible
- Alarms cost $0.10/month each after free tier
- Dashboard is free (first 3)
- S3 request metrics cost ~$0.30/month per filter

## Next Steps
Once comfortable with manual monitoring:
1. Consider Infrastructure as Code (CloudFormation)
2. Add more specific alarms (per-user limits)
3. Set up automated responses with Lambda
4. Integrate with third-party monitoring tools