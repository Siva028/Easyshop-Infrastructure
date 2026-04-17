output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  value = module.eks.configure_kubectl
}

output "ecr_repository_url" {
  description = "Paste into helm/easyshop/values.prod.yaml image.repository"
  value       = module.ecr.repository_url
}

output "github_actions_role_arn" {
  description = "Paste into GitHub secret AWS_ROLE_ARN_PROD"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}