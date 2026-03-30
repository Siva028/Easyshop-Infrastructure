# ── VPC outputs ───────────────────────────────────────────────────
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "nat_gateway_ids" {
  value = module.vpc.nat_gateway_ids
}

# ── EKS outputs ───────────────────────────────────────────────────
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Run this after apply to wire up kubectl"
  value       = module.eks.configure_kubectl
}

output "oidc_provider_arn" {
  description = "Used when creating IRSA roles for ArgoCD + app pods"
  value       = module.eks.oidc_provider_arn
}

# ── ECR outputs ───────────────────────────────────────────────────
output "ecr_repository_url" {
  description = "Paste into GitHub Actions ECR_REGISTRY + Helm values.dev.yaml image.repository"
  value       = module.ecr.repository_url
}

output "ecr_registry_id" {
  description = "Used for: aws ecr get-login-password | docker login <registry_id>.dkr.ecr..."
  value       = module.ecr.registry_id
}

output "ecr_repository_name" {
  description = "Used as ECR_REPOSITORY in GitHub Actions workflow env block"
  value       = module.ecr.repository_name
}

output "github_actions_role_arn" {
  description = "Paste into GitHub Actions secrets as AWS_ROLE_ARN — replaces static keys"
  value       = aws_iam_role.github_actions.arn
}