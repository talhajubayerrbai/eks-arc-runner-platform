# EKS ARC Runner Platform

> **GitHub Self-Hosted Runner Platform on Amazon EKS with Actions Runner Controller**

A production-ready platform that provisions an Amazon EKS cluster, installs GitHub's **Actions Runner Controller (ARC)** to provide ephemeral Kubernetes-native self-hosted runners, and deploys a Spring Boot 3.2 / Java 21 REST API through two fully automated GitHub Actions pipelines — both running **entirely on the self-hosted Kubernetes runners**.

---

## Architecture Summary

```
GitHub Actions  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
     Dispatch   ┃  VPC 10.0.0.0/16   us-east-1        ┃
        │        ┃                                     ┃
        │        ┃   ┏━━━━━━━━━━━━━━━━━━━━━━┓         ┃
        │        ┃   ┃  EKS Cluster 1.29   ┃         ┃
        │        ┃   ┃  Private subnets    ┃         ┃
        │        ┃   ┃   ┏────────────┐    ┃         ┃
        └─────────┼───►┃ ARC Runners  ┃    ┃         ┃
                 ┃   ┃   │ (ephemeral)  │    ┃         ┃
                 ┃   ┃   └────────────┘    ┃         ┃
                 ┃   ┃   ┏────────────┐    ┃         ┃
                 ┃   ┃   │ Spring Boot  │    ┃         ┃
                 ┃   ┃   │    App       │    ┃         ┃
                 ┃   ┃   └────────────┘    ┃         ┃
                 ┃   ┗━━━━━━━━━━━━━━━━━━━━━━┛         ┃
                 ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
                              ECR ◄── images
                              CloudWatch ◄ logs
```

### Key Components

| Component | Description |
|-----------|-------------|
| **VPC** | 10.0.0.0/16, 3 public + 3 private subnets across us-east-1a/b/c, IGW, NAT GW per AZ |
| **EKS** | Kubernetes 1.29, managed node group (t3.medium, min 2 / max 6), OIDC for IRSA |
| **ARC** | Actions Runner Controller with RunnerDeployment + HorizontalRunnerAutoscaler (1–20) |
| **ALB** | AWS Load Balancer Controller providing internet-facing ALB for the Spring Boot app |
| **ECR** | Private registry for Spring Boot app images with scan-on-push |
| **CloudWatch** | Log group `/eks/eks-arc-runner-platform`, Container Insights, CPU alarm |
| **Terraform** | Six clean modules: vpc, eks, iam, ecr, cloudwatch, helm-bootstrap |

---

## Prerequisites

- Terraform ≥ 1.7.0
- AWS CLI ≥ 2.x configured with appropriate permissions
- kubectl ≥ 1.29
- Helm ≥ 3.14
- Java 21 (for local app development)
- Docker (for local image builds)
- k6 (for local load testing)
- A **GitHub App** for ARC authentication (see below)

---

## Quick Start

### 1. Configure AWS credentials

```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=your-profile  # or use IAM role
```

### 2. Create the Terraform state bucket

```bash
aws s3 mb s3://your-tf-state-bucket --region us-east-1
aws s3api put-bucket-versioning \
  --bucket your-tf-state-bucket \
  --versioning-configuration Status=Enabled
```

### 3. Configure variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — fill in GitHub App credentials
```

### 4. Two-stage `terraform apply`

Stage 1 — Infrastructure (VPC, IAM, ECR, CloudWatch, EKS):
```bash
terraform init \
  -backend-config="bucket=your-tf-state-bucket" \
  -backend-config="key=eks-arc-runner-platform/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform apply \
  -target=module.vpc \
  -target=module.iam \
  -target=module.ecr \
  -target=module.cloudwatch \
  -target=module.eks
```

Stage 2 — Helm bootstrap (Metrics Server, ALB Controller, ARC):
```bash
terraform apply
```

> **Why two stages?** The Kubernetes/Helm Terraform providers cannot plan against a cluster being created in the same run — this is a [documented provider limitation](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#stacking-with-managed-kubernetes-cluster-resources).

### 5. Configure kubeconfig

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name eks-arc-runner-platform
```

### 6. Apply ARC runner manifests

```bash
kubectl apply -k k8s/
```

---

## GitHub App Authentication for ARC

ARC requires a GitHub App to authenticate with the GitHub API and register runners.

### Create the GitHub App

1. Go to **GitHub Settings → Developer Settings → GitHub Apps → New GitHub App**
2. Set:
   - **App name**: `eks-arc-runner-<your-org>`
   - **Homepage URL**: `https://github.com/talhajubayerrbai`
   - **Webhook**: Disable (uncheck Active)
   - **Permissions**: Actions (Read), Administration (Read & Write), Metadata (Read)
   - **Subscribe to events**: Workflow job
3. Click **Create GitHub App**
4. Note the **App ID** and **Installation ID**
5. Generate a **private key** (download the `.pem` file)
6. Install the app on your repository

### Encode and set the credentials

```bash
# Base64-encode the private key
base64 -w0 /path/to/private-key.pem > private-key.b64

# Set Terraform variables
export TF_VAR_github_app_id="YOUR_APP_ID"
export TF_VAR_github_app_installation_id="YOUR_INSTALLATION_ID"
export TF_VAR_github_app_private_key="$(cat private-key.b64)"
```

---

## Triggering the Pipelines

### Build & Deploy Pipeline

```bash
# Via GitHub CLI
gh workflow run build.yml

# Via GitHub UI: Actions → Build and Deploy → Run workflow
```

Stages: Checkout → Gradle Build → Checkstyle → PMD → SpotBugs → JUnit → JaCoCo → Docker Build → ECR Push → Helm Deploy → Rollout Verify

### Validation Pipeline

Triggered automatically on successful build. Or manually:

```bash
gh workflow run validate.yml --field app_url=http://your-alb-hostname
```

Stages: Smoke Test → REST Assured → k6 Load Test → Deployment Verification → HTML Report

---

## Destroying the Stack

```bash
cd terraform
terraform destroy
```

> **Warning**: This destroys all infrastructure including the EKS cluster, ECR images, and VPC. Ensure you have backed up any critical data.

---

## Repository Structure

```
.
├── .github/workflows/
│   ├── build.yml           # Build + Deploy pipeline (11 stages)
│   └── validate.yml        # Validation pipeline (5 stages)
├── app/                    # Spring Boot 3.2 / Java 21 REST API
│   ├── src/
│   ├── build.gradle.kts
│   ├── Dockerfile
│   └── config/             # Checkstyle, PMD configs
├── helm/spring-boot-app/   # Helm chart (Deployment, Service, Ingress, HPA)
├── k8s/                    # ARC manifests + Kustomize
├── terraform/              # Terraform root + 6 modules
├── tests/
│   ├── k6/                 # k6 load test
│   └── report/             # HTML report generator
└── docs/                   # Deployment guide, architecture, CI/CD diagrams
```
