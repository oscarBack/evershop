# EKS Cluster Health Verification Guide

This document provides comprehensive instructions for verifying the health and operational status of the EverShop EKS cluster.

## Prerequisites

Before running the verification, ensure you have the following tools installed:

1. **AWS CLI** (v2.x or later)
   - Download: https://aws.amazon.com/cli/
   - Verify: `aws --version`

2. **kubectl** (v1.28 or later)
   - Download: https://kubernetes.io/docs/tasks/tools/
   - Verify: `kubectl version --client`

3. **AWS SSO Configuration**
   - Profile configured: `aws-evershop-{environment}`
   - SSO login: `aws sso login --profile aws-evershop-dev`

## Automated Verification

### Using PowerShell (Windows)

```powershell
# Navigate to the scripts directory
cd infra-evershop/eks-deployment/scripts

# Run the verification script for dev environment
.\Verify-EKSHealth.ps1 -Environment dev

# Run for other environments
.\Verify-EKSHealth.ps1 -Environment qa
.\Verify-EKSHealth.ps1 -Environment prod
```

### Using Bash (Linux/Mac)

```bash
# Navigate to the scripts directory
cd infra-evershop/eks-deployment/scripts

# Make the script executable
chmod +x verify-eks-health.sh

# Run the verification script for dev environment
./verify-eks-health.sh dev

# Run for other environments
./verify-eks-health.sh qa
./verify-eks-health.sh prod
```

## Manual Verification Steps

If you prefer to run verification steps manually or need to troubleshoot specific issues, follow these steps:

### 1. AWS Authentication

```bash
# Login to AWS SSO
aws sso login --profile aws-evershop-dev

# Verify credentials
aws sts get-caller-identity --profile aws-evershop-dev
```

**Expected Output:**
```json
{
    "UserId": "AROAXXXXXXXXXXXXXXXXX:user@example.com",
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/AWSAdministratorAccess/user@example.com"
}
```

### 2. EKS Cluster Status

```bash
# Check cluster status
aws eks describe-cluster \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'cluster.{Status:status,Version:version,Endpoint:endpoint}' \
  --output table
```

**Expected Output:**
- Status: `ACTIVE`
- Version: `1.28` or later
- Endpoint: `https://XXXXXXXXXX.gr7.us-east-1.eks.amazonaws.com`

### 3. Control Plane Health

```bash
# Check control plane logging configuration
aws eks describe-cluster \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'cluster.logging.clusterLogging[?enabled==`true`].types[]' \
  --output table
```

**Expected Output:**
All five log types should be enabled:
- `api`
- `audit`
- `authenticator`
- `controllerManager`
- `scheduler`

### 4. OIDC Provider Configuration

```bash
# Get OIDC issuer URL
aws eks describe-cluster \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'cluster.identity.oidc.issuer' \
  --output text
```

**Expected Output:**
```
https://oidc.eks.us-east-1.amazonaws.com/id/XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### 5. Node Group Status

```bash
# List node groups
aws eks list-nodegroups \
  --cluster-name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --output table

# Describe node group
aws eks describe-nodegroup \
  --cluster-name evershop-cluster \
  --nodegroup-name evershop-ng \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'nodegroup.{Status:status,DesiredSize:scalingConfig.desiredSize,MinSize:scalingConfig.minSize,MaxSize:scalingConfig.maxSize,InstanceTypes:instanceTypes,Health:health.issues}' \
  --output table
```

**Expected Output (Dev Environment):**
- Status: `ACTIVE`
- DesiredSize: `2`
- MinSize: `2`
- MaxSize: `4`
- InstanceTypes: `['t3.medium']`
- Health: `[]` (no issues)

### 6. Update kubeconfig

```bash
# Update kubeconfig to connect to the cluster
aws eks update-kubeconfig \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev
```

**Expected Output:**
```
Added new context arn:aws:eks:us-east-1:123456789012:cluster/evershop-cluster to /home/user/.kube/config
```

### 7. Node Readiness

```bash
# Check node status
kubectl get nodes

