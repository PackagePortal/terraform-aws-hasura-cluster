# -----------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# -----------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# -----------------------------------------------------------------------------
# PARAMETERS
# -----------------------------------------------------------------------------

variable "region" {
  type        = string
  description = "Region to deploy"
  default     = "ap-northeast-1" # Asia Pacific Tokyo
}

variable "app_name" {
  type        = string
  description = "Name of application"
}

variable "use_jwt_auth" {
  type        = bool
  description = "Whether to set up JWT auth webhooks on the Hasura instance"
  default     = false
}

variable "vpc_id" {
  description = "VPC Id"
  type        = string
}

variable "capacity_provider" {
  description = "Capacity provider for tasks"
  type        = string
  default     = "FARGATE"
}

variable "domain" {
  description = "Log domain name"
  default = "hasura-logs"
}

variable "hasura_subdomain" {
  description = "The Subdomain for your hasura graphql service."
  default = ""
}

variable "app_subdomain" {
  description = "The Subdomain for your application that will make CORS requests to the hasura_subdomain"
  default = ""
}
variable "hasura_version_tag" {
  description = "The hasura graphql engine version tag"
}

variable "hasura_admin_secret" {
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
}

variable "rds_username" {
  description = "The username for RDS"
}

variable "rds_password" {
  description = "The password for RDS"
}

variable "rds_db_name" {
  description = "The DB name in the RDS instance"
}

variable "rds_instance" {
  description = "The size of RDS instance, eg db.t2.micro"
}

variable "az_count" {
  description = "How many AZ's to create in the VPC"
  default     = 2
}

variable "multi_az" {
  description = "Whether to deploy RDS and ECS in multi AZ mode or not"
  default     = true
}

variable "vpc_enable_dns_hostnames" {
  description = "A boolean flag to enable/disable DNS hostnames in the VPC. Defaults false."
  default     = false
}

variable "environment" {
  description = "Environment variables for ECS task: [ { name = \"foo\", value = \"bar\" }, ..]"
  default     = []
}

variable "secrets" {
  description = "Secrets variables for ECS task: [ { name = \"foo\", value = \"bar\" }, ..]"
  default     = []
}

variable "additional_db_security_groups" {
  description = "List of Security Group IDs to have access to the RDS instance"
  default     = []
}

variable "create_iam_service_linked_role" {
  description = "Whether to create IAM service linked role for AWS ElasticSearch service. Can be only one per AWS account."
  default     = true
}

variable "env_name" {
  type        = string
  description = "Adds environment prefix to resource names"
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

variable "cpu_size" {
  type        = string
  default     = "256"
  description = "CPU Units for Hasura ECS Cluster"
}

variable "memory_size" {
  type        = string
  default     = "512"
  description = "Memory Units for Hasura ECS Cluster"
}

variable "cidr_bit_offset" {
  type        = number
  default     = 0
  description = "CIDR offset for calculating subnets"
}

variable "use_custom_auth_webhook" {
  type = bool
  description = "Will a custom auth webhook be used"
  default = false
}

variable "custom_auth_webhook_image" {
  type = string
  description = "Docker image name for auth webhook"
  default = ""
}

variable "custom_auth_webhook_env" {
  type        = list(map(string))
  description = "Extra env vars for Auth webhook"
  default     = []
}

variable "custom_auth_webhook_secrets" {
  type        = list(map(string))
  description = "Extra secrets for Auth webhook"
  default     = []
}

variable "internet_route_table_id" {
  type        = string
  description = "Id of route table to get internet access for private subnets"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "AWS Resource tags"
  default = {}
}

variable "private_subnet_internet_route_table_id_hasura_vpc" {
  type = map(string)
  default = {
    dev  = "rtb-05b99407c66ee9d41"
    prod = "rtb-05fc07704dddbe854"
  }
}
