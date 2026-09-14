# Deployment Guide

Step-by-step instructions for deploying the EKS ARC Runner Platform from scratch.

---

## Prerequisites Checklist

- [ ] AWS account with permissions: EKS, EC2, IAM, ECR, VPC, CloudWatch, S3
- [ ] Terraform ≥ 1.7.0 installed
- [ ] AWS CLI ≥ 2.x installed and configured
- [ ] kubectl ≥ 1.29 installed
- [ ] Helm ≥ 3.14 installed
- [ ] GitHub account with repository admin access
- [ ] GitHub App created (see README for instructions)

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/talhajubayerrbai/eks-arc-runner-platform.git
cd eks-arc-runner-platform
```

---

## Step 2: Create S3 State Backend

Create an S3 bucket for Terraform remote state. The bucket name must be globally unique.

```bash
export TF_STATE_BUCKET="eks-arc-runner-platform-tfstate-$(AWS account ID)"
export AWS_REGION="us-east-1"

# Create bucket
aws s3 mb "s3://${TF_STATE_BUCKET}" --region "${AWS_REGION}"

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "${TF_STATE_BUCKET}" \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket "${TF_STATE_BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket "${TF_STATE_BUCKET}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

---

## Step 3: Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
github_app_id              = "123456"
github_app_installation_id = "78901234"
github_app_private_key     = "BASE64_ENCODED_PEM"
```

To base64-encode your private key:
```bash
base64 -w0 /path/to/github-app-private-key.pem
```

---

## Step 4: Initialise Terraform

```bash
terraform init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=eks-arc-runner-platform/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}"
```

---

## Step 5: Stage 1 Apply (Infrastructure)

This provisions VPC, IAM roles, ECR, CloudWatch, and EKS. Takes ~15–20 minutes.

```bash
terraform apply \
  -target=module.vpc \
  -target=module.iam \
  -target=module.ecr \
  -target=module.cloudwatch \
  -target=module.eks
```

Review the plan, type `yes` to confirm.

---

## Step 6: Configure kubeconfig

After the EKS cluster is up:

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name eks-arc-runner-platform

# Verify
kubectl get nodes
```

---

## Step 7: Stage 2 Apply (Helm Bootstrap)

Installs Metrics Server, AWS Load Balancer Controller, and ARC into the cluster.

```bash
terraform apply
```

This will:
1. Create namespaces `arc-system` and `arc-runners`
2. Deploy Metrics Server (kube-system)
3. Deploy AWS Load Balancer Controller (kube-system)
4. Deploy Actions Runner Controller (arc-system)

Verify:
```bash
kubectl get pods -n kube-system
kubectl get pods -n arc-system
```

---

## Step 8: Apply ARC Runner Manifests

```bash
kubectl apply -k k8s/

# Verify runners are registered
kubectl get runnerdeployments -n arc-runners
kubectl get horizontalrunnerautoscalers -n arc-runners
kubectl get pods -n arc-runners
```

Runners should appear in GitHub: **Repository Settings → Actions → Runners**.

---

## Step 9: Configure GitHub Actions Secrets

In your GitHub repository settings (**Settings → Secrets and variables → Actions**):

### Repository Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key with EKS/ECR permissions |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key |
| `AWS_ROLE_TO_ASSUME` | IRSA role ARN for OIDC federation (from Terraform output `spring_boot_app_role_arn`) |

### Repository Variables

| Variable | Description | Example |
|----------|-------------|---------||
| `AWS_REGION` | AWS region | `us-east-1` |
| `ECR_REGISTRY` | ECR registry URL | `123456789012.dkr.ecr.us-east-1.amazonaws.com` |

To get the ECR registry URL:
```bash
terraform output ecr_repository_url
# Remove the repository name suffix to get the registry base URL
```

---

## Step 10: Trigger the Build Pipeline

```bash
gh workflow run build.yml

# Watch the run
gh run watch
```

Or via GitHub UI: **Actions → Build and Deploy → Run workflow**.

The Spring Boot app will be:
1. Built and tested on self-hosted runners
2. Packaged as a Docker image and pushed to ECR
3. Deployed to the EKS cluster via Helm
4. Exposed via an ALB Ingress

---

## Step 11: Verify the Deployment

```bash
# Check deployment
kubectl get deployment spring-boot-app -n default

# Check pods
kubectl get pods -n default

# Get the ALB URL
kubectl get ingress spring-boot-app -n default

# Test endpoints
curl http://<ALB_HOSTNAME>/
curl http://<ALB_HOSTNAME>/health
curl http://<ALB_HOSTNAME>/hello
```

---

## Helm Values Override

To customise the Spring Boot app deployment:

```bash
# Scale to 3 replicas, set custom image
helm upgrade --install spring-boot-app helm/spring-boot-app/ \
  --set replicaCount=3 \
  --set image.tag=v1.2.3 \
  --set image.repository=123456789012.dkr.ecr.us-east-1.amazonaws.com/spring-boot-app \
  --namespace default
```

Or create a custom values file:

```yaml
# my-values.yaml
replicaCount: 3
autoscaling:
  minReplicas: 2
  maxReplicas: 10
resources:
  requests:
    cpu: 500m
    memory: 1Gi
```

```bash
helm upgrade spring-boot-app helm/spring-boot-app/ -f my-values.yaml
```

---

## Destroying the Stack

```bash
# Remove Helm releases first
helm uninstall spring-boot-app -n default

# Destroy all Terraform-managed resources
cd terraform
terraform destroy
```

> Resources created outside Terraform (e.g., ALB created by the controller) may need manual cleanup if `terraform destroy` fails.
