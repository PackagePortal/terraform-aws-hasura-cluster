##############################
# Container Cloudwatch Logging
##############################
resource "aws_cloudwatch_log_group" "hasura" {
  name              = "/ecs/${var.env_name}-${var.app_name}-hasura"
  retention_in_days = 30
  tags              = var.tags
}

####################
# ALB Log Bucket
####################
resource "aws_s3_bucket" "hasura" {
  bucket        = "hasura-${var.app_name}-${var.region}-${var.logs_domain}"
  force_destroy = true
  tags = var.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hasura" {
  bucket = aws_s3_bucket.hasura.id

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "hasura" {
  count  = var.alb_log_bucket_versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.hasura.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "hasura" {
  count  = var.alb_log_bucket_lifecycle_rules != null ? 1 : 0
  bucket = aws_s3_bucket.hasura.id

  dynamic "rule" {
    for_each = var.alb_log_bucket_lifecycle_rules.expiration_days != null ? [1] : []
    content {
      id     = "expire-current-versions"
      status = "Enabled"

      expiration {
        days = var.alb_log_bucket_lifecycle_rules.expiration_days
      }
    }
  }

  dynamic "rule" {
    for_each = var.alb_log_bucket_lifecycle_rules.noncurrent_version_expiration_days != null ? [1] : []
    content {
      id     = "expire-noncurrent-versions"
      status = "Enabled"

      noncurrent_version_expiration {
        noncurrent_days = var.alb_log_bucket_lifecycle_rules.noncurrent_version_expiration_days
      }
    }
  }

  dynamic "rule" {
    for_each = var.alb_log_bucket_lifecycle_rules.abort_incomplete_multipart_upload_days != null ? [1] : []
    content {
      id     = "abort-incomplete-multipart-uploads"
      status = "Enabled"

      abort_incomplete_multipart_upload {
        days_after_initiation = var.alb_log_bucket_lifecycle_rules.abort_incomplete_multipart_upload_days
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "hasura" {
  bucket = aws_s3_bucket.hasura.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
