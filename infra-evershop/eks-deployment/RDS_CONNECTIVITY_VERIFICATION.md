# RDS Connectivity Verification Guide

This guide provides instructions for verifying that EKS pods can successfully connect to the RDS PostgreSQL database.

## Quick Start

### Automated Verification (Recommended)

**Linux/Mac:**
```bash
cd infra-evershop/eks-deployment/scripts
chmod +x verify-rds-connectivity.sh
./verify-rds-connectivity.sh dev
```

**Windows (PowerShell):**
```powershell
cd infra-evershop/eks-deployment/scripts
.\Verify-RDSConnectivity.ps1 -Environment dev
```

## What Gets Verified

The verification script tests the following:

1. ✅ **Network Connectivity**: TCP connection to RDS endpoint on port 5432
2. ✅ **Authentication**: PostgreSQL authentication with credentials from Secrets Manager
3. ✅ **Database Operations**: CREATE, INSERT, SELECT, DROP table operations
4. ✅ **Concurrent Connections**: Multiple simultaneous database connections
5. ✅ **Security Groups**: Verification that security group rules are correctly configured

## Prerequisites

Before running the verification:

- AWS CLI v2.x or later installed
- kubectl v1.28 or later installed
- AWS SSO configured for the target environment
- EKS cluster deployed and accessible
- RDS instance deployed and available
- Terraform outputs available (or RDS endpoint known)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         EKS Cluster                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Test Pod (postgres:15-alpine)                       │  │
│  │  - PostgreSQL client tools (psql, nc)                │  │
│  │  - Environment variables with RDS connection details │  │
│  │  - Credentials from Kubernetes Secret                │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                       │
│                     │ Port 5432 (PostgreSQL)                │
│                     │                                       │
└─────────────────────┼───────────────────────────────────────┘
                      │
                      │ Security Group Rule:
                      │ Source: EKS Node Security Group
                      │ Port: 5432
                      │ Protocol: TCP
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    RDS PostgreSQL                           │
│  - Engine: PostgreSQL 15+                                   │
│  - Database: evershop                                       │
│  - User: evershop_admin                                     │
│  - Password: Stored in AWS Secrets Manager                  │
│  - Security Group: Allows 5432 from EKS nodes only          │
└─────────────────────────────────────────────────────────────┘
```

## Security Configuration

### Security Group Rules

**RDS Security Group:**
- **Inbound**: PostgreSQL (5432) from EKS node security group ONLY
- **Outbound**: None (RDS doesn't initiate connections)

**EKS Node Security Group:**
- **Outbound**: All traffic to 0.0.0.0/0 (allows connection to RDS)

### Credentials Management

- **Master Password**: Stored in AWS Secrets Manager
- **Secret Name**: `evershop/{environment}/rds-password`
- **Kubernetes Secret**: Created dynamically during verification
- **Secret Scope**: Namespace-scoped (default namespace)

## Verification Process

### Step-by-Step Flow

1. **Authentication**
   - Login to AWS SSO
   - Verify AWS credentials
   - Update kubeconfig for EKS cluster

2. **RDS Details Retrieval**
   - Get RDS endpoint from Terraform outputs
   - Fallback to AWS RDS API if Terraform output unavailable
   - Retrieve RDS password from Secrets Manager

3. **Kubernetes Setup**
   - Create Kubernetes secret with RDS credentials
   - Deploy PostgreSQL client test pod
   - Wait for pod to be ready

4. **Connectivity Tests**
   - **Test 1**: TCP connection using netcat (nc)
   - **Test 2**: PostgreSQL authentication using psql
   - **Test 3**: Database operations (CREATE/INSERT/SELECT/DROP)
   - **Test 4**: Concurrent connections (5 simultaneous connections)

5. **Security Verification**
   - Retrieve RDS security group ID
   - Verify ingress rules for port 5432
   - Confirm source is EKS node security group

6. **Report Generation**
   - Create verification report with timestamp
   - Include all test results
   - Document security group configuration

7. **Cleanup**
   - Optionally delete test pod
   - Optionally delete Kubernetes secret

## Manual Verification

If you need to verify connectivity manually:

### 1. Get RDS Endpoint

```bash
# From Terraform
cd infra-evershop/eks-deployment
terraform output rds_endpoint

