variable "vpc_name" {
  description = "Name prefix for the VPC and all its resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC (e.g. 10.0.0.0/16)"
  type        = string
}


variable "cluster_name" {
  description = "EKS cluster name — used in subnet tags for EKS service discovery"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet CIDRs — must match length of azs"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet CIDRs — must match length of azs"
  type        = list(string)
}

variable "azs" {
  description = "Availability zones — length must match subnet lists"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateway(s) for private subnets"
  type        = bool
  default     = false
}


variable "single_nat_gateway" {
  description = "true = one shared NAT (dev, cheaper). false = one NAT per AZ (prod, HA)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags to apply to all resources (env, project, team)"
  type        = map(string)
  default     = {}
}

# validation — catch subnet/AZ count mismatch at plan time
# not at apply time (which gives cryptic index errors)
locals {
  validate_public = (
    length(var.public_subnets) == length(var.azs)
      ? true
      : tobool("ERROR: public_subnets count must equal azs count")
  )
  validate_private = (
    length(var.private_subnets) == length(var.azs)
      ? true
      : tobool("ERROR: private_subnets count must equal azs count")
  )
}