locals {
  cluster_name = regexreplace(var.cluster_id, "^.*/", "")

  arangodb_number_of_cores = var.arangodb_cpu / 1024

  arangodb_port_mappings = [
    for port in var.arangodb_container_ports : {
      containerPort = tonumber(port)
      hostPort      = tonumber(port)
      protocol      = "tcp"
    }
  ]

  arangodb_bootstrap_secret_names = {
    for env_name, secret in var.arangodb_bootstrap_password_secrets :
    env_name => secret if !startswith(secret, "arn:")
  }

  arangodb_bootstrap_secret_arns_direct = {
    for env_name, secret in var.arangodb_bootstrap_password_secrets :
    env_name => secret if startswith(secret, "arn:")
  }

  arangodb_bootstrap_secret_arn_map = merge(
    local.arangodb_bootstrap_secret_arns_direct,
    { for env_name, secret in data.aws_secretsmanager_secret.arangodb_bootstrap : env_name => secret.arn }
  )

  arangodb_bootstrap_secret_arns = values(local.arangodb_bootstrap_secret_arn_map)

  arangodb_bootstrap_iam_statements = concat(
    length(local.arangodb_bootstrap_secret_arns) > 0 ? [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.arangodb_bootstrap_secret_arns
      }
    ] : [],
    length(var.arangodb_bootstrap_kms_key_arns) > 0 ? [
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.arangodb_bootstrap_kms_key_arns
      }
    ] : []
  )

  #############################################
  # ECS Task Definition Container Definitions #
  #############################################

  # Main ArangoDB container definition
  arangodb_main_container = {
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
      { name = "HEALTH_PROXY_AUTH_FILE", value = "/run/health-proxy/auth-header" },
      { name = "LOAD_BALANCER_URL", value = "http://${aws_lb.arangodb_alb.dns_name}" }
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
  }

  # Health proxy sidecar container definition
  arangodb_health_proxy_container = {
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

  # Bootstrap sidecar container definition
  arangodb_bootstrap_container = {
    name      = "${var.arangodb_service_name}-bootstrap"
    image     = "public.ecr.aws/docker/library/python:3.11-alpine"
    essential = false

    mountPoints = [
      {
        sourceVolume  = "health-proxy-auth"
        containerPath = "/run/health-proxy"
        readOnly      = true
      }
    ]

    environment = [
      { name = "ARANGODB_URL", value = "http://127.0.0.1:${var.arangodb_container_primary_port}" },
      { name = "AUTH_HEADER_FILE", value = "/run/health-proxy/auth-header" },
      { name = "BOOTSTRAP_JSON", value = jsonencode(var.arangodb_bootstrap_config) }
    ]

    secrets = [
      for env_name, secret_arn in local.arangodb_bootstrap_secret_arn_map : {
        name      = env_name
        valueFrom = secret_arn
      }
    ]

    command = [
      "python3",
      "-u",
      "-c",
      <<-EOPY
import json, os, sys, time, urllib.request, urllib.error

ARANGO_URL = os.environ.get("ARANGODB_URL", "http://127.0.0.1:8529")
AUTH_FILE = os.environ.get("AUTH_HEADER_FILE", "/run/health-proxy/auth-header")
BOOTSTRAP_JSON = os.environ.get("BOOTSTRAP_JSON", "{}")

def log(msg):
    sys.stderr.write(f"arangodb-bootstrap: {msg}\\n")
    sys.stderr.flush()

def read_auth_header():
    with open(AUTH_FILE, "r") as handle:
        content = handle.read().strip()
    if content.lower().startswith("authorization:"):
        return content.split(":", 1)[1].strip()
    return content

def request(method, path, body=None, ok=(200, 201, 202, 409)):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(f"{ARANGO_URL}{path}", data=data, method=method)
    req.add_header("Authorization", read_auth_header())
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        if exc.code in ok:
            return exc.code, exc.read()
        raise

def wait_ready():
    for _ in range(120):
        try:
            status, _ = request("GET", "/_admin/status", ok=(200, 503, 401))
            if status == 200:
                return True
        except Exception:
            pass
        time.sleep(2)
    return False

if not wait_ready():
    raise SystemExit("timed out waiting for ArangoDB")

config = json.loads(BOOTSTRAP_JSON or "{}")
users = config.get("users", [])
databases = config.get("databases", [])
collections = config.get("collections", [])

user_password_env = {u["username"]: u["password_env"] for u in users}

def password_for(username):
    env = user_password_env.get(username)
    if not env:
        raise RuntimeError(f"missing password env for user {username}")
    value = os.environ.get(env, "")
    if not value:
        raise RuntimeError(f"empty password for user {username} from {env}")
    return value

for user in users:
    if user["username"] == "root":
        log("Updating root user password, assuming it already exists")
        payload = {
          "passwd": password_for(user["username"]),
          "active": True,
        }
        status, _ = request("PUT", f"/_api/user/{user['username']}", payload)
        if status == 200:
            log("Updated root user password")
        else:
            log(f"Failed to update root user password, status={status}")
    else:
        active = user.get("active")
        if active is None:
            active = True
        payload = {
            "user": user["username"],
            "passwd": password_for(user["username"]),
            "active": active,
        }
        status, _ = request("POST", "/_api/user", payload)
        if status == 409:
            log(f"User {user['username']} already exists, skipping")
        elif status == 201:
            log(f"Added user {user['username']}")

for db in databases:
    db_users = []
    for username in db.get("users", []):
        db_users.append({
            "username": username,
            "passwd": password_for(username),
            "active": True,
        })
    payload = {"name": db["name"], "users": db_users}
    status, _ = request("POST", "/_api/database", payload)
    if status == 409:
        log(f"Database {db['name']} already exists, skipping")
    elif status == 201:
        log(f"Added database {db['name']}")

for col in collections:
    payload = {"name": col["name"]}
    col_type = col.get("type")
    if col_type is not None:
        payload["type"] = col_type
    status, _ = request("POST", f"/_db/{col['db']}/_api/collection", payload)
    if status == 409:
        log(f"Collection {col['name']} in database {col['db']} already exists, skipping")
    elif status == 200:
        log(f"Added collection {col['name']} in database {col['db']}")

log("ArangoDB Bootstrap complete")
      EOPY
    ]

    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.arangodb_log_group.name
        awslogs-region        = var.region
        awslogs-stream-prefix = "arangodb-bootstrap"
      }
    }
  }

  arangodb_container_definitions = concat([
    local.arangodb_main_container,
    local.arangodb_health_proxy_container,
    ],
    var.arangodb_bootstrap_enabled ? [local.arangodb_bootstrap_container] : []
  )
}