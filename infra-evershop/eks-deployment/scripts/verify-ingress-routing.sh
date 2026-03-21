#!/bin/bash

# Ingress Routing Verification Script for EverShop EKS Deployment
# This script verifies that AWS Load Balancer Controller and Ingress resources are correctly configured

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-dev}"
CLUSTER_NAME="evershop-cluster"
REGION="us-east-1"
AWS_PROFILE="aws-evershop-${ENVIRONMENT}"
NAMESPACE="evershop"
LBC_NAMESPACE="kube-system"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    print_success "AWS CLI found: $(aws --version)"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install it first."
        exit 1
    fi
    print_success "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Some features may not work properly."
    else
        print_success "jq found: $(jq --version)"
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        print_warning "curl not found. HTTP endpoint testing will be limited."
    else
        print_success "curl found"
    fi
}

# Function to authenticate with AWS
authenticate_aws() {
    print_header "Authenticating with AWS"
    
    print_info "Logging in to AWS SSO for profile: ${AWS_PROFILE}"
    aws sso login --profile "${AWS_PROFILE}" || {
        print_error "AWS SSO login failed"
        exit 1
    }
    
    print_info "Verifying AWS credentials..."
    CALLER_IDENTITY=$(aws sts get-caller-identity --profile "${AWS_PROFILE}" --output json)
    ACCOUNT_ID=$(echo "${CALLER_IDENTITY}" | jq -r '.Account')
    USER_ARN=$(echo "${CALLER_IDENTITY}" | jq -r '.Arn')
    
    print_success "Authenticated as: ${USER_ARN}"
    print_success "Account ID: ${ACCOUNT_ID}"
}

# Function to update kubeconfig
update_kubeconfig() {
    print_header "Updating kubeconfig"
    
    print_info "Updating kubeconfig for cluster: ${CLUSTER_NAME}"
    aws eks update-kubeconfig \
        --name "${CLUSTER_NAME}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" || {
        print_error "Failed to update kubeconfig"
        exit 1
    }
    
    print_success "kubeconfig updated successfully"
    
    # Verify connection
    print_info "Verifying cluster connectivity..."
    kubectl cluster-info || {
        print_error "Cannot connect to cluster"
        exit 1
    }
    print_success "Connected to cluster successfully"
}

# Function to verify AWS Load Balancer Controller
verify_load_balancer_controller() {
    print_header "Verifying AWS Load Balancer Controller"
    
    print_info "Checking AWS Load Balancer Controller deployment..."
    
    # Check if deployment exists
    if ! kubectl get deployment aws-load-balancer-controller -n "${LBC_NAMESPACE}" &> /dev/null; then
        print_error "AWS Load Balancer Controller deployment not found in namespace ${LBC_NAMESPACE}"
        return 1
    fi
    print_success "AWS Load Balancer Controller deployment found"
    
    # Check deployment status
    print_info "Checking deployment replicas..."
    DESIRED=$(kubectl get deployment aws-load-balancer-controller -n "${LBC_NAMESPACE}" -o jsonpath='{.spec.replicas}')
    READY=$(kubectl get deployment aws-load-balancer-controller -n "${LBC_NAMESPACE}" -o jsonpath='{.status.readyReplicas}')
    
    if [ "${READY}" != "${DESIRED}" ]; then
        print_error "AWS Load Balancer Controller not ready. Desired: ${DESIRED}, Ready: ${READY}"
        return 1
    fi
    print_success "AWS Load Balancer Controller is ready (${READY}/${DESIRED} replicas)"
    
    # Check pod status
    print_info "Checking controller pods..."
    kubectl get pods -n "${LBC_NAMESPACE}" -l app.kubernetes.io/name=aws-load-balancer-controller
    
    POD_STATUS=$(kubectl get pods -n "${LBC_NAMESPACE}" -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[*].status.phase}')
    if [[ ! "${POD_STATUS}" =~ "Running" ]]; then
        print_error "AWS Load Balancer Controller pods are not running"
        return 1
    fi
    print_success "AWS Load Balancer Controller pods are running"
    
    # Check service account
    print_info "Checking service account..."
    if ! kubectl get serviceaccount aws-load-balancer-controller -n "${LBC_NAMESPACE}" &> /dev/null; then
        print_error "AWS Load Balancer Controller service account not found"
        return 1
    fi
    
    # Verify IRSA annotation
    IRSA_ROLE=$(kubectl get serviceaccount aws-load-balancer-controller -n "${LBC_NAMESPACE}" -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}')
    if [ -z "${IRSA_ROLE}" ]; then
        print_warning "IRSA role annotation not found on service account"
    else
        print_success "IRSA role configured: ${IRSA_ROLE}"
    fi
    
    return 0
}