# Get detailed node information
kubectl get nodes -o wide

# Check node conditions
kubectl describe nodes
```

**Expected Output:**
```
NAME                          STATUS   ROLES    AGE   VERSION
ip-10-0-1-100.ec2.internal    Ready    <none>   1d    v1.28.x
ip-10-0-2-100.ec2.internal    Ready    <none>   1d    v1.28.x
```

All nodes should have:
- STATUS: `Ready`
- No critical conditions (MemoryPressure, DiskPressure, PIDPressure should be False)

### 8. Core Kubernetes Components

```bash
# Check kube-system pods
kubectl get pods -n kube-system

# Check specific components
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl get pods -n kube-system -l k8s-app=aws-node
```

**Expected Output:**
All pods should be in `Running` state with `READY` showing all containers ready (e.g., `1/1`, `2/2`).

Critical components:
- **CoreDNS**: 2+ pods running (DNS resolution)
- **kube-proxy**: 1 pod per node (network proxy)
- **aws-node**: 1 pod per node (VPC CNI for pod networking)

### 9. Cluster Connectivity Test

```bash
# Get cluster info
kubectl cluster-info

# Test API server connectivity
kubectl get --raw /healthz

# Check cluster version
kubectl version
```

**Expected Output:**
```
Kubernetes control plane is running at https://XXXXXXXXXX.gr7.us-east-1.eks.amazonaws.com
CoreDNS is running at https://XXXXXXXXXX.gr7.us-east-1.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### 10. Cluster Add-ons

```bash
# List managed add-ons
aws eks list-addons \
  --cluster-name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --output table

# Describe specific add-on (if any)
aws eks describe-addon \
  --cluster-name evershop-cluster \
  --addon-name vpc-cni \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'addon.{Name:addonName,Version:addonVersion,Status:status}' \
  --output table
```

**Expected Output:**
Common add-ons should be in `ACTIVE` status:
- `vpc-cni`
- `kube-proxy`
- `coredns`

### 11. Encryption Configuration

```bash
# Check encryption configuration
aws eks describe-cluster \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'cluster.encryptionConfig' \
  --output table
```

**Expected Output:**
```
Resources: ['secrets']
Provider.KeyArn: arn:aws:kms:us-east-1:123456789012:key/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

### 12. Endpoint Access Configuration

```bash
# Check endpoint access
aws eks describe-cluster \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'cluster.resourcesVpcConfig.{PublicAccess:endpointPublicAccess,PrivateAccess:endpointPrivateAccess}' \
  --output table
```

**Expected Output (by Environment):**

| Environment | Public Access | Private Access |
|-------------|---------------|----------------|
| Dev         | true          | true           |
| QA          | true          | true           |
| Prod        | false         | true           |

## Verification Checklist

Use this checklist to ensure all aspects of the cluster are verified:

### Cluster Level
- [ ] Cluster status is `ACTIVE`
- [ ] Kubernetes version is 1.28 or later
- [ ] Control plane logging enabled for all 5 log types
- [ ] OIDC provider configured and exists in IAM
- [ ] Endpoint access configured per environment requirements
- [ ] KMS encryption enabled for secrets

### Node Groups
- [ ] Node group status is `ACTIVE`
- [ ] Node group has no health issues
- [ ] Scaling configuration matches environment requirements
- [ ] Instance types match environment configuration

### Nodes
- [ ] All nodes are in `Ready` state
- [ ] No nodes have MemoryPressure, DiskPressure, or PIDPressure
- [ ] Node count matches desired capacity
- [ ] Nodes are distributed across availability zones

### Core Components
- [ ] CoreDNS pods are running (2+ replicas)
- [ ] kube-proxy pods are running (1 per node)
- [ ] aws-node (VPC CNI) pods are running (1 per node)
- [ ] All system pods in kube-system namespace are healthy

### Connectivity
- [ ] kubectl can connect to the cluster
- [ ] API server health check passes
- [ ] kubeconfig is properly configured

### Add-ons
- [ ] All managed add-ons are in `ACTIVE` status
- [ ] Add-on versions are compatible with cluster version

## Troubleshooting

### Issue: AWS CLI not found

**Solution:**
```bash
# Install AWS CLI v2
# Windows: Download from https://awscli.amazonaws.com/AWSCLIV2.msi
# Mac: brew install awscli
# Linux: 
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Issue: kubectl not found

