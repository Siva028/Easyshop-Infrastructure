variable "repo_name" {
  description = "ECR repository name — e.g. easyshop-dev or easyshop-prod"
  type        = string
}

variable "image_tag_mutability" {
  description = "IMMUTABLE = tags can't be overwritten (recommended for prod). MUTABLE = ok for dev."
  type        = string
  default     = "MUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "Must be MUTABLE or IMMUTABLE."
  }
}

variable "max_image_count" {
  description = "Max number of tagged images to keep. Older ones are expired by lifecycle policy."
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Allow terraform destroy even when images exist. true=dev, false=prod."
  type        = bool
  default     = false
}

variable "encryption_type" {
  description = "AES256 (default AWS managed) or KMS (customer managed key)."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "KMS"], var.encryption_type)
    error_message = "Must be AES256 or KMS."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN — only required when encryption_type = KMS."
  type        = string
  default     = null
}

# Required — no defaults, must be passed from root module
variable "ci_role_arn" {
  description = "IAM role ARN for GitHub Actions — granted push access to this repo."
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for EKS worker nodes — granted pull access to this repo."
  type        = string
}

variable "tags" {
  description = "Common tags — environment, project, team."
  type        = map(string)
  default     = {}
}

#Every variable typed and described. ci_role_arn and node_role_arn are required — no defaults — caller must pass them explicitly.
