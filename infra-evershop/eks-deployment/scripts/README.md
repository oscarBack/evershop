# EKS Deployment Scripts

This directory contains scripts for verifying and managing the EverShop EKS deployment.

## Available Scripts

### 1. EKS Health Verification

Scripts to verify the health and operational status of the EKS cluster.

#### verify-eks-health.sh (Linux/Mac)

Bash script for verifying EKS cluster health on Linux and macOS systems.

**Usage:**
```bash
chmod +x verify-eks-health.sh
./verify-eks-health.sh <environment>
```

**Parameters:**
- `environment`: Target environment (dev, qa, or prod)

**Example:**
```bash
./verify-eks-health.sh dev
```

#### Verify-EKSHealth.ps1 (Windows)

PowerShell script for verifying EKS cluster health on Windows systems.

**Usage:**
```powershell
.\Verify-EKSHealth.ps1 -Environment <environment>
```

**Parameters:**
- `-Environment`: Target environment (dev, qa, or prod)

**Example:**
```powershell
.\Verify-EKSHealth.ps1 -Environment dev
```

### What Gets Verified (EKS Health)

Both scripts verify the following aspects of the EKS cluster:

1. **AWS Authentication**
   - AWS SSO login
   - Credential verification

2. **Cluster Status**
   - Cluster state (ACTIVE)
   - Kubernetes version
   - Endpoint configuration

3. **Control Plane**
   - Logging configuration
   - OIDC provider setup

4. **Node Groups**
   - Node group status
   - Scaling configuration
   - Health issues

5. **Nodes**
   - Node readiness
   - Node conditions
   - Resource availability

6. **Core Components**
   - CoreDNS
   - kube-proxy
   - VPC CNI (aws-node)

7. **Cluster Connectivity**
   - kubectl connection
   - API server health

8. **Add-ons**
   - Managed add-on status
   - Add-on versions

### 2. RDS Connectivity Verification

Scripts to verify that EKS pods can successfully connect to the RDS PostgreSQL database.

#### verify-rds-connectivity.sh (Linux/Mac)

Bash script for verifying RDS connectivity from EKS pods on Linux and macOS systems.

**Usage:**
```bash
chmod +x verify-rds-connectivity.sh
./verify-rds-connectivity.sh <environment>
```

**Parameters:**
- `environment`: Target environment (dev, qa, or prod)

**Example:**
```bash
./verify-rds-connectivity.sh dev
```

#### Verify-RDSConnectivity.ps1 (Windows)

PowerShell script for verifying RDS connectivity from EKS pods on Windows systems.

**Usage:**
```powershell
.\Verify-RDSConnectivity.ps1 -Environment <environment>
```

**Parameters:**
- `-Environment`: Target environment (dev, qa, or prod)

**Example:**
```powershell
.\Verify-RDSConnectivity.ps1 -Environment dev
```

### What Gets Verified (RDS Connectivity)

The RDS connectivity scripts perform comprehensive testing:

1. **Prerequisites Check**
   - AWS CLI installation
   - kubectl installation
   - jq installation (optional)

2. **AWS Authentication**
   - AWS SSO login
   - Credential verification

3. **Kubeconfig Update**
   - Update kubeconfig for EKS cluster
   - Verify cluster connectivity

4. **RDS Details Retrieval**
   - Get RDS endpoint from Terraform outputs or AWS API
   - Retrieve RDS password from AWS Secrets Manager

5. **Kubernetes Setup**
   - Create Kubernetes secret with RDS credentials
   - Deploy PostgreSQL client test pod
   - Wait for pod to be ready

6. **Connectivity Tests**
   - **Test 1**: TCP connection to RDS endpoint on port 5432
   - **Test 2**: PostgreSQL authentication
   - **Test 3**: Database operations (CREATE/INSERT/SELECT/DROP)
   - **Test 4**: Concurrent connections (5 simultaneous)

7. **Security Group Verification**
   - Retrieve RDS security group ID
   - Verify ingress rules for port 5432
   - Confirm source is EKS node security group

8. **Report Generation**
   - Create timestamped verification report
   - Include all test results
   - Document security group configuration

9. **Cleanup**
   - Optionally delete test pod
   - Optionally delete Kubernetes secret

### 3. Ingress Routing Verification

Scripts to verify that AWS Load Balancer Controller and Ingress resources are correctly configured and routing traffic.

#### verify-ingress-routing.sh (Linux/Mac)

Bash script for verifying Ingress routing on Linux and macOS systems.

