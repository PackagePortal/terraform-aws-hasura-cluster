output "private_subnets" {
  value = aws_subnet.hasura_private
}

output "public_subnets" {
  value = aws_subnet.hasura_public
}

output "ecs_security_group" {
  value = aws_security_group.hasura_ecs
}

output "read_replica" {
  value = aws_db_instance.read_replica_hasura
}

output "aws_iam_role_ecs" {
  value = aws_iam_service_linked_role.ecs_service
}

output "alb_arn" {
  value = aws_alb.hasura.arn
}

output "alb_dns" {
  value = aws_alb.hasura.dns_name
}

output "iam_role" {
  value = aws_iam_role.hasura_role
}
