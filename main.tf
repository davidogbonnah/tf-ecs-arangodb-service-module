resource "random_password" "arangodb_jwt_secret" {
  length  = 64
  special = false # keep it simple for files/env vars
}

resource "aws_secretsmanager_secret" "arangodb_jwt_secret" {
  name        = "arangodb-jwt-secret"
  description = "ArangoDB JWT String Secret"
  tags        = var.tags
}

resource "aws_secretsmanager_secret_version" "arangodb_jwt_secret" {
  secret_id     = aws_secretsmanager_secret.arangodb_jwt_secret.id
  secret_string = random_password.arangodb_jwt_secret.result
}

resource "aws_cloudwatch_log_group" "arangodb_log_group" {
  name              = "/ecs/${var.arangodb_service_name}"
  retention_in_days = 14
  tags = merge(
    var.tags,
    {
      Name = "/ecs/${var.arangodb_service_name}"
    }
  )
}

resource "aws_service_discovery_private_dns_namespace" "arangodb_ns" {
  name = var.arangodb_sd_namespace
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "arangodb_starters" {
  name = var.arangodb_sd_service_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.arangodb_ns.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

resource "aws_ecs_task_definition" "arangodb_td" {
  family                   = "${var.arangodb_service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.arangodb_cpu
  memory                   = var.arangodb_memory
  execution_role_arn       = data.aws_iam_role.arangodb_task_execution_role.arn
  task_role_arn            = data.aws_iam_role.arangodb_task_role.arn

  volume {
    name      = "health-proxy-auth"
    host_path = "/var/lib/ecs/health-proxy-auth"
  }

  volume {
    name      = "arangodb-data"
    host_path = "/var/lib/arangodb"
  }

  container_definitions = jsonencode(local.arangodb_container_definitions)
}

resource "aws_ecs_service" "arangodb" {
  name                              = "arangodb-cluster-service"
  cluster                           = data.aws_ecs_cluster.arangodb_cluster.id
  task_definition                   = aws_ecs_task_definition.arangodb_td.arn
  desired_count                     = var.arangodb_desired_count
  health_check_grace_period_seconds = 300

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.arangodb_ecs_workers.name
    weight            = 1
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.arangodb_ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.arangodb_tg.arn
    container_name   = "${var.arangodb_service_name}-container"
    container_port   = var.arangodb_container_primary_port
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.arangodb_internal_tg.arn
    container_name   = "${var.arangodb_service_name}-container"
    container_port   = var.arangodb_container_primary_port
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  service_registries {
    registry_arn = aws_service_discovery_service.arangodb_starters.arn
  }

  force_new_deployment               = true
  deployment_minimum_healthy_percent = 67
  deployment_maximum_percent         = 167
  depends_on                         = [aws_lb_listener.arangodb_listener, aws_lb_listener.arangodb_internal_listener]
}

resource "aws_lb" "arangodb_alb" {
  name               = "${var.arangodb_service_name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.arangodb_alb_sg.id]
  subnets            = var.public_subnet_ids
  tags               = var.tags
}

resource "aws_lb" "arangodb_internal_alb" {
  name               = "${var.arangodb_service_name}-internal-alb"
  load_balancer_type = "application"
  internal           = true
  security_groups    = [aws_security_group.arangodb_internal_alb_sg.id]
  subnets            = var.private_subnet_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "arangodb_tg" {
  name        = "${var.arangodb_service_name}-tg"
  port        = var.arangodb_container_primary_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 60

  health_check {
    port                = tostring(var.arangodb_health_proxy_port)
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }
  tags = var.tags
}

resource "aws_lb_target_group" "arangodb_internal_tg" {
  name        = "${var.arangodb_service_name}-internal-tg"
  port        = var.arangodb_container_primary_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 60

  health_check {
    port                = tostring(var.arangodb_health_proxy_port)
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }
  tags = var.tags
}

resource "aws_lb_listener" "arangodb_listener" {
  load_balancer_arn = aws_lb.arangodb_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.arangodb_tg.arn
  }
}

resource "aws_lb_listener" "arangodb_internal_listener" {
  load_balancer_arn = aws_lb.arangodb_internal_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.arangodb_internal_tg.arn
  }
}

resource "aws_security_group" "arangodb_alb_sg" {
  name        = "${var.arangodb_service_name}-alb-sg"
  description = "Allow HTTP access to ArangoDB from known Public IPs"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.arangodb_service_name}-alb-sg"
    }
  )
}

