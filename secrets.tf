resource "aws_secretsmanager_secret" "db_url" {
  name = "${var.env_name}-${var.app_name}-db-url"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgres://${var.rds_username}:${var.rds_password}@${aws_db_instance.hasura.endpoint}/${var.rds_db_name}"
}

resource "aws_secretsmanager_secret" "admin_secret" {
  name = "${var.env_name}-${var.app_name}-admin-secret"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "admin_secret" {
  secret_id     = aws_secretsmanager_secret.admin_secret.id
  secret_string = var.hasura_admin_secret
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  count = var.use_jwt_auth ? 1 : 0
  name  = "${var.env_name}-${var.app_name}-jwt-secret"
  tags  = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  count         = var.use_jwt_auth ? 1 : 0
  secret_id     = aws_secretsmanager_secret.jwt_secret[0].id
  secret_string = "{\"type\":\"${var.hasura_jwt_secret_algo}\", \"jwk_url\": \"${var.hasura_jwt_secret_key}\"}"
}

resource "aws_secretsmanager_secret" "other_secrets" {
  count = length(var.hasura_secrets)
  name  = "${var.env_name}-${var.app_name}-${var.hasura_secrets[count.index].name}"
  tags  = var.tags
}

resource "aws_secretsmanager_secret_version" "other_secrets" {
  count         = length(var.hasura_secrets)
  secret_id     = aws_secretsmanager_secret.other_secrets[count.index].id
  secret_string = var.hasura_secrets[count.index].value

  depends_on = [
    aws_secretsmanager_secret.other_secrets
  ]
}

resource "aws_secretsmanager_secret" "actions_endpoints_secrets" {
  count = length(var.actions_endpoints_secrets)
  name  = "${var.env_name}-${var.app_name}-${var.actions_endpoints_secrets[count.index].name}"
  tags  = var.tags
}

resource "aws_secretsmanager_secret_version" "actions_endpoints_secrets" {
  count         = length(var.actions_endpoints_secrets)
  secret_id     = aws_secretsmanager_secret.actions_endpoints_secrets[count.index].id
  secret_string = var.actions_endpoints_secrets[count.index].value

  depends_on = [
    aws_secretsmanager_secret.actions_endpoints_secrets
  ]
}
