# Pre-Deployment Checklist

Complete this checklist before deploying EverShop to AWS EKS.

## 📋 Prerequisites

### Tools Installation

- [ ] **Terraform** (>= 1.5.0)
  ```bash
  terraform version
  ```
  Expected: `Terraform v1.5.0` or higher

- [ ] **AWS CLI** (>= 2.0)
  ```bash
  aws --version
  ```
  Expected: `aws-cli/2.x.x` or higher

- [ ] **kubectl** (>= 1.28)
  ```bash
  kubectl version --client
  ```
  Expected: `Client Version: v1.28.x` or higher

- [ ] **make** (any version)
  ```bash
  make --version
  ```
  Expected: `GNU Make` or compatible

- [ ] **Git Bash** (Windows only)
  - Required for running bash scripts on Windows
  - Included with Git for Windows

---

## 🔐 AWS Access

### Account Information

- [ ] AWS Account ID for dev environment: `___________________`
- [ ] AWS SSO start URL: `___________________`
- [ ] IAM role/permissions verified: `AWSAdministratorAccess` or equivalent

### SSO Configuration

- [ ] AWS SSO profile configured in `~/.aws/config`
  ```ini
  [profile aws-evershop-dev]
  sso_start_url = https://d-906760bf16.awsapps.com/start/#
  sso_region = us-east-1
  sso_account_id = <YOUR_ACCOUNT_ID>
  sso_role_name = AWSAdministratorAccess
  region = us-east-1
  output = json
  ```

- [ ] SSO login successful
  ```bash
  aws sso login --profile aws-evershop-dev
  ```

- [ ] Identity verified
  ```bash
  aws sts get-caller-identity --profile aws-evershop-dev
  ```

---

## 🗄️ Backend Resources

### S3 State Bucket

- [ ] S3 bucket created: `evershop-terraform-state`
  ```bash
  aws s3 ls | grep evershop-terraform-state
  ```

- [ ] Versioning enabled
  ```bash
  aws s3api get-bucket-versioning --bucket evershop-terraform-state --profile aws-evershop-dev
  ```
  Expected: `"Status": "Enabled"`

- [ ] Encryption enabled
  ```bash
  aws s3api get-bucket-encryption --bucket evershop-terraform-state --profile aws-evershop-dev
  ```
  Expected: `"SSEAlgorithm": "AES256"`

- [ ] Public access blocked
  ```bash
  aws s3api get-public-access-block --bucket evershop-terraform-state --profile aws-evershop-dev
  ```
  Expected: All values `true`

### DynamoDB Lock Table

- [ ] DynamoDB table created: `evershop-terraform-locks`
  ```bash
  aws dynamodb describe-table --table-name evershop-terraform-locks --profile aws-evershop-dev --query 'Table.TableStatus'
  ```
  Expected: `"ACTIVE"`

- [ ] Billing mode: `PAY_PER_REQUEST`
  ```bash
  aws dynamodb describe-table --table-name evershop-terraform-locks --profile aws-evershop-dev --query 'Table.BillingModeSummary.BillingMode'
  ```

---

## 📁 Project Files

### Configuration Files

- [ ] `dev.hcl` exists and is configured
  ```bash
  ls -la infra-evershop/eks-deployment/dev.hcl
  ```

- [ ] `providers.tf` backend configuration matches your setup
  - Bucket: `evershop-terraform-state`
  - Key: `eks-deployment/terraform.tfstate`
  - Region: `us-east-1`
  - DynamoDB table: `evershop-terraform-locks`

- [ ] `variables.tf` reviewed and understood

- [ ] `makefile` exists and is executable

### Directory Structure

- [ ] Working directory is correct
  ```bash
  pwd
  # Expected: .../evershop/infra-evershop/eks-deployment
  ```

- [ ] All Terraform files present
  ```bash
  ls -la *.tf
  # Expected: providers.tf, variables.tf, data.tf, vpc.tf, eks.tf, rds.tf, etc.
  ```

---

## 💰 Cost Awareness

### Estimated Monthly Costs (Dev)

- [ ] Reviewed cost estimates:
  - EKS Control Plane: ~$73/month
  - EC2 Instances (2x t3.medium): ~$60/month
  - NAT Gateway: ~$32/month
  - RDS (db.t3.micro): ~$15/month
  - ALB: ~$23/month
  - Data Transfer: ~$10-50/month
  - **Total: ~$213-253/month**

- [ ] Budget approved for ongoing costs

- [ ] Cost alerts configured (optional but recommended)

---

## 🔒 Security Review

### Network Security

- [ ] VPC CIDR reviewed: `10.0.0.0/16`
- [ ] Subnet allocation understood (3 public, 3 private, 3 database)
- [ ] Security group rules reviewed in `security_groups.tf`

