provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Environment = "prod"
    Project     = "easyshop"
    ManagedBy   = "terraform"
    region      = var.aws_region  # needed for configure_kubectl output
  }
}

# ── Step 1: VPC ───────────────────────────────────────────────────
# Creates the network. Outputs vpc_id, public_subnets, private_subnets.
# cluster_name passed here so subnet tags are correct for EKS discovery.
module "vpc" {
  source = "../../modules/vpc"

  vpc_name     = "${var.cluster_name}-vpc"
  cidr_block   = "10.1.0.0/16"          
  cluster_name = var.cluster_name

  # 3 AZs for HA in prod
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnets = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
  azs             = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

  enable_nat_gateway = true
  single_nat_gateway = false   # ← one NAT per AZ for HA in prod

  tags = local.common_tags
}

# ── Step 2: EKS ───────────────────────────────────────────────────
# module.vpc.* reads outputs from the VPC module above.
module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = "1.34"
  vpc_id             = module.vpc.vpc_id           # ← from VPC output

  # Control plane needs both — public for kubectl, private for nodes
  public_subnet_ids  = module.vpc.public_subnets   # ← from VPC output
  private_subnet_ids = module.vpc.private_subnets  # ← from VPC output

  # Larger nodes for prod
  system_node_instance_type = "t3.medium"
  system_min_size     = 2
  system_max_size     = 3
  system_desired_size = 2

  app_node_instance_type = "t3.large"    # ← larger than dev
  app_min_size     = 2
  app_max_size     = 6
  app_desired_size = 3

  tags = local.common_tags
}

# ── Step 3: ECR ───────────────────────────────────────────────────
# node_role_arn comes from EKS module output — no manual ARN needed.
# ci_role_arn is the IAM role GitHub Actions assumes via OIDC.
module "ecr" {
  source = "../../modules/ecr"

  repo_name            = "easyshop-prod"  # unique per environment
  image_tag_mutability = "IMMUTABLE"      # ← prod: tags cannot be overwritten
  max_image_count      = 20
  force_delete         = false            # ← protect prod images
  encryption_type      = "AES256"

  # EKS node role from Step 2 output — nodes can pull this image
  node_role_arn = module.eks.node_role_arn   # ← wired from EKS output

  # GitHub Actions OIDC role created below — GitHub can push to this repo
  ci_role_arn   = aws_iam_role.github_actions.arn

  tags = local.common_tags
}

# ── GitHub Actions OIDC IAM role ──────────────────────────────────
# This allows GitHub Actions to assume an IAM role via OIDC —
# no static AWS keys stored in GitHub secrets.
# OIDC provider for GitHub is created once per AWS account.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
resource "aws_iam_role" "github_actions" {
  name = "${var.cluster_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.common_tags
}

# ECR push permissions for GitHub Actions role
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Account-level: required by docker login, cannot be repo-scoped
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      # Repo-scoped: push/pull actions limited to THIS environment's repo only
      {
        Sid    = "ECRRepoActions"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = module.ecr.repository_arn
      }
    ]
  })
}