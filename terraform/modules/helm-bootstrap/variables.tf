variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ALB Controller."
  type        = string
}

variable "alb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller."
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID for ARC authentication."
  type        = string
  sensitive   = true
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID."
  type        = string
  sensitive   = true
}

variable "github_app_private_key" {
  description = "GitHub App private key (PEM, base64-encoded)."
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub organization or user name."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}
