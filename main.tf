# -----------------------------------------------------------------------------
# Service role allowing AWS to manage resources required for ECS
# -----------------------------------------------------------------------------

resource "aws_iam_service_linked_role" "ecs_service" {
  aws_service_name = "ecs.amazonaws.com"
  count            = var.create_iam_service_linked_role ? 1 : 0

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------------------------------
# Create VPC
# -----------------------------------------------------------------------------

# Fetch AZs in the current region
data "aws_availability_zones" "available" {
}

data "aws_vpc" "hasura" {
  id = var.vpc_id
}

# Create var.az_count private subnets for RDS, each in a different AZ
resource "aws_subnet" "hasura_private" {
  count             = var.az_count
  cidr_block        = cidrsubnet(data.aws_vpc.hasura.cidr_block, 8, count.index + var.cidr_bit_offset)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = data.aws_vpc.hasura.id

  tags = {
    Name = "${var.env_name} ${var.app_name} hasura #${count.index} (private)"
  }
}

resource "aws_route_table_association" "associate_routetable_to_private_subnet" {
  count = length(var.internet_route_table_id) > 0 ? var.az_count : 0
  subnet_id      = aws_subnet.hasura_private[count.index].id
  route_table_id = var.internet_route_table_id

  depends_on = [
    aws_subnet.hasura_private
  ]
}

# Create var.az_count public subnets for Hasura, each in a different AZ
resource "aws_subnet" "hasura_public" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(data.aws_vpc.hasura.cidr_block, 8, var.az_count + count.index + var.cidr_bit_offset)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = data.aws_vpc.hasura.id
  map_public_ip_on_launch = false

  tags = merge({
    Name = "${var.env_name} ${var.app_name} hasura #${var.az_count + count.index} (ALB)"
  }, var.tags)
}

resource "aws_route_table_association" "lb_subnet_to_private_route_table" {
  count = length(var.internet_route_table_id) > 0 ? var.az_count : 0
  subnet_id      = aws_subnet.hasura_public[count.index].id
  route_table_id = var.internet_route_table_id

  depends_on = [
    aws_subnet.hasura_public
  ]
}

# -----------------------------------------------------------------------------
# Create security groups
# -----------------------------------------------------------------------------

# Internet to ALB
resource "aws_security_group" "hasura_alb" {
  name        = "${var.env_name}-${var.app_name}-hasura-alb"
  description = "Allow access on port 443 only to ALB"
  vpc_id      = data.aws_vpc.hasura.id

  # Needs to be public because source ip is given by api gateway
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = var.tags
}