**Solution:**
```bash
# Windows (using Chocolatey)
choco install kubernetes-cli

# Mac
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Issue: AWS credentials expired

**Solution:**
```bash
# Re-login to AWS SSO
aws sso login --profile aws-evershop-dev
```

### Issue: Cluster not found

**Possible Causes:**
1. Cluster not yet deployed
2. Wrong region specified
3. Wrong AWS profile/account

**Solution:**
```bash
# Verify you're in the correct account
aws sts get-caller-identity --profile aws-evershop-dev

# List all EKS clusters in the region
aws eks list-clusters --region us-east-1 --profile aws-evershop-dev
```

### Issue: Nodes not ready

**Possible Causes:**
1. Node group still scaling up
2. Network connectivity issues
3. IAM role issues

**Solution:**
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name evershop-cluster \
  --nodegroup-name evershop-ng \
  --region us-east-1 \
  --profile aws-evershop-dev

# Check node events
kubectl describe nodes

# Check kubelet logs (requires SSH access to nodes)
# Or check CloudWatch Logs for node logs
```

### Issue: System pods not running

**Possible Causes:**
1. Insufficient resources
2. Image pull errors
3. Network issues

**Solution:**
```bash
# Check pod status and events
kubectl describe pod <pod-name> -n kube-system

# Check pod logs
kubectl logs <pod-name> -n kube-system

# Check node resources
kubectl top nodes
```

### Issue: kubectl cannot connect

**Possible Causes:**
1. kubeconfig not updated
2. Network connectivity issues
3. Security group rules blocking access

**Solution:**
```bash
# Update kubeconfig
aws eks update-kubeconfig \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev

# Test connectivity
kubectl get --raw /healthz

# Check security group rules for cluster endpoint
aws eks describe-cluster \
  --name evershop-cluster \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'cluster.resourcesVpcConfig.{SecurityGroups:securityGroupIds,PublicAccess:endpointPublicAccess}'
```

## Expected Results by Environment

### Dev Environment

| Metric | Expected Value |
|--------|----------------|
| Cluster Status | ACTIVE |
| Kubernetes Version | 1.28+ |
| Node Count | 2 |
| Node Type | t3.medium |
| Endpoint Access | Public + Private |
| Multi-AZ | Yes (nodes across AZs) |
| Control Plane Logs | All 5 types enabled |

### QA Environment

| Metric | Expected Value |
|--------|----------------|
| Cluster Status | ACTIVE |
| Kubernetes Version | 1.28+ |
| Node Count | 3 |
| Node Type | t3.large |
| Endpoint Access | Public + Private |
| Multi-AZ | Yes (nodes across AZs) |
| Control Plane Logs | All 5 types enabled |

### Prod Environment

| Metric | Expected Value |
|--------|----------------|
| Cluster Status | ACTIVE |
| Kubernetes Version | 1.28+ |
| Node Count | 5 |
| Node Type | m5.xlarge |
| Endpoint Access | Private only |
| Multi-AZ | Yes (nodes across AZs) |
| Control Plane Logs | All 5 types enabled |

## RDS Connectivity Verification

### Automated Verification

#### Using PowerShell (Windows)

```powershell
# Navigate to the scripts directory
cd infra-evershop/eks-deployment/scripts

# Run the RDS connectivity verification script for dev environment
.\Verify-RDSConnectivity.ps1 -Environment dev

# Run for other environments
.\Verify-RDSConnectivity.ps1 -Environment qa
.\Verify-RDSConnectivity.ps1 -Environment prod
```

#### Using Bash (Linux/Mac)

