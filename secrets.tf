resource "aws_secretsmanager_secret" "db_url" {
  name = "${var.env_name}-${var.app_name}-db-url"
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgres://${var.rds_username}:${var.rds_password}@${aws_db_instance.hasura.endpoint}/${var.rds_db_name}"
}

resource "aws_secretsmanager_secret" "admin_secret" {
  name = "${var.env_name}-${var.app_name}-admin-secret"
}

resource "aws_secretsmanager_secret_version" "admin_secret" {
  secret_id     = aws_secretsmanager_secret.admin_secret.id
  secret_string = var.hasura_admin_secret
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  count = var.use_jwt_auth ? 1 : 0
  name = "${var.env_name}-${var.app_name}-jwt-secret"
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  count = var.use_jwt_auth ? 1 : 0
  secret_id     = aws_secretsmanager_secret.jwt_secret[0].id
  secret_string = "{\"type\":\"${var.hasura_jwt_secret_algo}\", \"jwk_url\": \"${var.hasura_jwt_secret_key}\"}"
}

resource "aws_secretsmanager_secret" "other_secrets" {
  count = length(var.secrets)
  name = "${var.env_name}-${var.app_name}-${var.secrets[count.index].name}"
}

resource "aws_secretsmanager_secret_version" "other_secrets" {
  count = length(var.secrets)
  secret_id     = aws_secretsmanager_secret.other_secrets[count.index].id
  secret_string = var.secrets[count.index].value

  depends_on = [
    aws_secretsmanager_secret.other_secrets
  ]
}

resource "aws_secretsmanager_secret" "custom_auth_webhook_secrets" {
  count = length(var.custom_auth_webhook_secrets)
  name = "${var.env_name}-${var.app_name}-${var.custom_auth_webhook_secrets[count.index].name}"
}

resource "aws_secretsmanager_secret_version" "custom_auth_webhook_secrets" {
  count = length(var.custom_auth_webhook_secrets)
  secret_id     = aws_secretsmanager_secret.custom_auth_webhook_secrets[count.index].id
  secret_string = var.custom_auth_webhook_secrets[count.index].value

  depends_on = [
    aws_secretsmanager_secret.custom_auth_webhook_secrets
  ]
}

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
    aws_secretsmanager_secret.custom_auth_webhook_secrets.*.arn)
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
