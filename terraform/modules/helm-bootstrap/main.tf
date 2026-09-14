# ─── Helm Bootstrap Module ───────────────────────────────────────────────────────────────
#
# IMPORTANT: This module runs in Stage 2 apply (after the cluster exists).
# The kubernetes and helm providers resolve their config from cluster outputs.

# ─── Namespaces ──────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "arc_system" {
  metadata {
    name = "arc-system"
    labels = {
      name = "arc-system"
    }
  }
}

resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = "arc-runners"
    labels = {
      name = "arc-runners"
    }
  }
}

# ─── 1. Metrics Server ───────────────────────────────────────────────────────────────────
resource "helm_release" "metrics_server" {
  name             = "metrics-server"
  repository       = "https://kubernetes-sigs.github.io/metrics-server/"
  chart            = "metrics-server"
  namespace        = "kube-system"
  create_namespace = false
  version          = "3.12.1"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  set {
    name  = "args[1]"
    value = "--kubelet-preferred-address-types=InternalIP"
  }
}

# ─── 2. AWS Load Balancer Controller ───────────────────────────────────────────────────────
resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  create_namespace = false
  version          = "1.7.2"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\.amazonaws\.com/role-arn"
    value = var.alb_controller_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [helm_release.metrics_server]
}

# ─── 3. Actions Runner Controller (ARC) ───────────────────────────────────────────────────
#
# GitHub App credentials are passed as Terraform variables (sensitive).
# Set them via TF_VAR_github_app_id, TF_VAR_github_app_installation_id,
# and TF_VAR_github_app_private_key in your CI secrets or .env file.
#
# To create a GitHub App:
# 1. Go to GitHub Settings → Developer Settings → GitHub Apps → New
# 2. Permissions: Actions (Read), Administration (Read/Write), Metadata (Read)
# 3. Subscribe to events: Workflow job
# 4. Generate a private key and base64-encode it:
#    base64 -w0 private-key.pem
resource "helm_release" "actions_runner_controller" {
  name             = "actions-runner-controller"
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart            = "actions-runner-controller"
  namespace        = "arc-system"
  create_namespace = false
  version          = "0.23.7"

  set_sensitive {
    name  = "authSecret.github_app_id"
    value = var.github_app_id
  }

  set_sensitive {
    name  = "authSecret.github_app_installation_id"
    value = var.github_app_installation_id
  }

  set_sensitive {
    name  = "authSecret.github_app_private_key"
    value = var.github_app_private_key
  }

  set {
    name  = "authSecret.create"
    value = "true"
  }

  set {
    name  = "metrics.serviceMonitor.enabled"
    value = "false"
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  depends_on = [
    kubernetes_namespace.arc_system,
    helm_release.metrics_server,
  ]
}