```bash
# Navigate to the scripts directory
cd infra-evershop/eks-deployment/scripts

# Make the script executable
chmod +x verify-rds-connectivity.sh

# Run the verification script for dev environment
./verify-rds-connectivity.sh dev

# Run for other environments
./verify-rds-connectivity.sh qa
./verify-rds-connectivity.sh prod
```

### What the Script Does

The RDS connectivity verification script performs the following tests:

1. **Prerequisites Check**: Verifies AWS CLI, kubectl, and other required tools are installed
2. **AWS Authentication**: Logs in to AWS SSO and verifies credentials
3. **Kubeconfig Update**: Updates kubeconfig to connect to the EKS cluster
4. **RDS Details Retrieval**: Gets RDS endpoint from Terraform outputs or AWS API
5. **Secrets Retrieval**: Retrieves RDS password from AWS Secrets Manager
6. **Kubernetes Secret Creation**: Creates a secret with RDS credentials in the cluster
7. **Test Pod Deployment**: Deploys a PostgreSQL client pod in the cluster
8. **Connectivity Tests**:
   - TCP connection test to RDS endpoint on port 5432
   - PostgreSQL authentication test
   - Database operations test (CREATE/INSERT/SELECT/DROP)
   - Concurrent connections test
9. **Security Group Verification**: Checks security group rules for RDS
10. **Report Generation**: Creates a verification report with test results
11. **Cleanup**: Optionally removes test resources

### Manual RDS Connectivity Verification

If you prefer to verify RDS connectivity manually:

#### Step 1: Get RDS Connection Details

```bash
# Get RDS endpoint from Terraform
cd infra-evershop/eks-deployment
terraform output rds_endpoint

# Or get from AWS CLI
aws rds describe-db-instances \
  --db-instance-identifier evershop-dev \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

#### Step 2: Get RDS Password

```bash
# Retrieve password from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id evershop/dev/rds-password \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'SecretString' \
  --output text
```

#### Step 3: Create Kubernetes Secret

```bash
# Create secret with RDS credentials
kubectl create secret generic rds-credentials \
  --from-literal=password="YOUR_PASSWORD_HERE" \
  --from-literal=endpoint="YOUR_RDS_ENDPOINT_HERE" \
  --from-literal=database="evershop" \
  --from-literal=username="evershop_admin"
```

#### Step 4: Deploy Test Pod

```bash
# Apply the test pod manifest
kubectl apply -f scripts/rds-test-pod.yaml

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/rds-connectivity-test --timeout=120s
```

#### Step 5: Test Connectivity

```bash
# Test 1: TCP connection
kubectl exec rds-connectivity-test -- nc -zv YOUR_RDS_ENDPOINT 5432

# Test 2: PostgreSQL connection
kubectl exec rds-connectivity-test -- psql -h YOUR_RDS_ENDPOINT -U evershop_admin -d evershop -c 'SELECT version();'

# Test 3: Database operations
kubectl exec rds-connectivity-test -- psql -h YOUR_RDS_ENDPOINT -U evershop_admin -d evershop <<EOF
CREATE TABLE connectivity_test (id SERIAL PRIMARY KEY, test_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
INSERT INTO connectivity_test VALUES (DEFAULT);
SELECT * FROM connectivity_test;
DROP TABLE connectivity_test;
EOF
```

#### Step 6: Verify Security Groups

```bash
# Get RDS security group
RDS_SG=$(aws rds describe-db-instances \
  --db-instance-identifier evershop-dev \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids $RDS_SG \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432`]' \
  --output table
```

**Expected Output:**
- Source security group should be the EKS node security group
- Port should be 5432 (PostgreSQL)
- Protocol should be TCP

#### Step 7: Cleanup

```bash
# Delete test pod
kubectl delete pod rds-connectivity-test

# Delete secret
kubectl delete secret rds-credentials
```

### Troubleshooting RDS Connectivity

#### Issue: Cannot connect to RDS from pod

**Possible Causes:**
1. Security group rules not configured correctly
2. RDS instance not in the same VPC as EKS
3. Network ACLs blocking traffic
4. RDS instance not available

**Solution:**
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier evershop-dev \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].{Status:DBInstanceStatus,Endpoint:Endpoint.Address,VPC:DBSubnetGroup.VpcId}'

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids $RDS_SG \
  --region us-east-1 \
  --profile aws-evershop-dev

# Verify EKS nodes are in the same VPC
kubectl get nodes -o wide
```

#### Issue: Authentication failed

**Possible Causes:**
1. Incorrect password
2. Password not retrieved from Secrets Manager
3. Username incorrect

**Solution:**
```bash
# Verify secret exists
aws secretsmanager describe-secret \
  --secret-id evershop/dev/rds-password \
  --region us-east-1 \
  --profile aws-evershop-dev

# Check RDS master username
aws rds describe-db-instances \
  --db-instance-identifier evershop-dev \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].MasterUsername' \
  --output text
