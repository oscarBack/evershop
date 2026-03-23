# EverShop EKS Deployment

Terraform configuration for deploying EverShop eCommerce platform on AWS EKS.

## Usage

```hcl
module "evershop_eks" {
  source = "./eks-deployment"
  
  # Required variables
  aws_region  = "us-east-1"
  environment = "dev"
  
  # Optional overrides
  eks_cluster_name = "evershop-cluster"
  node_desired_capacity = 3
}
```

## Resources

| Name | Type |
|------|------|
| [aws_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_internet_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_eks_cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster) | resource |
| [aws_eks_node_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_node_group) | resource |
| [aws_db_instance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_ecr_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |
| [aws_cloudwatch_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| aws_region | AWS region for resource deployment | string | `us-east-1` | no |
| project_name | Project name for resource naming | string | `evershop` | no |
| environment | Environment name (dev, qa, prod) | string | `dev` | no |
| vpc_cidr | VPC CIDR block | string | `10.0.0.0/16` | no |
| availability_zones | List of availability zones | list(string) | `["us-east-1a", "us-east-1b", "us-east-1c"]` | no |
| eks_cluster_name | Name of the EKS cluster | string | `evershop-cluster` | no |
| eks_version | Kubernetes version for EKS cluster | string | `1.28` | no |
| node_instance_types | EC2 instance types for worker nodes | list(string) | `["m5.large"]` | no |
| node_desired_capacity | Desired number of worker nodes | number | `3` | no |
| node_min_capacity | Minimum number of worker nodes | number | `3` | no |
| node_max_capacity | Maximum number of worker nodes | number | `6` | no |
| node_disk_size | EBS disk size in GB for worker nodes | number | `100` | no |
| rds_instance_class | RDS instance class | string | `db.r5.large` | no |
| rds_allocated_storage | RDS allocated storage in GB | number | `100` | no |
| rds_engine_version | PostgreSQL engine version | string | `15.4` | no |
| rds_multi_az | Enable multi-AZ deployment for RDS | bool | `false` | no |
| rds_backup_retention_period | RDS backup retention period in days | number | `7` | no |
| rds_db_name | Name of the database | string | `evershop` | no |
| rds_username | Master username for RDS | string | `evershop_admin` | no |
| rds_password | Master password for RDS | string | `null` | yes |
| common_tags | Common tags applied to all resources | map(string) | see variables.tf | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| public_subnet_ids | List of public subnet IDs |
| private_subnet_ids | List of private subnet IDs |
| eks_cluster_endpoint | Endpoint for EKS cluster API server |
| eks_cluster_name | EKS cluster name |
| eks_node_group_role_arn | ARN of the IAM role for EKS node group |
| rds_instance_endpoint | Endpoint of the RDS instance |
| ecr_graphql_api_repository_url | URL of the ECR repository for GraphQL API |
| ecr_frontend_repository_url | URL of the ECR repository for React Frontend |
| cloudwatch_log_group_name | Name of the CloudWatch log group |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      AWS Account                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    VPC (10.0.0.0/16)                     ││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │ Public Subnets (3 AZs)                              │││
│  │  │  - Internet Gateway                                 │││
│  │  │  - NAT Gateway                                      │││
│  │  │  - Application Load Balancer                        │││
│  │  └─────────────────────────────────────────────────────┘││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │ Private Subnets (3 AZs)                             │││
│  │  │  - EKS Worker Nodes                                 │││
│  │  │  - RDS PostgreSQL (Multi-AZ)                        │││
│  │  └─────────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    EKS Cluster                           ││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │ Control Plane (AWS Managed)                         │││
│  │  │  - API Server, etcd, Controller Manager             │││
│  │  └─────────────────────────────────────────────────────┘││
│  │  ┌─────────────────────────────────────────────────────┐││
│  │  │ Node Groups                                         │││
│  │  │  - GraphQL API Pods                                 │││
│  │  │  - React Frontend Pods                              │││
│  │  │  - Add-ons (CNI, CoreDNS, etc.)                     │││
│  │  └─────────────────────────────────────────────────────┘││
│  └───────────────────────────────────���─────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │                    Supporting Services                   ││
│  │  - CloudWatch Logs & Metrics                            │││
│  │  - KMS Encryption Keys                                  │││
│  │  - Secrets Manager                                      │││
│  │  - ECR Container Registry                               │││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Environment Configuration

### Development

```hcl
environment = "dev"

node_instance_types   = ["t3.medium"]
node_desired_capacity = 2
node_min_capacity     = 2
node_max_capacity     = 4
node_disk_size        = 50

rds_instance_class   = "db.t3.micro"
rds_multi_az         = false
rds_backup_retention = 7
```

### QA

```hcl
environment = "qa"

node_instance_types   = ["t3.large"]
node_desired_capacity = 3
node_min_capacity     = 3
node_max_capacity     = 6
node_disk_size        = 50

rds_instance_class   = "db.t3.small"
rds_multi_az         = true
rds_backup_retention = 14
```

### Production

```hcl
environment = "prod"

node_instance_types   = ["m5.xlarge"]
node_desired_capacity = 5
node_min_capacity     = 5
node_max_capacity     = 10
node_disk_size        = 100

rds_instance_class   = "db.r5.large"
rds_multi_az         = true
rds_backup_retention = 30
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- kubectl installed
- AWS IAM permissions to create EKS, RDS, VPC, and IAM resources

## 📚 Documentation

| Document | Purpose | Audience |
|----------|---------|----------|
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | Complete deployment guide with AWS SSO setup | All users |
| [QUICK_START.md](./QUICK_START.md) | Fast-track deployment for experienced users | Advanced users |
| [PRE_DEPLOYMENT_CHECKLIST.md](./PRE_DEPLOYMENT_CHECKLIST.md) | Pre-deployment validation checklist | All users |
| [VERIFICATION.md](./VERIFICATION.md) | Detailed verification and health checks | All users |
| [QUICK_VERIFICATION.md](./QUICK_VERIFICATION.md) | Quick reference for common checks | All users |

## Quick Start

For first-time deployment, follow the [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md).

For experienced users:

```bash
# 1. Configure AWS SSO (one-time)
aws sso login --profile aws-evershop-dev

# 2. Deploy infrastructure
cd infra-evershop/eks-deployment
make tf-dev
terraform apply -var-file="dev.hcl"

# 3. Configure kubectl
aws eks update-kubeconfig --name evershop-cluster --region us-east-1 --profile aws-evershop-dev
```

See [QUICK_START.md](./QUICK_START.md) for more details.

## Security Groups

| Security Group | Purpose | Inbound Rules |
|----------------|---------|---------------|
| eks_node | EKS worker nodes | 443 from ALB, 10250 from control plane |
| rds | RDS PostgreSQL | 5432 from EKS nodes only |
| alb | Application Load Balancer | 80, 443 from 0.0.0.0/0 |

## Kubernetes Add-ons

| Add-on | Version | Purpose |
|--------|---------|---------|
| VPC CNI | Latest | Pod networking |
| CoreDNS | Latest | DNS resolution |
| kube-proxy | Latest | Service networking |
| EBS CSI Driver | Latest | Persistent volumes |
| Metrics Server | Latest | Resource metrics |
| AWS Load Balancer Controller | Latest | Ingress management |
| Cluster Autoscaler | Latest | Node autoscaling |

## Monitoring

- **CloudWatch Log Groups**:
  - `/aws/eks/evershop-cluster/control-plane` - Control plane logs
  - `/aws/eks/evershop-cluster/application` - Application logs

- **Log Retention**: 30 days (configurable)

## Important Notes

- Database password should be stored in AWS Secrets Manager in production
- Ensure KMS keys are properly backed up for disaster recovery
- Review security group rules before production deployment
- Enable Multi-AZ for high availability in QA and prod environments
- Use private endpoint access for production clusters
- Regularly update Kubernetes version and node group AMI

## Cluster Health Verification

After deploying the EKS cluster, verify its health and operational status:

### Automated Verification

**PowerShell (Windows):**
```powershell
.\scripts\Verify-EKSHealth.ps1 -Environment dev
```

**Bash (Linux/Mac):**
```bash
./scripts/verify-eks-health.sh dev
```

### Quick Manual Checks

```bash
# 1. Check cluster status
aws eks describe-cluster --name evershop-cluster --region us-east-1 --profile aws-evershop-dev --query 'cluster.status'

# 2. Update kubeconfig
aws eks update-kubeconfig --name evershop-cluster --region us-east-1 --profile aws-evershop-dev

# 3. Check nodes
kubectl get nodes

# 4. Check system pods
kubectl get pods -n kube-system

# 5. Test connectivity
kubectl cluster-info
```

### Verification Documentation

- **[VERIFICATION.md](./VERIFICATION.md)** - Comprehensive verification guide with detailed steps
- **[QUICK_VERIFICATION.md](./QUICK_VERIFICATION.md)** - Quick reference card for common checks

### Expected Results

✅ **Healthy Cluster:**
- Cluster status: `ACTIVE`
- All nodes: `Ready`
- All system pods: `Running`
- kubectl connectivity: Working
- Control plane logs: Enabled (5 types)
- OIDC provider: Configured

## Troubleshooting

### Check EKS Cluster Status

```bash
aws eks describe-cluster --name evershop-cluster --region us-east-1 --profile aws-evershop-dev
```

### View Node Group Status

```bash
aws eks describe-nodegroup --cluster-name evershop-cluster --nodegroup-name evershop-ng --region us-east-1 --profile aws-evershop-dev
```

### Check RDS Status

```bash
aws rds describe-db-instances --db-instance-identifier evershop-db --region us-east-1 --profile aws-evershop-dev
```

### View Terraform State

```bash
terraform state list
```

### Common Issues

| Issue | Solution |
|-------|----------|
| AWS credentials expired | Run `aws sso login --profile aws-evershop-dev` |
| kubectl cannot connect | Run `aws eks update-kubeconfig --name evershop-cluster --region us-east-1 --profile aws-evershop-dev` |
| Nodes not ready | Check node group status and CloudWatch logs |
| System pods not running | Check pod events with `kubectl describe pod <pod-name> -n kube-system` |

For detailed troubleshooting, see [VERIFICATION.md](./VERIFICATION.md#troubleshooting)

## License

This project is part of EverShop and follows the same licensing terms.