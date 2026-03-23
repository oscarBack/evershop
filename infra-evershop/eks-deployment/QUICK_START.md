# EverShop EKS - Quick Start Guide

Fast-track deployment guide for experienced users.

## Prerequisites Checklist

- [ ] Terraform >= 1.5.0 installed
- [ ] AWS CLI >= 2.0 installed
- [ ] kubectl >= 1.28 installed
- [ ] AWS SSO profile configured
- [ ] S3 backend and DynamoDB table created

---

## 1. AWS SSO Setup (One-Time)

```bash
# Add to ~/.aws/config
[profile aws-evershop-dev]
sso_start_url = https://d-906760bf16.awsapps.com/start/#
sso_region = us-east-1
sso_account_id = <YOUR_ACCOUNT_ID>
sso_role_name = AWSAdministratorAccess
region = us-east-1
output = json

# Login
aws sso login --profile aws-evershop-dev
```

---

## 2. Backend Setup (One-Time)

```bash
export AWS_PROFILE=aws-evershop-dev

# Create S3 bucket
aws s3api create-bucket --bucket evershop-terraform-state --region us-east-1
aws s3api put-bucket-versioning --bucket evershop-terraform-state --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket evershop-terraform-state --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB table
aws dynamodb create-table \
  --table-name evershop-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

---

## 3. Deploy Infrastructure

```bash
cd infra-evershop/eks-deployment

# Initialize and deploy
make tf-dev
terraform apply -var-file="dev.hcl" -auto-approve
```

**Deployment time:** ~25-30 minutes

---

## 4. Configure kubectl

```bash
aws eks update-kubeconfig --name evershop-cluster --region us-east-1 --profile aws-evershop-dev
kubectl get nodes
```

---

## 5. Get Outputs

```bash
# Save all outputs
terraform output > deployment-outputs.txt

# Key outputs
terraform output eks_cluster_endpoint
terraform output rds_instance_endpoint
terraform output ecr_graphql_api_repository_url
terraform output graphql_api_ingress_hostname
terraform output react_frontend_ingress_hostname
```

---

## 6. Retrieve RDS Password

```bash
# Find secret
aws secretsmanager list-secrets --profile aws-evershop-dev --query "SecretList[?contains(Name, 'evershop-rds')].ARN" --output text

# Get password
aws secretsmanager get-secret-value --secret-id <SECRET_ARN> --profile aws-evershop-dev --query SecretString --output text
```

---

## 7. Create Application Secrets

```bash
kubectl create secret generic evershop-db-credentials \
  --from-literal=host=<RDS_ENDPOINT> \
  --from-literal=port=5432 \
  --from-literal=database=evershop \
  --from-literal=username=evershop_admin \
  --from-literal=password=<RDS_PASSWORD> \
  -n evershop
```

---

## Quick Verification

```bash
# Cluster status
aws eks describe-cluster --name evershop-cluster --region us-east-1 --profile aws-evershop-dev --query 'cluster.status'

# Nodes
kubectl get nodes

# System pods
kubectl get pods -n kube-system

# RDS status
aws rds describe-db-instances --db-instance-identifier evershop-db-dev --profile aws-evershop-dev --query 'DBInstances[0].DBInstanceStatus'

# Ingress
kubectl get ingress -n evershop
```

---

## Common Commands

### Terraform

```bash
# Plan
make tf-dev

# Apply
terraform apply -var-file="dev.hcl"

# Destroy
terraform destroy -var-file="dev.hcl"

# Show state
terraform state list

# Show outputs
terraform output
```

### AWS SSO

```bash
# Login
aws sso login --profile aws-evershop-dev

# Logout
aws sso logout --profile aws-evershop-dev

# Check identity
aws sts get-caller-identity --profile aws-evershop-dev
```

### kubectl

```bash
# Get nodes
kubectl get nodes

# Get pods
kubectl get pods -n evershop
kubectl get pods -n kube-system

# Get services
kubectl get svc -n evershop

# Get ingress
kubectl get ingress -n evershop

# Describe resource
kubectl describe pod <POD_NAME> -n evershop

# Logs
kubectl logs <POD_NAME> -n evershop

# Execute command in pod
kubectl exec -it <POD_NAME> -n evershop -- /bin/bash
```

### ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 --profile aws-evershop-dev | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# List repositories
aws ecr describe-repositories --profile aws-evershop-dev

# List images
aws ecr list-images --repository-name evershop-graphql-api-dev --profile aws-evershop-dev
```

---

## Troubleshooting Quick Fixes

### SSO Expired
```bash
aws sso login --profile aws-evershop-dev
```

### kubectl Not Working
```bash
aws eks update-kubeconfig --name evershop-cluster --region us-east-1 --profile aws-evershop-dev
```

### Terraform Lock
```bash
terraform force-unlock <LOCK_ID>
```

### Nodes Not Ready
```bash
kubectl describe node <NODE_NAME>
kubectl get pods -n kube-system
```

---

## Resource Costs (Dev Environment)

| Resource | Type | Monthly Cost (Estimate) |
|----------|------|-------------------------|
| EKS Cluster | Control Plane | $73 |
| EC2 Instances | 2x t3.medium | $60 |
| NAT Gateway | Single | $32 |
| RDS | db.t3.micro | $15 |
| ALB | Application Load Balancer | $23 |
| Data Transfer | Varies | $10-50 |
| **Total** | | **~$213-253/month** |

---

## Next Steps

1. Build and push Docker images to ECR
2. Deploy EverShop application
3. Configure monitoring and alerts
4. Set up CI/CD pipeline
5. Review security settings

---

## Full Documentation

- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Complete deployment guide
- [VERIFICATION.md](./VERIFICATION.md) - Detailed verification steps
- [README.md](./README.md) - Architecture overview

---

**Deployment Time:** ~30 minutes  
**Difficulty:** Intermediate  
**Cost:** ~$213-253/month (dev)