**Usage:**
```bash
chmod +x verify-ingress-routing.sh
./verify-ingress-routing.sh <environment>
```

**Parameters:**
- `environment`: Target environment (dev, qa, or prod)

**Example:**
```bash
./verify-ingress-routing.sh dev
```

#### Verify-IngressRouting.ps1 (Windows)

PowerShell script for verifying Ingress routing on Windows systems.

**Usage:**
```powershell
.\Verify-IngressRouting.ps1 -Environment <environment>
```

**Parameters:**
- `-Environment`: Target environment (dev, qa, or prod)

**Example:**
```powershell
.\Verify-IngressRouting.ps1 -Environment dev
```

### What Gets Verified (Ingress Routing)

The Ingress routing scripts perform comprehensive verification:

1. **Prerequisites Check**
   - AWS CLI installation
   - kubectl installation
   - jq installation (optional)
   - curl installation

2. **AWS Authentication**
   - AWS SSO login
   - Credential verification

3. **Kubeconfig Update**
   - Update kubeconfig for EKS cluster
   - Verify cluster connectivity

4. **AWS Load Balancer Controller**
   - Deployment status and replicas
   - Pod status (Running)
   - Service account configuration
   - IRSA role annotation
   - Controller logs (no errors)

5. **Ingress Resources**
   - GraphQL API Ingress exists
   - Frontend Ingress exists
   - Ingress annotations correct
   - ALB DNS names assigned

6. **ALB Creation**
   - ALB provisioned in AWS
   - ALB state (active)
   - ALB DNS names
   - ALB tags and configuration

7. **Target Groups**
   - Target groups created
   - Correct ports (4000 for GraphQL, 3000 for Frontend)
   - Health check configuration
   - Target health status

8. **Listeners**
   - HTTP listener (80) configured
   - HTTPS listener (443) for qa/prod
   - HTTP to HTTPS redirect for qa/prod
   - ACM certificate attached for qa/prod

9. **Routing Rules**
   - Path-based routing (dev): `/api` → GraphQL, `/` → Frontend
   - Host-based routing (qa/prod): `api.{domain}` → GraphQL, `shop.{domain}` → Frontend
   - Backend service and port configuration

10. **HTTP Endpoint Testing**
    - Test GraphQL API endpoint
    - Test Frontend endpoint
    - Verify HTTP response codes
    - Check for connectivity issues

11. **DNS Resolution (QA/Prod)**
    - Verify custom domain DNS records
    - Check GraphQL API domain (api.{domain})
    - Check Frontend domain (shop.{domain})
    - Confirm DNS points to ALB

12. **Report Generation**
    - Create timestamped verification report
    - Include all test results
    - Document ALB and Ingress configuration

### Environment-Specific Behavior

#### Dev Environment
- HTTP (80) only, no HTTPS
- Path-based routing: `/api` and `/`
- Uses ALB DNS directly (no custom domain)
- No ACM certificate required

#### QA/Prod Environments
- HTTP (80) redirects to HTTPS (443)
- Host-based routing with custom domains
- ACM certificate attached
- Custom domain DNS configuration required

### 4. Supporting Files

#### rds-test-pod.yaml

Kubernetes manifest template for the RDS connectivity test pod. This file is used as a reference and is dynamically generated with actual RDS endpoint during script execution.

**Features:**
- PostgreSQL 15 Alpine image
- Environment variables for RDS connection
- Credentials from Kubernetes secret
- Resource limits and requests
- Sleep command to keep pod running for testing

## Prerequisites

### Required Tools

- **AWS CLI** (v2.x or later)
  - Download: https://aws.amazon.com/cli/
  - Verify: `aws --version`

- **kubectl** (v1.28 or later)
  - Download: https://kubernetes.io/docs/tasks/tools/
  - Verify: `kubectl version --client`

- **jq** (optional, for better JSON parsing)
  - Linux: `sudo apt-get install jq` or `sudo yum install jq`
  - Mac: `brew install jq`
  - Windows: Download from https://stedolan.github.io/jq/

### AWS Configuration

Ensure you have AWS SSO configured for the target environment:

```ini
# ~/.aws/config
[profile aws-evershop-dev]
sso_start_url = https://d-906760bf16.awsapps.com/start/#
sso_region = us-east-1
sso_account_id = {account_id}
sso_role_name = AWSAdministratorAccess
region = us-east-1
output = json
```

## Verification Workflow

### Complete Verification Process

For a complete post-deployment verification, run scripts in this order:

