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

resource "aws_s3_bucket_public_access_block" "hasura" {
  bucket = aws_s3_bucket.hasura.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
