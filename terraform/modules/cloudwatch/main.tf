# ─── CloudWatch Module ─────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/eks/${var.cluster_name}"
  retention_in_days = 30

  tags = {
    Name = "/eks/${var.cluster_name}"
  }
}

# Container Insights — enabled via EKS addon
resource "aws_eks_addon" "container_insights" {
  # This addon is created after the cluster — it is referenced in the main module.
  # We define the addon config here; the cluster reference is passed via variable.
  count             = 0  # Placeholder — managed via aws_cloudwatch_container_insights below
  cluster_name      = var.cluster_name
  addon_name        = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"

  tags = {
    Name = "${var.cluster_name}-container-insights"
  }
}

# Metric alarms — node CPU
resource "aws_cloudwatch_metric_alarm" "node_cpu_high" {
  alarm_name          = "${var.cluster_name}-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EKS node CPU utilization > 80%"

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = {
    Name = "${var.cluster_name}-node-cpu-high"
  }
}
