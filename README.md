# tf-ecs-arangodb-service-module
## Terraform module for deploying an ArangoDB cluster on AWS ECS with ALB and EC2 capacity.

### Architecture Components

- **Amazon ECS Cluster (Fargate)**
  - Manages the lifecycle of containerized ArangoDB workloads.
  - Serverless compute: no EC2 management required.

- **ECR (Elastic Container Registry)**
  - Stores Docker images for the ArangoDB container.
  - ECS pulls images from ECR at deployment time.

- **IAM Roles**
  - **Task Execution Role:** Allows ECS tasks to pull images from ECR and write logs to CloudWatch.
  - **Task Role:** (Optional) Grants the running container permissions to access AWS APIs if needed.

- **Application Load Balancer (ALB)**
  - Routes HTTP(S) traffic from clients to the ECS service.
  - Uses a target group to register ECS tasks as endpoints.
  - Listener forwards requests to the correct target group.

- **Security Groups**
  - **ALB Security Group:** Allows inbound HTTP/HTTPS from the public internet or specified CIDR ranges.
  - **ECS Security Group:** Allows inbound traffic from the ALB only; restricts other access.

- **CloudWatch Logs**
  - Captures and stores logs from the OPA container for monitoring and troubleshooting.

- **Networking**
  - **VPC/Subnets:** ECS tasks and ALB are deployed in specified subnets (typically public for ALB, private for ECS tasks).
  - **Ingress/Egress:** Controlled via security groups and subnet routing.

- **CI/CD Integration**
  - **Bitbucket Pipelines & GitHub Actions:** Automate Terraform validation, security scanning, and deployment.

### Traffic Flow

```text
[User/Client]
     |
     v
[Application Load Balancer] <-- Security Group (HTTP/HTTPS)
     |
     v
[ECS Service (ArangoDB Container)] <-- Security Group (from ALB only)
     |
     v
[CloudWatch Logs]   [ECR (for image pulls)]
```

## Prerequisites

- Terraform `>= 1.11.0`
- AWS CLI configured with appropriate permissions
- Docker (for building and pushing container images)


## Container Environment Variables

### ArangoDB starter container (`arangodb-container`)
- `JWT_SECRET` (secret): required; used to enable authentication and to generate the health-proxy auth header.
- `JWT_FILE`: path where the JWT secret is written (default `/run/jwt-secret/jwtSecret`).
- `SERVICE_DNS`: Cloud Map DNS name used to discover peer starters.
- `STARTER_PORT`: starter API port (default `8528`).
- `STARTER_PEER_DISCOVERY_TIMEOUT`: seconds to wait for peer discovery before bootstrapping.
- `STARTER_PEER_DISCOVERY_INTERVAL`: seconds between DNS discovery checks.
- `STARTER_DATA_DIR`: optional override for the starter data directory.
- `STARTER_DATA_DIR_PATTERN`: pattern for per-node data directories (default `./db%d`).
- `AGENCY_SIZE`: agency size passed to the starter.
- `STARTER_EXPECTED_COUNT`: reserved for future use; currently not consumed by `entrypoint.sh`.
- `ARANDGODB_OVERRIDE_DETECTED_TOTAL_MEMORY`: override ArangoDB memory detection.
- `ARANDGODB_OVERRIDE_DETECTED_NUMBER_OF_CORES`: override ArangoDB CPU detection.
- `HEALTH_PROXY_AUTH_FILE`: path where the proxy auth header is written (default `/run/health-proxy/auth-header`).

### ArangoDB health proxy container (`arangodb-health-proxy`)
- `HEALTH_PROXY_PORT`: port exposed by the proxy for ALB health checks.
- `HEALTH_PROXY_TARGET`: upstream health URL on the coordinator (`http://127.0.0.1:<port>/_admin/status`).
- `HEALTH_PROXY_AUTH_FILE`: file containing the `Authorization` header to use.

### ArangoDB bootstrap container (`arangodb-bootstrap`)
- `ARANGODB_URL`: URL of the ArangoDB coordinator endpoint used for bootstrapping (e.g., `http://127.0.0.1:8529`).
- `AUTH_HEADER_FILE`: file containing the `Authorization` header to use for bootstrap API calls.
- `BOOTSTRAP_JSON`: JSON string containing bootstrap configuration for users, databases, and collections.

## ArangoDB Starter Entrypoint Flow

The ArangoDB ECS task uses `entrypoint.sh` to bootstrap or join a cluster. The flow below highlights the key stages and which environment variables (from the task definition) influence them.

