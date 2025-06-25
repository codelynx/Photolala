# CloudWatch Monitoring for S3 Backup Service

## Overview

While users calculate their own usage client-side, we need server-side monitoring to:
- Track overall service costs and usage
- Detect abuse or anomalies
- Ensure service profitability
- Generate alerts for operational issues

## What CloudWatch Provides

### 1. S3 Metrics (Built-in)
- **BucketSizeBytes**: Total size of all objects in bucket
- **NumberOfObjects**: Total object count
- **AllRequests**: API request count
- **GetRequests**: Download requests
- **PutRequests**: Upload requests
- **DeleteRequests**: Deletion requests
- **StorageType**: Breakdown by storage class

### 2. S3 Request Metrics (Additional cost)
- Request metrics by prefix (per-user tracking)
- Latency metrics
- Error rates
- Detailed operation breakdowns

### 3. AWS Cost Explorer Integration
- Track costs per user (using S3 object tags)
- Storage class cost breakdown
- Data transfer costs
- Request costs

## Monitoring Strategy

### Phase 1: Basic Monitoring (No Lambda Required)

```yaml
# CloudWatch Alarms via AWS Console or CloudFormation
BasicMonitoringAlarms:
  - TotalStorageSizeAlarm:
      Metric: BucketSizeBytes
      Threshold: 50 TB  # Alert if total storage exceeds 50TB
      Period: 1 hour
      
  - DailyCostAlarm:
      Metric: EstimatedCharges
      Threshold: $100/day
      Period: 24 hours
      
  - HighRequestRateAlarm:
      Metric: AllRequests
      Threshold: 1,000,000 requests/hour
      Period: 1 hour
      
  - StorageGrowthRateAlarm:
      Metric: BucketSizeBytes (rate of change)
      Threshold: 1 TB/day growth
      Period: 24 hours
```

### Phase 2: Per-User Monitoring (Using S3 Inventory)

```yaml
# S3 Inventory Configuration
S3Inventory:
  Frequency: Daily
  Destination: s3://photolala-analytics/inventory/
  Fields:
    - Size
    - LastModifiedDate
    - StorageClass
    - ETag
    - Key
  Format: Parquet  # For Athena queries
```

Then use Athena to query:
```sql
-- Top users by storage
SELECT 
  SPLIT_PART(key, '/', 2) as user_id,
  SUM(size) as total_bytes,
  COUNT(*) as file_count
FROM s3_inventory
WHERE key LIKE 'users/%'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 100;

-- Users exceeding their tier
SELECT 
  user_id,
  total_bytes / 1099511627776 as total_tb,
  CASE 
    WHEN total_tb > 2 THEN 'Over Personal Limit'
    WHEN total_tb > 10 THEN 'Over Family Limit'
  END as status
FROM (
  SELECT 
    SPLIT_PART(key, '/', 2) as user_id,
    SUM(size) as total_bytes
  FROM s3_inventory
  WHERE key LIKE 'users/%'
  GROUP BY 1
)
WHERE total_bytes > 2199023255552;  -- 2TB
```

### Phase 3: Cost Attribution (Using S3 Object Tags)

```python
# Tag objects during upload
s3.put_object(
    Bucket='photolala-backup',
    Key=f'users/{user_id}/photos/{photo_hash}',
    Body=photo_data,
    StorageClass='DEEP_ARCHIVE',
    Tagging=f'user={user_id}&tier={subscription_tier}'
)
```

Then use Cost Allocation Tags:
- Enable tags in AWS Billing Console
- Track costs per user
- Monitor profitability per tier

## CloudWatch Dashboards

### Operations Dashboard
```
┌─────────────────────────────────────────┐
│ Total Storage         │ Active Users    │
│ 45.2 TB              │ 1,234           │
├─────────────────────────────────────────┤
│ Storage Growth (30d)                    │
│ [Graph showing growth trend]            │
├─────────────────────────────────────────┤
│ Request Rate (1h)                       │
│ [Graph showing API requests]            │
├─────────────────────────────────────────┤
│ Error Rate           │ Availability     │
│ 0.01%               │ 99.99%          │
└─────────────────────────────────────────┘
```

