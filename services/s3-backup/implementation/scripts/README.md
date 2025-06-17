# AWS Infrastructure Scripts

This directory contains scripts for setting up and managing the AWS infrastructure for Photolala's S3 backup service.

## Infrastructure Scripts

### `setup-aws-infrastructure.sh` 🆕

Complete infrastructure setup script that creates all necessary AWS resources:

- Creates S3 bucket with public access blocking (no versioning)
- Sets up IAM role for user access (PhotolalaUserRole)
- Creates IAM user for backend service (photolala-backend)
- Configures all necessary permissions
- Runs lifecycle configuration automatically
- Generates backend service credentials

**Usage:**
```bash
./setup-aws-infrastructure.sh
```

### `verify-infrastructure.sh` 🆕

Verification script that checks if all infrastructure components are correctly configured:

- Verifies S3 bucket settings
- Checks IAM roles and policies
- Tests STS token generation
- Optionally tests S3 operations with temporary credentials

**Usage:**
```bash
./verify-infrastructure.sh
```

### `configure-s3-lifecycle-final.sh`

The production-ready lifecycle configuration script implementing the V5 pricing strategy:

- **Universal 180-day archive** for all users (no per-user rules)
- **New path structure**: `photos/`, `thumbnails/`, `metadata/`
- **Simple configuration**: Only archives photos, thumbnails use Intelligent-Tiering

#### Features:
- ✅ Photos → Deep Archive after 180 days (95% cost reduction)
- ✅ Thumbnails → Intelligent-Tiering immediately (45% cost reduction)
- ✅ Metadata → Standard storage (always accessible)
- ✅ Cleanup incomplete multipart uploads after 7 days
- ✅ Creates monitoring and cost calculator scripts

#### Usage:
```bash
# Basic usage (uses default bucket name "photolala")
./configure-s3-lifecycle-final.sh

# With custom bucket
PHOTOLALA_BUCKET=my-bucket ./configure-s3-lifecycle-final.sh

# With custom region
AWS_REGION=eu-west-1 ./configure-s3-lifecycle-final.sh
```

#### Generated Helper Scripts:
- `monitor-lifecycle.sh` - Monitor storage transitions and costs
- `calculate-savings.sh` - Calculate cost savings from lifecycle policies

## Archived Scripts

The `archive-obsolete/` directory contains older scripts that used the previous path structure (`users/{userId}/photos/`) and more complex per-user lifecycle rules. These are kept for historical reference but should not be used.

## Important Notes

1. **Prerequisites**: AWS CLI must be configured with appropriate credentials
2. **Bucket Creation**: The bucket must exist before running the script
3. **Existing Rules**: The script will replace any existing lifecycle rules
4. **Cost Impact**: Lifecycle transitions may incur one-time transition costs

## Marketing Message

> "Your last 6 months of photos always at your fingertips!"

This aligns with the 180-day archive policy, giving users confidence that their recent photos are immediately accessible.

## Setup Order

For initial setup, run scripts in this order:

1. **`setup-aws-infrastructure.sh`** - Creates all AWS resources
2. **`verify-infrastructure.sh`** - Verifies everything is configured correctly

The setup script automatically runs the lifecycle configuration, so you don't need to run `configure-s3-lifecycle-final.sh` separately unless you need to update the lifecycle rules later.

## Alternative: Terraform

If you prefer Infrastructure as Code, use the Terraform configuration in `../terraform/` instead of the shell scripts. See the [Terraform README](../terraform/README.md) for details.