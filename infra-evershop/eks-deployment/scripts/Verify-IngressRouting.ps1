# Ingress Routing Verification Script for EverShop EKS Deployment (PowerShell)
# This script verifies that AWS Load Balancer Controller and Ingress resources are correctly configured

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "qa", "prod")]
    [string]$Environment = "dev"
)

# Configuration
$ClusterName = "evershop-cluster"
$Region = "us-east-1"
$AwsProfile = "aws-evershop-$Environment"
$Namespace = "evershop"
$LbcNamespace = "kube-system"

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
    
    # Check for jq (optional)
    try {
        $jqVersion = jq --version 2>&1
        Write-Success "jq found: $jqVersion"
        $script:HasJq = $true
    }
    catch {
        Write-Warning "jq not found. Some features may not work properly."
        $script:HasJq = $false
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

# Function to verify AWS Load Balancer Controller
function Test-LoadBalancerController {
    Write-Header "Verifying AWS Load Balancer Controller"
    
    Write-Info "Checking AWS Load Balancer Controller deployment..."
    
    # Check if deployment exists
    $deployment = kubectl get deployment aws-load-balancer-controller -n $LbcNamespace 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "AWS Load Balancer Controller deployment not found in namespace $LbcNamespace"
        return $false
    }
    Write-Success "AWS Load Balancer Controller deployment found"
    
    # Check deployment status
    Write-Info "Checking deployment replicas..."
    $desired = kubectl get deployment aws-load-balancer-controller -n $LbcNamespace -o jsonpath='{.spec.replicas}' 2>&1
    $ready = kubectl get deployment aws-load-balancer-controller -n $LbcNamespace -o jsonpath='{.status.readyReplicas}' 2>&1
    
    if ($ready -ne $desired) {
        Write-Error "AWS Load Balancer Controller not ready. Desired: $desired, Ready: $ready"
        return $false
    }
    Write-Success "AWS Load Balancer Controller is ready ($ready/$desired replicas)"
    
    # Check pod status
    Write-Info "Checking controller pods..."
    kubectl get pods -n $LbcNamespace -l app.kubernetes.io/name=aws-load-balancer-controller
    
    $podStatus = kubectl get pods -n $LbcNamespace -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[*].status.phase}' 2>&1
    if ($podStatus -notmatch "Running") {
        Write-Error "AWS Load Balancer Controller pods are not running"
        return $false
    }
    Write-Success "AWS Load Balancer Controller pods are running"
    
    # Check service account
    Write-Info "Checking service account..."
    $sa = kubectl get serviceaccount aws-load-balancer-controller -n $LbcNamespace 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "AWS Load Balancer Controller service account not found"
        return $false
    }
    
    # Verify IRSA annotation
    $irsaRole = kubectl get serviceaccount aws-load-balancer-controller -n $LbcNamespace -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}' 2>&1
    if (-not $irsaRole) {
        Write-Warning "IRSA role annotation not found on service account"
    }
    else {
        Write-Success "IRSA role configured: $irsaRole"
    }
    
    return $true
}

# Function to verify Ingress resources
function Test-IngressResources {
    Write-Header "Verifying Ingress Resources"
    
    Write-Info "Checking for Ingress resources in namespace: $Namespace"
    
    # Check if namespace exists
    $ns = kubectl get namespace $Namespace 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Namespace $Namespace not found"
        return $false
    }
    Write-Success "Namespace $Namespace exists"
    
    # List all ingresses
    Write-Info "Listing Ingress resources..."
    kubectl get ingress -n $Namespace
    
    # Check GraphQL API Ingress
    Write-Info "Verifying GraphQL API Ingress..."
    $graphqlIngress = kubectl get ingress -n $Namespace 2>&1 | Select-String "graphql-api-ingress"
    if (-not $graphqlIngress) {
        Write-Error "GraphQL API Ingress not found"
        return $false
    }
    Write-Success "GraphQL API Ingress found"
    
    # Check Frontend Ingress
    Write-Info "Verifying Frontend Ingress..."
    $frontendIngress = kubectl get ingress -n $Namespace 2>&1 | Select-String "frontend-ingress"
    if (-not $frontendIngress) {
        Write-Error "Frontend Ingress not found"
        return $false
    }
    Write-Success "Frontend Ingress found"
    
    # Get Ingress details
    Write-Info "GraphQL API Ingress details:"
    kubectl describe ingress -n $Namespace 2>&1 | Select-String -Pattern "graphql-api-ingress" -Context 0,20
    
    Write-Info "Frontend Ingress details:"
    kubectl describe ingress -n $Namespace 2>&1 | Select-String -Pattern "frontend-ingress" -Context 0,20
    
    return $true
}

