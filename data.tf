data "aws_ami" "arangodb_ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

data "aws_secretsmanager_secret" "arangodb_bootstrap" {
  for_each = local.arangodb_bootstrap_secret_names

  name = each.value
}

data "aws_subnet" "private_subnets" {
  for_each = toset(var.private_subnet_ids)

  id = each.value
}
