terraform {
    backend "s3" { 
        bucket = "easyshop-terraform-state-reyes"
        key = "dev/terraform.tfstate"
        region = "ap-south-1"
        dynamodb_table = "easyshop-terraform-locks"
        encrypt = true
    }
}