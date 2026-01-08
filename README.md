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
| [aws_ecs_cluster_capacity_providers.cloud_management_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster_capacity_providers) | resource |
| [aws_ecs_service.arangodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.arangodb_td](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_instance_profile.arangodb_ecs_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.arangodb_secrets_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.arangodb_ecs_instance_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.arangodb_ecs_instance_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.exec_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.arangodb_ecs_workers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.arangodb_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.arangodb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.arangodb_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_secretsmanager_secret.arangodb_jwt_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.arangodb_jwt_secret](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.arangodb_alb_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.arangodb_ecs_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.arangodb_alb_sg_egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_alb_sg_ingress_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_alb_ingress_8528](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_alb_ingress_health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_egress_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.arangodb_ecs_sg_ingress_ports](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_service_discovery_private_dns_namespace.arangodb_ns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_private_dns_namespace) | resource |
| [aws_service_discovery_service.arangodb_starters](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [random_password.arangodb_jwt_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_ami.arangodb_ecs_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_arangodb_agency_size"></a> [arangodb\_agency\_size](#input\_arangodb\_agency\_size) | Agency size for the ArangoDB starter cluster. | `number` | n/a | yes |
| <a name="input_arangodb_container_ports"></a> [arangodb\_container\_ports](#input\_arangodb\_container\_ports) | Container ports exposed by the ArangoDB task. | `list(string)` | n/a | yes |
| <a name="input_arangodb_container_primary_port"></a> [arangodb\_container\_primary\_port](#input\_arangodb\_container\_primary\_port) | Primary ArangoDB coordinator port behind the ALB. | `number` | n/a | yes |
| <a name="input_arangodb_cpu"></a> [arangodb\_cpu](#input\_arangodb\_cpu) | CPU units for the ArangoDB task. | `number` | n/a | yes |
| <a name="input_arangodb_data_volume_size"></a> [arangodb\_data\_volume\_size](#input\_arangodb\_data\_volume\_size) | EBS data volume size in GiB for each ECS worker. | `number` | n/a | yes |
| <a name="input_arangodb_data_volume_type"></a> [arangodb\_data\_volume\_type](#input\_arangodb\_data\_volume\_type) | EBS volume type for ArangoDB data. | `string` | n/a | yes |
| <a name="input_arangodb_desired_count"></a> [arangodb\_desired\_count](#input\_arangodb\_desired\_count) | Desired number of ArangoDB tasks. | `number` | n/a | yes |
| <a name="input_arangodb_health_check_path"></a> [arangodb\_health\_check\_path](#input\_arangodb\_health\_check\_path) | HTTP path used for ArangoDB health checks. | `string` | n/a | yes |
| <a name="input_arangodb_health_proxy_port"></a> [arangodb\_health\_proxy\_port](#input\_arangodb\_health\_proxy\_port) | Port exposed by the health-proxy sidecar. | `number` | n/a | yes |
| <a name="input_arangodb_memory"></a> [arangodb\_memory](#input\_arangodb\_memory) | Memory (MiB) for the ArangoDB task. | `number` | n/a | yes |
| <a name="input_arangodb_repository_url"></a> [arangodb\_repository\_url](#input\_arangodb\_repository\_url) | ECR repository URL for the ArangoDB image. | `string` | n/a | yes |
| <a name="input_arangodb_sd_namespace"></a> [arangodb\_sd\_namespace](#input\_arangodb\_sd\_namespace) | Cloud Map namespace for ArangoDB starter discovery. | `string` | n/a | yes |
| <a name="input_arangodb_sd_service_name"></a> [arangodb\_sd\_service\_name](#input\_arangodb\_sd\_service\_name) | Cloud Map service name for ArangoDB starters. | `string` | n/a | yes |
| <a name="input_arangodb_service_name"></a> [arangodb\_service\_name](#input\_arangodb\_service\_name) | ArangoDB service name used for ECS and ALB resources. | `string` | n/a | yes |
| <a name="input_arangodb_tag"></a> [arangodb\_tag](#input\_arangodb\_tag) | ArangoDB image tag. | `string` | n/a | yes |
| <a name="input_cluster_id"></a> [cluster\_id](#input\_cluster\_id) | ECS cluster ID where ArangoDB is deployed. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | ECS cluster name used by ECS agent bootstrap. | `string` | n/a | yes |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for ECS tasks and EC2 capacity. | `list(string)` | n/a | yes |
| <a name="input_public_network_ip_range"></a> [public\_network\_ip\_range](#input\_public\_network\_ip\_range) | CIDR blocks allowed to access the ArangoDB ALB. | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Public subnet IDs for the ArangoDB ALB. | `list(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region for logging and resource configuration. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to module resources. | `map(string)` | n/a | yes |
| <a name="input_task_execution_role"></a> [task\_execution\_role](#input\_task\_execution\_role) | IAM execution role name for ECS tasks. | `string` | n/a | yes |
| <a name="input_task_execution_role_arn"></a> [task\_execution\_role\_arn](#input\_task\_execution\_role\_arn) | IAM execution role ARN for ECS tasks. | `string` | n/a | yes |
| <a name="input_task_role_arn"></a> [task\_role\_arn](#input\_task\_role\_arn) | IAM task role ARN for ECS tasks. | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for ALB, security groups, and Cloud Map. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | n/a |
| <a name="output_jwt_secret_arn"></a> [jwt\_secret\_arn](#output\_jwt\_secret\_arn) | n/a |
<!-- END_TF_DOCS -->