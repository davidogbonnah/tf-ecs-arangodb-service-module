data "aws_ami" "arangodb_ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

data "aws_iam_role" "arangodb_task_execution_role" {
  name = var.task_execution_role
}

data "aws_iam_role" "arangodb_task_role" {
  name = var.task_role
}

data "aws_secretsmanager_secret" "arangodb_bootstrap" {
  for_each = local.arangodb_bootstrap_secret_names

  name = each.value
}

data "aws_ecs_cluster" "arangodb_cluster" {
  cluster_name = var.cluster_name
}

data "aws_subnet" "private_subnets" {
  for_each = toset(var.private_subnet_ids)

  id = each.value
}
