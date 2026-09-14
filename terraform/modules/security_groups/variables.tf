variable "cluster_name" {
  description = "EKS cluster name — used in SG names and tags"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create the security groups"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC — used for intra-cluster rules"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all security group resources"
  type        = map(string)
  default     = {}
}
