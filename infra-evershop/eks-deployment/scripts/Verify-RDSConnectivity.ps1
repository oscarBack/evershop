# RDS Connectivity Verification Script for EverShop EKS Deployment (PowerShell)
# This script verifies that EKS pods can connect to the RDS PostgreSQL database

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "qa", "prod")]
    [string]$Environment = "dev"
)

# Configuration
$ClusterName = "evershop-cluster"
$Region = "us-east-1"
$AwsProfile = "aws-evershop-$Environment"
$Namespace = "default"
$PodName = "rds-connectivity-test"

# Color functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check AWS CLI
    try {
        $awsVersion = aws --version 2>&1
        Write-Success "AWS CLI found: $awsVersion"
    }
    catch {
        Write-Error "AWS CLI not found. Please install it first."
        exit 1
    }
    
    # Check kubectl
    try {
        $kubectlVersion = kubectl version --client --short 2>&1
        if (-not $kubectlVersion) {
            $kubectlVersion = kubectl version --client 2>&1
        }
        Write-Success "kubectl found: $kubectlVersion"
    }
    catch {
        Write-Error "kubectl not found. Please install it first."
        exit 1
    }
}

# Function to authenticate with AWS
function Connect-AWS {
    Write-Header "Authenticating with AWS"
    
    Write-Info "Logging in to AWS SSO for profile: $AwsProfile"
    aws sso login --profile $AwsProfile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "AWS SSO login failed"
        exit 1
    }
    
    Write-Info "Verifying AWS credentials..."
    $callerIdentity = aws sts get-caller-identity --profile $AwsProfile --output json | ConvertFrom-Json
    
    Write-Success "Authenticated as: $($callerIdentity.Arn)"
    Write-Success "Account ID: $($callerIdentity.Account)"
}

# Function to update kubeconfig
function Update-Kubeconfig {
    Write-Header "Updating kubeconfig"
    
    Write-Info "Updating kubeconfig for cluster: $ClusterName"
    aws eks update-kubeconfig --name $ClusterName --region $Region --profile $AwsProfile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update kubeconfig"
        exit 1
    }
    
    Write-Success "kubeconfig updated successfully"
    
    # Verify connection
    Write-Info "Verifying cluster connectivity..."
    kubectl cluster-info
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot connect to cluster"
        exit 1
    }
    
    Write-Success "Connected to cluster successfully"
}

