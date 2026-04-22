provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Project   = "easyshop"
    ManagedBy = "terraform"
    Scope     = "account-bootstrap"
  }
}

# Dynamically fetch GitHub's OIDC cert thumbprint — no hardcoded SHA1
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# Account-wide OIDC trust for GitHub Actions (one per AWS account)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  lifecycle {
    prevent_destroy = true
  }
  tags = local.common_tags
}