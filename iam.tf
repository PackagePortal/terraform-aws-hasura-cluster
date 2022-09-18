##############################
# Optional linked service role
##############################
resource "aws_iam_service_linked_role" "ecs_service" {
  aws_service_name = "ecs.amazonaws.com"
  count            = var.create_iam_service_linked_role ? 1 : 0

  lifecycle {
    prevent_destroy = true
  }
}

########################
# Create IAM for logging
########################
data "aws_iam_policy_document" "hasura_log_publishing" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutLogEventsBatch",
    ]

    resources = ["arn:aws:logs:${var.region}:*:log-group:/ecs/${var.env_name}-${var.app_name}-hasura:*"]
  }
}

resource "aws_iam_policy" "hasura_log_publishing" {
  name        = "${var.env_name}-${var.app_name}-hasura-log-pub"
  path        = "/"
  description = "Allow publishing to cloudwach"

  policy = data.aws_iam_policy_document.hasura_log_publishing.json
}

data "aws_iam_policy_document" "hasura_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "hasura_role" {
  name               = "${var.env_name}-${var.app_name}-hasura-role"
  path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.hasura_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "hasura_role_log_publishing" {
  role       = aws_iam_role.hasura_role.name
  policy_arn = aws_iam_policy.hasura_log_publishing.arn
}

#############################
# S3 Logging Bucket Policy
#############################
data "aws_iam_policy_document" "hasura" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.hasura.arn}/alb/*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }
  }

  statement {
    effect = "Deny"
    resources = [
      aws_s3_bucket.hasura.arn,
      "${aws_s3_bucket.hasura.arn}/*",
    ]
    actions = ["s3:*"]
    not_principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.main.arn]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "hasura" {
  bucket = aws_s3_bucket.hasura.id
  policy = data.aws_iam_policy_document.hasura.json
}

#######################################
# AWS Secrets manager access for Hasura
#######################################
data "aws_iam_policy_document" "hasura_secret_read" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = concat([
      aws_secretsmanager_secret.db_url.arn,
      aws_secretsmanager_secret.admin_secret.arn,
      ],
      var.use_jwt_auth ? [aws_secretsmanager_secret.jwt_secret[0].arn] : [],
      aws_secretsmanager_secret.other_secrets.*.arn,
    aws_secretsmanager_secret.actions_endpoints_secrets.*.arn)
  }
}

resource "aws_iam_policy" "hasura_secret_read" {
  name        = "${var.env_name}-${var.app_name}-secrets-access"
  path        = "/"
  description = "Allow reading secrets"

  policy = data.aws_iam_policy_document.hasura_secret_read.json
}

resource "aws_iam_role_policy_attachment" "hasura_secret_read" {
  role       = aws_iam_role.hasura_role.name
  policy_arn = aws_iam_policy.hasura_secret_read.arn
}

############################
# ECR Image Pull Permissions
############################
data "aws_iam_policy_document" "ecr_image_pull" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = [
      "*", # This needs to be a wildcard so that the GetAuthorizationToken permission is granted
    ]
  }
}

locals {
  # If no image is specified we do not need these options.
  ecr_policy_needed = var.actions_endpoints_image != "" ? 1 : 0
}

resource "aws_iam_policy" "ecr_image_pull" {
  count       = local.ecr_policy_needed
  name        = "${var.env_name}-${var.app_name}-ecr-pull"
  path        = "/"
  description = "Allow Fargate Cluster ${var.env_name}-${var.app_name} to interact with ECR"

  policy = data.aws_iam_policy_document.ecr_image_pull.json
}

resource "aws_iam_role_policy_attachment" "ecr_image_pull" {
  count      = local.ecr_policy_needed
  role       = aws_iam_role.hasura_role.name
  policy_arn = aws_iam_policy.ecr_image_pull[0].arn
}