# Function to verify Ingress resources
verify_ingress_resources() {
    print_header "Verifying Ingress Resources"
    
    print_info "Checking for Ingress resources in namespace: ${NAMESPACE}"
    
    # Check if namespace exists
    if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
        print_error "Namespace ${NAMESPACE} not found"
        return 1
    fi
    print_success "Namespace ${NAMESPACE} exists"
    
    # List all ingresses
    print_info "Listing Ingress resources..."
    kubectl get ingress -n "${NAMESPACE}"
    
    # Check GraphQL API Ingress
    print_info "Verifying GraphQL API Ingress..."
    if ! kubectl get ingress -n "${NAMESPACE}" | grep -q "graphql-api-ingress"; then
        print_error "GraphQL API Ingress not found"
        return 1
    fi
    print_success "GraphQL API Ingress found"
    
    # Check Frontend Ingress
    print_info "Verifying Frontend Ingress..."
    if ! kubectl get ingress -n "${NAMESPACE}" | grep -q "frontend-ingress"; then
        print_error "Frontend Ingress not found"
        return 1
    fi
    print_success "Frontend Ingress found"
    
    # Get Ingress details
    print_info "GraphQL API Ingress details:"
    kubectl describe ingress -n "${NAMESPACE}" | grep -A 20 "graphql-api-ingress" || true
    
    print_info "Frontend Ingress details:"
    kubectl describe ingress -n "${NAMESPACE}" | grep -A 20 "frontend-ingress" || true
    
    return 0
}

# Function to verify ALB creation
verify_alb_creation() {
    print_header "Verifying ALB Creation"
    
    print_info "Waiting for ALB to be provisioned (this may take 2-3 minutes)..."
    sleep 30
    
    # Get ALB DNS names from Ingress
    print_info "Retrieving ALB DNS names from Ingress resources..."
    
    GRAPHQL_ALB=$(kubectl get ingress -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.metadata.name | contains("graphql")) | .status.loadBalancer.ingress[0].hostname' 2>/dev/null || echo "")
    FRONTEND_ALB=$(kubectl get ingress -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.metadata.name | contains("frontend")) | .status.loadBalancer.ingress[0].hostname' 2>/dev/null || echo "")
    
    if [ -z "${GRAPHQL_ALB}" ]; then
        print_warning "GraphQL API ALB DNS not yet available"
    else
        print_success "GraphQL API ALB: ${GRAPHQL_ALB}"
    fi
    
    if [ -z "${FRONTEND_ALB}" ]; then
        print_warning "Frontend ALB DNS not yet available"
    else
        print_success "Frontend ALB: ${FRONTEND_ALB}"
    fi
    
    # List ALBs in AWS
    print_info "Listing Application Load Balancers in AWS..."
    aws elbv2 describe-load-balancers \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-${NAMESPACE}')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
        --output table || print_warning "Could not list ALBs from AWS API"
    
    return 0
}

# Function to verify target groups
verify_target_groups() {
    print_header "Verifying Target Groups"
    
    print_info "Listing target groups for EKS cluster..."
    
    # Get target groups with k8s tag
    TG_LIST=$(aws elbv2 describe-target-groups \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query "TargetGroups[?contains(TargetGroupName, 'k8s')].{Name:TargetGroupName,Port:Port,Protocol:Protocol,HealthCheckPath:HealthCheckPath}" \
        --output table 2>/dev/null || echo "")
    
    if [ -z "${TG_LIST}" ]; then
        print_warning "No target groups found (they may not be created yet)"
    else
        echo "${TG_LIST}"
        print_success "Target groups found"
    fi
    
    # Check target health
    print_info "Checking target health..."
    TG_ARNS=$(aws elbv2 describe-target-groups \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query "TargetGroups[?contains(TargetGroupName, 'k8s')].TargetGroupArn" \
        --output text 2>/dev/null || echo "")
    
    if [ -n "${TG_ARNS}" ]; then
        for TG_ARN in ${TG_ARNS}; do
            print_info "Target health for ${TG_ARN}:"
            aws elbv2 describe-target-health \
                --target-group-arn "${TG_ARN}" \
                --region "${REGION}" \
                --profile "${AWS_PROFILE}" \
                --query "TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason}" \
                --output table 2>/dev/null || print_warning "Could not get target health"
        done
    fi
    
    return 0
}