### Cost Dashboard
```
┌─────────────────────────────────────────┐
│ Monthly Cost         │ Cost per User    │
│ $89.45              │ $0.07           │
├─────────────────────────────────────────┤
│ Cost Breakdown                          │
│ Storage: $45.20 (50%)                   │
│ Requests: $30.15 (34%)                  │
│ Transfer: $14.10 (16%)                  │
├─────────────────────────────────────────┤
│ Cost Trend (6 months)                   │
│ [Graph showing cost over time]          │
└─────────────────────────────────────────┘
```

## Alerting Strategy

### Critical Alerts (PagerDuty)
- Storage cost exceeds $200/day
- Total storage exceeds 100TB
- Error rate > 5%
- Unusual activity patterns

### Warning Alerts (Email)
- User exceeds 5TB storage
- Daily uploads > 100GB from single user
- Storage growth > 2TB/day
- Cost per user > $2/month

### Info Alerts (Slack)
- New user signups
- Large retrieval requests
- Weekly cost summary

## Abuse Detection

### Patterns to Monitor
1. **Rapid Upload**: >100GB in 1 hour
2. **Duplicate Data**: Same files uploaded multiple times
3. **Non-Photo Content**: Large files that aren't images
4. **Sharing Abuse**: Multiple users accessing same Apple ID

### Response Actions
1. **Soft Limit**: Throttle API requests
2. **Hard Limit**: Block uploads temporarily
3. **Investigation**: Manual review of account
4. **Communication**: Email user about unusual activity

## Implementation Without Lambda

Most monitoring can be done without any scripts:

### No Scripts Required:
1. **CloudWatch Alarms**: Configure via Console (point-and-click)
2. **S3 Metrics**: Automatically collected by AWS
3. **Cost Tracking**: AWS Cost Explorer with tags (Console)
4. **Dashboards**: Create in CloudWatch Console (drag-and-drop)
5. **SNS Alerts**: Configure email/SMS in Console

### Where Scripts Might Be Used (Optional):
1. **S3 Inventory + Athena Queries**:
   - S3 Inventory: Enable via Console (no script)
   - Athena: SQL queries to analyze inventory (can save queries)
   - Could schedule queries with EventBridge + Lambda (optional)

2. **CloudFormation/Terraform**:
   - Infrastructure as Code (optional)
   - Automate alarm creation
   - Version control monitoring setup

3. **Custom Metrics**:
   - Only if you want metrics CloudWatch doesn't provide
   - Example: "Photos uploaded per hour" would need Lambda

### Manual Setup Process (No Scripts):
1. **AWS Console → CloudWatch → Alarms**
   - Click "Create Alarm"
   - Select S3 metric (e.g., BucketSizeBytes)
   - Set threshold (e.g., > 50TB)
   - Add SNS topic for notifications

2. **AWS Console → S3 → Bucket → Management**
   - Enable Inventory
   - Choose frequency (daily)
   - Select fields to export

3. **AWS Console → Cost Management**
   - Enable Cost Allocation Tags
   - Create cost reports
   - Set budget alerts

## Future Enhancements

When Lambda is needed:
1. **Real-time Abuse Detection**: Process S3 events immediately
2. **Automated Responses**: Block users programmatically
3. **Custom Metrics**: Calculate complex business metrics
4. **Integration**: Send data to external analytics tools

## Minimal Monitoring Setup (No Scripts)

For MVP, just set up these 3 alarms in AWS Console:

1. **High Cost Alert**
   - Metric: EstimatedCharges
   - Threshold: > $100/day
   - Email alert to admin

2. **Storage Size Alert**
   - Metric: BucketSizeBytes
   - Threshold: > 50TB
   - Email alert to admin

3. **High Request Rate**
   - Metric: AllRequests
   - Threshold: > 1M requests/hour
   - Email alert to admin

This takes ~15 minutes to set up manually and requires zero scripts.

## Cost Estimate

- CloudWatch Alarms: ~$0.10/alarm/month
- S3 Inventory: ~$0.0025/million objects listed
- CloudWatch Dashboards: Free (first 3)
- Athena Queries: ~$5/TB scanned
- Total: ~$10-50/month for monitoring

This is a small price for operational visibility and cost control.