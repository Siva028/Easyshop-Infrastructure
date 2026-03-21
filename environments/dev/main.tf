provider "aws" {
  region = var.aws_region
}

locals {
  common_tags = {
    Environment = "dev"
    Project     = "easyshop"
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_name     = "easyshop-dev-vpc"
  cidr_block   = "10.0.0.0/16"
  cluster_name = var.cluster_name  
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  azs             = ["ap-south-1a", "ap-south-1b"]

  enable_nat_gateway = false   
  single_nat_gateway = true    

  tags = local.common_tags     
}