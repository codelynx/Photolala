# Terraform Configuration for Photolala AWS Infrastructure

This directory contains Terraform configuration for setting up the AWS infrastructure needed for Photolala's S3 backup service.

## Prerequisites

1. Install Terraform: https://www.terraform.io/downloads
2. Configure AWS credentials:
   ```bash
   aws configure
   ```

## Usage

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Review the Plan

```bash
terraform plan
```

### 3. Apply the Configuration

```bash
terraform apply
```

When prompted, type `yes` to confirm.

### 4. Get Backend Credentials

After applying, retrieve the backend service credentials:

```bash
terraform output -json backend_environment_variables
```

Save these credentials securely for your backend service.

## Customization

You can override default values by creating a `terraform.tfvars` file:

```hcl
aws_region  = "eu-west-1"
bucket_name = "my-photolala-bucket"
environment = "staging"
```

Or pass variables directly:

```bash
terraform apply -var="bucket_name=my-photolala-bucket"
```

## Resources Created

1. **S3 Bucket** with:
   - Public access blocked
   - Lifecycle rules configured
   - No versioning (not needed)

2. **IAM Role** (`PhotolalaUserRole`):
   - For STS to assume when generating user tokens
   - Scoped permissions to user's own files

3. **IAM User** (`photolala-backend`):
   - For backend service to assume roles
   - Limited to STS operations only

4. **Access Keys**:
   - For backend service authentication

## Outputs

- `bucket_name`: Name of the S3 bucket
- `bucket_arn`: ARN of the S3 bucket
- `user_role_arn`: ARN to use for STS AssumeRole
- `backend_user_arn`: ARN of the backend service user
- `backend_environment_variables`: Complete env vars for backend (sensitive)

## Security Notes

1. The backend access keys are marked as sensitive in Terraform
2. Store the credentials securely (e.g., AWS Secrets Manager)
3. Rotate access keys regularly
4. Enable CloudTrail for audit logging
5. Consider using AWS SSO or IAM Identity Center for production

## Destroying Resources

To tear down all resources:

```bash
terraform destroy
```

⚠️ **Warning**: This will delete all resources including the S3 bucket and its contents.

## State Management

For production use, consider:

1. Using remote state backend (S3 + DynamoDB)
2. Enabling state file encryption
3. Implementing state file locking

Example backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "photolala-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "photolala-terraform-locks"
    encrypt        = true
  }
}
```