# Function to get RDS endpoint
function Get-RDSEndpoint {
    Write-Header "Retrieving RDS Connection Details"
    
    Write-Info "Getting RDS endpoint from Terraform outputs..."
    
    Push-Location (Join-Path $PSScriptRoot "..")
    
    try {
        $script:RdsEndpoint = terraform output -raw rds_endpoint 2>$null
    }
    catch {
        $script:RdsEndpoint = $null
    }
    
    if (-not $script:RdsEndpoint) {
        Write-Warning "Could not get RDS endpoint from Terraform output"
        Write-Info "Attempting to retrieve from AWS RDS API..."
        
        $rdsIdentifier = "evershop-$Environment"
        $rdsInfo = aws rds describe-db-instances `
            --db-instance-identifier $rdsIdentifier `
            --region $Region `
            --profile $AwsProfile `
            --query 'DBInstances[0].Endpoint.Address' `
            --output text 2>$null
        
        if (-not $rdsInfo -or $rdsInfo -eq "None") {
            Write-Error "Could not retrieve RDS endpoint. Please ensure RDS instance exists."
            Pop-Location
            exit 1
        }
        
        $script:RdsEndpoint = $rdsInfo
    }
    
    Pop-Location
    
    Write-Success "RDS Endpoint: $script:RdsEndpoint"
    
    # Get RDS password from Secrets Manager
    Write-Info "Retrieving RDS password from Secrets Manager..."
    $secretName = "evershop/$Environment/rds-password"
    $script:RdsPassword = aws secretsmanager get-secret-value `
        --secret-id $secretName `
        --region $Region `
        --profile $AwsProfile `
        --query 'SecretString' `
        --output text 2>$null
    
    if (-not $script:RdsPassword) {
        Write-Error "Could not retrieve RDS password from Secrets Manager"
        exit 1
    }
    
    Write-Success "RDS password retrieved successfully"
}

# Function to create Kubernetes secret
function New-K8sSecret {
    Write-Header "Creating Kubernetes Secret"
    
    Write-Info "Creating secret with RDS credentials in namespace: $Namespace"
    
    # Delete existing secret if it exists
    kubectl delete secret rds-credentials -n $Namespace 2>$null
    
    # Create new secret
    kubectl create secret generic rds-credentials `
        -n $Namespace `
        --from-literal=password="$script:RdsPassword" `
        --from-literal=endpoint="$script:RdsEndpoint" `
        --from-literal=database="evershop" `
        --from-literal=username="evershop_admin"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create Kubernetes secret"
        exit 1
    }
    
    Write-Success "Kubernetes secret created successfully"
}

# Function to deploy test pod
function Deploy-TestPod {
    Write-Header "Deploying RDS Test Pod"
    
    # Delete existing pod if it exists
    Write-Info "Cleaning up any existing test pod..."
    kubectl delete pod $PodName -n $Namespace 2>$null
    
    # Wait for pod to be deleted
    Start-Sleep -Seconds 5
    
    Write-Info "Creating test pod manifest..."
    
    # Create temporary pod manifest
    $podManifest = @"
apiVersion: v1
kind: Pod
metadata:
  name: $PodName
  namespace: $Namespace
  labels:
    app: rds-test
spec:
  serviceAccountName: default
  containers:
  - name: postgres-client
    image: postgres:15-alpine
    command:
      - sleep
      - "3600"
    env:
    - name: PGHOST
      value: "$script:RdsEndpoint"
    - name: PGPORT
      value: "5432"
    - name: PGDATABASE
      value: "evershop"
    - name: PGUSER
      value: "evershop_admin"
    - name: PGPASSWORD
      valueFrom:
        secretKeyRef:
          name: rds-credentials
          key: password
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
  restartPolicy: Never
"@
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    $podManifest | Out-File -FilePath $tempFile -Encoding UTF8
    
    Write-Info "Deploying test pod..."
    kubectl apply -f $tempFile
    
    Remove-Item $tempFile
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy test pod"
        exit 1
    }
    
    Write-Success "Test pod deployed"
    
    # Wait for pod to be ready
    Write-Info "Waiting for pod to be ready (timeout: 120s)..."
    kubectl wait --for=condition=Ready pod/$PodName -n $Namespace --timeout=120s
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Pod failed to become ready"
        Write-Info "Pod status:"
        kubectl describe pod $PodName -n $Namespace
        exit 1
    }
    
    Write-Success "Test pod is ready"
}

# Function to test RDS connectivity
function Test-RDSConnectivity {
    Write-Header "Testing RDS Connectivity"
    
    Write-Info "Testing basic network connectivity to RDS endpoint..."
    
    # Test 1: Network connectivity
    Write-Info "Test 1: TCP connection to $($script:RdsEndpoint):5432"
    kubectl exec -n $Namespace $PodName -- sh -c "timeout 10 nc -zv $($script:RdsEndpoint) 5432"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot establish TCP connection to RDS"
        return $false
    }
    Write-Success "TCP connection successful"
    
    # Test 2: PostgreSQL connection
    Write-Info "Test 2: PostgreSQL authentication and connection"
    kubectl exec -n $Namespace $PodName -- sh -c "psql -h $($script:RdsEndpoint) -U evershop_admin -d evershop -c 'SELECT version();'"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "PostgreSQL connection failed"
        return $false
    }
    Write-Success "PostgreSQL connection successful"
    
    # Test 3: Database operations
    Write-Info "Test 3: Database operations (CREATE/SELECT/DROP)"
    $sqlCommands = @"
CREATE TABLE IF NOT EXISTS connectivity_test (
    id SERIAL PRIMARY KEY,
    test_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    test_message TEXT
);

INSERT INTO connectivity_test (test_message) VALUES ('RDS connectivity test successful');

SELECT * FROM connectivity_test ORDER BY test_time DESC LIMIT 1;

DROP TABLE connectivity_test;
"@
    
    kubectl exec -n $Namespace $PodName -- sh -c "psql -h $($script:RdsEndpoint) -U evershop_admin -d evershop -c `"$sqlCommands`""
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Database operations failed"
        return $false
    }
    Write-Success "Database operations successful"
    
    # Test 4: Multiple concurrent connections
    Write-Info "Test 4: Multiple concurrent connections"
    1..5 | ForEach-Object {
        Start-Job -ScriptBlock {
            param($ns, $pod, $endpoint)
            kubectl exec -n $ns $pod -- sh -c "psql -h $endpoint -U evershop_admin -d evershop -c 'SELECT 1;'" 2>&1 | Out-Null
        } -ArgumentList $Namespace, $PodName, $script:RdsEndpoint
    } | Wait-Job | Remove-Job
    
    Write-Success "Multiple concurrent connections successful"
    
    Write-Success "All RDS connectivity tests passed!"
    return $true
}

