# EKS Cluster Health Verification Script (PowerShell)
# This script verifies the health and operational status of the EKS cluster

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "qa", "prod")]
    [string]$Environment = "dev"
)

# Configuration
$ClusterName = "evershop-cluster"
$AWSRegion = "us-east-1"
$AWSProfile = "aws-evershop-$Environment"

# Colors for output
$ColorReset = "`e[0m"
$ColorRed = "`e[31m"
$ColorGreen = "`e[32m"
$ColorYellow = "`e[33m"
$ColorBlue = "`e[34m"

function Write-Section {
    param([string]$Message)
    Write-Host "`n$ColorBlue=== $Message ===$ColorReset"
}

function Write-Success {
    param([string]$Message)
    Write-Host "$ColorGreen✓ $Message$ColorReset"
}

function Write-Warning {
    param([string]$Message)
    Write-Host "$ColorYellow⚠ $Message$ColorReset"
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "$ColorRed✗ $Message$ColorReset"
}

Write-Host "$ColorBlue========================================$ColorReset"
Write-Host "$ColorBlue EKS Cluster Health Verification$ColorReset"
Write-Host "$ColorBlue Environment: $Environment$ColorReset"
Write-Host "$ColorBlue Cluster: $ClusterName$ColorReset"
Write-Host "$ColorBlue Region: $AWSRegion$ColorReset"
Write-Host "$ColorBlue========================================$ColorReset`n"

# Check if AWS CLI is installed
Write-Section "Checking Prerequisites"
try {
    $awsVersion = aws --version 2>&1
    Write-Success "AWS CLI is installed: $awsVersion"
} catch {
    Write-ErrorMsg "AWS CLI is not installed"
    Write-Host "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
}

# Check if kubectl is installed
try {
    $kubectlVersion = kubectl version --client --short 2>&1
    Write-Success "kubectl is installed"
} catch {
    Write-ErrorMsg "kubectl is not installed"
    Write-Host "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
}

# Check AWS credentials
Write-Section "Checking AWS Credentials"
try {
    $identity = aws sts get-caller-identity --profile $AWSProfile 2>&1 | ConvertFrom-Json
    $accountId = $identity.Account
    Write-Success "AWS credentials are valid (Account: $accountId)"
} catch {
    Write-ErrorMsg "AWS credentials are invalid or expired"
    Write-Warning "Run: aws sso login --profile $AWSProfile"
    exit 1
}

# Check EKS cluster status
Write-Section "Checking EKS Cluster Status"
try {
    $cluster = aws eks describe-cluster --name $ClusterName --region $AWSRegion --profile $AWSProfile 2>&1 | ConvertFrom-Json
    $clusterStatus = $cluster.cluster.status
    
    if ($clusterStatus -eq "ACTIVE") {
        Write-Success "Cluster status: $clusterStatus"
    } else {
        Write-ErrorMsg "Cluster status: $clusterStatus"
        exit 1
    }
} catch {
    Write-ErrorMsg "Cluster not found: $ClusterName"
    Write-Host "Error: $_"
    exit 1
}

# Check cluster version
Write-Section "Checking Cluster Version"
$clusterVersion = $cluster.cluster.version
Write-Success "Kubernetes version: $clusterVersion"

$versionParts = $clusterVersion.Split('.')
$majorVersion = [int]$versionParts[0]
$minorVersion = [int]$versionParts[1]

if ($majorVersion -eq 1 -and $minorVersion -ge 28) {
    Write-Success "Version meets requirement (1.28+)"
} else {
    Write-Warning "Version is below recommended (1.28+)"
}

# Check control plane logging
Write-Section "Checking Control Plane Logging"
$enabledLogs = $cluster.cluster.logging.clusterLogging | Where-Object { $_.enabled -eq $true } | Select-Object -ExpandProperty types
$requiredLogs = @("api", "audit", "authenticator", "controllerManager", "scheduler")

foreach ($logType in $requiredLogs) {
    if ($enabledLogs -contains $logType) {
        Write-Success "Log type enabled: $logType"
    } else {
        Write-Warning "Log type not enabled: $logType"
    }
}

# Check OIDC provider
Write-Section "Checking OIDC Provider"
$oidcIssuer = $cluster.cluster.identity.oidc.issuer

if ($oidcIssuer) {
    Write-Success "OIDC provider configured: $oidcIssuer"
    
    # Extract OIDC ID
    $oidcId = ($oidcIssuer -replace 'https://', '') -split '/' | Select-Object -Last 1
    $oidcProviderArn = "arn:aws:iam::${accountId}:oidc-provider/oidc.eks.${AWSRegion}.amazonaws.com/id/${oidcId}"
    
    try {
        aws iam get-open-id-connect-provider --open-id-connect-provider-arn $oidcProviderArn --profile $AWSProfile 2>&1 | Out-Null
        Write-Success "OIDC provider exists in IAM"
    } catch {
        Write-Warning "OIDC provider not found in IAM"
    }
} else {
    Write-ErrorMsg "OIDC provider not configured"
}

# Check cluster endpoint access
Write-Section "Checking Cluster Endpoint Access"
$publicAccess = $cluster.cluster.resourcesVpcConfig.endpointPublicAccess
$privateAccess = $cluster.cluster.resourcesVpcConfig.endpointPrivateAccess

Write-Success "Public endpoint access: $publicAccess"
Write-Success "Private endpoint access: $privateAccess"

# Check encryption
Write-Section "Checking Encryption Configuration"
$encryptionConfig = $cluster.cluster.encryptionConfig

if ($encryptionConfig) {
    $resources = $encryptionConfig[0].resources -join ", "
    Write-Success "Encryption enabled for: $resources"
} else {
    Write-Warning "Encryption not configured"
}

