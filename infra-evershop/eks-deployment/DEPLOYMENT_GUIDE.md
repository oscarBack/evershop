# EverShop EKS Deployment Guide

Complete guide for deploying EverShop to AWS EKS in the development environment.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS SSO Configuration](#aws-sso-configuration)
3. [Terraform Backend Setup](#terraform-backend-setup)
4. [Environment Configuration](#environment-configuration)
5. [Deployment Steps](#deployment-steps)
6. [Post-Deployment Configuration](#post-deployment-configuration)
7. [Verification](#verification)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

Install the following tools before proceeding:

| Tool | Version | Installation |
|------|---------|--------------|
| **Terraform** | >= 1.5.0 | [Download](https://www.terraform.io/downloads) |
| **AWS CLI** | >= 2.0 | [Download](https://aws.amazon.com/cli/) |
| **kubectl** | >= 1.28 | [Download](https://kubernetes.io/docs/tasks/tools/) |
| **make** | Any | Included with Git Bash on Windows |

### Verify Installations

```bash
# Check Terraform
terraform version

# Check AWS CLI
aws --version

# Check kubectl
kubectl version --client

# Check make
make --version
```

### AWS Account Access

Ensure you have:
- AWS account credentials with administrator access
- Permission to create EKS, RDS, VPC, IAM, and ECR resources
- AWS SSO configured for your organization

---

## AWS SSO Configuration

### Step 1: Configure AWS SSO Profile

Add the following profile to your AWS config file:

**Location:**
- Windows: `C:\Users\<username>\.aws\config`
- Linux/Mac: `~/.aws/config`

**Profile Configuration:**

```ini
[profile aws-evershop-dev]
sso_start_url = https://d-906760bf16.awsapps.com/start/#
sso_region = us-east-1
sso_account_id = <YOUR_DEV_ACCOUNT_ID>
sso_role_name = AWSAdministratorAccess
region = us-east-1
output = json
```

**Replace `<YOUR_DEV_ACCOUNT_ID>` with your actual AWS account ID for the dev environment.**

### Step 2: Login to AWS SSO

```bash
aws sso login --profile aws-evershop-dev
```

This will:
1. Open your browser for authentication
2. Prompt you to authorize the AWS CLI
3. Cache credentials locally

### Step 3: Verify SSO Login

```bash
# Check caller identity
aws sts get-caller-identity --profile aws-evershop-dev

# Expected output:
# {
#     "UserId": "AROAXXXXXXXXXXXXXXXXX:user@example.com",
#     "Account": "123456789012",
#     "Arn": "arn:aws:sts::123456789012:assumed-role/AWSAdministratorAccess/user@example.com"
# }
```

### SSO Session Management

```bash
# Login (valid for 8 hours by default)
aws sso login --profile aws-evershop-dev

# Logout
aws sso logout --profile aws-evershop-dev

# Check if session is valid
aws sts get-caller-identity --profile aws-evershop-dev
```

---

## Terraform Backend Setup

Before deploying infrastructure, create the S3 backend for Terraform state management.

### Step 1: Create S3 Bucket for State

```bash
# Set profile
export AWS_PROFILE=aws-evershop-dev

# Create S3 bucket
aws s3api create-bucket \
  --bucket evershop-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket evershop-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket evershop-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket evershop-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Step 2: Verify Backend Resources

```bash
# Check S3 bucket
aws s3 ls | grep evershop-terraform-state

# Verify encryption is enabled
aws s3api get-bucket-encryption \
  --bucket evershop-terraform-state
```

---

## Environment Configuration

### Development Environment (dev.hcl)

The `dev.hcl` file contains environment-specific configuration:

```hcl
project_name = "evershop"
environment  = "dev"
aws_region   = "us-east-1"

# VPC Configuration
vpc_cidr               = "10.0.0.0/16"
vpc_single_nat_gateway = true  # Cost optimization for dev

# EKS Configuration
eks_cluster_name            = "evershop-cluster"
eks_version                 = "1.28"
eks_endpoint_public_access  = true
eks_endpoint_private_access = true

# Node Group Configuration (cost-optimized for dev)
node_instance_types   = ["t3.medium"]
node_desired_capacity = 2
node_min_capacity     = 2
node_max_capacity     = 4
node_disk_size        = 50

# RDS Configuration (cost-optimized for dev)
rds_instance_class          = "db.t3.micro"
rds_allocated_storage       = 20
rds_engine_version          = "15.4"
rds_multi_az                = false
rds_backup_retention_period = 7

# Monitoring
cloudwatch_log_retention_days = 7

# Ingress (dev uses ALB DNS directly)
domain_name         = ""
acm_certificate_arn = ""

# Tags
common_tags = {
  ManagedBy    = "Terraform"
  Organization = "EverShop"
  Environment  = "dev"
  CostCenter   = "development"
}
```

### Key Configuration Decisions for Dev

| Setting | Value | Rationale |
|---------|-------|-----------|
| `vpc_single_nat_gateway` | `true` | Cost savings (~$32/month per NAT Gateway) |
| `node_instance_types` | `t3.medium` | Sufficient for dev workloads, cost-effective |
| `node_desired_capacity` | `2` | Minimal HA, lower costs |
| `rds_instance_class` | `db.t3.micro` | Adequate for dev database |
| `rds_multi_az` | `false` | Not required for dev environment |
| `domain_name` | `""` | Use ALB DNS directly, no custom domain |

---

## Deployment Steps

### Step 1: Navigate to Deployment Directory

```bash
cd c:\Users\oscar\OneDrive\Documentos\Github\evershop\infra-evershop\eks-deployment
```

### Step 2: Initialize Terraform

```bash
# Option 1: Using makefile (recommended)
make tf-dev

# Option 2: Manual commands
aws sso login --profile aws-evershop-dev
terraform init
terraform workspace select dev || terraform workspace new dev
```

**What happens during `terraform init`:**
- Downloads required provider plugins (AWS, Kubernetes, Helm)
- Configures S3 backend for state storage
- Initializes workspace

### Step 3: Review the Deployment Plan

```bash
# Generate and review plan
terraform plan -var-file="dev.hcl" -out=dev.tfplan

# Review resources to be created
terraform show dev.tfplan
```

**Expected Resources (approximately 60+ resources):**
- 1 VPC with 9 subnets (3 public, 3 private, 3 database)
- 1 Internet Gateway
- 1 NAT Gateway (dev uses single NAT)
- 1 EKS Cluster
- 1 EKS Node Group
- 1 RDS PostgreSQL instance
- 2 ECR repositories
- Multiple Security Groups
- Multiple IAM roles and policies
- CloudWatch log groups
- Kubernetes resources (namespaces, service accounts, ingress)

### Step 4: Apply the Configuration

```bash
# Apply the plan
terraform apply dev.tfplan

# Or apply directly (will prompt for confirmation)
terraform apply -var-file="dev.hcl"
```

**Deployment Timeline:**
- VPC and networking: ~2-3 minutes
- EKS cluster: ~10-12 minutes
- EKS node group: ~3-5 minutes
- RDS instance: ~5-7 minutes
- Kubernetes resources: ~2-3 minutes
- **Total: ~25-30 minutes**

### Step 5: Save Terraform Outputs

```bash
# Save all outputs to file
terraform output > deployment-outputs.txt

# View specific outputs
terraform output eks_cluster_endpoint
terraform output rds_instance_endpoint
terraform output ecr_graphql_api_repository_url
terraform output ecr_react_frontend_repository_url
```

---

## Post-Deployment Configuration

### Step 1: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev

# Verify connection
kubectl cluster-info
kubectl get nodes
```

### Step 2: Verify Kubernetes Resources

```bash
# Check namespaces
kubectl get namespaces

# Check system pods
kubectl get pods -n kube-system

# Check service accounts
kubectl get serviceaccounts -n evershop

# Check ingress
kubectl get ingress -n evershop
```

### Step 3: Retrieve RDS Credentials

The RDS password is auto-generated and stored in AWS Secrets Manager:

```bash
# Get secret ARN
aws secretsmanager list-secrets \
  --profile aws-evershop-dev \
  --query "SecretList[?contains(Name, 'evershop-rds')].ARN" \
  --output text

# Retrieve password
aws secretsmanager get-secret-value \
  --secret-id <SECRET_ARN> \
  --profile aws-evershop-dev \
  --query SecretString \
  --output text
```

### Step 4: Configure Application Secrets

Create Kubernetes secrets for the application:

```bash
# Create database connection secret
kubectl create secret generic evershop-db-credentials \
  --from-literal=host=<RDS_ENDPOINT> \
  --from-literal=port=5432 \
  --from-literal=database=evershop \
  --from-literal=username=evershop_admin \
  --from-literal=password=<RDS_PASSWORD> \
  -n evershop

# Verify secret
kubectl get secret evershop-db-credentials -n evershop
```

### Step 5: Get Application URLs

```bash
# Get GraphQL API URL
kubectl get ingress graphql-api-ingress -n evershop \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get Frontend URL
kubectl get ingress react-frontend-ingress -n evershop \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Note:** It may take 2-3 minutes for the ALB to become fully operational.

---

## Verification

### Automated Verification

Run the provided verification scripts:

**PowerShell (Windows):**
```powershell
.\scripts\Verify-EKSHealth.ps1 -Environment dev
```

**Bash (Linux/Mac/Git Bash):**
```bash
./scripts/verify-eks-health.sh dev
```

### Manual Verification Checklist

#### 1. EKS Cluster Health

```bash
# Cluster status
aws eks describe-cluster \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'cluster.status'
# Expected: "ACTIVE"

# Node status
kubectl get nodes
# Expected: All nodes in "Ready" state
```

#### 2. System Pods Health

```bash
# Check all system pods
kubectl get pods -n kube-system

# Expected pods running:
# - coredns-*
# - aws-node-*
# - kube-proxy-*
# - aws-load-balancer-controller-*
```

#### 3. RDS Connectivity

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier evershop-db-dev \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].DBInstanceStatus'
# Expected: "available"

# Test connectivity from pod
kubectl run -it --rm debug \
  --image=postgres:15 \
  --restart=Never \
  -n evershop \
  -- psql -h <RDS_ENDPOINT> -U evershop_admin -d evershop
```

#### 4. ECR Repositories

```bash
# List ECR repositories
aws ecr describe-repositories \
  --profile aws-evershop-dev \
  --query 'repositories[*].repositoryName'

# Expected:
# - evershop-graphql-api-dev
# - evershop-react-frontend-dev
```

#### 5. Load Balancer

```bash
# Check ALB status
aws elbv2 describe-load-balancers \
  --profile aws-evershop-dev \
  --query 'LoadBalancers[?contains(LoadBalancerName, `evershop`)].State.Code'
# Expected: "active"

# Test ALB endpoint
curl -I http://<ALB_DNS_NAME>
```

### Health Check Summary

| Component | Check Command | Expected Result |
|-----------|---------------|-----------------|
| EKS Cluster | `aws eks describe-cluster` | Status: ACTIVE |
| Nodes | `kubectl get nodes` | All Ready |
| System Pods | `kubectl get pods -n kube-system` | All Running |
| RDS | `aws rds describe-db-instances` | Status: available |
| ALB | `aws elbv2 describe-load-balancers` | State: active |
| ECR | `aws ecr describe-repositories` | 2 repositories |

---

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: AWS SSO Session Expired

**Symptoms:**
```
Error: error configuring Terraform AWS Provider: failed to get shared config profile, aws-evershop-dev
```

**Solution:**
```bash
aws sso login --profile aws-evershop-dev
```

#### Issue 2: Terraform State Conflicts

**Symptoms:**
```
Error: Error acquiring the state lock
```

**Note:** State locking has been disabled. If you encounter state conflicts when running concurrent operations, ensure only one `terraform apply` runs at a time.

**Solution:**
```bash
# If state is corrupted, refresh it
terraform refresh -var-file="dev.hcl"

# Or manually sync state
terraform state pull > backup.tfstate
terraform state push backup.tfstate
```

#### Issue 3: EKS Nodes Not Ready

**Symptoms:**
```
NAME                          STATUS     ROLES    AGE
ip-10-0-1-100.ec2.internal   NotReady   <none>   5m
```

**Solution:**
```bash
# Check node events
kubectl describe node <NODE_NAME>

# Check system pods
kubectl get pods -n kube-system

# Check node logs
kubectl logs -n kube-system aws-node-<POD_ID>
```

#### Issue 4: RDS Connection Timeout

**Symptoms:**
```
psql: could not connect to server: Connection timed out
```

**Solution:**
```bash
# Verify security group rules
aws ec2 describe-security-groups \
  --group-ids <RDS_SG_ID> \
  --profile aws-evershop-dev

# Ensure EKS node security group is allowed
# Check RDS is in correct subnets
aws rds describe-db-instances \
  --db-instance-identifier evershop-db-dev \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].DBSubnetGroup'
```

#### Issue 5: kubectl Cannot Connect

**Symptoms:**
```
Unable to connect to the server: dial tcp: lookup <cluster-endpoint>: no such host
```

**Solution:**
```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev

# Verify AWS credentials
aws sts get-caller-identity --profile aws-evershop-dev

# Check cluster endpoint
aws eks describe-cluster \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'cluster.endpoint'
```

#### Issue 6: Insufficient IAM Permissions

**Symptoms:**
```
Error: error creating EKS Cluster: AccessDeniedException
```

**Solution:**
- Verify your IAM role has `AWSAdministratorAccess` or equivalent
- Check SSO role assignment in AWS SSO console
- Contact AWS administrator to grant necessary permissions

#### Issue 7: Resource Quota Exceeded

**Symptoms:**
```
Error: error creating VPC: VpcLimitExceeded
```

**Solution:**
```bash
# Check VPC quota
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --profile aws-evershop-dev

# Request quota increase if needed
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 10 \
  --profile aws-evershop-dev
```

### Getting Help

1. **Check Terraform logs:**
   ```bash
   export TF_LOG=DEBUG
   terraform apply -var-file="dev.hcl"
   ```

2. **Check CloudWatch logs:**
   - EKS control plane: `/aws/eks/evershop-cluster/cluster`
   - Application logs: `/aws/eks/evershop-cluster/application`

3. **Review AWS Console:**
   - EKS: https://console.aws.amazon.com/eks
   - RDS: https://console.aws.amazon.com/rds
   - VPC: https://console.aws.amazon.com/vpc

4. **Consult documentation:**
   - [VERIFICATION.md](./VERIFICATION.md) - Detailed verification steps
   - [README.md](./README.md) - Architecture overview
   - [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

---

## Cleanup (Destroy Infrastructure)

**⚠️ WARNING: This will permanently delete all resources!**

### Step 1: Backup Important Data

```bash
# Backup RDS database
aws rds create-db-snapshot \
  --db-instance-identifier evershop-db-dev \
  --db-snapshot-identifier evershop-db-dev-final-backup \
  --profile aws-evershop-dev

# Export Kubernetes resources
kubectl get all -n evershop -o yaml > evershop-k8s-backup.yaml
```

### Step 2: Destroy Infrastructure

```bash
# Destroy all resources
terraform destroy -var-file="dev.hcl"

# Confirm by typing: yes
```

### Step 3: Clean Up Backend (Optional)

```bash
# Delete S3 bucket (remove all versions first)
aws s3 rm s3://evershop-terraform-state --recursive
aws s3api delete-bucket --bucket evershop-terraform-state
```

---

## Next Steps

After successful deployment:

1. **Deploy Application:**
   - Build and push Docker images to ECR
   - Deploy EverShop application to EKS
   - Configure environment variables

2. **Set Up CI/CD:**
   - Configure GitHub Actions or Jenkins
   - Automate Docker builds and deployments
   - Set up automated testing

3. **Configure Monitoring:**
   - Set up CloudWatch dashboards
   - Configure alerts and notifications
   - Enable container insights

4. **Security Hardening:**
   - Review security group rules
   - Enable AWS GuardDuty
   - Configure AWS WAF for ALB
   - Implement network policies

5. **Cost Optimization:**
   - Review resource utilization
   - Configure autoscaling policies
   - Set up cost alerts

---

## Additional Resources

- [EverShop Documentation](https://evershop.io/docs)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

---

## Support

For issues or questions:
- Review [VERIFICATION.md](./VERIFICATION.md) for detailed checks
- Check [Troubleshooting](#troubleshooting) section above
- Consult AWS documentation
- Review Terraform state: `terraform state list`

---

**Last Updated:** March 2026  
**Terraform Version:** >= 1.5.0  
**EKS Version:** 1.28  
**PostgreSQL Version:** 15.4
