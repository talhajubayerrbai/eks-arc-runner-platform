variable "project_name" {
  description = "Project name."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for node group."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs."
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for nodes."
  type        = string
}

variable "node_min_size" {
  description = "Minimum nodes."
  type        = number
}

variable "node_max_size" {
  description = "Maximum nodes."
  type        = number
}

variable "node_desired_size" {
  description = "Desired nodes."
  type        = number
}

variable "ssh_key_name" {
  description = "SSH key pair name (empty = no SSH)."
  type        = string
  default     = ""
}

variable "node_role_arn" {
  description = "IAM role ARN for the node group."
  type        = string
}

variable "cloudwatch_log_group" {
  description = "CloudWatch log group name for EKS control plane logs."
  type        = string
}
