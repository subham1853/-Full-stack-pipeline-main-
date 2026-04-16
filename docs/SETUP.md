# Setup Guide

Complete step-by-step guide to set up the CI/CD pipeline from scratch.

---

## Table of Contents

1. [AWS Account Setup](#1-aws-account-setup)
2. [GitHub Repository Setup](#2-github-repository-setup)
3. [Terraform Backend Setup](#3-terraform-backend-setup)
4. [EKS Cluster Deployment](#4-eks-cluster-deployment)
5. [CI/CD Pipeline Configuration](#5-cicd-pipeline-configuration)
6. [Application Deployment](#6-application-deployment)

---

## 1. AWS Account Setup

### Create IAM User/Role

```bash
# Create IAM policy for EKS management
cat > eks-policy.json << 'EOF'
{
  "Version": "2026-04-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:*",
        "ec2:*",
        "iam:*",
        "kms:*",
        "logs:*",
        "elasticloadbalancing:*",
        "autoscaling:*",
        "acm:*",
        "route53:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Create policy
aws iam create-policy \
  --policy-name CICDDemoEKSAccess \
  --policy-document file://eks-policy.json

# Create user
aws iam create-user --user-name cicd-demo-admin

# Attach policy
aws iam attach-user-policy \
  --user-name cicd-demo-admin \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/CICDDemoEKSAccess

# Create access keys
aws iam create-access-key --user-name cicd-demo-admin
```

### Configure AWS CLI

```bash
aws configure
# Enter your Access Key ID
# Enter your Secret Access Key
# Enter region (e.g., us-west-2)
# Enter output format (json)
```

---

## 2. GitHub Repository Setup

### Create Repository Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key | AWS authentication |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Key | AWS authentication |
| `AWS_REGION` | us-west-2 | AWS region |
| `GITHUB_TOKEN` | Auto-generated | GitHub Container Registry |
| `SLACK_WEBHOOK_URL` | Your Slack webhook | Notifications |

### Configure GitHub Container Registry

```bash
# Create personal access token with packages:write scope
# Then login
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

---

## 3. Terraform Backend Setup

### Create S3 Bucket for State

```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket cicd-demo-terraform-state \
  --region us-west-2 \
  --create-bucket-configuration LocationConstraint=us-west-2

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket cicd-demo-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket cicd-demo-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'
```

### Create DynamoDB Table for Locking

```bash
aws dynamodb create-table \
  --table-name cicd-demo-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

---

## 4. EKS Cluster Deployment

### Initialize Terraform

```bash
cd terraform

# Initialize with backend
terraform init

# Or migrate from local state
terraform init -migrate-state
```

### Deploy Staging Environment

```bash
# Select workspace
terraform workspace new staging
terraform workspace select staging

# Plan
terraform plan -var-file=environments/staging/terraform.tfvars

# Apply
terraform apply -var-file=environments/staging/terraform.tfvars

# Get kubeconfig
aws eks update-kubeconfig \
  --name cicd-demo-staging \
  --region us-west-2

# Verify
kubectl get nodes
kubectl get pods -n kube-system
```

### Deploy Production Environment

```bash
# Create production workspace
terraform workspace new production
terraform workspace select production

# Plan
terraform plan -var-file=environments/production/terraform.tfvars

# Apply
terraform apply -var-file=environments/production/terraform.tfvars

# Get kubeconfig
aws eks update-kubeconfig \
  --name cicd-demo-production \
  --region us-west-2
```

---

## 5. CI/CD Pipeline Configuration

### GitHub Actions Setup

The GitHub Actions workflow is already configured in `.github/workflows/ci-cd-pipeline.yml`.

#### Required Secrets

Make sure these secrets are configured in GitHub:

```yaml
# Repository → Settings → Secrets and variables → Actions
AWS_ACCESS_KEY_ID: your-access-key
AWS_SECRET_ACCESS_KEY: your-secret-key
AWS_REGION: us-west-2
```

### Jenkins Setup (Alternative)

#### Install Required Plugins

1. Go to **Manage Jenkins → Manage Plugins**
2. Install:
   - Docker Pipeline
   - Kubernetes CLI
   - SonarQube Scanner
   - Pipeline Stage View
   - Blue Ocean

#### Configure Credentials

1. Go to **Manage Jenkins → Manage Credentials**
2. Add credentials:
   - `docker-registry-credentials` (Username/Password)
   - `aws-credentials` (AWS Credentials)
   - `kubeconfig` (Secret file)
   - `sonarqube-token` (Secret text)

#### Create Pipeline Job

1. Click **New Item**
2. Select **Pipeline**
3. Name: `cicd-demo-app`
4. Under Pipeline section:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: Your repo URL
   - Script Path: `Jenkinsfile`

---

## 6. Application Deployment

### Deploy Using Kustomize

```bash
# Deploy to staging
kubectl apply -k k8s/overlays/staging

# Wait for rollout
kubectl rollout status deployment/staging-cicd-demo-app -n staging

# Check status
kubectl get all -n staging
```

### Deploy Using Helm

```bash
# Add repo (optional)
helm repo add cicd-demo https://your-org.github.io/charts

# Install
helm upgrade --install cicd-demo-app ./helm/cicd-demo-app \
  --namespace staging \
  --create-namespace \
  --set image.tag=v1.0.0 \
  --wait

# Verify
helm list -n staging
kubectl get pods -n staging
```

### Verify Deployment

```bash
# Get service URL
kubectl get svc -n staging

# Port forward for testing
kubectl port-forward svc/staging-cicd-demo-service 8080:80 -n staging

# Test endpoints
curl http://localhost:8080/health
curl http://localhost:8080/api/status
```

---

## Verification Checklist

- [ ] AWS CLI configured with correct credentials
- [ ] Terraform backend (S3 + DynamoDB) created
- [ ] EKS cluster deployed and accessible
- [ ] GitHub Actions secrets configured
- [ ] Container registry accessible
- [ ] Application deployed and running
- [ ] Ingress configured with TLS
- [ ] Monitoring stack deployed
- [ ] Alerts configured

---

## Next Steps

1. [Configure Monitoring](./MONITORING.md)
2. [Set up Alerts](./ALERTING.md)
3. [Configure Backup](./BACKUP.md)
4. [Security Hardening](./SECURITY.md)
