# terraform-aws-hasura-cluster

Creates the network, RDS, and ECS Fargate resources for deploying an internal facing hasura instance.

This does not create a public endpoint, link to an API gateway for that.

Example usage:
```terraform
module "example" {
  source                 = "github.com/PackagePortal/terraform-aws-hasura-cluster?ref=v0.0.1"
  
  app_name               = "my-hasura-app"
  region                 = local.region
  hasura_version_tag     = "v2.0.9"
  hasura_admin_secret    = var.admin_secret
  rds_db_name            = "mydbname"
  rds_instance           = "db.t2.small"
  rds_username           = "admin"
  rds_password           = var.rds_pass
  az_count               = 2 # Should be at least 2
  hasura_console_enabled = local.env == "prod" ? "false" : "true" # This must be a string for obscure aws cli reasons
  capacity_provider      = "FARGATE_SPOT" # Hasura is so lightweight SPOT instances should be your default
  read_replica_enabled   = false # Set to true to create a read replica (useful in prod for pointing to metabase)
  cpu_size               = 256
  memory_size            = 512

  use_custom_auth_webhook   = true # Set to false if using default webhook
  custom_auth_webhook_image = var.flask_app_image_name  # Custom auth webhook that can be used

  environment            = [
    {
      name: "ORDER_CREATE_EVENT_URL"
      value: "${var.sns_gateway_root_domain}/orders"
    },
    {
      name: "ORDER_CREATE_EVENT_API_KEY",
      value: var.sns_gateway_api_key
    },
    {
      name: "EVENT_GATEWAY_BASE_URL",
      value: var.event_gateway_url[local.env]
    },
    {
      name: "EVENT_GATEWAY_API_KEY",
      value: var.event_gateway_api_key
    }
  ]

  custom_auth_webhook_env = [
    {
      name: "SCRIPT_PATH"
      value: "auth_server:app"
    }
  ]

  env_name                       = local.env
  additional_db_security_groups  = [] # Add additional security groups that should be able to directly query DB (e.g. metabase)
  create_iam_service_linked_role = false # If you have not deployed an instance in an account set to true
  vpc_id                         = var.vpc_id
  cidr_bit_offset                = 0 # bit offset for subnets
  use_jwt_auth                   = false # Set to true to use built in hasura JWT auth
  internet_route_table_id        = var.private_subnet_internet_route_table_id
  tags                           = local.tags
}
```
