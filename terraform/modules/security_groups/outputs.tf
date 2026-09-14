output "cluster_sg_id" {
  description = "Security group ID for the EKS control plane"
  value       = aws_security_group.cluster.id
}

output "node_sg_id" {
  description = "Security group ID for the EKS managed node group"
  value       = aws_security_group.nodes.id
}