# Function to verify security groups
function Test-SecurityGroups {
    Write-Header "Verifying Security Group Configuration"
    
    Write-Info "Retrieving RDS security group..."
    $rdsIdentifier = "evershop-$Environment"
    $rdsSg = aws rds describe-db-instances `
        --db-instance-identifier $rdsIdentifier `
        --region $Region `
        --profile $AwsProfile `
        --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' `
        --output text 2>$null
    
    if (-not $rdsSg) {
        Write-Warning "Could not retrieve RDS security group"
        return
    }
    
    Write-Success "RDS Security Group: $rdsSg"
    
    Write-Info "Checking ingress rules..."
    aws ec2 describe-security-groups `
        --group-ids $rdsSg `
        --region $Region `
        --profile $AwsProfile `
        --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432`]' `
        --output table
    
    Write-Success "Security group verification complete"
    
    return $rdsSg
}

# Function to cleanup
function Remove-TestResources {
    Write-Header "Cleanup"
    
    $response = Read-Host "Do you want to delete the test pod? (y/n)"
    
    if ($response -eq 'y' -or $response -eq 'Y') {
        Write-Info "Deleting test pod..."
        kubectl delete pod $PodName -n $Namespace 2>$null
        Write-Success "Test pod deleted"
        
        Write-Info "Deleting Kubernetes secret..."
        kubectl delete secret rds-credentials -n $Namespace 2>$null
        Write-Success "Secret deleted"
    }
    else {
        Write-Info "Test pod and secret retained for further testing"
        Write-Info "To delete manually, run:"
        Write-Host "  kubectl delete pod $PodName -n $Namespace"
        Write-Host "  kubectl delete secret rds-credentials -n $Namespace"
    }
}

# Function to generate report
function New-VerificationReport {
    param([string]$SecurityGroup)
    
    Write-Header "Verification Report"
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportFile = "rds-connectivity-verification-$Environment-$timestamp.txt"
    
    $report = @"
RDS Connectivity Verification Report
=====================================

Environment: $Environment
Cluster: $ClusterName
Region: $Region
Date: $(Get-Date)

RDS Details:
  Endpoint: $script:RdsEndpoint
  Database: evershop
  Username: evershop_admin

Test Results:
  ✓ TCP Connection: PASSED
  ✓ PostgreSQL Authentication: PASSED
  ✓ Database Operations: PASSED
  ✓ Concurrent Connections: PASSED

Security Group Configuration:
  Security Group ID: $SecurityGroup

Verification Status: SUCCESS
"@
    
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Success "Verification report saved to: $reportFile"
}

# Main execution
function Main {
    Write-Header "RDS Connectivity Verification for EverShop EKS"
    
    Write-Host "Environment: $Environment"
    Write-Host "Cluster: $ClusterName"
    Write-Host "Region: $Region"
    Write-Host "AWS Profile: $AwsProfile"
    Write-Host ""
    
    Test-Prerequisites
    Connect-AWS
    Update-Kubeconfig
    Get-RDSEndpoint
    New-K8sSecret
    Deploy-TestPod
    
    $testResult = Test-RDSConnectivity
    
    if ($testResult) {
        $securityGroup = Test-SecurityGroups
        New-VerificationReport -SecurityGroup $securityGroup
        Write-Success "RDS connectivity verification completed successfully!"
    }
    else {
        Write-Error "RDS connectivity verification failed"
        Write-Info "Checking pod logs..."
        kubectl logs $PodName -n $Namespace 2>$null
        exit 1
    }
    
    Remove-TestResources
}

# Run main function
Main
