# S3 Lifecycle Configuration for Photolala
# This Terraform configuration sets up lifecycle rules for the Photolala S3 bucket

resource "aws_s3_bucket_lifecycle_configuration" "photolala_lifecycle" {
  bucket = var.photolala_bucket_name

  # Rule 1: Archive user photos after 6 months
  rule {
    id     = "archive-user-photos"
    status = "Enabled"

    filter {
      prefix = "users/"
    }

    transition {
      days          = 180 # 6 months
      storage_class = "DEEP_ARCHIVE"
    }

    # Only apply to photo files, not metadata or thumbnails
    filter {
      and {
        prefix = "users/"
        tags = {
          "Type" = "photo"
        }
      }
    }
  }

  # Rule 2: Intelligent tiering for thumbnails (immediate)
  rule {
    id     = "optimize-thumbnails"
    status = "Enabled"

    filter {
      prefix = "users/"
    }

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }

    # Only apply to thumbnail files
    filter {
      and {
        prefix = "users/"
        tags = {
          "Type" = "thumbnail"
        }
      }
    }
  }

  # Rule 3: Keep metadata in STANDARD (no transition)
  # No rule needed - files stay in STANDARD by default
}

# Alternative configuration using path-based filtering
resource "aws_s3_bucket_lifecycle_configuration" "photolala_lifecycle_path_based" {
  bucket = var.photolala_bucket_name

  # Rule 1: Archive user photos after 6 months
  rule {
    id     = "archive-user-photos"
    status = "Enabled"

    filter {
      prefix = "users/"
    }

    # Apply to any file under photos/ subdirectory
    filter {
      and {
        prefix = "users/"
        object_size_greater_than = 1024 # Only files > 1KB (excludes markers)
      }
    }

    transition {
      days          = 180 # 6 months
      storage_class = "DEEP_ARCHIVE"
    }

    # Exclude metadata and thumbnails
    noncurrent_version_transition {
      noncurrent_days = 1
      storage_class   = "DEEP_ARCHIVE"
    }
  }

  # Rule 2: Intelligent tiering for thumbnails
  rule {
    id     = "optimize-thumbnails"
    status = "Enabled"

    filter {
      prefix = "thumbnails/"
    }

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }

  # Rule 3: Delete incomplete multipart uploads after 7 days
  rule {
    id     = "cleanup-incomplete-uploads"
    status = "Enabled"

    filter {} # Apply to entire bucket

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Variables
variable "photolala_bucket_name" {
  description = "Name of the Photolala S3 bucket"
  type        = string
  default     = "photolala"
}

# Outputs
output "lifecycle_rules" {
  description = "List of lifecycle rules applied to the bucket"
  value       = aws_s3_bucket_lifecycle_configuration.photolala_lifecycle.rule
}