```

#### Issue: Test pod fails to start

**Possible Causes:**
1. Image pull errors
2. Insufficient resources
3. Secret not found

**Solution:**
```bash
# Check pod status
kubectl describe pod rds-connectivity-test

# Check pod logs
kubectl logs rds-connectivity-test

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Expected Results

After successful RDS connectivity verification:

| Test | Expected Result |
|------|----------------|
| TCP Connection | Connection successful to RDS endpoint on port 5432 |
| PostgreSQL Authentication | Successfully authenticated with evershop_admin user |
| Database Operations | CREATE, INSERT, SELECT, DROP operations successful |
| Concurrent Connections | Multiple simultaneous connections successful |
| Security Group Rules | PostgreSQL (5432) ingress from EKS node security group only |

## Ingress Routing Verification

### Automated Verification

#### Using PowerShell (Windows)

```powershell
# Navigate to the scripts directory
cd infra-evershop/eks-deployment/scripts

# Run the Ingress routing verification script for dev environment
.\Verify-IngressRouting.ps1 -Environment dev

# Run for other environments
.\Verify-IngressRouting.ps1 -Environment qa
.\Verify-IngressRouting.ps1 -Environment prod
```

#### Using Bash (Linux/Mac)

```bash
# Navigate to the scripts directory
cd infra-evershop/eks-deployment/scripts

# Make the script executable
chmod +x verify-ingress-routing.sh

# Run the verification script for dev environment
./verify-ingress-routing.sh dev

# Run for other environments
./verify-ingress-routing.sh qa
./verify-ingress-routing.sh prod
```

### What the Script Does

The Ingress routing verification script performs the following checks:

1. **Prerequisites Check**: Verifies AWS CLI, kubectl, and other required tools are installed
2. **AWS Authentication**: Logs in to AWS SSO and verifies credentials
3. **Kubeconfig Update**: Updates kubeconfig to connect to the EKS cluster
4. **AWS Load Balancer Controller Verification**: Checks deployment status, replicas, and IRSA configuration
5. **Ingress Resources Verification**: Verifies GraphQL API and Frontend Ingress resources exist
6. **ALB Creation**: Checks that Application Load Balancers have been provisioned
7. **Target Groups**: Verifies target groups and health checks
8. **Listeners**: Checks HTTP/HTTPS listeners and redirect configuration
9. **Routing Rules**: Verifies path-based and host-based routing rules
10. **HTTP Endpoint Testing**: Tests connectivity to ALB endpoints
11. **DNS Resolution**: Verifies custom domain DNS configuration (qa/prod only)
12. **Report Generation**: Creates a verification report with test results

### Manual Ingress Routing Verification

If you prefer to verify Ingress routing manually:

#### Step 1: Verify AWS Load Balancer Controller

```bash
# Check if AWS Load Balancer Controller is deployed
kubectl get deployment aws-load-balancer-controller -n kube-system

# Check controller pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=50
```

**Expected Output:**
- Deployment should show READY status (e.g., 2/2)
- Pods should be in Running state
- No error messages in logs

#### Step 2: Verify Ingress Resources