1. **Initialize secrets and auth header**
   - Reads `JWT_SECRET` (secret) and writes it to `JWT_FILE`.
   - Uses `JWT_SECRET` to generate the health-proxy Authorization header and writes it to `HEALTH_PROXY_AUTH_FILE`.
2. **Discover peers via Cloud Map**
   - Resolves `SERVICE_DNS` to find starter IPs.
   - Uses `STARTER_PEER_DISCOVERY_TIMEOUT` and `STARTER_PEER_DISCOVERY_INTERVAL` to control how long and how often to poll.
3. **Select a stable data directory**
   - Chooses a per-node data directory from `STARTER_DATA_DIR_PATTERN` (or `STARTER_DATA_DIR` if set).
   - Ensures the data directory exists before starting the starter.
4. **Bootstrap or join**
   - If no peer starters are discovered (excluding self), it starts the initial node.
   - If peers are found, it computes a join list and starts as a joining node.
   - In both cases it passes `AGENCY_SIZE` into the starter and sets its advertised address from the container IPs.
5. **Health checks via sidecar**
   - The health proxy uses `HEALTH_PROXY_TARGET` and `HEALTH_PROXY_AUTH_FILE` to call the coordinator health endpoint without exposing credentials to the ALB.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |
| <a name="provider_random"></a> [random](#provider\_random) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.arangodb_ecs_workers_asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_cloudwatch_log_group.arangodb_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_capacity_provider.arangodb_ecs_workers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_capacity_provider) | resource |
| [aws_ecs_service.arangodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.arangodb_td](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_instance_profile.arangodb_ecs_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.arangodb_bootstrap_secrets_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.arangodb_secrets_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.arangodb_ecs_instance_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.arangodb_ecs_instance_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.exec_bootstrap_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.exec_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.arangodb_ecs_workers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.arangodb_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb.arangodb_internal_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.arangodb_internal_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.arangodb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.arangodb_internal_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.arangodb_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_secretsmanager_secret.arangodb_jwt_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.arangodb_jwt_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.arangodb_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.arangodb_ecs_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.arangodb_internal_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.arangodb_alb_sg_egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_alb_sg_ingress_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_alb_ingress_8528](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_alb_ingress_health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_ingress_ports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_internal_alb_ingress_8528](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_internal_alb_ingress_health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_internal_alb_sg_egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_internal_alb_sg_ingress_runner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_service_discovery_private_dns_namespace.arangodb_ns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_service_discovery_service.arangodb_starters](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [random_password.arangodb_jwt_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_ami.arangodb_ecs_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_secretsmanager_secret.arangodb_bootstrap](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_subnet.private_subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_arangodb_agency_size"></a> [arangodb\_agency\_size](#input\_arangodb\_agency\_size) | Agency size for the ArangoDB starter cluster. | `number` | `3` | no |
| <a name="input_arangodb_bootstrap_config"></a> [arangodb\_bootstrap\_config](#input\_arangodb\_bootstrap\_config) | Static bootstrap config for users, databases, and collections (passwords referenced via env vars). | <pre>object({<br/>    users = list(object({<br/>      username     = string<br/>      password_env = string<br/>      active       = optional(bool, true)<br/>    }))<br/>    databases = list(object({<br/>      name  = string<br/>      users = list(string)<br/>    }))<br/>    collections = list(object({<br/>      db   = string<br/>      name = string<br/>      type = optional(number)<br/>    }))<br/>  })</pre> | <pre>{<br/>  "collections": [],<br/>  "databases": [],<br/>  "users": []<br/>}</pre> | no |
| <a name="input_arangodb_bootstrap_enabled"></a> [arangodb\_bootstrap\_enabled](#input\_arangodb\_bootstrap\_enabled) | Whether to run the ArangoDB bootstrap sidecar. | `bool` | `false` | no |
| <a name="input_arangodb_bootstrap_kms_key_arns"></a> [arangodb\_bootstrap\_kms\_key\_arns](#input\_arangodb\_bootstrap\_kms\_key\_arns) | Optional KMS key ARNs used to encrypt the SSM parameters. | `list(string)` | `[]` | no |
| <a name="input_arangodb_bootstrap_password_secrets"></a> [arangodb\_bootstrap\_password\_secrets](#input\_arangodb\_bootstrap\_password\_secrets) | Map of env var name -> Secrets Manager secret name or ARN for bootstrap passwords. | `map(string)` | `{}` | no |
| <a name="input_arangodb_container_ports"></a> [arangodb\_container\_ports](#input\_arangodb\_container\_ports) | Container ports exposed by the ArangoDB task. | `list(string)` | <pre>[<br/>  "8528",<br/>  "8529",<br/>  "8530",<br/>  "8531"<br/>]</pre> | no |
| <a name="input_arangodb_container_primary_port"></a> [arangodb\_container\_primary\_port](#input\_arangodb\_container\_primary\_port) | Primary ArangoDB coordinator port behind the ALB. | `number` | `8529` | no |
| <a name="input_arangodb_cpu"></a> [arangodb\_cpu](#input\_arangodb\_cpu) | CPU units for the ArangoDB task. | `number` | `254` | no |
| <a name="input_arangodb_data_volume_size"></a> [arangodb\_data\_volume\_size](#input\_arangodb\_data\_volume\_size) | EBS data volume size in GiB for each ECS worker. | `number` | `10` | no |
| <a name="input_arangodb_data_volume_type"></a> [arangodb\_data\_volume\_type](#input\_arangodb\_data\_volume\_type) | EBS volume type for ArangoDB data. | `string` | `"gp3"` | no |
| <a name="input_arangodb_desired_count"></a> [arangodb\_desired\_count](#input\_arangodb\_desired\_count) | Desired number of ArangoDB tasks. | `number` | `3` | no |
| <a name="input_arangodb_health_check_path"></a> [arangodb\_health\_check\_path](#input\_arangodb\_health\_check\_path) | HTTP path used for ArangoDB health checks. | `string` | `"/_admin/status"` | no |
| <a name="input_arangodb_health_proxy_port"></a> [arangodb\_health\_proxy\_port](#input\_arangodb\_health\_proxy\_port) | Port exposed by the health-proxy sidecar. | `number` | `18080` | no |
| <a name="input_arangodb_memory"></a> [arangodb\_memory](#input\_arangodb\_memory) | Memory (MiB) for the ArangoDB task. | `number` | `512` | no |
| <a name="input_arangodb_repository_url"></a> [arangodb\_repository\_url](#input\_arangodb\_repository\_url) | ECR repository URL for the ArangoDB image. | `string` | n/a | yes |
| <a name="input_arangodb_sd_namespace"></a> [arangodb\_sd\_namespace](#input\_arangodb\_sd\_namespace) | Cloud Map namespace for ArangoDB starter discovery. | `string` | n/a | yes |
| <a name="input_arangodb_sd_service_name"></a> [arangodb\_sd\_service\_name](#input\_arangodb\_sd\_service\_name) | Cloud Map service name for ArangoDB starters. | `string` | n/a | yes |
| <a name="input_arangodb_service_name"></a> [arangodb\_service\_name](#input\_arangodb\_service\_name) | ArangoDB service name used for ECS and ALB resources. | `string` | n/a | yes |
| <a name="input_arangodb_tag"></a> [arangodb\_tag](#input\_arangodb\_tag) | ArangoDB image tag. | `string` | `"3.12"` | no |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ECS cluster ID where the OPA service is deployed. | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment (e.g., dev, staging, prod). | `string` | n/a | yes |
| <a name="input_org_name"></a> [org\_name](#input\_org\_name) | Organization name for tagging. | `string` | n/a | yes |
| <a name="input_org_owner_email"></a> [org\_owner\_email](#input\_org\_owner\_email) | Contact email for the organization owner, used in resource tagging. | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for ECS tasks and EC2 capacity. | `list(string)` | n/a | yes |
| <a name="input_public_access_cidrs"></a> [public\_access\_cidrs](#input\_public\_access\_cidrs) | CIDR blocks allowed to access the ArangoDB ALB. | `list(string)` | `[]` | no |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Public subnet IDs for the ArangoDB ALB. | `list(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region for logging and resource configuration. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to module resources. | `map(string)` | `{}` | no |
| <a name="input_task_execution_role_arn"></a> [task\_execution\_role\_arn](#input\_task\_execution\_role\_arn) | IAM execution role ARN for ECS tasks. | `string` | n/a | yes |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | IAM task role ARN for ECS tasks. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for ALB, security groups, and Cloud Map. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | n/a |
| <a name="output_alb_url"></a> [alb\_url](#output\_alb\_url) | n/a |
| <a name="output_capacity_provider_name"></a> [capacity\_provider\_name](#output\_capacity\_provider\_name) | n/a |
| <a name="output_internal_alb_dns_name"></a> [internal\_alb\_dns\_name](#output\_internal\_alb\_dns\_name) | n/a |
| <a name="output_internal_alb_url"></a> [internal\_alb\_url](#output\_internal\_alb\_url) | n/a |
| <a name="output_jwt_secret_arn"></a> [jwt\_secret\_arn](#output\_jwt\_secret\_arn) | n/a |
<!-- END_TF_DOCS -->