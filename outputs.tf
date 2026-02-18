output "alb_dns_name" {
  value = aws_lb.arangodb_alb.dns_name
}

output "internal_alb_dns_name" {
  value = aws_lb.arangodb_internal_alb.dns_name
}

output "alb_url" {
  value = "http://${aws_lb.arangodb_alb.dns_name}"
}

output "internal_alb_url" {
  value = "http://${aws_lb.arangodb_internal_alb.dns_name}"
}

output "capacity_provider_name" {
  value = aws_ecs_capacity_provider.arangodb_ecs_workers.name
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.arangodb_jwt_secret.arn
}
