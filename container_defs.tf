locals {
  # auth_hook and jwt_hook are optional settings for auth hooks
  auth_hook = var.use_custom_auth_webhook ? [{
    name = "HASURA_GRAPHQL_AUTH_HOOK"
    value = "http://localhost:5000"
  }] : []

  ecs_environment = concat(local.auth_hook, [
    {
      name  = "HASURA_GRAPHQL_ENABLE_CONSOLE",
      value = var.hasura_console_enabled
    },
    {
      name  = "HASURA_GRAPHQL_CORS_DOMAIN",
      value = "*"
    },
    {
      name  = "HASURA_GRAPHQL_PG_CONNECTIONS",
      value = "100"
    }
  ])

  auth_image = {
    networkMode = "awsvpc"
    name        = "auth"
    image       = var.custom_auth_webhook_image
    cpu         = 256
    memory      = 512
    portMappings = [
      {
        containerPort = 5000,
        hostPort      = 5000
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
        "name"  = "HASURA_GRAPHQL_ADMIN_SECRET",
        "valueFrom" = aws_secretsmanager_secret.admin_secret.arn
      }
    ], local.custom_auth_webhook_secrets)

    environment = flatten(concat([
      {
        name: "HASURA_ENDPOINT"
        value: "http://localhost:8080/v1/graphql"
      }
    ], var.custom_auth_webhook_env))
  }

  other_secrets = [for index, secret in var.secrets: {
    "name" = secret.name,
    "valueFrom" = aws_secretsmanager_secret.other_secrets[index].arn
  }]

  custom_auth_webhook_secrets = [for index, secret in var.custom_auth_webhook_secrets: {
    "name" = secret.name,
    "valueFrom" = aws_secretsmanager_secret.custom_auth_webhook_secrets[index].arn
  }]

  ecs_container_definitions = concat([
    {
      image       = "hasura/graphql-engine:${var.hasura_version_tag}"
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

      environment = flatten([local.ecs_environment, var.environment])
      secrets = concat([
        {
          "name"  = "HASURA_GRAPHQL_DATABASE_URL",
          "valueFrom" = aws_secretsmanager_secret.db_url.arn
        },
        {
          "name"  = "HASURA_GRAPHQL_ADMIN_SECRET",
          "valueFrom" = aws_secretsmanager_secret.admin_secret.arn
        },
      ],
      var.use_jwt_auth ? [
        {
          "name"  = "HASURA_GRAPHQL_JWT_SECRET",
          "valueFrom" = aws_secretsmanager_secret.jwt_secret[0].arn
        }
      ] : [],
      local.other_secrets)
    }
  ], var.use_custom_auth_webhook ? [local.auth_image] : [])

  alb_port = 80
}
