# terraform-aws-hasura-cluster
Manages the creation of an ECS Fargate Cluster running Hasura, an RDS instance, a load
balancer and the associated network resources. See What this module creates for a full list
of what it creates in terraform. See Examples for annotated examples showing how to set up
various uses.

This module expands on the work in this repo https://github.com/Rayraegah/terraform-aws-hasura

## What this module creates
- Application Load Balancer (ALB)
  - Can be configured to be intenral or external as well as http or https. If using https
  the ACM ceritificate needs to be provided.
- ECS Cluster
  - Has a task running Hasura and an optionally created extra task for running endpoints
    for Hasura actions
- Public subnet to hold ALB
- Private subnet for Hasura instance
- Network security groups for private and public subnets
- AWS RDS Postgres Instance
  - Optionally can have a read replica
- AWS Secrets Manager secrets for sensitive variables in both Hasura Task and optional acitons tasks
- Cloudwatch Logging for Hasura cluster and actions endpoints
- S3 Bucket to log ALB access
- Appropriate IAM policies for the ECS cluster to interact with other resources
  - If an actions endpoint image is used, permission will be given to pull ECR images.

## Requirements
- Aws Account and aws cli setup
- Terraform 0.15+
- Existing VPC with Internet Gateway in AWS account and region being deployed to.
- If using HTTPS ACM certificate for domain ALB will be tied to.

Note that applying this Terraform will generate resources that will incur charges on your AWS account.

## Examples

Public facing cluster (requires an ACM certificate to be created outside the module)
with no actions endpoints, using JWT auth (i.e. Firebase).

```terraform
module "example" {
  source                 = "PackagePortal/terraform-aws-hasura-cluster"
  version                = "v1.0.x"
  
  # General Settings
  app_name               = "my-hasura-app"
  env_name               = local.env
  region                 = local.region
  tags                   = local.tags
  
  # RDS Settings
  rds_db_name            = "mydbname"
  rds_instance           = "db.t2.small"
  rds_username           = "admin"
  rds_password           = var.rds_pass
  read_replica_enabled   = false
  
  # Network Settings
  vpc_id                         = var.vpc_id
  cidr_bit_offset                = 8 # bit offset for subnets
  capacity_provider              = "FARGATE_SPOT"
  read_replica_enabled           = false
  additional_db_security_groups  = [] # Add additional security groups that should be able to directly query DB (e.g. metabase)
  acm_certificate_arn            = aws_acm_ceritificate.my_cert.arn
  alb_port                       = 443
  hasura_cors_domain             = "mydomain.com, mydomain.com:443" # Will only allow your website origin on CORs

  # If you are using non-default route tables, private_subnet_route_table_id and
  # internet_route_table_id are used to set route table associations for the private
  # and public subnets respectively

  # JWT Auth Settings
  use_jwt_auth           = true # Set to true to use built in hasura JWT auth
  hasura_jwt_secret_algo = "RS256"
  hasura_jwt_secret_key  = var.my_jwt_secret_key

  # Hasura settings
  cpu_size               = 256
  memory_size            = 512
  hasura_version_tag     = "v2.11.0"
  hasura_admin_secret    = var.admin_secret
  hasura_console_enabled = local.env == "prod" ? "false" : "true" # This must be a string
  hasura_environment     = [
    {
      name: "MY_APP_SETTING"
      value: "Hi"
    }
  ]
  hasura_secrets = [
    {
      name: "MY_SUPER_SECRET_APP_SETTING"
      value: var.my_super_secret_app_setting
    }
  ]
}
```

Internal facing cluster with actions endpoints task added, using an auth endpoint on
the actions endpoints task. Using a network load balancer this can be placed behind
an API gateway while still remaining internal.

```terraform
module "example" {
  source                 = "PackagePortal/terraform-aws-hasura-cluster"
  version                = "v1.0.x"
  
  # General Settings
  app_name               = "my-hasura-app"
  env_name               = local.env
  region                 = local.region
  tags                   = local.tags
  
  # RDS Settings
  rds_db_name            = "mydbname"
  rds_instance           = "db.t2.small"
  rds_username           = "admin"
  rds_password           = var.rds_pass
  read_replica_enabled   = false
  
  # Network Settings
  vpc_id                         = var.vpc_id
  cidr_bit_offset                = 8 # bit offset for subnets
  capacity_provider              = "FARGATE_SPOT"
  additional_db_security_groups  = [] # Add additional security groups that should be able to directly query DB (e.g. metabase)
  alb_port                       = 80
  internal_alb                   = true

  # If you are using non-default route tables, private_subnet_route_table_id and
  # internet_route_table_id are used to set route table associations for the private
  # and public subnets respectively

  # JWT Auth Settings
  use_custom_auth_webhook = true
  custom_auth_url         = "http://localhost:5000/my-auth-endpoint"

  # Hasura settings
  cpu_size               = 512
  memory_size            = 1024
  hasura_version_tag     = "v2.11.0"
  hasura_admin_secret    = var.admin_secret
  hasura_cors_domain     = "*"
  hasura_console_enabled = local.env == "prod" ? "false" : "true" # This must be a string
  hasura_environment     = [
    {
      name: "MY_APP_SETTING"
      value: "Hi"
    }
  ]
  hasura_secrets = [
    {
      name: "MY_SUPER_SECRET_APP_SETTING"
      value: var.my_super_secret_app_setting
    }
  ]

  # Actions endpoints settings
  use_actions_endpoint           = true
  actions_endpoints_cpu_limit    = 256
  actions_endpoints_memory_limit = 512
  actions_endpoints_port         = 5000
  actions_endpoints_image        = "my-aws-ecr-repo-image:tag"
  actions_endpoints_env          = [
    {
      name: "MY_OTHER_APP_SETTING"
      value: "Hi again"
    }
  ]
  actions_endpoints_secrets = [
    {
      name: "SUPER_SECRET_SETTING_2"
      value: var.super_secret_setting_2
    }
  ]
}
```
