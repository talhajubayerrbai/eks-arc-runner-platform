variable "project_name" {
  description = "Project name."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "oidc_provider" {
  description = "OIDC provider URL without https://."
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN."
  type        = string
}
