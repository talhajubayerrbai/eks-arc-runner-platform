variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project tag value applied to every resource."
  type        = string
  default     = "eks-arc-runner-platform"
}

variable "environment" {
  description = "Environment tag value."
  type        = string
  default     = "production"
}

# ─── Networking ───────────────────────────────────────────────────────────
variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to deploy across."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the three public subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the three private subnets."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

# ─── EKS ─────────────────────────────────────────────────────────────────────
variable "kubernetes_version" {
  description = "EKS Kubernetes version (must be in EKS standard support window)."
  type        = string
  default     = "1.29"
}

variable "node_instance_type" {
  description = "EC2 instance type for managed node group."
  type        = string
  default     = "t3.medium"
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 6
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 3
}

variable "ssh_key_name" {
  description = "Optional EC2 key pair name for node SSH access."
  type        = string
  default     = ""
}

# ─── ARC / GitHub App ───────────────────────────────────────────────────────
variable "github_owner" {
  description = "GitHub organization or user name owning the repository."
  type        = string
  default     = "talhajubayerrbai"
}

variable "github_repo" {
  description = "GitHub repository name ARC runners will register to."
  type        = string
  default     = "eks-arc-runner-platform"
}

# These three must be supplied before `terraform apply`.
# Store them in GitHub Actions secrets and pass as TF_VAR_* variables.
variable "github_app_id" {
  description = "GitHub App ID for Actions Runner Controller authentication."
  type        = string
  sensitive   = true
  default     = "PLACEHOLDER_GITHUB_APP_ID"
}

variable "github_app_installation_id" {
  description = "GitHub App installation ID."
  type        = string
  sensitive   = true
  default     = "PLACEHOLDER_GITHUB_APP_INSTALLATION_ID"
}

variable "github_app_private_key" {
  description = "GitHub App private key (PEM, base64-encoded)."
  type        = string
  sensitive   = true
  default     = "PLACEHOLDER_GITHUB_APP_PRIVATE_KEY"
}
