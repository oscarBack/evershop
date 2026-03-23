# Getting Started with EverShop EKS Deployment

Welcome! This guide will help you navigate the deployment documentation and get started quickly.

## 📖 Documentation Overview

We've organized the documentation to support different user needs and experience levels:

### For First-Time Deployers

1. **Start here:** [PRE_DEPLOYMENT_CHECKLIST.md](./PRE_DEPLOYMENT_CHECKLIST.md)
   - Verify all prerequisites
   - Ensure tools are installed
   - Validate AWS access
   - Complete pre-deployment checks

2. **Then follow:** [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
   - Complete AWS SSO configuration
   - Set up Terraform backend
   - Deploy infrastructure step-by-step
   - Post-deployment configuration

3. **Finally verify:** [VERIFICATION.md](./VERIFICATION.md)
   - Comprehensive health checks
   - Detailed verification steps
   - Troubleshooting guidance

### For Experienced Users

1. **Quick reference:** [QUICK_START.md](./QUICK_START.md)
   - Fast-track deployment commands
   - Common operations
   - Quick troubleshooting

2. **Quick checks:** [QUICK_VERIFICATION.md](./QUICK_VERIFICATION.md)
   - Essential health checks
   - Common verification commands

### For Architecture Understanding

- **Architecture overview:** [README.md](./README.md)
  - System architecture
  - Resource descriptions
  - Technical specifications

---

## 🎯 Choose Your Path

### Path 1: Complete Guided Deployment (Recommended for First Time)

**Time Required:** 1-2 hours (including reading)

```
PRE_DEPLOYMENT_CHECKLIST.md
          ↓
DEPLOYMENT_GUIDE.md
          ↓
VERIFICATION.md
```

**Best for:**
- First-time AWS EKS users
- Users new to Terraform
- Production deployments requiring thorough validation

### Path 2: Fast-Track Deployment (For Experienced Users)

**Time Required:** 30-45 minutes

```
QUICK_START.md
     ↓
QUICK_VERIFICATION.md
```

**Best for:**
- Experienced DevOps engineers
- Users familiar with AWS EKS and Terraform
- Development/testing environments

---

## 🚀 Quick Decision Tree

```
Are you deploying EKS for the first time?
│
├─ YES → Follow Path 1 (Complete Guided Deployment)
│        Start with PRE_DEPLOYMENT_CHECKLIST.md
│
└─ NO → Do you have AWS SSO configured?
         │
         ├─ YES → Follow Path 2 (Fast-Track)
         │        Start with QUICK_START.md
         │
         └─ NO → Follow Path 1, Section "AWS SSO Configuration"
                  Then switch to Path 2
```

---

## 📋 What You'll Deploy

This infrastructure deployment creates:

### Core Infrastructure
- **VPC** with 9 subnets across 3 availability zones
- **EKS Cluster** (Kubernetes 1.28) with managed control plane
- **EKS Node Group** with 2 t3.medium instances (dev)
- **RDS PostgreSQL** (15.4) for application database
- **Application Load Balancer** for ingress traffic

### Supporting Services
- **ECR Repositories** for container images
- **CloudWatch Log Groups** for monitoring
- **IAM Roles** with IRSA for pod-level permissions
- **Security Groups** for network isolation
- **Secrets Manager** for sensitive data

### Kubernetes Add-ons
- AWS Load Balancer Controller
- Cluster Autoscaler
- VPC CNI
- CoreDNS
- kube-proxy

**Total Resources:** ~60+ AWS resources

---

## ⏱️ Time Estimates

| Phase | Time Required |
|-------|---------------|
| Prerequisites setup | 15-30 minutes |
| AWS SSO configuration | 10-15 minutes |
| Backend setup (S3 + DynamoDB) | 5-10 minutes |
| Terraform deployment | 25-30 minutes |
| Post-deployment configuration | 10-15 minutes |
| Verification | 10-15 minutes |
| **Total (first time)** | **75-115 minutes** |
| **Total (experienced)** | **30-45 minutes** |

---

## 💰 Cost Estimates

### Development Environment (dev.hcl)

| Resource | Configuration | Monthly Cost |
|----------|---------------|--------------|
| EKS Control Plane | Managed | $73 |
| EC2 Instances | 2x t3.medium | $60 |
| NAT Gateway | Single | $32 |
| RDS PostgreSQL | db.t3.micro, 20GB | $15 |
| Application Load Balancer | Standard | $23 |
| Data Transfer | Estimated | $10-50 |
| **Total** | | **$213-253/month** |

### Cost Optimization Tips
- Dev uses single NAT Gateway (saves ~$32/month vs multi-AZ)
- Smaller instance types (t3.medium vs m5.large)
- No multi-AZ RDS (saves ~50% on RDS costs)
- Reduced node count (2 vs 3+)

---

## 🔧 Prerequisites Summary

### Required Tools

| Tool | Minimum Version | Check Command |
|------|-----------------|---------------|
| Terraform | 1.5.0 | `terraform version` |
| AWS CLI | 2.0 | `aws --version` |
| kubectl | 1.28 | `kubectl version --client` |
| make | Any | `make --version` |

### Required Access

- AWS account with administrator permissions
- AWS SSO configured (or IAM credentials)
- Ability to create:
  - VPC and networking resources
  - EKS clusters
  - RDS instances
  - IAM roles and policies
  - ECR repositories

### Required Knowledge

**Minimum (Path 1):**
- Basic command line usage
- Basic understanding of cloud infrastructure
- Ability to follow step-by-step instructions

**Recommended (Path 2):**
- AWS EKS experience
- Terraform experience
- Kubernetes fundamentals
- AWS networking concepts

---

## 📁 File Structure

```
eks-deployment/
├── GETTING_STARTED.md              ← You are here
├── DEPLOYMENT_GUIDE.md             ← Complete deployment guide
├── QUICK_START.md                  ← Fast-track guide
├── PRE_DEPLOYMENT_CHECKLIST.md     ← Pre-deployment validation
├── VERIFICATION.md                 ← Detailed verification
├── QUICK_VERIFICATION.md           ← Quick health checks
├── README.md                       ← Architecture overview
│
├── dev.hcl                         ← Dev environment config
├── qa.hcl                          ← QA environment config
├── prod.hcl                        ← Prod environment config
│
├── providers.tf                    ← Provider configuration
├── variables.tf                    ← Variable definitions
├── data.tf                         ← Data sources
├── vpc.tf                          ← VPC resources
├── eks.tf                          ← EKS cluster
├── rds.tf                          ← RDS database
├── security_groups.tf              ← Security groups
├── iam.tf                          ← IAM roles
├── ecr.tf                          ← ECR repositories
├── ingress.tf                      ← Ingress resources
├── monitoring.tf                   ← CloudWatch resources
├── outputs.tf                      ← Output values
│
├── makefile                        ← Automation commands
│
└── scripts/                        ← Verification scripts
    ├── verify-eks-health.sh
    ├── Verify-EKSHealth.ps1
    ├── verify-rds-connectivity.sh
    └── Verify-RDSConnectivity.ps1
```

---

## 🎓 Learning Path

### If you're new to AWS EKS

1. **Before deployment:**
   - Read [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
   - Understand [Kubernetes basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)
   - Review [VPC networking concepts](https://docs.aws.amazon.com/vpc/latest/userguide/)

2. **During deployment:**
   - Follow [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) carefully
   - Read explanations for each step
   - Don't skip verification steps

3. **After deployment:**
   - Explore deployed resources in AWS Console
   - Practice kubectl commands
   - Review CloudWatch logs

### If you're new to Terraform

1. **Before deployment:**
   - Complete [Terraform Getting Started](https://learn.hashicorp.com/terraform)
   - Understand state management
   - Learn about workspaces

2. **During deployment:**
   - Review each `.tf` file to understand resources
   - Examine the plan output before applying
   - Understand the backend configuration

3. **After deployment:**
   - Explore Terraform state: `terraform state list`
   - Review outputs: `terraform output`
   - Practice making small changes

---

## 🆘 Getting Help

### Documentation

1. Check the relevant guide:
   - Deployment issues → [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#troubleshooting)
   - Verification issues → [VERIFICATION.md](./VERIFICATION.md#troubleshooting)
   - Quick fixes → [QUICK_START.md](./QUICK_START.md#troubleshooting-quick-fixes)

2. Review AWS documentation:
   - [AWS EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
   - [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Common Issues

| Issue | Quick Fix | Full Guide |
|-------|-----------|------------|
| SSO expired | `aws sso login --profile aws-evershop-dev` | [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#issue-1-aws-sso-session-expired) |
| kubectl not working | `aws eks update-kubeconfig ...` | [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#issue-5-kubectl-cannot-connect) |
| State conflicts | Ensure sequential `terraform apply` | [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#issue-2-terraform-state-conflicts) |

### Debug Mode

Enable detailed logging:

```bash
# Terraform debug
export TF_LOG=DEBUG
terraform apply -var-file="dev.hcl"

# AWS CLI debug
aws eks describe-cluster --name evershop-cluster --debug

# kubectl verbose
kubectl get pods -v=8
```

---

## ✅ Success Criteria

Your deployment is successful when:

- [ ] EKS cluster status is `ACTIVE`
- [ ] All nodes are in `Ready` state
- [ ] All system pods are `Running`
- [ ] RDS instance status is `available`
- [ ] ALB is `active` and responding
- [ ] kubectl can connect to cluster
- [ ] Ingress resources have hostnames assigned

Run verification:
```bash
./scripts/verify-eks-health.sh dev
```

---

## 🎯 Next Steps After Deployment

1. **Application Deployment**
   - Build Docker images for EverShop
   - Push images to ECR
   - Deploy application to EKS
   - Configure environment variables

2. **Monitoring Setup**
   - Configure CloudWatch dashboards
   - Set up alerts and notifications
   - Enable Container Insights
   - Configure log aggregation

3. **Security Hardening**
   - Review security group rules
   - Enable AWS GuardDuty
   - Configure AWS WAF
   - Implement network policies
   - Enable pod security policies

4. **CI/CD Pipeline**
   - Set up GitHub Actions or Jenkins
   - Automate Docker builds
   - Automate deployments
   - Configure automated testing

5. **Backup and DR**
   - Configure RDS automated backups
   - Set up EBS snapshot policies
   - Document disaster recovery procedures
   - Test backup restoration

---

## 📞 Support

For issues or questions:

1. **Check documentation** (this guide and linked guides)
2. **Review Terraform state** (`terraform state list`)
3. **Check AWS Console** for resource status
4. **Review CloudWatch logs** for errors
5. **Consult AWS documentation** for service-specific issues

---

## 🔄 Keeping Up to Date

### Regular Maintenance

- **Weekly:** Review CloudWatch metrics and costs
- **Monthly:** Update Terraform providers and modules
- **Quarterly:** Review and update Kubernetes version
- **Annually:** Review architecture and optimize costs

### Version Updates

```bash
# Update Terraform providers
make tf-u-dev

# Check for EKS version updates
aws eks describe-addon-versions --kubernetes-version 1.28

# Update kubectl
# Follow official Kubernetes documentation
```

---

## 🎉 Ready to Start?

Choose your path and begin:

- **First-time deployer?** → [PRE_DEPLOYMENT_CHECKLIST.md](./PRE_DEPLOYMENT_CHECKLIST.md)
- **Experienced user?** → [QUICK_START.md](./QUICK_START.md)
- **Need architecture details?** → [README.md](./README.md)

---

**Good luck with your deployment!** 🚀

---

**Document Version:** 1.0  
**Last Updated:** March 2026  
**Maintained by:** EverShop Infrastructure Team
