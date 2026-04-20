provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Environment = "prod"
    Project     = "easyshop"
    ManagedBy   = "terraform"
    region      = var.aws_region
  }
}

# ── VPC ───────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  vpc_name     = "${var.cluster_name}-vpc"
  cidr_block   = "10.1.0.0/16"          # ← different CIDR from dev (10.0.x)
  cluster_name = var.cluster_name

  # 3 AZs for HA in prod
  public_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnets = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]
  azs             = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

  enable_nat_gateway = true
  single_nat_gateway = false   # ← one NAT per AZ for HA in prod

  tags = local.common_tags
}

# ── EKS ───────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = "1.31"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets

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

# ── ECR ───────────────────────────────────────────────────────────
module "ecr" {
  source = "../../modules/ecr"

  repo_name            = "easyshop-prod"  # ← separate repo from dev
  image_tag_mutability = "IMMUTABLE"      # ← prod: tags cannot be overwritten
  max_image_count      = 20
  force_delete         = false            # ← protect prod images
  encryption_type      = "AES256"

  node_role_arn = module.eks.node_role_arn
  ci_role_arn   = aws_iam_role.github_actions.arn

  tags = local.common_tags
}

# ── GitHub Actions OIDC role (prod) ───────────────────────────────
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}
resource "aws_iam_role" "github_actions" {
  name = "${var.cluster_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
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

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ]
      Resource = "*"
    }]
  })
}