```bash
# List Ingress resources in evershop namespace
kubectl get ingress -n evershop

# Describe GraphQL API Ingress
kubectl describe ingress evershop-graphql-api-ingress -n evershop

# Describe Frontend Ingress
kubectl describe ingress evershop-frontend-ingress -n evershop
```

**Expected Output:**
- Both Ingress resources should exist
- Each should have an ADDRESS field with ALB DNS name
- Annotations should include ALB-specific configuration

#### Step 3: Verify ALB Creation

```bash
# Get ALB DNS names from Ingress
kubectl get ingress -n evershop -o wide

# List ALBs in AWS
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-evershop')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
  --output table
```

**Expected Output:**
- ALB DNS names should be visible in Ingress status
- ALBs should be in "active" state
- DNS names should match between kubectl and AWS CLI

#### Step 4: Verify Target Groups

```bash
# List target groups
aws elbv2 describe-target-groups \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query "TargetGroups[?contains(TargetGroupName, 'k8s')].{Name:TargetGroupName,Port:Port,Protocol:Protocol,HealthCheckPath:HealthCheckPath}" \
  --output table

# Check target health (replace TG_ARN with actual ARN)
aws elbv2 describe-target-health \
  --target-group-arn TG_ARN \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query "TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State}" \
  --output table
```

**Expected Output:**
- Target groups should exist for GraphQL API (port 4000) and Frontend (port 3000)
- Health check paths should be configured
- Targets should be in "healthy" state (if backend services are deployed)

#### Step 5: Verify Listeners

```bash
# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-evershop')].LoadBalancerArn" \
  --output text | head -1)

# List listeners
aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query "Listeners[].{Port:Port,Protocol:Protocol,DefaultAction:DefaultActions[0].Type}" \
  --output table
```

**Expected Output (Dev Environment):**
- HTTP listener on port 80
- No HTTPS listener (dev uses HTTP only)

**Expected Output (QA/Prod Environments):**
- HTTP listener on port 80 with redirect action
- HTTPS listener on port 443 with forward action

#### Step 6: Test HTTP Endpoints

```bash
# Get ALB DNS name
GRAPHQL_ALB=$(kubectl get ingress -n evershop -o jsonpath='{.items[?(@.metadata.name=="evershop-graphql-api-ingress")].status.loadBalancer.ingress[0].hostname}')
FRONTEND_ALB=$(kubectl get ingress -n evershop -o jsonpath='{.items[?(@.metadata.name=="evershop-frontend-ingress")].status.loadBalancer.ingress[0].hostname}')

# Test GraphQL API endpoint (dev)
curl -I http://$GRAPHQL_ALB/api

# Test Frontend endpoint (dev)
curl -I http://$FRONTEND_ALB/

# For qa/prod, test HTTPS redirect
curl -I http://$GRAPHQL_ALB/
```

**Expected Output:**
- Dev: HTTP 200, 404, or 503 (depending on backend deployment status)
- QA/Prod: HTTP 301/302 redirect to HTTPS

#### Step 7: Verify Routing Rules

```bash
# Check GraphQL API routing
kubectl get ingress evershop-graphql-api-ingress -n evershop -o yaml | grep -A 10 "rules:"

# Check Frontend routing
kubectl get ingress evershop-frontend-ingress -n evershop -o yaml | grep -A 10 "rules:"
```

**Expected Output (Dev):**
- GraphQL API: Path `/api` routes to `graphql-api` service on port 4000
- Frontend: Path `/` routes to `react-frontend` service on port 3000
- No host-based routing (uses ALB DNS directly)

**Expected Output (QA/Prod):**
- GraphQL API: Host `api.{domain}` routes to `graphql-api` service
- Frontend: Host `shop.{domain}` routes to `react-frontend` service
- Custom domain configured with ACM certificate

#### Step 8: Verify DNS Resolution (QA/Prod Only)

```bash
# Check DNS for GraphQL API
nslookup api.evershop.example.com

# Check DNS for Frontend
nslookup shop.evershop.example.com

# Verify DNS points to ALB
dig api.evershop.example.com +short
```

