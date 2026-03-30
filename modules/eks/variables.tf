variable "cluster_name" {
  description = "EKS cluster name — used for all resource naming"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version (check EKS supported versions)"
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "VPC ID — from module.vpc.vpc_id output"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs — for EKS control plane endpoint only"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — where worker nodes are placed"
  type        = list(string)
}

# ── System node group (CoreDNS, ArgoCD, Prometheus) ───────────────
variable "system_node_instance_type" {
  description = "Instance type for system node group"
  type        = string
  default     = "t3.medium"
}

variable "system_desired_size" {
  description = "Desired system node count"
  type        = number
  default     = 1
}

variable "system_min_size" {
  description = "Minimum system node count"
  type        = number
  default     = 1
}

variable "system_max_size" {
  description = "Maximum system node count"
  type        = number
  default     = 2
}

# ── App node group (EasyShop Next.js, MongoDB) ────────────────────
variable "app_node_instance_type" {
  description = "Instance type for app node group"
  type        = string
  default     = "t3.medium"
}

variable "app_desired_size" {
  description = "Desired app node count"
  type        = number
  default     = 1
}

variable "app_min_size" {
  description = "Minimum app node count"
  type        = number
  default     = 1
}

variable "app_max_size" {
  description = "Maximum app node count"
  type        = number
  default     = 2
}

variable "tags" {
  description = "Common tags for all resources (env, project, team)"
  type        = map(string)
  default     = {}
}