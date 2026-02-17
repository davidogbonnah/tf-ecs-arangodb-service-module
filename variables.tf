variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)."
  type        = string
}

variable "org_name" {
  description = "Organization name for tagging."
  type        = string
}

variable "org_owner_email" {
  description = "Contact email for the organization owner, used in resource tagging."
  type        = string
}

variable "arangodb_agency_size" {
  description = "Agency size for the ArangoDB starter cluster."
  type        = number
  default     = 3
}

variable "arangodb_container_ports" {
  description = "Container ports exposed by the ArangoDB task."
  type        = list(string)
  default     = ["8528", "8529", "8530", "8531"]
}

variable "arangodb_container_primary_port" {
  description = "Primary ArangoDB coordinator port behind the ALB."
  type        = number
  default     = 8529
}

variable "arangodb_cpu" {
  description = "CPU units for the ArangoDB task."
  type        = number
  default     = 254 # 0.25 vCPU
}

variable "arangodb_data_volume_size" {
  description = "EBS data volume size in GiB for each ECS worker."
  type        = number
  default     = 10
}

variable "arangodb_data_volume_type" {
  description = "EBS volume type for ArangoDB data."
  type        = string
  default     = "gp3"
}

variable "arangodb_desired_count" {
  description = "Desired number of ArangoDB tasks."
  type        = number
  default     = 3
}

variable "arangodb_health_check_path" {
  description = "HTTP path used for ArangoDB health checks."
  type        = string
  default     = "/_admin/status"
}

variable "arangodb_health_proxy_port" {
  description = "Port exposed by the health-proxy sidecar."
  type        = number
  default     = 18080
}

variable "arangodb_memory" {
  description = "Memory (MiB) for the ArangoDB task."
  type        = number
  default     = 512 # 0.5 GB
}

variable "arangodb_repository_url" {
  description = "ECR repository URL for the ArangoDB image."
  type        = string
}

variable "arangodb_sd_namespace" {
  description = "Cloud Map namespace for ArangoDB starter discovery."
  type        = string
}

variable "arangodb_sd_service_name" {
  description = "Cloud Map service name for ArangoDB starters."
  type        = string
}

variable "arangodb_service_name" {
  description = "ArangoDB service name used for ECS and ALB resources."
  type        = string
}

variable "arangodb_tag" {
  description = "ArangoDB image tag."
  type        = string
  default     = "3.12"
}

variable "arangodb_bootstrap_enabled" {
  description = "Whether to run the ArangoDB bootstrap sidecar."
  type        = bool
  default     = false
}

variable "arangodb_bootstrap_config" {
  description = "Static bootstrap config for users, databases, and collections (passwords referenced via env vars)."
  type = object({
    users = list(object({
      username     = string
      password_env = string
      active       = optional(bool, true)
    }))
    databases = list(object({
      name  = string
      users = list(string)
    }))
    collections = list(object({
      db   = string
      name = string
      type = optional(number)
    }))
  })
  default = {
    users       = []
    databases   = []
    collections = []
  }
}

variable "arangodb_bootstrap_password_secrets" {
  description = "Map of env var name -> Secrets Manager secret name or ARN for bootstrap passwords."
  type        = map(string)
  default     = {}
}

variable "arangodb_bootstrap_kms_key_arns" {
  description = "Optional KMS key ARNs used to encrypt the SSM parameters."
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "ECS cluster name used by ECS agent bootstrap."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and EC2 capacity."
  type        = list(string)
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access the ArangoDB ALB."
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ArangoDB ALB."
  type        = list(string)
}

variable "region" {
  description = "AWS region for logging and resource configuration."
  type        = string
}

variable "tags" {
  description = "Tags applied to module resources."
  type        = map(string)
}

variable "task_execution_role" {
  description = "IAM execution role name for ECS tasks."
  type        = string
}

variable "task_role" {
  description = "IAM task role name for ECS tasks."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for ALB, security groups, and Cloud Map."
  type        = string
}