**Expected Output:**
- DNS should resolve to ALB DNS name
- CNAME record should point to ALB

### Troubleshooting Ingress Routing

#### Issue: AWS Load Balancer Controller not deployed

**Possible Causes:**
1. Controller not installed
2. IRSA role not configured
3. Controller pods failing

**Solution:**
```bash
# Check if controller exists
kubectl get deployment aws-load-balancer-controller -n kube-system

# Check pod status
kubectl describe pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --tail=100

# Verify IRSA role
kubectl get serviceaccount aws-load-balancer-controller -n kube-system -o yaml | grep eks.amazonaws.com/role-arn
```

#### Issue: Ingress resources not creating ALB

**Possible Causes:**
1. Incorrect Ingress annotations
2. Controller not watching the namespace
3. IAM permissions missing
4. Subnet tags missing

**Solution:**
```bash
# Check Ingress annotations
kubectl get ingress -n evershop -o yaml | grep -A 5 "annotations:"

# Check controller logs for errors
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller | grep -i error

# Verify subnet tags
aws ec2 describe-subnets \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --filters "Name=vpc-id,Values=VPC_ID" \
  --query "Subnets[].Tags[?Key=='kubernetes.io/role/elb']"
```

#### Issue: ALB created but targets unhealthy

**Possible Causes:**
1. Backend services not deployed
2. Security group rules blocking traffic
3. Health check path incorrect
4. Pods not ready

**Solution:**
```bash
# Check if backend services exist
kubectl get service -n evershop

# Check if pods are running
kubectl get pods -n evershop

# Check security group rules
aws ec2 describe-security-groups \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --filters "Name=tag:kubernetes.io/cluster/evershop-cluster,Values=owned"

# Check target health details
aws elbv2 describe-target-health \
  --target-group-arn TG_ARN \
  --region us-east-1 \
  --profile aws-evershop-dev
```

#### Issue: HTTP requests timing out

**Possible Causes:**
1. ALB still provisioning
2. Security group rules blocking traffic
3. Network ACLs blocking traffic
4. Backend services not responding

**Solution:**
```bash
# Check ALB state
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-evershop')].State"

# Wait for ALB to be active (can take 2-3 minutes)
# Then test again

# Check security group rules allow HTTP/HTTPS
aws ec2 describe-security-groups \
  --group-ids ALB_SG_ID \
  --region us-east-1 \
  --profile aws-evershop-dev
```

#### Issue: HTTPS redirect not working (QA/Prod)

**Possible Causes:**
1. ACM certificate not attached
2. Redirect annotation missing
3. Listener not configured correctly

**Solution:**
```bash
# Check Ingress annotations for certificate
kubectl get ingress -n evershop -o yaml | grep certificate-arn

# Check listener configuration
aws elbv2 describe-listeners \
  --load-balancer-arn ALB_ARN \
  --region us-east-1 \
  --profile aws-evershop-dev

# Verify redirect action on port 80
aws elbv2 describe-listeners \
  --load-balancer-arn ALB_ARN \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query "Listeners[?Port==\`80\`].DefaultActions"
```

### Expected Results by Environment

#### Dev Environment

| Component | Expected Result |
|-----------|----------------|
| AWS Load Balancer Controller | Deployed and running (2/2 replicas) |
| GraphQL API Ingress | Exists with ALB DNS name |
| Frontend Ingress | Exists with ALB DNS name |
| ALB | Active state, internet-facing |
| Listeners | HTTP (80) only |
| Target Groups | GraphQL API (4000), Frontend (3000) |
| Routing | Path-based: `/api` → GraphQL, `/` → Frontend |
| Domain | Uses ALB DNS directly (no custom domain) |
| SSL/TLS | Not configured (HTTP only) |

#### QA Environment

