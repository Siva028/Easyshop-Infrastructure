variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "cluster_name" {
  description = "EKS cluster name — flows into VPC tags, EKS, ECR repo name"
  type        = string
  default     = "easyshop-prod"
}

variable "github_org" {
  description = "GitHub organisation or username — scopes OIDC trust to your account"
  type        = string
  # e.g. "Siva028"
}

variable "github_repo" {
  description = "GitHub repository name — scopes OIDC trust to this repo only"
  type        = string
  # e.g. "tws-e-commerce-app"
}