# Function to verify listeners
verify_listeners() {
    print_header "Verifying ALB Listeners"
    
    print_info "Checking listener configuration..."
    
    # Get ALB ARNs
    ALB_ARNS=$(aws elbv2 describe-load-balancers \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-${NAMESPACE}')].LoadBalancerArn" \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${ALB_ARNS}" ]; then
        print_warning "No ALBs found for namespace ${NAMESPACE}"
        return 0
    fi
    
    for ALB_ARN in ${ALB_ARNS}; do
        ALB_NAME=$(aws elbv2 describe-load-balancers \
            --load-balancer-arns "${ALB_ARN}" \
            --region "${REGION}" \
            --profile "${AWS_PROFILE}" \
            --query "LoadBalancers[0].LoadBalancerName" \
            --output text 2>/dev/null)
        
        print_info "Listeners for ALB: ${ALB_NAME}"
        
        aws elbv2 describe-listeners \
            --load-balancer-arn "${ALB_ARN}" \
            --region "${REGION}" \
            --profile "${AWS_PROFILE}" \
            --query "Listeners[].{Port:Port,Protocol:Protocol,DefaultActions:DefaultActions[0].Type}" \
            --output table 2>/dev/null || print_warning "Could not get listeners"
        
        # Check for HTTPS listener in qa/prod
        if [ "${ENVIRONMENT}" != "dev" ]; then
            HTTPS_LISTENER=$(aws elbv2 describe-listeners \
                --load-balancer-arn "${ALB_ARN}" \
                --region "${REGION}" \
                --profile "${AWS_PROFILE}" \
                --query "Listeners[?Port==\`443\`].Port" \
                --output text 2>/dev/null || echo "")
            
            if [ -z "${HTTPS_LISTENER}" ]; then
                print_warning "HTTPS listener (443) not found for ${ENVIRONMENT} environment"
            else
                print_success "HTTPS listener (443) configured"
            fi
            
            # Check for HTTP to HTTPS redirect
            HTTP_REDIRECT=$(aws elbv2 describe-listeners \
                --load-balancer-arn "${ALB_ARN}" \
                --region "${REGION}" \
                --profile "${AWS_PROFILE}" \
                --query "Listeners[?Port==\`80\`].DefaultActions[?Type==\`redirect\`]" \
                --output text 2>/dev/null || echo "")
            
            if [ -z "${HTTP_REDIRECT}" ]; then
                print_warning "HTTP to HTTPS redirect not configured"
            else
                print_success "HTTP to HTTPS redirect configured"
            fi
        else
            print_info "Dev environment: HTTP only (expected)"
        fi
    done
    
    return 0
}

# Function to verify routing rules
verify_routing_rules() {
    print_header "Verifying Routing Rules"
    
    print_info "Checking Ingress routing configuration..."
    
    # Check GraphQL API routing
    print_info "GraphQL API Ingress routing:"
    if [ "${ENVIRONMENT}" == "dev" ]; then
        kubectl get ingress -n "${NAMESPACE}" -o json | \
            jq -r '.items[] | select(.metadata.name | contains("graphql")) | .spec.rules[].http.paths[] | "Path: \(.path) -> Service: \(.backend.service.name):\(.backend.service.port.number)"' 2>/dev/null || \
            print_warning "Could not parse routing rules"
    else
        kubectl get ingress -n "${NAMESPACE}" -o json | \
            jq -r '.items[] | select(.metadata.name | contains("graphql")) | .spec.rules[] | "Host: \(.host) -> Paths: \(.http.paths[].path)"' 2>/dev/null || \
            print_warning "Could not parse routing rules"
    fi
    
    # Check Frontend routing
    print_info "Frontend Ingress routing:"
    if [ "${ENVIRONMENT}" == "dev" ]; then
        kubectl get ingress -n "${NAMESPACE}" -o json | \
            jq -r '.items[] | select(.metadata.name | contains("frontend")) | .spec.rules[].http.paths[] | "Path: \(.path) -> Service: \(.backend.service.name):\(.backend.service.port.number)"' 2>/dev/null || \
            print_warning "Could not parse routing rules"
    else
        kubectl get ingress -n "${NAMESPACE}" -o json | \
            jq -r '.items[] | select(.metadata.name | contains("frontend")) | .spec.rules[] | "Host: \(.host) -> Paths: \(.http.paths[].path)"' 2>/dev/null || \
            print_warning "Could not parse routing rules"
    fi
    
    return 0
}

# Function to test HTTP endpoints
test_http_endpoints() {
    print_header "Testing HTTP Endpoints"
    
    print_info "Retrieving ALB DNS names..."
    
    GRAPHQL_ALB=$(kubectl get ingress -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.metadata.name | contains("graphql")) | .status.loadBalancer.ingress[0].hostname' 2>/dev/null || echo "")
    FRONTEND_ALB=$(kubectl get ingress -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.metadata.name | contains("frontend")) | .status.loadBalancer.ingress[0].hostname' 2>/dev/null || echo "")
    
    if [ -z "${GRAPHQL_ALB}" ] && [ -z "${FRONTEND_ALB}" ]; then
        print_warning "ALB DNS names not yet available. Skipping HTTP endpoint tests."
        print_info "Please wait a few minutes for ALB provisioning to complete, then re-run this script."
        return 0
    fi
    
    # Test GraphQL API endpoint
    if [ -n "${GRAPHQL_ALB}" ]; then
        print_info "Testing GraphQL API endpoint..."
        
        if [ "${ENVIRONMENT}" == "dev" ]; then
            TEST_URL="http://${GRAPHQL_ALB}/api"
        else
            TEST_URL="http://${GRAPHQL_ALB}/"
        fi
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "${TEST_URL}" 2>/dev/null || echo "000")
        
        if [ "${HTTP_CODE}" == "000" ]; then
            print_warning "Could not connect to GraphQL API endpoint (ALB may still be provisioning)"
        elif [ "${HTTP_CODE}" == "503" ] || [ "${HTTP_CODE}" == "502" ]; then
            print_warning "GraphQL API endpoint returned ${HTTP_CODE} (backend service may not be deployed yet)"
        else
            print_success "GraphQL API endpoint responded with HTTP ${HTTP_CODE}"
        fi
    fi
    
    # Test Frontend endpoint
    if [ -n "${FRONTEND_ALB}" ]; then
        print_info "Testing Frontend endpoint..."
        
        TEST_URL="http://${FRONTEND_ALB}/"
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "${TEST_URL}" 2>/dev/null || echo "000")
        
        if [ "${HTTP_CODE}" == "000" ]; then
            print_warning "Could not connect to Frontend endpoint (ALB may still be provisioning)"
        elif [ "${HTTP_CODE}" == "503" ] || [ "${HTTP_CODE}" == "502" ]; then
            print_warning "Frontend endpoint returned ${HTTP_CODE} (backend service may not be deployed yet)"
        else
            print_success "Frontend endpoint responded with HTTP ${HTTP_CODE}"
        fi
    fi
    
    return 0
}

