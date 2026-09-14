# Remote state in S3 — bucket, key and region are injected at init time via
# -backend-config flags so no sensitive values are hardcoded here.
#
# Initialise with:
#   terraform init \
#     -backend-config="bucket=<TF_STATE_BUCKET>" \
#     -backend-config="key=eks-arc-runner-platform/terraform.tfstate" \
#     -backend-config="region=us-east-1"
#
# The CI pipeline injects these from the GitHub Actions secrets/variables
# set by `set_pipeline_account`.
terraform {
  backend "s3" {
    # Values supplied at init via -backend-config; do NOT hardcode here.
    encrypt        = true
    use_path_style = false
  }
}