1. **EKS Health Verification**
   ```bash
   ./verify-eks-health.sh dev
   ```
   Ensures the EKS cluster is healthy and operational.

2. **RDS Connectivity Verification**
   ```bash
   ./verify-rds-connectivity.sh dev
   ```
   Verifies that pods can connect to the RDS database.

3. **Ingress Routing Verification**
   ```bash
   ./verify-ingress-routing.sh dev
   ```
   Verifies ALB creation, Ingress routing, and endpoint connectivity.

## Output

The scripts provide colored output for easy reading:

- **Blue [INFO]**: Informational messages
- **Green [SUCCESS]**: Successful operations
- **Yellow [WARNING]**: Warnings (non-critical issues)
- **Red [ERROR]**: Errors (critical issues)

### Sample Output (Ingress Routing)

```
========================================
Ingress Routing Verification for EverShop EKS
========================================

[INFO] Checking AWS Load Balancer Controller deployment...
[SUCCESS] AWS Load Balancer Controller deployment found
[SUCCESS] AWS Load Balancer Controller is ready (2/2 replicas)

[INFO] Checking for Ingress resources in namespace: evershop
[SUCCESS] Namespace evershop exists
[SUCCESS] GraphQL API Ingress found
[SUCCESS] Frontend Ingress found

[INFO] Retrieving ALB DNS names from Ingress resources...
[SUCCESS] GraphQL API ALB: k8s-evershop-graphql-xxx.us-east-1.elb.amazonaws.com
[SUCCESS] Frontend ALB: k8s-evershop-frontend-xxx.us-east-1.elb.amazonaws.com

[INFO] Testing GraphQL API endpoint...
[SUCCESS] GraphQL API endpoint responded with HTTP 200

[SUCCESS] Ingress routing verification completed!
```

## Generated Reports

### Ingress Routing Report

The Ingress verification script generates a timestamped report:

**Filename**: `ingress-routing-verification-{environment}-{timestamp}.txt`

**Contents**:
- Environment details
- AWS Load Balancer Controller status
- Ingress resources configuration
- ALB details and DNS names
- Verification status
- Next steps

**Example**:
```
Ingress Routing Verification Report
====================================

Environment: dev
Cluster: evershop-cluster
Region: us-east-1
Date: 2024-01-15 14:45:30

AWS Load Balancer Controller:
  Status: True
  Replicas: 2/2

Ingress Resources:
NAME                           CLASS   HOSTS   ADDRESS                                    PORTS   AGE
evershop-graphql-api-ingress   alb     *       k8s-evershop-graphql-xxx.elb.amazonaws.com 80      5m
evershop-frontend-ingress      alb     *       k8s-evershop-frontend-xxx.elb.amazonaws.com 80     5m

Application Load Balancers:
NAME                          DNS                                         STATE
k8s-evershop-graphql-xxx      k8s-evershop-graphql-xxx.elb.amazonaws.com  active
k8s-evershop-frontend-xxx     k8s-evershop-frontend-xxx.elb.amazonaws.com active

Verification Status: COMPLETED

Next Steps:
  1. Verify backend services are deployed (graphql-api, react-frontend)
  2. Test endpoints using ALB DNS names
  3. For qa/prod: Configure DNS records to point to ALB
  4. For qa/prod: Verify HTTPS and certificate configuration
```

### RDS Connectivity Report

```
========================================
RDS Connectivity Verification for EverShop EKS
========================================

[INFO] Test 1: TCP connection to evershop-dev.xxx.us-east-1.rds.amazonaws.com:5432
[SUCCESS] TCP connection successful

[INFO] Test 2: PostgreSQL authentication and connection
[SUCCESS] PostgreSQL connection successful

[INFO] Test 3: Database operations (CREATE/SELECT/DROP)
[SUCCESS] Database operations successful

[INFO] Test 4: Multiple concurrent connections
[SUCCESS] Multiple concurrent connections successful

[SUCCESS] All RDS connectivity tests passed!
```

## Generated Reports

### RDS Connectivity Report

The RDS verification script generates a timestamped report:

**Filename**: `rds-connectivity-verification-{environment}-{timestamp}.txt`

**Contents**:
- Environment details
- RDS connection information
- Test results summary
- Security group configuration
- Verification status

**Example**:
```
RDS Connectivity Verification Report
=====================================

Environment: dev
Cluster: evershop-cluster
Region: us-east-1
Date: 2024-01-15 14:30:22

RDS Details:
  Endpoint: evershop-dev.xxx.us-east-1.rds.amazonaws.com
  Database: evershop
  Username: evershop_admin

Test Results:
  ✓ TCP Connection: PASSED
  ✓ PostgreSQL Authentication: PASSED
  ✓ Database Operations: PASSED
  ✓ Concurrent Connections: PASSED

Verification Status: SUCCESS
```

