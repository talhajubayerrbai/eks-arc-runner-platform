# ──────────────────────────────────────────────────────────────────────────────
# Security Groups Module
# Cluster SG + Node SG for the EKS cluster
# ──────────────────────────────────────────────────────────────────────────────

# ── Cluster Security Group ───────────────────────────────────────────────────
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster security group — control plane communication"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# Allow nodes → control plane (API server)
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nodes.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Allow nodes to reach control plane"
}

# Allow kubectl from within VPC CIDR
resource "aws_security_group_rule" "cluster_ingress_vpc_kubectl" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.cluster.id
  description       = "kubectl access from within VPC"
}

# Control plane → nodes (kubelet, logs, exec)
resource "aws_security_group_rule" "cluster_egress_nodes" {
  type                     = "egress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nodes.id
  security_group_id        = aws_security_group.cluster.id
  description              = "Control plane to node ports"
}

resource "aws_security_group_rule" "cluster_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
  description       = "Allow all egress from control plane"
}

# ── Node Security Group ──────────────────────────────────────────────────────
resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS node group security group"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name                                            = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}"    = "owned"
  })
}

# Nodes → control plane
resource "aws_security_group_rule" "nodes_ingress_control_plane" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.nodes.id
  description              = "Control plane to kubelet/node ports"
}

# Node-to-node (all within VPC for pod networking)
resource "aws_security_group_rule" "nodes_ingress_intra" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.nodes.id
  description       = "All intra-VPC traffic to nodes"
}

# ALB health checks (HTTP/HTTPS)
resource "aws_security_group_rule" "nodes_ingress_alb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes.id
  description       = "ALB → node HTTP"
}

resource "aws_security_group_rule" "nodes_ingress_alb_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes.id
  description       = "ALB → node HTTPS"
}

# NodePort range
resource "aws_security_group_rule" "nodes_ingress_nodeport" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.nodes.id
  description       = "NodePort range from within VPC"
}

# Unrestricted egress
resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes.id
  description       = "Unrestricted egress from nodes"
}