resource "aws_security_group" "arangodb_internal_alb_sg" {
  name        = "${var.arangodb_service_name}-internal-alb-sg"
  description = "Allow private ALB access to ArangoDB from private subnets"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.arangodb_service_name}-internal-alb-sg"
    }
  )
}

resource "aws_security_group_rule" "arangodb_alb_sg_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.arangodb_alb_sg.id
  cidr_blocks       = var.public_access_cidrs
  description       = "Allow HTTP access from known Public IPs"
}

resource "aws_security_group_rule" "arangodb_internal_alb_sg_ingress_runner" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.arangodb_internal_alb_sg.id
  cidr_blocks       = data.aws_subnet.private_subnets[*].cidr_block
  description       = "Allow HTTP access from private subnets"
}

resource "aws_security_group_rule" "arangodb_alb_sg_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.arangodb_alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound TCP traffic to anywhere"
}

resource "aws_security_group_rule" "arangodb_internal_alb_sg_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.arangodb_internal_alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound TCP traffic to anywhere"
}

resource "aws_security_group" "arangodb_ecs_sg" {
  name        = "${var.arangodb_service_name}-ecs-sg"
  description = "Allow ECS ArangoDB communication"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.arangodb_service_name}-sg"
    }
  )
}

resource "aws_security_group_rule" "arangodb_ecs_sg_ingress_ports" {
  for_each                 = toset(var.arangodb_container_ports)
  type                     = "ingress"
  from_port                = tonumber(each.value)
  to_port                  = tonumber(each.value)
  protocol                 = "tcp"
  security_group_id        = aws_security_group.arangodb_ecs_sg.id
  source_security_group_id = aws_security_group.arangodb_ecs_sg.id
  description              = "Allow intra-cluster traffic"
}

resource "aws_security_group_rule" "arangodb_ecs_sg_alb_ingress_8528" {
  type                     = "ingress"
  from_port                = var.arangodb_container_primary_port
  to_port                  = var.arangodb_container_primary_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.arangodb_ecs_sg.id
  source_security_group_id = aws_security_group.arangodb_alb_sg.id
  description              = "Allow HTTP access from ALB"
}

resource "aws_security_group_rule" "arangodb_ecs_sg_internal_alb_ingress_8528" {
  type                     = "ingress"
  from_port                = var.arangodb_container_primary_port
  to_port                  = var.arangodb_container_primary_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.arangodb_ecs_sg.id
  source_security_group_id = aws_security_group.arangodb_internal_alb_sg.id
  description              = "Allow HTTP access from internal ALB"
}

resource "aws_security_group_rule" "arangodb_ecs_sg_alb_ingress_health" {
  type                     = "ingress"
  from_port                = var.arangodb_health_proxy_port
  to_port                  = var.arangodb_health_proxy_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.arangodb_ecs_sg.id
  source_security_group_id = aws_security_group.arangodb_alb_sg.id
  description              = "Allow ALB health checks to reach the proxy sidecar"
}

resource "aws_security_group_rule" "arangodb_ecs_sg_internal_alb_ingress_health" {
  type                     = "ingress"
  from_port                = var.arangodb_health_proxy_port
  to_port                  = var.arangodb_health_proxy_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.arangodb_ecs_sg.id
  source_security_group_id = aws_security_group.arangodb_internal_alb_sg.id
  description              = "Allow internal ALB health checks to reach the proxy sidecar"
}
resource "aws_security_group_rule" "arangodb_ecs_sg_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.arangodb_ecs_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound traffic"
}
