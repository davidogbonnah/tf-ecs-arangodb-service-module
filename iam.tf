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
  role       = var.task_execution_role
  policy_arn = aws_iam_policy.arangodb_secrets_access.arn
}