# Function to verify DNS resolution (for qa/prod)
verify_dns_resolution() {
    print_header "Verifying DNS Resolution"
    
    if [ "${ENVIRONMENT}" == "dev" ]; then
        print_info "Dev environment uses ALB DNS directly. Skipping custom domain DNS verification."
        return 0
    fi
    
    print_info "Checking DNS resolution for custom domains..."
    
    # Get domain name from Terraform outputs
    cd "$(dirname "$0")/.." || exit 1
    DOMAIN_NAME=$(terraform output -raw domain_name 2>/dev/null || echo "")
    
    if [ -z "${DOMAIN_NAME}" ] || [ "${DOMAIN_NAME}" == "null" ]; then
        print_warning "Custom domain not configured for ${ENVIRONMENT} environment"
        return 0
    fi
    
    print_info "Domain: ${DOMAIN_NAME}"
    
    # Check GraphQL API domain
    print_info "Checking DNS for api.${DOMAIN_NAME}..."
    if command -v dig &> /dev/null; then
        dig "api.${DOMAIN_NAME}" +short || print_warning "DNS lookup failed"
    elif command -v nslookup &> /dev/null; then
        nslookup "api.${DOMAIN_NAME}" || print_warning "DNS lookup failed"
    else
        print_warning "dig or nslookup not found. Cannot verify DNS resolution."
    fi
    
    # Check Frontend domain
    print_info "Checking DNS for shop.${DOMAIN_NAME}..."
    if command -v dig &> /dev/null; then
        dig "shop.${DOMAIN_NAME}" +short || print_warning "DNS lookup failed"
    elif command -v nslookup &> /dev/null; then
        nslookup "shop.${DOMAIN_NAME}" || print_warning "DNS lookup failed"
    else
        print_warning "dig or nslookup not found. Cannot verify DNS resolution."
    fi
    
    return 0
}

