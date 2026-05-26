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
  for_each = { for s in var.hasura_secrets : s.name => s }
  name     = "${var.env_name}-${var.app_name}-${each.value.name}"
  tags     = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "other_secrets" {
  for_each      = { for s in var.hasura_secrets : s.name => s }
  secret_id     = aws_secretsmanager_secret.other_secrets[each.key].id
  secret_string = each.value.value
}

resource "aws_secretsmanager_secret" "actions_endpoints_secrets" {
  for_each = { for s in var.actions_endpoints_secrets : s.name => s }
  name     = "${var.env_name}-${var.app_name}-${each.value.name}"
  tags     = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "actions_endpoints_secrets" {
  for_each      = { for s in var.actions_endpoints_secrets : s.name => s }
  secret_id     = aws_secretsmanager_secret.actions_endpoints_secrets[each.key].id
  secret_string = each.value.value
}