# From AWS CLI
aws rds describe-db-instances \
  --db-instance-identifier evershop-dev \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text
```

### 2. Get RDS Password

```bash
aws secretsmanager get-secret-value \
  --secret-id evershop/dev/rds-password \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'SecretString' \
  --output text
```

### 3. Create Test Pod

```bash
# Update the manifest with your RDS endpoint
kubectl apply -f scripts/rds-test-pod.yaml

# Wait for pod
kubectl wait --for=condition=Ready pod/rds-connectivity-test --timeout=120s
```

### 4. Test Connection

```bash
# TCP test
kubectl exec rds-connectivity-test -- nc -zv YOUR_RDS_ENDPOINT 5432

# PostgreSQL test
kubectl exec rds-connectivity-test -- psql -h YOUR_RDS_ENDPOINT -U evershop_admin -d evershop -c 'SELECT version();'
```

## Troubleshooting

### Common Issues and Solutions

#### Issue: "Cannot establish TCP connection to RDS"

**Diagnosis:**
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier evershop-dev \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].DBInstanceStatus'

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids YOUR_RDS_SG_ID \
  --region us-east-1 \
  --profile aws-evershop-dev
```

**Solutions:**
1. Verify RDS instance is in "available" state
2. Check security group allows port 5432 from EKS node security group
3. Verify RDS and EKS are in the same VPC
4. Check network ACLs are not blocking traffic

#### Issue: "PostgreSQL authentication failed"

**Diagnosis:**
```bash
# Verify secret exists
aws secretsmanager describe-secret \
  --secret-id evershop/dev/rds-password \
  --region us-east-1 \
  --profile aws-evershop-dev

# Check master username
aws rds describe-db-instances \
  --db-instance-identifier evershop-dev \
  --region us-east-1 \
  --profile aws-evershop-dev \
  --query 'DBInstances[0].MasterUsername'
```

**Solutions:**
1. Verify password in Secrets Manager is correct
2. Check username matches RDS master username
3. Ensure database name is correct (evershop)
4. Verify Kubernetes secret was created correctly

#### Issue: "Test pod fails to start"

**Diagnosis:**
```bash
# Check pod status
kubectl describe pod rds-connectivity-test

# Check pod logs
kubectl logs rds-connectivity-test

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

**Solutions:**
1. Verify image can be pulled (postgres:15-alpine)
2. Check node has sufficient resources
3. Verify Kubernetes secret exists
4. Check for any admission controller errors

#### Issue: "Database operations failed"

**Diagnosis:**
```bash
# Check RDS logs
aws rds describe-db-log-files \
  --db-instance-identifier evershop-dev \
  --region us-east-1 \
  --profile aws-evershop-dev

# Check PostgreSQL version
kubectl exec rds-connectivity-test -- psql -h YOUR_RDS_ENDPOINT -U evershop_admin -d evershop -c 'SELECT version();'
```

**Solutions:**
1. Verify user has necessary permissions (CREATE, INSERT, SELECT, DROP)
2. Check database exists and is accessible
3. Verify no conflicting table names
4. Check RDS storage is not full

## Expected Results

### Successful Verification Output

```
========================================
RDS Connectivity Verification for EverShop EKS
========================================

Environment: dev
Cluster: evershop-cluster
Region: us-east-1
AWS Profile: aws-evershop-dev

========================================
Checking Prerequisites
========================================

[SUCCESS] AWS CLI found: aws-cli/2.x.x
[SUCCESS] kubectl found: v1.28.x

========================================
Authenticating with AWS
========================================

[SUCCESS] Authenticated as: arn:aws:sts::123456789012:assumed-role/...
[SUCCESS] Account ID: 123456789012

========================================
Updating kubeconfig
========================================

[SUCCESS] kubeconfig updated successfully
[SUCCESS] Connected to cluster successfully

