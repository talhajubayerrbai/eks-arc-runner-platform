# ─── ECR Module ───────────────────────────────────────────────────────────────────
resource "aws_ecr_repository" "spring_boot_app" {
  name                 = "spring-boot-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-spring-boot-app"
  }
}

# Lifecycle policy: keep last 20 images, expire untagged after 7 days
resource "aws_ecr_lifecycle_policy" "spring_boot_app" {
  repository = aws_ecr_repository.spring_boot_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep last 20 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}
