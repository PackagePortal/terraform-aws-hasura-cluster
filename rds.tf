resource "aws_db_subnet_group" "hasura" {
  name       = "${var.env_name}-${var.app_name}-hasura"
  subnet_ids = aws_subnet.hasura_private.*.id
}

resource "aws_db_instance" "hasura" {
  name                   = var.rds_db_name
  identifier             = "${var.env_name}-${var.app_name}-hasura"
  username               = var.rds_username
  password               = var.rds_password
  port                   = "5432"
  engine                 = "postgres"
  engine_version         = var.pg_version
  instance_class         = var.rds_instance
  allocated_storage      = var.env_name == "prod" ? "100" : "10"
  storage_encrypted      = true
  vpc_security_group_ids = [aws_security_group.hasura_rds.id]
  db_subnet_group_name   = aws_db_subnet_group.hasura.name
  parameter_group_name   = var.parameter_group_name
  multi_az               = var.multi_az
  storage_type           = "gp2"
  publicly_accessible    = false

  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  apply_immediately           = true
  maintenance_window          = var.maintenance_window
  skip_final_snapshot         = false
  copy_tags_to_snapshot       = true
  backup_retention_period     = 7
  backup_window               = var.backup_window
  final_snapshot_identifier   = "hasura"
  deletion_protection         = true

  tags = var.tags
}

resource "aws_db_instance" "read_replica_hasura" {
  count                = var.read_replica_enabled ? 1 : 0
  name                 = var.rds_db_name
  identifier           = "${var.env_name}-${var.app_name}-hasura-read-replica"
  username             = "" # Do not set the user name/password for a replica
  password             = ""
  port                 = "5432"
  instance_class       = var.read_replica_rds_instance
  allocated_storage    = var.env_name == "prod" ? "100" : "10"
  storage_encrypted    = true
  parameter_group_name = var.parameter_group_name
  multi_az             = var.multi_az
  storage_type         = "gp2"
  publicly_accessible  = false
  replicate_source_db  = aws_db_instance.hasura.id

  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  apply_immediately           = true
  maintenance_window          = var.maintenance_window
  skip_final_snapshot         = false
  copy_tags_to_snapshot       = true
  backup_retention_period     = 0
  backup_window               = var.backup_window
  final_snapshot_identifier   = "hasura"
  deletion_protection         = true

  tags = var.tags
}