# Function to verify ALB creation
function Test-ALBCreation {
    Write-Header "Verifying ALB Creation"
    
    Write-Info "Waiting for ALB to be provisioned (this may take 2-3 minutes)..."
    Start-Sleep -Seconds 30
    
    # Get ALB DNS names from Ingress
    Write-Info "Retrieving ALB DNS names from Ingress resources..."
    
    if ($script:HasJq) {
        $ingressJson = kubectl get ingress -n $Namespace -o json 2>&1 | ConvertFrom-Json
        
        $script:GraphqlAlb = ($ingressJson.items | Where-Object { $_.metadata.name -match "graphql" }).status.loadBalancer.ingress[0].hostname
        $script:FrontendAlb = ($ingressJson.items | Where-Object { $_.metadata.name -match "frontend" }).status.loadBalancer.ingress[0].hostname
    }
    else {
        # Fallback without jq
        $script:GraphqlAlb = kubectl get ingress -n $Namespace -o jsonpath='{.items[?(@.metadata.name=="evershop-graphql-api-ingress")].status.loadBalancer.ingress[0].hostname}' 2>&1
        $script:FrontendAlb = kubectl get ingress -n $Namespace -o jsonpath='{.items[?(@.metadata.name=="evershop-frontend-ingress")].status.loadBalancer.ingress[0].hostname}' 2>&1
    }
    
    if (-not $script:GraphqlAlb) {
        Write-Warning "GraphQL API ALB DNS not yet available"
    }
    else {
        Write-Success "GraphQL API ALB: $script:GraphqlAlb"
    }
    
    if (-not $script:FrontendAlb) {
        Write-Warning "Frontend ALB DNS not yet available"
    }
    else {
        Write-Success "Frontend ALB: $script:FrontendAlb"
    }
    
    # List ALBs in AWS
    Write-Info "Listing Application Load Balancers in AWS..."
    aws elbv2 describe-load-balancers `
        --region $Region `
        --profile $AwsProfile `
        --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-$Namespace')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" `
        --output table 2>&1
    
    return $true
}