### Access Control

- [ ] EKS endpoint access configuration reviewed:
  - Public access: `true` (for dev)
  - Private access: `true`

- [ ] IAM roles and policies reviewed in `iam.tf`

- [ ] RDS password will be auto-generated and stored in Secrets Manager

### Compliance

- [ ] Deployment complies with organizational policies
- [ ] No sensitive data in configuration files
- [ ] Tags configured for cost tracking and compliance

---

## 📊 Resource Quotas

### AWS Service Limits

- [ ] VPC quota sufficient (default: 5 per region)
  ```bash
  aws service-quotas get-service-quota --service-code vpc --quota-code L-F678F1CE --profile aws-evershop-dev
  ```

- [ ] EKS cluster quota sufficient (default: 100 per region)
  ```bash
  aws service-quotas get-service-quota --service-code eks --quota-code L-1194D53C --profile aws-evershop-dev
  ```

- [ ] Elastic IP quota sufficient (need 1 for NAT Gateway)
  ```bash
  aws service-quotas get-service-quota --service-code ec2 --quota-code L-0263D0A3 --profile aws-evershop-dev
  ```

- [ ] RDS instance quota sufficient
  ```bash
  aws service-quotas get-service-quota --service-code rds --quota-code L-7B6409FD --profile aws-evershop-dev
  ```

---

## 🧪 Pre-Deployment Tests

### Terraform Validation

- [ ] Terraform initialized successfully
  ```bash
  cd infra-evershop/eks-deployment
  terraform init
  ```

- [ ] Terraform validation passed
  ```bash
  terraform validate
  ```
  Expected: `Success! The configuration is valid.`

- [ ] Terraform formatting checked
  ```bash
  terraform fmt -check -recursive
  ```

- [ ] Workspace created/selected
  ```bash
  terraform workspace select dev || terraform workspace new dev
  ```

### Plan Review

- [ ] Terraform plan generated successfully
  ```bash
  terraform plan -var-file="dev.hcl" -out=dev.tfplan
  ```

- [ ] Plan reviewed for expected resources (~60+ resources)

- [ ] No unexpected deletions or replacements

- [ ] Resource names follow naming convention

---

## 📝 Documentation Review

### Required Reading

- [ ] [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) reviewed
- [ ] [README.md](./README.md) architecture understood
- [ ] [VERIFICATION.md](./VERIFICATION.md) verification steps understood

### Runbooks Prepared

- [ ] Deployment runbook ready
- [ ] Rollback plan documented
- [ ] Troubleshooting guide accessible

---

## 👥 Team Communication

### Notifications

- [ ] Team notified of deployment schedule
- [ ] Stakeholders informed of potential downtime (if applicable)
- [ ] On-call engineer identified

### Change Management

- [ ] Change request submitted (if required)
- [ ] Approval obtained (if required)
- [ ] Deployment window scheduled

---

## 🚀 Deployment Readiness

### Final Checks

- [ ] All checklist items above completed
- [ ] Deployment time allocated (~30 minutes)
- [ ] Backup plan prepared
- [ ] Monitoring tools ready
- [ ] Support contacts available

### Environment Variables

- [ ] `AWS_PROFILE` set (optional)
  ```bash
  export AWS_PROFILE=aws-evershop-dev
  ```

- [ ] `TF_LOG` set for debugging (optional)
  ```bash
  export TF_LOG=INFO
  ```

---

## ✅ Ready to Deploy

Once all items are checked:

```bash
# Navigate to deployment directory
cd infra-evershop/eks-deployment

# Deploy using makefile
make tf-dev
terraform apply -var-file="dev.hcl"

# Or deploy directly
aws sso login --profile aws-evershop-dev
terraform init
terraform workspace select dev || terraform workspace new dev
terraform apply -var-file="dev.hcl"
```

---

## 📞 Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| AWS Administrator | _____________ | _____________ |
| DevOps Lead | _____________ | _____________ |
| On-Call Engineer | _____________ | _____________ |
| Project Manager | _____________ | _____________ |

---

## 🔄 Post-Deployment

After successful deployment, complete:

- [ ] [Post-Deployment Configuration](./DEPLOYMENT_GUIDE.md#post-deployment-configuration)
- [ ] [Verification Steps](./VERIFICATION.md)
- [ ] Update documentation with actual values
- [ ] Share deployment outputs with team
- [ ] Schedule post-deployment review

---

**Checklist Version:** 1.0  
**Last Updated:** March 2026  
**Estimated Completion Time:** 30-45 minutes (excluding deployment)

---

## Notes

Use this space for deployment-specific notes:

```
Date: _______________
Deployed by: _______________
Notes:




```
