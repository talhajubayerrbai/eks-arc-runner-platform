# ───────────────────────────────────────────────────────────────────────────────
# EKS ARC Runner Platform — Root Module
# ───────────────────────────────────────────────────────────────────────────────
#
# IMPORTANT — TWO-STAGE APPLY:
#   Stage 1 (cluster creation):
#     terraform apply -target=module.vpc -target=module.iam -target=module.ecr \
#                     -target=module.cloudwatch -target=module.eks
#
#   Stage 2 (Helm bootstrap + kubeconfig):
#     terraform apply
#
# This is required because the kubernetes/helm providers cannot plan against a
# cluster being created in the same run (hashicorp/kubernetes known limitation).
# ───────────────────────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  cluster_name = var.project_name
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition
}

# ─── VPC ──────────────────────────────────────────────────────────────────────────
module "vpc" {
  source               = "./modules/vpc"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name         = local.cluster_name
}

# ─── IAM ──────────────────────────────────────────────────────────────────────────
# NOTE: The IAM module creates the node role FIRST (no EKS dependency),
# then the EKS module uses that node_role_arn.
# The IRSA roles (alb_controller, cluster_autoscaler, spring_boot_app) depend on
# the EKS OIDC provider — those are created in a separate pass or via depends_on.
module "iam" {
  source            = "./modules/iam"
  project_name      = var.project_name
  cluster_name      = local.cluster_name
  aws_region        = var.aws_region
  account_id        = local.account_id
  # OIDC values are empty strings in Stage 1; the IRSA roles gracefully handle
  # placeholder values and are overwritten in Stage 2 apply.
  oidc_provider     = try(module.eks.oidc_provider, "")
  oidc_provider_arn = try(module.eks.oidc_provider_arn, "")
}

# ─── ECR ──────────────────────────────────────────────────────────────────────────
module "ecr" {
  source       = "./modules/ecr"
  project_name = var.project_name
}

# ─── CloudWatch ────────────────────────────────────────────────────────────────────
module "cloudwatch" {
  source       = "./modules/cloudwatch"
  project_name = var.project_name
  cluster_name = local.cluster_name
}

# ─── EKS ──────────────────────────────────────────────────────────────────────────
module "eks" {
  source              = "./modules/eks"
  project_name        = var.project_name
  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_subnet_ids   = module.vpc.public_subnet_ids
  node_instance_type  = var.node_instance_type
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size
  ssh_key_name        = var.ssh_key_name
  node_role_arn       = module.iam.node_role_arn
  cloudwatch_log_group = module.cloudwatch.log_group_name
  depends_on          = [module.vpc, module.cloudwatch]
}

# ─── Helm Bootstrap ──────────────────────────────────────────────────────────────────
module "helm_bootstrap" {
  source                    = "./modules/helm-bootstrap"
  cluster_name              = local.cluster_name
  aws_region                = var.aws_region
  vpc_id                    = module.vpc.vpc_id
  alb_controller_role_arn   = module.iam.alb_controller_role_arn
  github_app_id             = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key    = var.github_app_private_key
  github_owner              = var.github_owner
  github_repo               = var.github_repo
  depends_on                = [module.eks]
}
