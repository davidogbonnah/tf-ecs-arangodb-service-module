variable "arangodb_agency_size" {
  description = "Agency size for the ArangoDB starter cluster."
  type = number
}

variable "arangodb_container_ports" {
  description = "Container ports exposed by the ArangoDB task."
  type = list(string)
}

variable "arangodb_container_primary_port" {
  description = "Primary ArangoDB coordinator port behind the ALB."
  type = number
}

variable "arangodb_cpu" {
  description = "CPU units for the ArangoDB task."
  type = number
}

variable "arangodb_data_volume_size" {
  description = "EBS data volume size in GiB for each ECS worker."
  type = number
}

variable "arangodb_data_volume_type" {
  description = "EBS volume type for ArangoDB data."
  type = string
}

variable "arangodb_desired_count" {
  description = "Desired number of ArangoDB tasks."
  type = number
}

variable "arangodb_health_check_path" {
  description = "HTTP path used for ArangoDB health checks."
  type = string
}

variable "arangodb_health_proxy_port" {
  description = "Port exposed by the health-proxy sidecar."
  type = number
}

variable "arangodb_memory" {
  description = "Memory (MiB) for the ArangoDB task."
  type = number
}

variable "arangodb_repository_url" {
  description = "ECR repository URL for the ArangoDB image."
  type = string
}

variable "arangodb_sd_namespace" {
  description = "Cloud Map namespace for ArangoDB starter discovery."
  type = string
}

variable "arangodb_sd_service_name" {
  description = "Cloud Map service name for ArangoDB starters."
  type = string
}

variable "arangodb_service_name" {
  description = "ArangoDB service name used for ECS and ALB resources."
  type = string
}

variable "arangodb_tag" {
  description = "ArangoDB image tag."
  type = string
}

variable "cluster_id" {
  description = "ECS cluster ID where ArangoDB is deployed."
  type = string
}

variable "cluster_name" {
  description = "ECS cluster name used by ECS agent bootstrap."
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and EC2 capacity."
  type = list(string)
}

variable "public_network_ip_range" {
  description = "CIDR blocks allowed to access the ArangoDB ALB."
  type = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ArangoDB ALB."
  type = list(string)
}

variable "region" {
  description = "AWS region for logging and resource configuration."
  type = string
}

variable "tags" {
  description = "Tags applied to module resources."
  type = map(string)
}

variable "task_execution_role" {
  description = "IAM execution role name for ECS tasks."
  type        = string
}

variable "task_execution_role_arn" {
  description = "IAM execution role ARN for ECS tasks."
  type = string
}

variable "task_role_arn" {
  description = "IAM task role ARN for ECS tasks."
  type = string
}

variable "vpc_id" {
  description = "VPC ID for ALB, security groups, and Cloud Map."
  type = string
}
