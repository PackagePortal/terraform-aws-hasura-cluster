output "private_subnets" {
  description = "Private subnet resources (list)"
  value = aws_subnet.hasura_private
}

output "public_subnets" {
  description = "Public subnet resources (list)"
  value = aws_subnet.hasura_public
}

output "ecs_security_group" {
  description = "AWS security group for "
  value = aws_security_group.hasura_ecs
}

output "read_replica" {
  description = "Read replica (if enabled)"
  value = aws_db_instance.read_replica_hasura
}

output "aws_iam_role_ecs" {
  description = "ECS linked service role if created"
  value = aws_iam_service_linked_role.ecs_service
}

output "alb_arn" {
  description = "Application load balancer ARN"
  value = aws_alb.hasura.arn
}

output "alb_dns" {
  description = "Application load balancer DNS name"
  value = aws_alb.hasura.dns_name
}

output "alb_zone_id" {
  description = "Application load balancer DNS name"
  value = aws_alb.hasura.zone_id
}

output "iam_role" {
  description = "IAM role ECS tasks use"
  value = aws_iam_role.hasura_role
}
