output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "cluster_sg_id" {
  description = "Cluster security group ID."
  value       = aws_security_group.cluster.id
}

output "node_sg_id" {
  description = "Node security group ID."
  value       = aws_security_group.node.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.main.cidr_block
}
