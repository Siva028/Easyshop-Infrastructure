terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws"; version = "~> 5.0" }
    tls = { source = "hashicorp/tls"; version = "~> 4.0" }
  }

  backend "s3" {
    bucket         = "easyshop-tfstate"
    key            = "prod/terraform.tfstate"  # ← different key from dev
    region         = "ap-south-1"
    dynamodb_table = "easyshop-tfstate-lock"
    encrypt        = true
  }
}