## Troubleshooting

### Common Issues

#### EKS Health Verification

- **AWS credentials expired**: Re-run `aws sso login --profile aws-evershop-{env}`
- **Cluster not found**: Verify cluster name and region
- **kubectl not configured**: Run `aws eks update-kubeconfig`
- **Nodes not ready**: Check node group status and events

#### Ingress Routing Verification

- **ALB not created**: Check AWS Load Balancer Controller logs and IRSA permissions
- **Ingress resources not found**: Verify Terraform applied Ingress resources
- **Targets unhealthy**: Check backend services are deployed and security groups
- **HTTP timeout**: Wait for ALB provisioning (2-3 minutes) or check security groups
- **HTTPS redirect not working**: Verify ACM certificate and redirect annotations (qa/prod)
- **DNS not resolving**: Check Route53 records point to ALB DNS (qa/prod)

#### RDS Connectivity Verification

- **Cannot connect to RDS**: Check security group rules allow port 5432 from EKS nodes
- **Authentication failed**: Verify password in Secrets Manager
- **Test pod fails to start**: Check image pull permissions and node resources
- **Database operations failed**: Verify user has necessary permissions

### Detailed Troubleshooting

For detailed troubleshooting guides, refer to:
- [VERIFICATION.md](../VERIFICATION.md) - Complete verification guide
- [RDS_CONNECTIVITY_VERIFICATION.md](../RDS_CONNECTIVITY_VERIFICATION.md) - RDS-specific guide

## Security Considerations

### Credentials Management

- **RDS Password**: Stored in AWS Secrets Manager, never in code
- **Kubernetes Secret**: Created dynamically, namespace-scoped
- **AWS Credentials**: Managed via AWS SSO, temporary credentials

### Network Security

- **Security Groups**: RDS only accepts connections from EKS node security group
- **VPC Isolation**: RDS in private subnets, no public access
- **Encryption**: All connections use TLS/SSL

### Cleanup

Always clean up test resources after verification:
- Delete test pods
- Delete Kubernetes secrets
- Review CloudWatch logs for any issues

## Integration with CI/CD

### GitHub Actions Example

```yaml
- name: Verify EKS Health
  run: |
    cd infra-evershop/eks-deployment/scripts
    chmod +x verify-eks-health.sh
    ./verify-eks-health.sh dev

- name: Verify RDS Connectivity
  run: |
    cd infra-evershop/eks-deployment/scripts
    chmod +x verify-rds-connectivity.sh
    ./verify-rds-connectivity.sh dev
```

### Jenkins Pipeline Example

```groovy
stage('Verify Infrastructure') {
    steps {
        sh '''
            cd infra-evershop/eks-deployment/scripts
            chmod +x verify-eks-health.sh verify-rds-connectivity.sh
            ./verify-eks-health.sh dev
            ./verify-rds-connectivity.sh dev
        '''
    }
}
```

## Environment-Specific Expectations

### Dev Environment
- Node count: 2
- Instance type: t3.medium
- Endpoint: Public + Private
- Multi-AZ: Yes
- RDS: db.t3.micro, Single-AZ

### QA Environment
- Node count: 3
- Instance type: t3.large
- Endpoint: Public + Private
- Multi-AZ: Yes
- RDS: db.t3.small, Multi-AZ

### Prod Environment
- Node count: 5
- Instance type: m5.xlarge
- Endpoint: Private only
- Multi-AZ: Yes
- RDS: db.r5.large, Multi-AZ

## Additional Resources

- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [RDS PostgreSQL Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Troubleshooting EKS](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [PostgreSQL Client Documentation](https://www.postgresql.org/docs/current/app-psql.html)
- [VERIFICATION.md](../VERIFICATION.md) - Complete verification guide
- [RDS_CONNECTIVITY_VERIFICATION.md](../RDS_CONNECTIVITY_VERIFICATION.md) - RDS-specific guide
- [QUICK_VERIFICATION.md](../QUICK_VERIFICATION.md) - Quick reference card

## Support

For issues or questions:
1. Check the troubleshooting sections in this README
2. Review the detailed verification guides
3. Check CloudWatch logs for EKS and RDS
4. Review Terraform state for infrastructure configuration
5. Contact the DevOps team