# ALB TO ECS
resource "aws_security_group" "hasura_ecs" {
  name        = "${var.env_name}-${var.app_name}-hasura-tasks"
  description = "allow inbound access from the ALB only"
  vpc_id      = data.aws_vpc.hasura.id

  ingress {
    protocol        = "tcp"
    from_port       = "8080"
    to_port         = "8080"
    security_groups = [aws_security_group.hasura_alb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = var.tags
}

# ECS to RDS
resource "aws_security_group" "hasura_rds" {
  name        = "${var.env_name}-${var.app_name}-hasura-rds"
  description = "allow inbound access from the hasura tasks only"
  vpc_id      = data.aws_vpc.hasura.id

  ingress {
    protocol        = "tcp"
    from_port       = "5432"
    to_port         = "5432"
    security_groups = concat([aws_security_group.hasura_ecs.id], var.additional_db_security_groups)
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Create RDS
# -----------------------------------------------------------------------------

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
  engine_version         = "10.18"
  instance_class         = var.rds_instance
  allocated_storage      = var.env_name == "prod" ? "100" : "10"
  storage_encrypted      = true
  vpc_security_group_ids = [aws_security_group.hasura_rds.id]
  db_subnet_group_name   = aws_db_subnet_group.hasura.name
  parameter_group_name   = "default.postgres10"
  multi_az               = var.multi_az
  storage_type           = "gp2"
  publicly_accessible    = false

  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  apply_immediately           = true
  maintenance_window          = "sun:06:00-sun:08:00"
  skip_final_snapshot         = false
  copy_tags_to_snapshot       = true
  backup_retention_period     = 7
  backup_window               = "04:00-06:00"
  final_snapshot_identifier   = "hasura"
  deletion_protection         = true

  tags = merge({
    Backup: "Daily30"
  }, var.tags)
}

resource "aws_db_instance" "read_replica_hasura" {
  count                = var.read_replica_enabled ? 1 : 0
  name                 = var.rds_db_name
  identifier           = "${var.env_name}-${var.app_name}-hasura-reports"
  username             = "" # Do not set the user name/password for a replica
  password             = ""
  port                 = "5432"
  instance_class       = var.read_replica_rds_instance
  allocated_storage    = var.env_name == "prod" ? "100" : "10"
  storage_encrypted    = true
  parameter_group_name = "default.postgres10"
  multi_az             = var.multi_az
  storage_type         = "gp2"
  publicly_accessible  = false
  replicate_source_db  = aws_db_instance.hasura.id

  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  apply_immediately           = true
  maintenance_window          = "sun:06:00-sun:08:00"
  skip_final_snapshot         = false
  copy_tags_to_snapshot       = true
  backup_retention_period     = 0
  backup_window               = "04:00-06:00"
  final_snapshot_identifier   = "hasura"
  deletion_protection         = true

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Create ECS cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "hasura" {
  name = "${var.env_name}-${var.app_name}-hasura-cluster"

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = var.capacity_provider
  }

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Create logging
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "hasura" {
  name              = "/ecs/${var.env_name}-${var.app_name}-hasura"
  retention_in_days = 30
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Create IAM for logging
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Create a task definition
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "hasura" {
  family                   = "${var.env_name}-${var.app_name}-hasura"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu_size
  memory                   = var.memory_size
  execution_role_arn       = aws_iam_role.hasura_role.arn
  task_role_arn            = aws_iam_role.hasura_role.arn

  container_definitions = jsonencode(local.ecs_container_definitions)
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Create the ECS service
# -----------------------------------------------------------------------------

resource "aws_ecs_service" "hasura" {
  depends_on = [
    aws_ecs_task_definition.hasura,
    aws_cloudwatch_log_group.hasura,
    aws_alb_listener.hasura
  ]
  name            = "${var.env_name}-${var.app_name}-hasura-service"
  cluster         = aws_ecs_cluster.hasura.id
  task_definition = aws_ecs_task_definition.hasura.arn
  desired_count   = var.multi_az == true ? "2" : "1"

  network_configuration {
    security_groups  = [aws_security_group.hasura_ecs.id]
    subnets          = aws_subnet.hasura_private.*.id
  }

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = 100
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.hasura.id
    container_name   = "hasura"
    container_port   = "8080"
  }
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Create the ALB log bucket
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# Add IAM policy to allow the ALB to log to it
# -----------------------------------------------------------------------------

data "aws_elb_service_account" "main" {
}

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
      test = "Bool"
      variable = "aws:SecureTransport"
      values = [ "false" ]
    }
  }
}

resource "aws_s3_bucket_policy" "hasura" {
  bucket = aws_s3_bucket.hasura.id
  policy = data.aws_iam_policy_document.hasura.json
}

# -----------------------------------------------------------------------------
# Create the ALB
# -----------------------------------------------------------------------------

resource "aws_alb" "hasura" {
  name            = "${var.env_name}-${var.app_name}-hasura-alb"
  subnets         = aws_subnet.hasura_public.*.id
  security_groups = [aws_security_group.hasura_alb.id]
  internal        = true

  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.hasura.id
    prefix  = "alb"
    enabled = true
  }

  depends_on = [aws_s3_bucket.hasura]
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Create the ALB target group for ECS
# -----------------------------------------------------------------------------

resource "aws_alb_target_group" "hasura" {
  name        = "${var.env_name}-${var.app_name}-hasura-alb"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.hasura.id
  target_type = "ip"

  health_check {
    path    = "/healthz"
    matcher = "200"
  }
  tags = var.tags
}

# -----------------------------------------------------------------------------
# Create the ALB listener
# -----------------------------------------------------------------------------

resource "aws_alb_listener" "hasura" {
  load_balancer_arn = aws_alb.hasura.id
  port              = local.alb_port
  protocol          = "HTTP"
  #certificate_arn   = aws_acm_certificate.hasura.arn

  default_action {
    target_group_arn = aws_alb_target_group.hasura.id
    type             = "forward"
  }
  tags = var.tags
}

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

resource "aws_iam_policy" "ecr_image_pull" {
  name        = "${var.env_name}-${var.app_name}-ecr-pull"
  path        = "/"
  description = "Allow Fargate Cluster ${var.env_name}-${var.app_name} to interact with ECR"

  policy = data.aws_iam_policy_document.ecr_image_pull.json
}

resource "aws_iam_role_policy_attachment" "ecr_image_pull" {
  role       = aws_iam_role.hasura_role.name
  policy_arn = aws_iam_policy.ecr_image_pull.arn
}
