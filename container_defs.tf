locals {
  # auth_hook and jwt_hook are optional settings for auth hooks
  auth_hook = var.use_custom_auth_webhook ? [{
    name  = "HASURA_GRAPHQL_AUTH_HOOK"
    value = var.custom_auth_url
  }] : []

  hasura_ecs_env_defaults = concat(local.auth_hook, [
    {
      name  = "HASURA_GRAPHQL_ENABLE_CONSOLE",
      value = var.hasura_console_enabled
    },
    {
      name  = "HASURA_GRAPHQL_CORS_DOMAIN",
      value = var.hasura_cors_domain
    },
    {
      name  = "HASURA_GRAPHQL_PG_CONNECTIONS",
      value = "100"
    }
  ])

  actions_image = {
    networkMode = "awsvpc"
    name        = "actions_endpoints"
    image       = var.actions_endpoints_image
    cpu         = var.actions_endpoints_cpu_limit
    memory      = var.actions_endpoints_memory_limit
    portMappings = [
      {
        containerPort = var.actions_endpoints_port,
        hostPort      = var.actions_endpoints_port
      }
    ]

    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.hasura.name,
        awslogs-region        = var.region,
        awslogs-stream-prefix = "ecs"
      }
    }

    secrets = concat([
      {
        "name"      = "HASURA_GRAPHQL_ADMIN_SECRET",
        "valueFrom" = aws_secretsmanager_secret.admin_secret.arn
      }
    ], local.actions_endpoints_secrets)

    environment = flatten(concat([
      {
        name : "HASURA_ENDPOINT"
        value : "http://localhost:8080/v1/graphql"
      }
    ], var.actions_endpoints_env))
  }

  other_secrets = [for index, secret in var.hasura_secrets : {
    "name"      = secret.name,
    "valueFrom" = aws_secretsmanager_secret.other_secrets[index].arn
  }]

  actions_endpoints_secrets = [for index, secret in var.actions_endpoints_secrets : {
    "name"      = secret.name,
    "valueFrom" = aws_secretsmanager_secret.actions_endpoints_secrets[index].arn
  }]

  ecs_container_definitions = concat([
    {
      image       = "${var.hasura_image_base}:${var.hasura_version_tag}"
      name        = "hasura",
      networkMode = "awsvpc",

      portMappings = [
        {
          containerPort = 8080,
          hostPort      = 8080
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.hasura.name,
          awslogs-region        = var.region,
          awslogs-stream-prefix = "ecs"
        }
      }

      environment = flatten([local.hasura_ecs_env_defaults, var.hasura_environment])
      secrets = concat([
        {
          "name"      = "HASURA_GRAPHQL_DATABASE_URL",
          "valueFrom" = aws_secretsmanager_secret.db_url.arn
        },
        {
          "name"      = "HASURA_GRAPHQL_ADMIN_SECRET",
          "valueFrom" = aws_secretsmanager_secret.admin_secret.arn
        },
        ],
        var.use_jwt_auth ? [
          {
            "name"      = "HASURA_GRAPHQL_JWT_SECRET",
            "valueFrom" = aws_secretsmanager_secret.jwt_secret[0].arn
          }
        ] : [],
      local.other_secrets)
    }
  ], var.use_actions_endpoint ? [local.actions_image] : [])
}