========================================
Retrieving RDS Connection Details
========================================

[SUCCESS] RDS Endpoint: evershop-dev.xxxxxxxxxx.us-east-1.rds.amazonaws.com
[SUCCESS] RDS password retrieved successfully

========================================
Creating Kubernetes Secret
========================================

[SUCCESS] Kubernetes secret created successfully

========================================
Deploying RDS Test Pod
========================================

[SUCCESS] Test pod deployed
[SUCCESS] Test pod is ready

========================================
Testing RDS Connectivity
========================================

[INFO] Test 1: TCP connection to evershop-dev.xxxxxxxxxx.us-east-1.rds.amazonaws.com:5432
[SUCCESS] TCP connection successful

[INFO] Test 2: PostgreSQL authentication and connection
[SUCCESS] PostgreSQL connection successful

[INFO] Test 3: Database operations (CREATE/SELECT/DROP)
[SUCCESS] Database operations successful

[INFO] Test 4: Multiple concurrent connections
[SUCCESS] Multiple concurrent connections successful

[SUCCESS] All RDS connectivity tests passed!

========================================
Verifying Security Group Configuration
========================================

[SUCCESS] RDS Security Group: sg-xxxxxxxxxxxxxxxxx
[SUCCESS] Security group verification complete

========================================
Verification Report
========================================

[SUCCESS] Verification report saved to: rds-connectivity-verification-dev-20240115-143022.txt

[SUCCESS] RDS connectivity verification completed successfully!
```

## Verification Report

The script generates a detailed report with the following information:

```
RDS Connectivity Verification Report
=====================================

Environment: dev
Cluster: evershop-cluster
Region: us-east-1
Date: 2024-01-15 14:30:22

RDS Details:
  Endpoint: evershop-dev.xxxxxxxxxx.us-east-1.rds.amazonaws.com
  Database: evershop
  Username: evershop_admin

Test Results:
  ✓ TCP Connection: PASSED
  ✓ PostgreSQL Authentication: PASSED
  ✓ Database Operations: PASSED
  ✓ Concurrent Connections: PASSED

Security Group Configuration:
  [Security group rules table]

Verification Status: SUCCESS
```

## Best Practices

1. **Run verification after infrastructure deployment**: Always verify RDS connectivity after deploying or updating infrastructure

2. **Test in all environments**: Run verification in dev, qa, and prod environments

3. **Keep credentials secure**: Never log or expose RDS passwords in plain text

4. **Clean up test resources**: Always delete test pods and secrets after verification

5. **Document issues**: If verification fails, document the issue and resolution for future reference

6. **Automate in CI/CD**: Integrate verification into your CI/CD pipeline for automated testing

7. **Monitor regularly**: Set up CloudWatch alarms for RDS connectivity issues

## Integration with CI/CD

To integrate RDS connectivity verification into your CI/CD pipeline:

```yaml
# Example GitHub Actions workflow
- name: Verify RDS Connectivity
  run: |
    cd infra-evershop/eks-deployment/scripts
    chmod +x verify-rds-connectivity.sh
    ./verify-rds-connectivity.sh dev
```

```groovy
// Example Jenkins pipeline stage
stage('Verify RDS Connectivity') {
    steps {
        sh '''
            cd infra-evershop/eks-deployment/scripts
            chmod +x verify-rds-connectivity.sh
            ./verify-rds-connectivity.sh dev
        '''
    }
}
```

## Additional Resources

- [AWS RDS Security Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.Security.html)
- [EKS Security Best Practices](https://aws.github.io/aws-eks-best-practices/security/docs/)
- [PostgreSQL Connection Documentation](https://www.postgresql.org/docs/current/libpq-connect.html)
- [Kubernetes Secrets Management](https://kubernetes.io/docs/concepts/configuration/secret/)

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review CloudWatch logs for RDS and EKS
3. Consult the main VERIFICATION.md document
4. Contact the DevOps team

---

**Last Updated**: 2024-01-15
**Version**: 1.0.0
**Maintainer**: DevOps Team
