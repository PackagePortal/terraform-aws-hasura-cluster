# Fetch AZs and VPC in the current region
data "aws_availability_zones" "available" {
}

data "aws_vpc" "hasura" {
  id = var.vpc_id
}

local {
  https = var.alb_port == 443
}

####################
# Network resources
####################

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

resource "aws_route_table_association" "private_subnet_route_table_id" {
  count = length(var.private_subnet_route_table_id) > 0 ? var.az_count : 0
  subnet_id      = aws_subnet.hasura_private[count.index].id
  route_table_id = var.private_subnet_route_table_id

  depends_on = [
    aws_subnet.hasura_private
  ]
}

# Create var.az_count public subnets for ALBs, each in a different AZ
resource "aws_subnet" "hasura_public" {
  count                   = var.az_count
  cidr_block              = cidrsubnet(data.aws_vpc.hasura.cidr_block, 8, var.az_count + count.index + var.cidr_bit_offset)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  vpc_id                  = data.aws_vpc.hasura.id
  map_public_ip_on_launch = var.map_public_ip_on_public_subnet

  tags = merge({
    Name = "${var.env_name} ${var.app_name} hasura #${var.az_count + count.index} (ALB)"
  }, var.tags)
}

resource "aws_route_table_association" "lb_subnet_to_route_table" {
  count = length(var.internet_route_table_id) > 0 ? var.az_count : 0
  subnet_id      = aws_subnet.hasura_public[count.index].id
  route_table_id = var.internet_route_table_id

  depends_on = [
    aws_subnet.hasura_public
  ]
}

# Internet to ALB
resource "aws_security_group" "hasura_alb" {
  name        = "${var.env_name}-${var.app_name}-hasura-alb"
  description = "Allows access to ALB on exposed port"
  vpc_id      = data.aws_vpc.hasura.id

  ingress {
    protocol    = "tcp"
    from_port   = var.alb_port
    to_port     = var.alb_port
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
    from_port       = 8080
    to_port         = 8080
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
    from_port       = 5432
    to_port         = 5432
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

###############
# ECS Cluster
###############
resource "aws_ecs_cluster" "hasura" {
  name = "${var.env_name}-${var.app_name}-hasura-cluster"

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = var.capacity_provider
  }

  tags = var.tags
}

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

resource "aws_ecs_service" "hasura" {
  depends_on = [
    aws_ecs_task_definition.hasura,
    aws_cloudwatch_log_group.hasura,
    aws_alb_listener.hasura
  ]
  name            = "${var.env_name}-${var.app_name}-hasura-service"
  cluster         = aws_ecs_cluster.hasura.id
  task_definition = aws_ecs_task_definition.hasura.arn
  desired_count   = var.multi_az ? "2" : "1"

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

data "aws_elb_service_account" "main" {
}

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

resource "aws_alb_listener" "hasura" {
  load_balancer_arn = aws_alb.hasura.id
  port              = var.alb_port
  protocol          = local.https ? "HTTPS" : "HTTP"
  certificate_arn   = local.https ? var.acm_certificate_arn : null

  default_action {
    target_group_arn = aws_alb_target_group.hasura.id
    type             = "forward"
  }
  tags = var.tags
}
