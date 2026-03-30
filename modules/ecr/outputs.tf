output "repository_url" {
  description = "Full ECR repository URL — used as image.repository in Helm values.yaml"
  value       = aws_ecr_repository.this.repository_url
}

output "registry_id" {
  description = "AWS account ID of the registry — used for docker login: <registry_id>.dkr.ecr.<region>.amazonaws.com"
  value       = aws_ecr_repository.this.registry_id
}

output "repository_name" {
  description = "Short repository name — used in GitHub Actions ECR_REPOSITORY env var"
  value       = aws_ecr_repository.this.name
}

output "repository_arn" {
  description = "Full ARN of the repository — used in IAM policy conditions"
  value       = aws_ecr_repository.this.arn
}