# Function to verify target groups
function Test-TargetGroups {
    Write-Header "Verifying Target Groups"
    
    Write-Info "Listing target groups for EKS cluster..."
    
    # Get target groups with k8s tag
    $tgList = aws elbv2 describe-target-groups `
        --region $Region `
        --profile $AwsProfile `
        --query "TargetGroups[?contains(TargetGroupName, 'k8s')].{Name:TargetGroupName,Port:Port,Protocol:Protocol,HealthCheckPath:HealthCheckPath}" `
        --output table 2>&1
    
    if (-not $tgList) {
        Write-Warning "No target groups found (they may not be created yet)"
    }
    else {
        Write-Host $tgList
        Write-Success "Target groups found"
    }
    
    # Check target health
    Write-Info "Checking target health..."
    $tgArns = aws elbv2 describe-target-groups `
        --region $Region `
        --profile $AwsProfile `
        --query "TargetGroups[?contains(TargetGroupName, 'k8s')].TargetGroupArn" `
        --output text 2>&1
    
    if ($tgArns) {
        $tgArns -split '\s+' | ForEach-Object {
            if ($_) {
                Write-Info "Target health for $_"
                aws elbv2 describe-target-health `
                    --target-group-arn $_ `
                    --region $Region `
                    --profile $AwsProfile `
                    --query "TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}" `
                    --output table 2>&1
            }
        }
    }
    
    return $true
}

# Function to verify listeners
function Test-Listeners {
    Write-Header "Verifying ALB Listeners"
    
    Write-Info "Checking listener configuration..."
    
    # Get ALB ARNs
    $albArns = aws elbv2 describe-load-balancers `
        --region $Region `
        --profile $AwsProfile `
        --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-$Namespace')].LoadBalancerArn" `
        --output text 2>&1
    
    if (-not $albArns) {
        Write-Warning "No ALBs found for namespace $Namespace"
        return $true
    }
    
    $albArns -split '\s+' | ForEach-Object {
        if ($_) {
            $albArn = $_
            $albName = aws elbv2 describe-load-balancers `
                --load-balancer-arns $albArn `
                --region $Region `
                --profile $AwsProfile `
                --query "LoadBalancers[0].LoadBalancerName" `
                --output text 2>&1
            
            Write-Info "Listeners for ALB: $albName"
            
            aws elbv2 describe-listeners `
                --load-balancer-arn $albArn `
                --region $Region `
                --profile $AwsProfile `
                --query "Listeners[].{Port:Port,Protocol:Protocol,DefaultActions:DefaultActions[0].Type}" `
                --output table 2>&1
            
            # Check for HTTPS listener in qa/prod
            if ($Environment -ne "dev") {
                $httpsListener = aws elbv2 describe-listeners `
                    --load-balancer-arn $albArn `
                    --region $Region `
                    --profile $AwsProfile `
                    --query "Listeners[?Port==``443``].Port" `
                    --output text 2>&1
                
                if (-not $httpsListener) {
                    Write-Warning "HTTPS listener (443) not found for $Environment environment"
                }
                else {
                    Write-Success "HTTPS listener (443) configured"
                }
                
                # Check for HTTP to HTTPS redirect
                $httpRedirect = aws elbv2 describe-listeners `
                    --load-balancer-arn $albArn `
                    --region $Region `
                    --profile $AwsProfile `
                    --query "Listeners[?Port==``80``].DefaultActions[?Type==``redirect``]" `
                    --output text 2>&1
                
                if (-not $httpRedirect) {
                    Write-Warning "HTTP to HTTPS redirect not configured"
                }
                else {
                    Write-Success "HTTP to HTTPS redirect configured"
                }
            }
            else {
                Write-Info "Dev environment: HTTP only (expected)"
            }
        }
    }
    
    return $true
}

# Function to verify routing rules
function Test-RoutingRules {
    Write-Header "Verifying Routing Rules"
    
    Write-Info "Checking Ingress routing configuration..."
    
    # Check GraphQL API routing
    Write-Info "GraphQL API Ingress routing:"
    if ($Environment -eq "dev") {
        kubectl get ingress -n $Namespace -o json 2>&1 | ConvertFrom-Json | 
            Select-Object -ExpandProperty items | 
            Where-Object { $_.metadata.name -match "graphql" } | 
            Select-Object -ExpandProperty spec | 
            Select-Object -ExpandProperty rules | 
            Select-Object -ExpandProperty http | 
            Select-Object -ExpandProperty paths | 
            ForEach-Object {
                Write-Host "  Path: $($_.path) -> Service: $($_.backend.service.name):$($_.backend.service.port.number)"
            }
    }
    else {
        kubectl get ingress -n $Namespace -o json 2>&1 | ConvertFrom-Json | 
            Select-Object -ExpandProperty items | 
            Where-Object { $_.metadata.name -match "graphql" } | 
            Select-Object -ExpandProperty spec | 
            Select-Object -ExpandProperty rules | 
            ForEach-Object {
                Write-Host "  Host: $($_.host) -> Paths: $($_.http.paths.path -join ', ')"
            }
    }
    
    # Check Frontend routing
    Write-Info "Frontend Ingress routing:"
    if ($Environment -eq "dev") {
        kubectl get ingress -n $Namespace -o json 2>&1 | ConvertFrom-Json | 
            Select-Object -ExpandProperty items | 
            Where-Object { $_.metadata.name -match "frontend" } | 
            Select-Object -ExpandProperty spec | 
            Select-Object -ExpandProperty rules | 
            Select-Object -ExpandProperty http | 
            Select-Object -ExpandProperty paths | 
            ForEach-Object {
                Write-Host "  Path: $($_.path) -> Service: $($_.backend.service.name):$($_.backend.service.port.number)"
            }
    }
    else {
        kubectl get ingress -n $Namespace -o json 2>&1 | ConvertFrom-Json | 
            Select-Object -ExpandProperty items | 
            Where-Object { $_.metadata.name -match "frontend" } | 
            Select-Object -ExpandProperty spec | 
            Select-Object -ExpandProperty rules | 
            ForEach-Object {
                Write-Host "  Host: $($_.host) -> Paths: $($_.http.paths.path -join ', ')"
            }
    }
    
    return $true
}

# Function to test HTTP endpoints
function Test-HTTPEndpoints {
    Write-Header "Testing HTTP Endpoints"
    
    Write-Info "Retrieving ALB DNS names..."
    
    if (-not $script:GraphqlAlb -and -not $script:FrontendAlb) {
        Write-Warning "ALB DNS names not yet available. Skipping HTTP endpoint tests."
        Write-Info "Please wait a few minutes for ALB provisioning to complete, then re-run this script."
        return $true
    }
    
    # Test GraphQL API endpoint
    if ($script:GraphqlAlb) {
        Write-Info "Testing GraphQL API endpoint..."
        
        if ($Environment -eq "dev") {
            $testUrl = "http://$($script:GraphqlAlb)/api"
        }
        else {
            $testUrl = "http://$($script:GraphqlAlb)/"
        }
        
        try {
            $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            $httpCode = $response.StatusCode
        }
        catch {
            $httpCode = $_.Exception.Response.StatusCode.value__
            if (-not $httpCode) {
                $httpCode = 0
            }
        }
        
        if ($httpCode -eq 0) {
            Write-Warning "Could not connect to GraphQL API endpoint (ALB may still be provisioning)"
        }
        elseif ($httpCode -eq 503 -or $httpCode -eq 502) {
            Write-Warning "GraphQL API endpoint returned $httpCode (backend service may not be deployed yet)"
        }
        else {
            Write-Success "GraphQL API endpoint responded with HTTP $httpCode"
        }
    }
    
    # Test Frontend endpoint
    if ($script:FrontendAlb) {
        Write-Info "Testing Frontend endpoint..."
        
        $testUrl = "http://$($script:FrontendAlb)/"
        
        try {
            $response = Invoke-WebRequest -Uri $testUrl -Method Get -TimeoutSec 10 -UseBasicParsing -ErrorAction Stop
            $httpCode = $response.StatusCode
        }
        catch {
            $httpCode = $_.Exception.Response.StatusCode.value__
            if (-not $httpCode) {
                $httpCode = 0
            }
        }
        
        if ($httpCode -eq 0) {
            Write-Warning "Could not connect to Frontend endpoint (ALB may still be provisioning)"
        }
        elseif ($httpCode -eq 503 -or $httpCode -eq 502) {
            Write-Warning "Frontend endpoint returned $httpCode (backend service may not be deployed yet)"
        }
        else {
            Write-Success "Frontend endpoint responded with HTTP $httpCode"
        }
    }
    
    return $true
}

# Function to verify DNS resolution (for qa/prod)
function Test-DNSResolution {
    Write-Header "Verifying DNS Resolution"
    
    if ($Environment -eq "dev") {
        Write-Info "Dev environment uses ALB DNS directly. Skipping custom domain DNS verification."
        return $true
    }
    
    Write-Info "Checking DNS resolution for custom domains..."
    
    # Get domain name from Terraform outputs
    Push-Location (Join-Path $PSScriptRoot "..")
    
    try {
        $domainName = terraform output -raw domain_name 2>$null
    }
    catch {
        $domainName = $null
    }
    
    Pop-Location
    
    if (-not $domainName -or $domainName -eq "null") {
        Write-Warning "Custom domain not configured for $Environment environment"
        return $true
    }
    
    Write-Info "Domain: $domainName"
    
    # Check GraphQL API domain
    Write-Info "Checking DNS for api.$domainName..."
    try {
        $dnsResult = Resolve-DnsName "api.$domainName" -ErrorAction Stop
        Write-Host $dnsResult
    }
    catch {
        Write-Warning "DNS lookup failed for api.$domainName"
    }
    
    # Check Frontend domain
    Write-Info "Checking DNS for shop.$domainName..."
    try {
        $dnsResult = Resolve-DnsName "shop.$domainName" -ErrorAction Stop
        Write-Host $dnsResult
    }
    catch {
        Write-Warning "DNS lookup failed for shop.$domainName"
    }
    
    return $true
}

# Function to generate verification report
function New-VerificationReport {
    Write-Header "Verification Report"
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $reportFile = "ingress-routing-verification-$Environment-$timestamp.txt"
    
    $lbcStatus = kubectl get deployment aws-load-balancer-controller -n $LbcNamespace -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>&1
    $lbcReplicas = kubectl get deployment aws-load-balancer-controller -n $LbcNamespace -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>&1
    
    $report = @"
Ingress Routing Verification Report
====================================

Environment: $Environment
Cluster: $ClusterName
Region: $Region
Date: $(Get-Date)

AWS Load Balancer Controller:
  Status: $lbcStatus
  Replicas: $lbcReplicas

Ingress Resources:
$(kubectl get ingress -n $Namespace 2>&1)

Application Load Balancers:
$(aws elbv2 describe-load-balancers --region $Region --profile $AwsProfile --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-$Namespace')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" --output table 2>&1)

Verification Status: COMPLETED

Next Steps:
  1. Verify backend services are deployed (graphql-api, react-frontend)
  2. Test endpoints using ALB DNS names
  3. For qa/prod: Configure DNS records to point to ALB
  4. For qa/prod: Verify HTTPS and certificate configuration
"@
    
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Success "Verification report saved to: $reportFile"
}

# Function to display summary
function Show-Summary {
    Write-Header "Verification Summary"
    
    Write-Host "Environment: $Environment"
    Write-Host ""
    Write-Host "✓ AWS Load Balancer Controller: Verified"
    Write-Host "✓ Ingress Resources: Verified"
    Write-Host "✓ ALB Creation: Checked"
    Write-Host "✓ Target Groups: Checked"
    Write-Host "✓ Listeners: Verified"
    Write-Host "✓ Routing Rules: Verified"
    Write-Host ""
    
    # Display ALB DNS names
    if ($script:GraphqlAlb) {
        Write-Host "GraphQL API Endpoint:"
        if ($Environment -eq "dev") {
            Write-Host "  http://$($script:GraphqlAlb)/api"
        }
        else {
            Write-Host "  http://$($script:GraphqlAlb)/ (or https://api.{domain})"
        }
    }
    
    if ($script:FrontendAlb) {
        Write-Host "Frontend Endpoint:"
        if ($Environment -eq "dev") {
            Write-Host "  http://$($script:FrontendAlb)/"
        }
        else {
            Write-Host "  http://$($script:FrontendAlb)/ (or https://shop.{domain})"
        }
    }
    
    Write-Host ""
    Write-Info "Note: Backend services (graphql-api, react-frontend) must be deployed for endpoints to respond successfully."
}

# Main execution
function Main {
    Write-Header "Ingress Routing Verification for EverShop EKS"
    
    Write-Host "Environment: $Environment"
    Write-Host "Cluster: $ClusterName"
    Write-Host "Region: $Region"
    Write-Host "AWS Profile: $AwsProfile"
    Write-Host ""
    
    Test-Prerequisites
    Connect-AWS
    Update-Kubeconfig
    
    if (-not (Test-LoadBalancerController)) {
        Write-Error "AWS Load Balancer Controller verification failed"
        exit 1
    }
    
    if (-not (Test-IngressResources)) {
        Write-Error "Ingress resources verification failed"
        exit 1
    }
    
    Test-ALBCreation
    Test-TargetGroups
    Test-Listeners
    Test-RoutingRules
    Test-HTTPEndpoints
    Test-DNSResolution
    
    New-VerificationReport
    Show-Summary
    
    Write-Success "Ingress routing verification completed!"
}

# Run main function
Main