| Component | Expected Result |
|-----------|----------------|
| AWS Load Balancer Controller | Deployed and running (2/2 replicas) |
| GraphQL API Ingress | Exists with custom domain |
| Frontend Ingress | Exists with custom domain |
| ALB | Active state, internet-facing |
| Listeners | HTTP (80) redirects to HTTPS (443) |
| Target Groups | GraphQL API (4000), Frontend (3000) |
| Routing | Host-based: `api.{domain}` → GraphQL, `shop.{domain}` → Frontend |
| Domain | Custom domain configured |
| SSL/TLS | ACM certificate attached, HTTPS enabled |

#### Prod Environment

| Component | Expected Result |
|-----------|----------------|
| AWS Load Balancer Controller | Deployed and running (2/2 replicas) |
| GraphQL API Ingress | Exists with custom domain |
| Frontend Ingress | Exists with custom domain |
| ALB | Active state, internet-facing |
| Listeners | HTTP (80) redirects to HTTPS (443) |
| Target Groups | GraphQL API (4000), Frontend (3000) |
| Routing | Host-based: `api.{domain}` → GraphQL, `shop.{domain}` → Frontend |
| Domain | Custom domain configured |
| SSL/TLS | ACM certificate attached, HTTPS enabled |

### Verification Checklist

Use this checklist to ensure all aspects of Ingress routing are verified:

#### AWS Load Balancer Controller
- [ ] Controller deployment exists in kube-system namespace
- [ ] Controller pods are running (2/2 replicas)
- [ ] IRSA role is configured on service account
- [ ] Controller logs show no errors
- [ ] Controller version is compatible with EKS version

#### Ingress Resources
- [ ] GraphQL API Ingress exists in evershop namespace
- [ ] Frontend Ingress exists in evershop namespace
- [ ] Ingress resources have ALB DNS names in status
- [ ] Ingress annotations are correct for environment
- [ ] Ingress class is set to "alb"

#### Application Load Balancer
- [ ] ALB is provisioned and in active state
- [ ] ALB is internet-facing
- [ ] ALB DNS name is accessible
- [ ] ALB has correct tags (kubernetes.io/cluster/*)
- [ ] ALB security group allows HTTP/HTTPS traffic

#### Target Groups
- [ ] Target groups exist for GraphQL API and Frontend
- [ ] Target groups have correct ports (4000, 3000)
- [ ] Health check paths are configured
- [ ] Targets are registered (if backend services deployed)
- [ ] Target health is "healthy" (if backend services deployed)

#### Listeners
- [ ] HTTP listener (80) exists
- [ ] HTTPS listener (443) exists (qa/prod only)
- [ ] HTTP redirects to HTTPS (qa/prod only)
- [ ] ACM certificate attached to HTTPS listener (qa/prod only)
- [ ] Default actions are configured correctly

#### Routing Rules
- [ ] Path-based routing configured (dev)
- [ ] Host-based routing configured (qa/prod)
- [ ] GraphQL API routes to correct service and port
- [ ] Frontend routes to correct service and port
- [ ] Routing rules match environment requirements

#### DNS Configuration (QA/Prod Only)
- [ ] Custom domain DNS records exist
- [ ] DNS resolves to ALB DNS name
- [ ] GraphQL API domain (api.{domain}) resolves correctly
- [ ] Frontend domain (shop.{domain}) resolves correctly
- [ ] ACM certificate is valid for domains

#### Connectivity
- [ ] HTTP requests to ALB succeed (or return expected status)
- [ ] HTTPS requests succeed (qa/prod only)
- [ ] HTTP redirects to HTTPS (qa/prod only)
- [ ] Backend services respond (if deployed)
- [ ] No timeout errors

## Next Steps

After successful verification:

1. **Deploy Application Workloads**: Proceed with deploying EverShop GraphQL API and React Frontend
2. **Configure Monitoring**: Set up CloudWatch dashboards and alarms
3. **Configure Autoscaling**: Deploy Cluster Autoscaler or Karpenter
4. **Security Hardening**: Review and apply security best practices
5. **Performance Testing**: Test application performance and scaling

## References

- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Troubleshooting EKS](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [RDS PostgreSQL Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [PostgreSQL Client Documentation](https://www.postgresql.org/docs/current/app-psql.html)
- [AWS Load Balancer Controller Documentation](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
