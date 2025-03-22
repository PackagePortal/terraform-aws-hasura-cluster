#################
# General 
#################
variable "region" {
  type        = string
  description = "AWS region to deploy in"
  default     = "us-east-1"
}

variable "app_name" {
  type        = string
  description = "Used to name the hasura instance"
}

variable "env_name" {
  type        = string
  description = "Enviroment prefix on resource names"
}

variable "tags" {
  type        = map(string)
  description = "AWS Resource tags"
  default     = {}
}

###########################
# Hasura instance variables
###########################
variable "use_jwt_auth" {
  type        = bool
  description = "Whether to set up JWT auth webhooks on the Hasura instance"
  default     = false
}

variable "capacity_provider" {
  description = "Capacity provider for tasks"
  type        = string
  default     = "FARGATE_SPOT"
}

variable "logs_domain" {
  type        = string
  description = "Log domain name"
  default     = "hasura-logs"
}

variable "hasura_image_base" {
  type        = string
  description = "What Hasura Docker image to use"
  default     = "hasura/graphql-engine"
}

variable "hasura_version_tag" {
  type        = string
  description = "The hasura graphql engine version tag"
}

variable "hasura_admin_secret" {
  type        = string
  description = "The admin secret to secure hasura; for admin access"
}

variable "hasura_jwt_secret_key" {
  type        = string
  description = "The secret shared key for JWT verification"
  default     = ""
}

variable "hasura_jwt_secret_algo" {
  type        = string
  description = "The algorithm for JWT verification (HS256 or RS256)"
  default     = ""
}

variable "hasura_console_enabled" {
  description = "Should the Hasura Console web interface be enabled?"
  type        = string
  default     = "false"
}

variable "hasura_environment" {
  description = "Environment variables for ECS task: [ { name = \"foo\", value = \"bar\" }, ..]"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "hasura_secrets" {
  description = "Secrets variables for ECS task: [ { name = \"foo\", value = \"bar\" }, ..]"
  default     = []
  type = list(object({
    name  = string
    value = string
  }))
}

variable "hasura_cors_domain" {
  description = "CORs domains to allow to access Hasura. Defaults to all domains (not recommended for publicly exposed APIs)"
  type        = string
  default     = "*"
}

variable "cpu_size" {
  type        = number
  default     = 512
  description = "CPU Units for ECS Cluster"
}

variable "memory_size" {
  type        = number
  default     = 1024
  description = "Memory Units for ECS Cluster"
}

variable "auto_scaling_max" {
  description = "Maximum number of Hasura instances"
  type        = number
  default     = 1
}

variable "auto_scaling_min" {
  description = "Minimum number of Hasura instances"
  type        = number
  default     = 1
}

variable "auto_scaling_ram_scale_out_percent" {
  description = "RAM utilization percentage to scale out at"
  type        = number
  default     = 80
}

variable "auto_scaling_cpu_scale_out_percent" {
  description = "CPU utilization percentage to scale out at"
  type        = number
  default     = 80
}

###########################
# Network related variables
###########################
variable "vpc_id" {
  description = "VPC that the hasura instance will be created in."
  type        = string
}

variable "az_count" {
  description = "How many AZ's to create in the VPC"
  default     = 2
}

variable "multi_az" {
  description = "Whether to deploy RDS and ECS in multi AZ mode or not"
  default     = true
}

variable "additional_db_security_groups" {
  description = "List of Security Group IDs to have access to the RDS instance"
  default     = []
}

variable "cidr_bit_offset" {
  type        = number
  default     = 0
  description = "CIDR offset for calculating subnets"
}

variable "internet_route_table_id" {
  type        = string
  description = "Route table for public subnets"
  default     = ""
}

variable "private_subnet_route_table_id" {
  type        = string
  description = "Route table for the private subnet"
  default     = ""
}

variable "internal_alb" {
  type        = bool
  description = "Controls map_public_ip_on_launch for the public subnet, set to false for internal serving."
  default     = false
}

variable "alb_port" {
  type        = number
  description = "Port ALB will listen on. Defaults to 443 for SSL"
  default     = 443
}

variable "acm_certificate_arn" {
  type        = string
  description = "Certificate ARN for use with ALB if listening port is 443"
  default     = ""
}

##########################
# RDS variables
##########################
variable "rds_username" {
  description = "The username for RDS"
  type        = string
}

variable "rds_password" {
  description = "The password for RDS"
  type        = string
  default     = "db.t2.small"
}

variable "pg_version" {
  type           = string
  description = "Postgres DB version"
  default        = "14.5"
}

variable "parameter_group_name" {
  type        = string
  description = "AWS RDS parameter group - change this for a custom group or non-default pg version"
  default     = "default.postgres14"
}

variable "rds_db_name" {
  description = "The DB name in the RDS instance"
}

variable "rds_instance" {
  description = "The size of RDS instance, eg db.t2.micro"
}

variable "create_iam_service_linked_role" {
  description = "Whether to create IAM service linked role for AWS. One needed per AWS account."
  default     = true
}

variable "read_replica_enabled" {
  type        = bool
  description = "Create a read replica or not"
  default     = false
}

variable "read_replica_rds_instance" {
  type        = string
  default     = "db.t2.small"
  description = "What size read replica to create"
}

variable "maintenance_window" {
  type        = string
  description = "When to perform maintenance on the RDS instance"
  default = "sun:06:00-sun:08:00"
}

variable "backup_window" {
  type        = string
  description = "When to perform backups on the RDS instance"
  default     = "04:00-06:00"
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Enable performance insights for the RDS instance"
  default     = false
}

variable "performance_insights_retention_period" {
  type        = number
  description = "Performance insights retention period"
  default     = 7
}

########################################################
# Variables controlling the actions endpoints container
########################################################
variable "use_actions_endpoint" {
  type        = bool
  description = "Whether or not to create the custom actions endpoint container"
  default     = false
}

variable "actions_endpoints_cpu_limit" {
  type        = number
  default     = 256
  description = "CPU Units limit for actions endpoints"
}

variable "actions_endpoints_memory_limit" {
  type        = number
  default     = 512
  description = "Memory Units for actions endpoints"
}

variable "actions_endpoints_port" {
  type        = number
  default     = 5000
  description = "Port actions endpoints are served on"
}

variable "actions_endpoints_image" {
  type        = string
  description = "Docker image name for actions endpoints"
  default     = ""
}

variable "actions_endpoints_env" {
  description = "Enviroment vars for actions endpoints container"
  default     = []
  type = list(object({
    name  = string
    value = string
  }))
}

variable "actions_endpoints_secrets" {
  description = "Values to be stored as secrets for actions endpoints container"
  default     = []
  type = list(object({
    name  = string
    value = string
  }))
}

variable "use_custom_auth_webhook" {
  type        = bool
  description = "Whether or not to use a custom authentication endpoint"
  default     = false
}

variable "custom_auth_url" {
  type        = string
  description = "Custom authentication url, defaults to auth path of actions server"
  default     = "http://localhost:5000/auth"
}

variable "tasks_public_ip" {
  type        = bool
  description = "Whether or not the Hasura tasks get assigned a public IP. Set to true if you are not using a NAT Gateway for private traffic"
  default     = false
}
