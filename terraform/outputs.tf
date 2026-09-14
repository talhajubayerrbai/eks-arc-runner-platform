output "vpc_id" {
  description = "VPC ID."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN."
  value       = module.eks.cluster_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL for the Spring Boot app image."
  value       = module.ecr.repository_url
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for EKS."
  value       = module.cloudwatch.log_group_name
}

output "node_role_arn" {
  description = "IAM role ARN of the node group."
  value       = module.iam.node_role_arn
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for AWS Load Balancer Controller."
  value       = module.iam.alb_controller_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for Cluster Autoscaler."
  value       = module.iam.cluster_autoscaler_role_arn
}

output "spring_boot_app_role_arn" {
  description = "IRSA role ARN for the Spring Boot application."
  value       = module.iam.spring_boot_app_role_arn
}
