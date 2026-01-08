output "alb_dns_name" {
  value = aws_lb.arangodb_alb.dns_name
}

output "jwt_secret_arn" {
  value = aws_secretsmanager_secret.arangodb_jwt_secret.arn
}
