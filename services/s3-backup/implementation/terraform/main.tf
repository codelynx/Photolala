terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "S3 bucket name for photo storage"
  type        = string
  default     = "photolala"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

# S3 Bucket
resource "aws_s3_bucket" "photolala" {
  bucket = var.bucket_name

  tags = {
    Name        = "Photolala Storage"
    Environment = var.environment
  }
}

# S3 Bucket Versioning - Not needed for this use case
# Versioning is disabled by default

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "photolala" {
  bucket = aws_s3_bucket.photolala.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "photolala" {
  bucket = aws_s3_bucket.photolala.id

  rule {
    id     = "archive-photos-180-days"
    status = "Enabled"

    filter {
      prefix = "photos/"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }
  }

  rule {
    id     = "optimize-thumbnails-immediately"
    status = "Enabled"

    filter {
      prefix = "thumbnails/"
    }

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  rule {
    id     = "cleanup-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# IAM Role for Users
resource "aws_iam_role" "photolala_user" {
  name = "PhotolalaUserRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }
    ]
  })

  tags = {
    Name        = "Photolala User Role"
    Environment = var.environment
  }
}

# IAM Policy for Users
resource "aws_iam_role_policy" "photolala_user" {
  name = "PhotolalaUserPolicy"
  role = aws_iam_role.photolala_user.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:RestoreObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.bucket_name}/photos/$${aws:userid}/*",
          "arn:aws:s3:::${var.bucket_name}/thumbnails/$${aws:userid}/*",
          "arn:aws:s3:::${var.bucket_name}/metadata/$${aws:userid}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${var.bucket_name}"
        Condition = {
          StringLike = {
            "s3:prefix" = [
              "photos/$${aws:userid}/*",
              "thumbnails/$${aws:userid}/*",
              "metadata/$${aws:userid}/*"
            ]
          }
        }
      }
    ]
  })
}

# IAM User for Backend Service
resource "aws_iam_user" "backend" {
  name = "photolala-backend"
  path = "/system/"

  tags = {
    Name        = "Photolala Backend Service"
    Environment = var.environment
  }
}

# IAM Policy for Backend Service
resource "aws_iam_user_policy" "backend" {
  name = "PhotolalaBackendPolicy"
  user = aws_iam_user.backend.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = aws_iam_role.photolala_user.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sts:TagSession"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Access Key for Backend Service
resource "aws_iam_access_key" "backend" {
  user = aws_iam_user.backend.name
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Outputs
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.photolala.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.photolala.arn
}

output "user_role_arn" {
  description = "ARN of the user role for STS"
  value       = aws_iam_role.photolala_user.arn
}

output "backend_user_arn" {
  description = "ARN of the backend service user"
  value       = aws_iam_user.backend.arn
}

output "backend_access_key_id" {
  description = "Access key ID for backend service"
  value       = aws_iam_access_key.backend.id
  sensitive   = true
}

output "backend_secret_access_key" {
  description = "Secret access key for backend service"
  value       = aws_iam_access_key.backend.secret
  sensitive   = true
}

output "backend_environment_variables" {
  description = "Environment variables for backend service"
  value = {
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.backend.id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.backend.secret
    AWS_REGION           = var.aws_region
    PHOTOLALA_ROLE_ARN   = aws_iam_role.photolala_user.arn
  }
  sensitive = true
}