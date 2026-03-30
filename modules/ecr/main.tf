# ── ECR Repository ───────────────────────────────────────────────
resource "aws_ecr_repository" "this" {
  name                 = var.repo_name          
  image_tag_mutability = var.image_tag_mutability 

  image_scanning_configuration {
    scan_on_push = true
  }

  # FIX 4: encryption — AES256 for dev, KMS for prod
  encryption_configuration {
    encryption_type = var.encryption_type        # "AES256" or "KMS"
    kms_key         = var.encryption_type == "KMS" ? var.kms_key_arn : null
  }

  force_delete = var.force_delete               #true=dev, false=prod

  tags = merge(var.tags, {
    Name = var.repo_name
  })
}

# Lifecycle policy 
# Rule 1: expire untagged (dangling) images after 1 day
# Rule 2: keep only last N tagged images (configurable per env)
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last ${var.max_image_count} tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev-", "sha-", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_image_count
        }
        action = { type = "expire" }
      }
    ]
  })
}

# Repository policy — push (CI) + pull (EKS nodes) 
# This scopes ECR access to exactly who needs it:
#   - ci_role_arn  : GitHub Actions pushes images
#   - node_role_arn: EKS worker nodes pull images
resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # GitHub Actions CI role — push only
      {
        Sid    = "CIPushAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.ci_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken"
        ]
      },
      # EKS node role — pull only
      {
        Sid    = "EKSNodePullAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.node_role_arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
