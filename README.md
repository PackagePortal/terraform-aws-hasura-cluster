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
  - Has a service that runs a task for Hasura and an optionally created extra task for running endpoints
    for Hasura actions
  - Auto scaling can be configured
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
  version                = "v1.1.x"
  
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

  # Auto scaling settings - scale out up to 10 at 100% cpu or ram
  auto_scaling_ram_scale_out_percent = 100
  auto_scaling_cpu_scale_out_percent = 100
  auto_scaling_max                   = 10
  auto_scaling_min                   = 1

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
## Reference

Created with [terraform-docs](https://github.com/terraform-docs/terraform-docs)

### Resources

| Name | Type |
|------|------|
| [aws_alb.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb) | resource |
| [aws_alb_listener.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_listener) | resource |
| [aws_alb_target_group.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/alb_target_group) | resource |
| [aws_cloudwatch_log_group.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_db_instance.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_instance.read_replica_hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_subnet_group.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_ecs_cluster.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.ecr_image_pull](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.hasura_log_publishing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.hasura_secret_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.hasura_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ecr_image_pull](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.hasura_role_log_publishing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.hasura_secret_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_service_linked_role.ecs_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_route_table_association.lb_subnet_to_route_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.private_subnet_route_table_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_secretsmanager_secret.actions_endpoints_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.admin_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.db_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.jwt_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.other_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.actions_endpoints_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.admin_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.db_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.jwt_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.other_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.hasura_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.hasura_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.hasura_rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.hasura_private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.hasura_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_appautoscaling_target.hasura_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_appautoscaling_policy.hasura_memory_autoscaling_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.hasura_cpu_autoscaling_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_elb_service_account.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/elb_service_account) | data source |
| [aws_iam_policy_document.ecr_image_pull](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.hasura_assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.hasura_log_publishing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.hasura_secret_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_vpc.hasura](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | Certificate ARN for use with ALB if listening port is 443 | `string` | `""` | no |
| <a name="input_actions_endpoints_cpu_limit"></a> [actions\_endpoints\_cpu\_limit](#input\_actions\_endpoints\_cpu\_limit) | CPU Units limit for actions endpoints | `string` | `"256"` | no |
| <a name="input_actions_endpoints_env"></a> [actions\_endpoints\_env](#input\_actions\_endpoints\_env) | Enviroment vars for actions endpoints container | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_actions_endpoints_image"></a> [actions\_endpoints\_image](#input\_actions\_endpoints\_image) | Docker image name for actions endpoints | `string` | `""` | no |
| <a name="input_actions_endpoints_memory_limit"></a> [actions\_endpoints\_memory\_limit](#input\_actions\_endpoints\_memory\_limit) | Memory Units for actions endpoints | `string` | `"512"` | no |
| <a name="input_actions_endpoints_port"></a> [actions\_endpoints\_port](#input\_actions\_endpoints\_port) | Port actions endpoints are served on | `number` | `5000` | no |
| <a name="input_actions_endpoints_secrets"></a> [actions\_endpoints\_secrets](#input\_actions\_endpoints\_secrets) | Values to be stored as secrets for actions endpoints container | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_additional_db_security_groups"></a> [additional\_db\_security\_groups](#input\_additional\_db\_security\_groups) | List of Security Group IDs to have access to the RDS instance | `list` | `[]` | no |
| <a name="input_alb_port"></a> [alb\_port](#input\_alb\_port) | Port ALB will listen on. Defaults to 443 for SSL | `number` | `443` | no |
| <a name="input_app_name"></a> [app\_name](#input\_app\_name) | Used to name the hasura instance | `string` | n/a | yes |
| <a name="input_auto_scaling_max"></a> [auto\_scaling\_max](#input\_auto\_scaling\_max) | Maximum number of Hasura instances | `number` | n/a | no |
| <a name="input_auto_scaling_min"></a> [auto\_scaling\_min](#input\_auto_scaling_min) | Minimum number of Hasura instances | `number` | n/a | no |
| <a name="input_auto_scaling_ram_scale_out_percent"></a> [auto\_scaling\_ram\_scale\_out\_percent](#input\_auto\_scaling\_ram\_scale\_out\_percent) | RAM utilization percentage to scale out at | `number` | n/a | no |
| <a name="input_auto_scaling_cpu_scale_out_percent"></a> [auto\_scaling\_cpu\_scale\_out\_percent](#input\_auto\_scaling\_cpu\_scale\_out\_percent) | CPU utilization percentage to scale out at | `number` | n/a | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | How many AZ's to create in the VPC | `number` | `2` | no |
| <a name="input_capacity_provider"></a> [capacity\_provider](#input\_capacity\_provider) | Capacity provider for tasks | `string` | `"FARGATE_SPOT"` | no |
| <a name="input_cidr_bit_offset"></a> [cidr\_bit\_offset](#input\_cidr\_bit\_offset) | CIDR offset for calculating subnets | `number` | `0` | no |
| <a name="input_cpu_size"></a> [cpu\_size](#input\_cpu\_size) | CPU Units for ECS Cluster | `string` | `"512"` | no |
| <a name="input_create_iam_service_linked_role"></a> [create\_iam\_service\_linked\_role](#input\_create\_iam\_service\_linked\_role) | Whether to create IAM service linked role for AWS. One needed per AWS account. | `bool` | `true` | no |
| <a name="input_custom_auth_url"></a> [custom\_auth\_url](#input\_custom\_auth\_url) | Custom authentication url, defaults to auth path of actions server | `string` | `"http://localhost:5000/auth"` | no |
| <a name="input_env_name"></a> [env\_name](#input\_env\_name) | Enviroment prefix on resource names | `string` | n/a | yes |
| <a name="input_hasura_admin_secret"></a> [hasura\_admin\_secret](#input\_hasura\_admin\_secret) | The admin secret to secure hasura; for admin access | `string` | n/a | yes |
| <a name="input_hasura_console_enabled"></a> [hasura\_console\_enabled](#input\_hasura\_console\_enabled) | Should the Hasura Console web interface be enabled? | `string` | `"false"` | no |
| <a name="input_hasura_cors_domain"></a> [hasura\_cors\_domain](#input\_hasura\_cors\_domain) | CORs domains to allow to access Hasura. Defaults to all domains (not recommended for publicly exposed APIs) | `string` | `"*"` | no |
| <a name="input_hasura_environment"></a> [hasura\_environment](#input\_hasura\_environment) | Environment variables for ECS task: [ { name = "foo", value = "bar" }, ..] | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_hasura_image_base"></a> [hasura\_image\_base](#input\_hasura\_image\_base) | What Hasura Docker image to use | `string` | `"hasura/graphql-engine"` | no |
| <a name="input_hasura_jwt_secret_algo"></a> [hasura\_jwt\_secret\_algo](#input\_hasura\_jwt\_secret\_algo) | The algorithm for JWT verification (HS256 or RS256) | `string` | `""` | no |
| <a name="input_hasura_jwt_secret_key"></a> [hasura\_jwt\_secret\_key](#input\_hasura\_jwt\_secret\_key) | The secret shared key for JWT verification | `string` | `""` | no |
| <a name="input_hasura_secrets"></a> [hasura\_secrets](#input\_hasura\_secrets) | Secrets variables for ECS task: [ { name = "foo", value = "bar" }, ..] | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_hasura_version_tag"></a> [hasura\_version\_tag](#input\_hasura\_version\_tag) | The hasura graphql engine version tag | `string` | n/a | yes |
| <a name="input_internal_alb"></a> [internal\_alb](#input\_internal\_alb) | Controls map\_public\_ip\_on\_launch for the public subnet, set to false for internal serving. | `bool` | `false` | no |
| <a name="input_internet_route_table_id"></a> [internet\_route\_table\_id](#input\_internet\_route\_table\_id) | Route table for public subnets | `string` | `""` | no |
| <a name="input_logs_domain"></a> [logs\_domain](#input\_logs\_domain) | Log domain name | `string` | `"hasura-logs"` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Memory Units for ECS Cluster | `string` | `"1024"` | no |
| <a name="input_multi_az"></a> [multi\_az](#input\_multi\_az) | Whether to deploy RDS and ECS in multi AZ mode or not | `bool` | `true` | no |
| <a name="input_parameter_group_name"></a> [parameter\_group\_name](#input\_parameter\_group\_name) | AWS RDS parameter group - change this for a custom group or non-default pg version | `string` | `"default.postgres14"` | no |
| <a name="input_pg_version"></a> [pg\_version](#input\_pg\_version) | Postgres DB version | `string` | `"14.5"` | no |
| <a name="input_private_subnet_route_table_id"></a> [private\_subnet\_route\_table\_id](#input\_private\_subnet\_route\_table\_id) | Route table for the private subnet | `string` | `""` | no |
| <a name="input_rds_db_name"></a> [rds\_db\_name](#input\_rds\_db\_name) | The DB name in the RDS instance | `any` | n/a | yes |
| <a name="input_rds_instance"></a> [rds\_instance](#input\_rds\_instance) | The size of RDS instance, eg db.t2.micro | `any` | n/a | yes |
| <a name="input_rds_password"></a> [rds\_password](#input\_rds\_password) | The password for RDS | `string` | `"db.t2.small"` | no |
| <a name="input_rds_username"></a> [rds\_username](#input\_rds\_username) | The username for RDS | `string` | n/a | yes |
| <a name="input_read_replica_enabled"></a> [read\_replica\_enabled](#input\_read\_replica\_enabled) | Create a read replica or not | `bool` | `false` | no |
| <a name="input_read_replica_rds_instance"></a> [read\_replica\_rds\_instance](#input\_read\_replica\_rds\_instance) | What size read replica to create | `string` | `"db.t2.small"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy in | `string` | `"us-east-1"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | AWS Resource tags | `map(string)` | `{}` | no |
| <a name="input_use_actions_endpoint"></a> [use\_actions\_endpoint](#input\_use\_actions\_endpoint) | Whether or not to create the custom actions endpoint container | `bool` | `false` | no |
| <a name="input_use_custom_auth_webhook"></a> [use\_custom\_auth\_webhook](#input\_use\_custom\_auth\_webhook) | Whether or not to use a custom authentication endpoint | `bool` | `false` | no |
| <a name="input_use_jwt_auth"></a> [use\_jwt\_auth](#input\_use\_jwt\_auth) | Whether to set up JWT auth webhooks on the Hasura instance | `bool` | `false` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC that the hasura instance will be created in. | `string` | n/a | yes |

### Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | Application load balancer ARN |
| <a name="output_alb_dns"></a> [alb\_dns](#output\_alb\_dns) | Application load balancer DNS name |
| <a name="output_aws_iam_role_ecs"></a> [aws\_iam\_role\_ecs](#output\_aws\_iam\_role\_ecs) | ECS linked service role if created |
| <a name="output_ecs_security_group"></a> [ecs\_security\_group](#output\_ecs\_security\_group) | AWS security group for |
| <a name="output_iam_role"></a> [iam\_role](#output\_iam\_role) | IAM role ECS tasks use |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | Private subnet resources (list) |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | Public subnet resources (list) |
| <a name="output_read_replica"></a> [read\_replica](#output\_read\_replica) | Read replica (if enabled) |
<!-- END_TF_DOCS -->
