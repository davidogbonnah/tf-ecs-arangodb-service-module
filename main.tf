locals {
  arangodb_number_of_cores = var.arangodb_cpu / 1024
  arangodb_port_mappings = [
    for port in var.arangodb_container_ports : {
      containerPort = tonumber(port)
      hostPort      = tonumber(port)
      protocol      = "tcp"
    }
  ]
}

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
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  volume {
    name      = "health-proxy-auth"
    host_path = "/var/lib/ecs/health-proxy-auth"
  }

  volume {
    name      = "arangodb-data"
    host_path = "/var/lib/arangodb"
  }

  container_definitions = jsonencode([
    {
      name      = "${var.arangodb_service_name}-container"
      image     = "${var.arangodb_repository_url}:${var.arangodb_tag}"
      cpu       = var.arangodb_cpu
      memory    = var.arangodb_memory
      essential = true

      portMappings = local.arangodb_port_mappings

      mountPoints = [
        {
          sourceVolume  = "health-proxy-auth"
          containerPath = "/run/health-proxy"
          readOnly      = false
        },
        {
          sourceVolume  = "arangodb-data"
          containerPath = "/var/lib/arangodb"
          readOnly      = false
        }
      ]

      environment = [
        { name = "SERVICE_DNS", value = "${var.arangodb_sd_service_name}.${var.arangodb_sd_namespace}" },
        { name = "STARTER_EXPECTED_COUNT", value = tostring(var.arangodb_desired_count) },
        { name = "AGENCY_SIZE", value = tostring(var.arangodb_agency_size) },
        { name = "ARANDGODB_OVERRIDE_DETECTED_TOTAL_MEMORY", value = "${var.arangodb_memory}M" },
        { name = "ARANDGODB_OVERRIDE_DETECTED_NUMBER_OF_CORES", value = tostring(local.arangodb_number_of_cores) },
        { name = "STARTER_PEER_DISCOVERY_TIMEOUT", value = "120" },
        { name = "STARTER_DATA_DIR_PATTERN", value = "/var/lib/arangodb/db%d" },
        { name = "HEALTH_PROXY_AUTH_FILE", value = "/run/health-proxy/auth-header" }
      ]

      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret_version.arangodb_jwt_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.arangodb_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "arangodb"
        }
      }
    },
    {
      name      = "${var.arangodb_service_name}-health-proxy"
      image     = "public.ecr.aws/docker/library/python:3.11-alpine"
      essential = true

      portMappings = [
        {
          containerPort = var.arangodb_health_proxy_port
          hostPort      = var.arangodb_health_proxy_port
          protocol      = "tcp"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "health-proxy-auth"
          containerPath = "/run/health-proxy"
          readOnly      = true
        }
      ]

      environment = [
        { name = "HEALTH_PROXY_PORT", value = tostring(var.arangodb_health_proxy_port) },
        { name = "HEALTH_PROXY_TARGET", value = "http://127.0.0.1:${var.arangodb_container_primary_port}${var.arangodb_health_check_path}" },
        { name = "HEALTH_PROXY_AUTH_FILE", value = "/run/health-proxy/auth-header" }
      ]

      command = [
        "python3",
        "-u",
        "-c",
        <<-EOPY
import http.server, urllib.request, urllib.error, os, sys
TARGET = os.environ.get("HEALTH_PROXY_TARGET", "")
PORT = int(os.environ.get("HEALTH_PROXY_PORT", "18080"))
AUTH_FILE = os.environ.get("HEALTH_PROXY_AUTH_FILE", "").strip()

def log(msg):
    sys.stderr.write(f"health-proxy: {msg}\\n")

def load_authorization_header():
    if not AUTH_FILE:
        raise RuntimeError("missing auth header file path")
    try:
        with open(AUTH_FILE, "r") as handle:
            content = handle.read().strip()
    except OSError as exc:
        raise RuntimeError(f"failed to read auth header: {exc}") from exc
    if not content:
        raise RuntimeError("empty auth header")
    if content.lower().startswith("authorization:"):
        return content.split(":", 1)[1].strip()
    return content

def fetch_status():
    if not TARGET:
        raise RuntimeError("missing target")
    req = urllib.request.Request(TARGET)
    req.add_header("Authorization", load_authorization_header())
    with urllib.request.urlopen(req, timeout=5) as resp:
        body = resp.read()
        return resp.status, body

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/health", "/_health"):
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"not found")
            return
        try:
            status, body = fetch_status()
            healthy = 200 <= status < 400
            log(f"{self.client_address[0]} {self.command} {self.path} status={status} healthy={healthy}")
        except Exception as exc:
            log(f"{self.client_address[0]} {self.command} {self.path} error={exc}")
            self.send_response(503)
            self.end_headers()
            self.wfile.write(str(exc).encode())
            return
        self.send_response(200 if healthy else status)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass

http.server.ThreadingHTTPServer(("", PORT), Handler).serve_forever()
EOPY
      ]

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.arangodb_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "arangodb-health"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "arangodb" {
  name                              = "arangodb-cluster-service"
  cluster                           = var.cluster_id
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

  force_new_deployment       = true
  deployment_maximum_percent = 200
  depends_on                 = [aws_lb_listener.arangodb_listener]
}

resource "aws_lb" "arangodb_alb" {
  name               = "${var.arangodb_service_name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.arangodb_alb_sg.id]
  subnets            = var.public_subnet_ids
  tags               = var.tags
}

resource "aws_lb_target_group" "arangodb_tg" {
  name        = "${var.arangodb_service_name}-tg"
  port        = var.arangodb_container_primary_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
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

resource "aws_security_group_rule" "arangodb_alb_sg_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.arangodb_alb_sg.id
  cidr_blocks       = var.public_network_ip_range
  description       = "Allow HTTP access from known Public IPs"
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

resource "aws_security_group_rule" "arangodb_ecs_sg_alb_ingress_health" {
  type                     = "ingress"
  from_port                = var.arangodb_health_proxy_port
  to_port                  = var.arangodb_health_proxy_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.arangodb_ecs_sg.id
  source_security_group_id = aws_security_group.arangodb_alb_sg.id
  description              = "Allow ALB health checks to reach the proxy sidecar"
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
