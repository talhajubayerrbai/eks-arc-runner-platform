#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# Cluster Bootstrap Script
# Installs Metrics Server, AWS Load Balancer Controller, and ARC
# via Helm into a running EKS cluster.
#
# Prerequisites:
#   - kubectl configured to the target cluster
#   - helm >=3.12 on PATH
#   - AWS CLI configured (aws eks update-kubeconfig already run)
#
# Usage:
#   export CLUSTER_NAME=eks-arc-runner-platform
#   export AWS_REGION=us-east-1
#   export ALB_CONTROLLER_ROLE_ARN=arn:aws:iam::<ACCOUNT_ID>:role/eks-arc-alb-controller
#   export GITHUB_APP_ID=<app_id>
#   export GITHUB_APP_INSTALLATION_ID=<installation_id>
#   export GITHUB_APP_PRIVATE_KEY_B64=<base64-encoded PEM>
#   ./helm-bootstrap/bootstrap.sh
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────────
CLUSTER_NAME="${CLUSTER_NAME:-eks-arc-runner-platform}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ALB_CONTROLLER_ROLE_ARN="${ALB_CONTROLLER_ROLE_ARN:?ALB_CONTROLLER_ROLE_ARN is required}"
GITHUB_APP_ID="${GITHUB_APP_ID:?GITHUB_APP_ID is required}"
GITHUB_APP_INSTALLATION_ID="${GITHUB_APP_INSTALLATION_ID:?GITHUB_APP_INSTALLATION_ID is required}"
GITHUB_APP_PRIVATE_KEY_B64="${GITHUB_APP_PRIVATE_KEY_B64:?GITHUB_APP_PRIVATE_KEY_B64 is required (base64-encoded PEM)}"

log()  { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] INFO  $*"; }
err()  { echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] ERROR $*" >&2; }
wait_rollout() {
  local ns="$1" kind="$2" name="$3"
  log "Waiting for ${kind}/${name} in namespace ${ns}..."
  kubectl rollout status "${kind}/${name}" -n "${ns}" --timeout=5m
}

# ── Add Helm repos ───────────────────────────────────────────────────────────
log "Adding Helm repositories..."
helm repo add metrics-server       https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo add eks                  https://aws.github.io/eks-charts 2>/dev/null || true
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller 2>/dev/null || true
helm repo update

# ── 1. Metrics Server ─────────────────────────────────────────────────────────────
log "Installing Metrics Server..."
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --values helm-bootstrap/values/metrics-server-values.yaml \
  --wait --timeout 5m
wait_rollout kube-system deployment metrics-server

# ── 2. AWS Load Balancer Controller ──────────────────────────────────────────────
log "Installing AWS Load Balancer Controller..."

# Install CRDs first
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master" \
  --server-side 2>/dev/null || \
kubectl apply -f https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml \
  --server-side 2>/dev/null || true

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --values helm-bootstrap/values/aws-load-balancer-controller-values.yaml \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ALB_CONTROLLER_ROLE_ARN}" \
  --wait --timeout 5m
wait_rollout kube-system deployment aws-load-balancer-controller

# ── 3. Actions Runner Controller (ARC) ───────────────────────────────────────────
log "Creating arc-system namespace..."
kubectl create namespace arc-system --dry-run=client -o yaml | kubectl apply -f -

log "Creating ARC GitHub App secret..."
PRIVATE_KEY=$(echo "${GITHUB_APP_PRIVATE_KEY_B64}" | base64 -d)
kubectl create secret generic controller-manager \
  --namespace arc-system \
  --from-literal=github_app_id="${GITHUB_APP_ID}" \
  --from-literal=github_app_installation_id="${GITHUB_APP_INSTALLATION_ID}" \
  --from-literal=github_app_private_key="${PRIVATE_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Installing Actions Runner Controller..."
helm upgrade --install actions-runner-controller \
  actions-runner-controller/actions-runner-controller \
  --namespace arc-system \
  --values helm-bootstrap/values/arc-values.yaml \
  --set authSecret.create=false \
  --set authSecret.name=controller-manager \
  --wait --timeout 10m
wait_rollout arc-system deployment actions-runner-controller

# ── 4. Apply ARC runner manifests ────────────────────────────────────────────────
log "Applying RunnerDeployment and HorizontalRunnerAutoscaler..."
kubectl apply -k k8s/

log "✔ Bootstrap complete!"
log "  Metrics Server       → kube-system/deployment/metrics-server"
log "  AWS LB Controller    → kube-system/deployment/aws-load-balancer-controller"
log "  ARC Controller       → arc-system/deployment/actions-runner-controller"
log "  ARC Runners          → arc-runners/runndeployment/arc-runner"
log ""
log "To verify runners registered with GitHub:"
log "  kubectl get runners -n arc-runners"
