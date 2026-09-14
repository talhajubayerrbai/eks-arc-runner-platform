output "node_role_arn" {
  description = "Node group IAM role ARN."
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Node group IAM role name."
  value       = aws_iam_role.node.name
}

output "alb_controller_role_arn" {
  description = "ALB Controller IRSA role ARN."
  value       = aws_iam_role.alb_controller.arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IRSA role ARN."
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "spring_boot_app_role_arn" {
  description = "Spring Boot app IRSA role ARN."
  value       = aws_iam_role.spring_boot_app.arn
}
