##############################
# Container Cloudwatch Logging
##############################
resource "aws_cloudwatch_log_group" "hasura" {
  name              = "/ecs/${var.env_name}-${var.app_name}-hasura"
  retention_in_days = 30
  tags = var.tags
}

####################
# ALB Log Bucket
####################
resource "aws_s3_bucket" "hasura" {
  bucket = "hasura-${var.app_name}-${var.region}-${var.hasura_subdomain}-${var.domain}"
  acl = "private"
  force_destroy = "true"

  /*logging {
    target_bucket = "ppi-accesslogs-${var.env_name}"
    target_prefix = "S3/hasura-merchant-${var.region}-${var.hasura_subdomain}-${var.domain}/"
  }*/

  server_side_encryption_configuration {
    rule {
      bucket_key_enabled = false
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "hasura" {
  bucket = aws_s3_bucket.hasura.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}