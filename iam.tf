resource "aws_iam_policy" "arangodb_secrets_access" {
  name = "${var.arangodb_service_name}-secrets-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = [aws_secretsmanager_secret.arangodb_jwt_secret.arn]
      }
  ] })
}

resource "aws_iam_role_policy_attachment" "exec_secrets" {
  role       = local.task_execution_role_name
  policy_arn = aws_iam_policy.arangodb_secrets_access.arn
}

resource "aws_iam_policy" "arangodb_bootstrap_secrets_access" {
  count = var.arangodb_bootstrap_enabled && length(var.arangodb_bootstrap_password_secrets) > 0 ? 1 : 0

  name = "${var.arangodb_service_name}-bootstrap-secrets-access"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.arangodb_bootstrap_iam_statements
  })
}

resource "aws_iam_role_policy_attachment" "exec_bootstrap_secrets" {
  count = var.arangodb_bootstrap_enabled && length(var.arangodb_bootstrap_password_secrets) > 0 ? 1 : 0

  role       = local.task_execution_role_name
  policy_arn = aws_iam_policy.arangodb_bootstrap_secrets_access[0].arn
}