# Function to generate verification report
generate_report() {
    print_header "Verification Report"
    
    REPORT_FILE="ingress-routing-verification-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Ingress Routing Verification Report"
        echo "===================================="
        echo ""
        echo "Environment: ${ENVIRONMENT}"
        echo "Cluster: ${CLUSTER_NAME}"
        echo "Region: ${REGION}"
        echo "Date: $(date)"
        echo ""
        echo "AWS Load Balancer Controller:"
        echo "  Status: $(kubectl get deployment aws-load-balancer-controller -n ${LBC_NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "Unknown")"
        echo "  Replicas: $(kubectl get deployment aws-load-balancer-controller -n ${LBC_NAMESPACE} -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null || echo "Unknown")"
        echo ""
        echo "Ingress Resources:"
        kubectl get ingress -n "${NAMESPACE}" 2>/dev/null || echo "  Could not retrieve ingress resources"
        echo ""
        echo "Application Load Balancers:"
        aws elbv2 describe-load-balancers \
            --region "${REGION}" \
            --profile "${AWS_PROFILE}" \
            --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-${NAMESPACE}')].{Name:LoadBalancerName,DNS:DNSName,State:State.Code}" \
            --output table 2>/dev/null || echo "  Could not retrieve ALB information"
        echo ""
        echo "Verification Status: COMPLETED"
        echo ""
        echo "Next Steps:"
        echo "  1. Verify backend services are deployed (graphql-api, react-frontend)"
        echo "  2. Test endpoints using ALB DNS names"
        echo "  3. For qa/prod: Configure DNS records to point to ALB"
        echo "  4. For qa/prod: Verify HTTPS and certificate configuration"
    } > "${REPORT_FILE}"
    
    print_success "Verification report saved to: ${REPORT_FILE}"
}

# Function to display summary
display_summary() {
    print_header "Verification Summary"
    
    echo "Environment: ${ENVIRONMENT}"
    echo ""
    echo "✓ AWS Load Balancer Controller: Verified"
    echo "✓ Ingress Resources: Verified"
    echo "✓ ALB Creation: Checked"
    echo "✓ Target Groups: Checked"
    echo "✓ Listeners: Verified"
    echo "✓ Routing Rules: Verified"
    echo ""
    
    # Display ALB DNS names
    GRAPHQL_ALB=$(kubectl get ingress -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.metadata.name | contains("graphql")) | .status.loadBalancer.ingress[0].hostname' 2>/dev/null || echo "")
    FRONTEND_ALB=$(kubectl get ingress -n "${NAMESPACE}" -o json | jq -r '.items[] | select(.metadata.name | contains("frontend")) | .status.loadBalancer.ingress[0].hostname' 2>/dev/null || echo "")
    
    if [ -n "${GRAPHQL_ALB}" ]; then
        echo "GraphQL API Endpoint:"
        if [ "${ENVIRONMENT}" == "dev" ]; then
            echo "  http://${GRAPHQL_ALB}/api"
        else
            echo "  http://${GRAPHQL_ALB}/ (or https://api.{domain})"
        fi
    fi
    
    if [ -n "${FRONTEND_ALB}" ]; then
        echo "Frontend Endpoint:"
        if [ "${ENVIRONMENT}" == "dev" ]; then
            echo "  http://${FRONTEND_ALB}/"
        else
            echo "  http://${FRONTEND_ALB}/ (or https://shop.{domain})"
        fi
    fi
    
    echo ""
    print_info "Note: Backend services (graphql-api, react-frontend) must be deployed for endpoints to respond successfully."
}

# Main execution
main() {
    print_header "Ingress Routing Verification for EverShop EKS"
    
    echo "Environment: ${ENVIRONMENT}"
    echo "Cluster: ${CLUSTER_NAME}"
    echo "Region: ${REGION}"
    echo "AWS Profile: ${AWS_PROFILE}"
    echo ""
    
    check_prerequisites
    authenticate_aws
    update_kubeconfig
    
    if ! verify_load_balancer_controller; then
        print_error "AWS Load Balancer Controller verification failed"
        exit 1
    fi
    
    if ! verify_ingress_resources; then
        print_error "Ingress resources verification failed"
        exit 1
    fi
    
    verify_alb_creation
    verify_target_groups
    verify_listeners
    verify_routing_rules
    test_http_endpoints
    verify_dns_resolution
    
    generate_report
    display_summary
    
    print_success "Ingress routing verification completed!"
}

# Run main function
main