# Check node groups
Write-Section "Checking Node Groups"
try {
    $nodeGroups = aws eks list-nodegroups --cluster-name $ClusterName --region $AWSRegion --profile $AWSProfile 2>&1 | ConvertFrom-Json
    
    if ($nodeGroups.nodegroups.Count -eq 0) {
        Write-ErrorMsg "No node groups found"
    } else {
        foreach ($ng in $nodeGroups.nodegroups) {
            Write-Host "`n$ColorYellow Node Group: $ng$ColorReset"
            
            $ngDetails = aws eks describe-nodegroup --cluster-name $ClusterName --nodegroup-name $ng --region $AWSRegion --profile $AWSProfile 2>&1 | ConvertFrom-Json
            
            $ngStatus = $ngDetails.nodegroup.status
            $ngHealth = $ngDetails.nodegroup.health.issues
            $desired = $ngDetails.nodegroup.scalingConfig.desiredSize
            $min = $ngDetails.nodegroup.scalingConfig.minSize
            $max = $ngDetails.nodegroup.scalingConfig.maxSize
            
            if ($ngStatus -eq "ACTIVE") {
                Write-Success "Status: $ngStatus"
            } else {
                Write-ErrorMsg "Status: $ngStatus"
            }
            
            if ($ngHealth.Count -eq 0) {
                Write-Success "Health: No issues"
            } else {
                Write-Warning "Health issues: $($ngHealth -join ', ')"
            }
            
            Write-Success "Scaling: Min=$min, Desired=$desired, Max=$max"
        }
    }
} catch {
    Write-ErrorMsg "Error checking node groups: $_"
}

# Update kubeconfig
Write-Section "Updating kubeconfig"
try {
    aws eks update-kubeconfig --name $ClusterName --region $AWSRegion --profile $AWSProfile 2>&1 | Out-Null
    Write-Success "kubeconfig updated"
} catch {
    Write-Warning "Failed to update kubeconfig: $_"
}

# Check node readiness
Write-Section "Checking Node Readiness"
try {
    $nodes = kubectl get nodes --no-headers 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $nodeLines = $nodes -split "`n" | Where-Object { $_ -ne "" }
        $totalNodes = $nodeLines.Count
        $readyNodes = ($nodeLines | Where-Object { $_ -match "\s+Ready\s+" }).Count
        $notReadyNodes = ($nodeLines | Where-Object { $_ -match "\s+NotReady\s+" }).Count
        
        Write-Success "Total nodes: $totalNodes"
        Write-Success "Ready nodes: $readyNodes"
        
        if ($notReadyNodes -gt 0) {
            Write-ErrorMsg "Not ready nodes: $notReadyNodes"
        }
        
        Write-Host "`n$ColorYellow Node Details:$ColorReset"
        kubectl get nodes -o wide
    } else {
        Write-Warning "Unable to retrieve nodes (kubectl may not be configured)"
    }
} catch {
    Write-Warning "Error checking node readiness: $_"
}

# Check core system pods
Write-Section "Checking Core System Pods (kube-system)"
try {
    $pods = kubectl get pods -n kube-system --no-headers 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $podLines = $pods -split "`n" | Where-Object { $_ -ne "" }
        $totalPods = $podLines.Count
        $runningPods = ($podLines | Where-Object { $_ -match "\s+Running\s+" }).Count
        
        Write-Success "Total system pods: $totalPods"
        Write-Success "Running pods: $runningPods"
        
        # Check for critical components
        $criticalComponents = @("coredns", "kube-proxy", "aws-node")
        
        foreach ($component in $criticalComponents) {
            $componentPods = ($podLines | Where-Object { $_ -match $component -and $_ -match "\s+Running\s+" }).Count
            if ($componentPods -gt 0) {
                Write-Success "${component}: $componentPods pod(s) running"
            } else {
                Write-ErrorMsg "${component}: No running pods found"
            }
        }
        
        Write-Host "`n$ColorYellow System Pod Status:$ColorReset"
        kubectl get pods -n kube-system
    } else {
        Write-Warning "Unable to retrieve pods (kubectl may not be configured)"
    }
} catch {
    Write-Warning "Error checking system pods: $_"
}

# Test kubectl connectivity
Write-Section "Testing kubectl Connectivity"
try {
    $clusterInfo = kubectl cluster-info 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "kubectl can connect to the cluster"
        Write-Host $clusterInfo
    } else {
        Write-ErrorMsg "kubectl cannot connect to the cluster"
    }
} catch {
    Write-ErrorMsg "Error testing kubectl connectivity: $_"
}

# Check cluster add-ons
Write-Section "Checking Cluster Add-ons"
try {
    $addons = aws eks list-addons --cluster-name $ClusterName --region $AWSRegion --profile $AWSProfile 2>&1 | ConvertFrom-Json
    
    if ($addons.addons.Count -eq 0) {
        Write-Warning "No managed add-ons found"
    } else {
        foreach ($addon in $addons.addons) {
            $addonDetails = aws eks describe-addon --cluster-name $ClusterName --addon-name $addon --region $AWSRegion --profile $AWSProfile 2>&1 | ConvertFrom-Json
            $addonStatus = $addonDetails.addon.status
            
            if ($addonStatus -eq "ACTIVE") {
                Write-Success "Add-on ${addon}: $addonStatus"
            } else {
                Write-Warning "Add-on ${addon}: $addonStatus"
            }
        }
    }
} catch {
    Write-Warning "Error checking add-ons: $_"
}

# Generate summary
Write-Section "Verification Summary"
Write-Host "$ColorGreen Cluster Health Check Complete$ColorReset`n"
Write-Host "Cluster Name: $ClusterName"
Write-Host "Environment: $Environment"
Write-Host "Region: $AWSRegion"
Write-Host "Timestamp: $(Get-Date)"
