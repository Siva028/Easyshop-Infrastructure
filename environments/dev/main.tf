provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Environment = "dev"
    Project     = "easyshop"
    ManagedBy   = "terraform"
    region      = var.aws_region   # needed for configure_kubectl output
  }
}

# ── Step 1: VPC ───────────────────────────────────────────────────
# Creates the network. Outputs vpc_id, public_subnets, private_subnets.
# cluster_name passed here so subnet tags are correct for EKS discovery.
module "vpc" {
  source = "../../modules/vpc"

  vpc_name           = "${var.cluster_name}-vpc"
  cidr_block         = "10.0.0.0/16"
  cluster_name       = var.cluster_name  

  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.3.0/24", "10.0.4.0/24"]
  azs                = ["ap-south-1a", "ap-south-1b"]

  enable_nat_gateway = true    # dev needs NAT for nodes to pull ECR images
  single_nat_gateway = true    # one NAT only — cost saving for dev

  tags = local.common_tags
}

# ── Step 2: EKS ───────────────────────────────────────────────────
# module.vpc.* reads outputs from the VPC module above.
module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = "1.34"
  vpc_id          = module.vpc.vpc_id              # ← from VPC output

  # Control plane needs both — public for kubectl, private for nodes
  public_subnet_ids  = module.vpc.public_subnets   # ← from VPC output
  private_subnet_ids = module.vpc.private_subnets  # ← from VPC output

  # Dev: small + minimal nodes to save cost
  system_node_instance_type = "t3.medium"
  system_desired_size       = 1
  system_min_size           = 1
  system_max_size           = 1

  app_node_instance_type = "t3.medium"
  app_desired_size       = 1
  app_min_size           = 1
  app_max_size           = 2

  tags = local.common_tags
}

# ── Step 3: ECR ───────────────────────────────────────────────────
# node_role_arn comes from EKS module output — no manual ARN needed.
# ci_role_arn is the IAM role GitHub Actions assumes via OIDC.
module "ecr" {
  source = "../../modules/ecr"

  repo_name            = "easyshop-dev"        # unique per environment
  image_tag_mutability = "MUTABLE"             # dev: ok to overwrite tags
  max_image_count      = 5                     # keep fewer images in dev
  force_delete         = true                  # allow destroy in dev
  encryption_type      = "AES256"             

  # EKS node role from Step 2 output — nodes can pull this image
  node_role_arn = module.eks.node_role_arn     # ← wired from EKS output

  # GitHub Actions IAM role — created separately (see ci_role below)
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
          # Scope to your repo only — set var.github_org and var.github_repo to your actual GitHub org/repo
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