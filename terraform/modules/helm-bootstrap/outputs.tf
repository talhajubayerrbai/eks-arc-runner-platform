output "metrics_server_status" {
  description = "Metrics Server Helm release status."
  value       = helm_release.metrics_server.status
}

output "alb_controller_status" {
  description = "AWS Load Balancer Controller Helm release status."
  value       = helm_release.aws_load_balancer_controller.status
}

output "arc_status" {
  description = "Actions Runner Controller Helm release status."
  value       = helm_release.actions_runner_controller.status
}
