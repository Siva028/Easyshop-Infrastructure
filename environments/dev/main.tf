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
  cluster_name       = var.cluster_name   # ← fixes the subnet tag issue

  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets    = ["10.0.3.0/24", "10.0.4.0/24"]
  azs                = ["ap-south-1a", "ap-south-1b"]

  enable_nat_gateway = true    # dev needs NAT for nodes to pull ECR images
  single_nat_gateway = true    # one NAT only — cost saving for dev

  tags = local.common_tags
}

# ── Step 2: EKS ───────────────────────────────────────────────────
# VPC outputs feed directly into EKS inputs — no copy-pasting IDs.
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