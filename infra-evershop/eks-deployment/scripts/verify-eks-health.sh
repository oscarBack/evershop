#!/bin/bash

# EKS Cluster Health Verification Script
# This script verifies the health and operational status of the EKS cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT="${1:-dev}"
CLUSTER_NAME="evershop-cluster"
AWS_REGION="us-east-1"
AWS_PROFILE="aws-evershop-${ENVIRONMENT}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}EKS Cluster Health Verification${NC}"
echo -e "${BLUE}Environment: ${ENVIRONMENT}${NC}"
echo -e "${BLUE}Cluster: ${CLUSTER_NAME}${NC}"
echo -e "${BLUE}Region: ${AWS_REGION}${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    print_success "AWS CLI is installed"
}

# Function to check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    print_success "kubectl is installed"
}

# Function to check AWS credentials
check_aws_credentials() {
    print_section "Checking AWS Credentials"
    
    if aws sts get-caller-identity --profile "${AWS_PROFILE}" &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --profile "${AWS_PROFILE}" --query Account --output text)
        print_success "AWS credentials are valid (Account: ${ACCOUNT_ID})"
    else
        print_error "AWS credentials are invalid or expired"
        print_warning "Run: aws sso login --profile ${AWS_PROFILE}"
        exit 1
    fi
}

# Function to check EKS cluster status
check_cluster_status() {
    print_section "Checking EKS Cluster Status"
    
    CLUSTER_STATUS=$(aws eks describe-cluster \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'cluster.status' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "${CLUSTER_STATUS}" == "ACTIVE" ]; then
        print_success "Cluster status: ${CLUSTER_STATUS}"
    elif [ "${CLUSTER_STATUS}" == "NOT_FOUND" ]; then
        print_error "Cluster not found: ${CLUSTER_NAME}"
        exit 1
    else
        print_error "Cluster status: ${CLUSTER_STATUS}"
        exit 1
    fi
}

# Function to check cluster version
check_cluster_version() {
    print_section "Checking Cluster Version"
    
    CLUSTER_VERSION=$(aws eks describe-cluster \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'cluster.version' \
        --output text)
    
    print_success "Kubernetes version: ${CLUSTER_VERSION}"
    
    # Check if version is 1.28 or later
    MAJOR_VERSION=$(echo "${CLUSTER_VERSION}" | cut -d. -f1)
    MINOR_VERSION=$(echo "${CLUSTER_VERSION}" | cut -d. -f2)
    
    if [ "${MAJOR_VERSION}" -eq 1 ] && [ "${MINOR_VERSION}" -ge 28 ]; then
        print_success "Version meets requirement (1.28+)"
    else
        print_warning "Version is below recommended (1.28+)"
    fi
}

# Function to check control plane logging
check_control_plane_logging() {
    print_section "Checking Control Plane Logging"
    
    ENABLED_LOGS=$(aws eks describe-cluster \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'cluster.logging.clusterLogging[?enabled==`true`].types[]' \
        --output text)
    
    REQUIRED_LOGS=("api" "audit" "authenticator" "controllerManager" "scheduler")
    
    for log_type in "${REQUIRED_LOGS[@]}"; do
        if echo "${ENABLED_LOGS}" | grep -q "${log_type}"; then
            print_success "Log type enabled: ${log_type}"
        else
            print_warning "Log type not enabled: ${log_type}"
        fi
    done
}

# Function to check OIDC provider
check_oidc_provider() {
    print_section "Checking OIDC Provider"
    
    OIDC_ISSUER=$(aws eks describe-cluster \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'cluster.identity.oidc.issuer' \
        --output text)
    
    if [ -n "${OIDC_ISSUER}" ]; then
        print_success "OIDC provider configured: ${OIDC_ISSUER}"
        
        # Extract OIDC ID
        OIDC_ID=$(echo "${OIDC_ISSUER}" | sed 's|https://||' | cut -d'/' -f2)
        
        # Check if OIDC provider exists in IAM
        if aws iam get-open-id-connect-provider \
            --open-id-connect-provider-arn "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}" \
            --profile "${AWS_PROFILE}" &> /dev/null; then
            print_success "OIDC provider exists in IAM"
        else
            print_warning "OIDC provider not found in IAM"
        fi
    else
        print_error "OIDC provider not configured"
    fi
}

# Function to check cluster endpoint access
check_endpoint_access() {
    print_section "Checking Cluster Endpoint Access"
    
    PUBLIC_ACCESS=$(aws eks describe-cluster \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'cluster.resourcesVpcConfig.endpointPublicAccess' \
        --output text)
    
    PRIVATE_ACCESS=$(aws eks describe-cluster \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'cluster.resourcesVpcConfig.endpointPrivateAccess' \
        --output text)
    
    print_success "Public endpoint access: ${PUBLIC_ACCESS}"
    print_success "Private endpoint access: ${PRIVATE_ACCESS}"
}

# Function to check encryption
check_encryption() {
    print_section "Checking Encryption Configuration"
    
    ENCRYPTION_CONFIG=$(aws eks describe-cluster \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'cluster.encryptionConfig[0].resources[]' \
        --output text)
    
    if [ -n "${ENCRYPTION_CONFIG}" ]; then
        print_success "Encryption enabled for: ${ENCRYPTION_CONFIG}"
    else
        print_warning "Encryption not configured"
    fi
}

# Function to update kubeconfig
update_kubeconfig() {
    print_section "Updating kubeconfig"
    
    aws eks update-kubeconfig \
        --name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" &> /dev/null
    
    print_success "kubeconfig updated"
}

# Function to check node groups
check_node_groups() {
    print_section "Checking Node Groups"
    
    NODE_GROUPS=$(aws eks list-nodegroups \
        --cluster-name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'nodegroups[]' \
        --output text)
    
    if [ -z "${NODE_GROUPS}" ]; then
        print_error "No node groups found"
        return
    fi
    
    for ng in ${NODE_GROUPS}; do
        echo -e "\n${YELLOW}Node Group: ${ng}${NC}"
        
        NG_STATUS=$(aws eks describe-nodegroup \
            --cluster-name "${CLUSTER_NAME}" \
            --nodegroup-name "${ng}" \
            --region "${AWS_REGION}" \
            --profile "${AWS_PROFILE}" \
            --query 'nodegroup.status' \
            --output text)
        
        NG_HEALTH=$(aws eks describe-nodegroup \
            --cluster-name "${CLUSTER_NAME}" \
            --nodegroup-name "${ng}" \
            --region "${AWS_REGION}" \
            --profile "${AWS_PROFILE}" \
            --query 'nodegroup.health.issues[]' \
            --output text)
        
        DESIRED=$(aws eks describe-nodegroup \
            --cluster-name "${CLUSTER_NAME}" \
            --nodegroup-name "${ng}" \
            --region "${AWS_REGION}" \
            --profile "${AWS_PROFILE}" \
            --query 'nodegroup.scalingConfig.desiredSize' \
            --output text)
        
        MIN=$(aws eks describe-nodegroup \
            --cluster-name "${CLUSTER_NAME}" \
            --nodegroup-name "${ng}" \
            --region "${AWS_REGION}" \
            --profile "${AWS_PROFILE}" \
            --query 'nodegroup.scalingConfig.minSize' \
            --output text)
        
        MAX=$(aws eks describe-nodegroup \
            --cluster-name "${CLUSTER_NAME}" \
            --nodegroup-name "${ng}" \
            --region "${AWS_REGION}" \
            --profile "${AWS_PROFILE}" \
            --query 'nodegroup.scalingConfig.maxSize' \
            --output text)
        
        if [ "${NG_STATUS}" == "ACTIVE" ]; then
            print_success "Status: ${NG_STATUS}"
        else
            print_error "Status: ${NG_STATUS}"
        fi
        
        if [ -z "${NG_HEALTH}" ]; then
            print_success "Health: No issues"
        else
            print_warning "Health issues: ${NG_HEALTH}"
        fi
        
        print_success "Scaling: Min=${MIN}, Desired=${DESIRED}, Max=${MAX}"
    done
}

# Function to check node readiness
check_node_readiness() {
    print_section "Checking Node Readiness"
    
    NODES=$(kubectl get nodes --no-headers 2>/dev/null || echo "")
    
    if [ -z "${NODES}" ]; then
        print_error "Unable to retrieve nodes (kubectl may not be configured)"
        return
    fi
    
    TOTAL_NODES=$(echo "${NODES}" | wc -l)
    READY_NODES=$(echo "${NODES}" | grep -c " Ready " || echo "0")
    NOT_READY_NODES=$(echo "${NODES}" | grep -c " NotReady " || echo "0")
    
    print_success "Total nodes: ${TOTAL_NODES}"
    print_success "Ready nodes: ${READY_NODES}"
    
    if [ "${NOT_READY_NODES}" -gt 0 ]; then
        print_error "Not ready nodes: ${NOT_READY_NODES}"
    fi
    
    echo -e "\n${YELLOW}Node Details:${NC}"
    kubectl get nodes -o wide 2>/dev/null || print_warning "Unable to get node details"
}

# Function to check core system pods
check_system_pods() {
    print_section "Checking Core System Pods (kube-system)"
    
    PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null || echo "")
    
    if [ -z "${PODS}" ]; then
        print_error "Unable to retrieve pods (kubectl may not be configured)"
        return
    fi
    
    TOTAL_PODS=$(echo "${PODS}" | wc -l)
    RUNNING_PODS=$(echo "${PODS}" | grep -c " Running " || echo "0")
    
    print_success "Total system pods: ${TOTAL_PODS}"
    print_success "Running pods: ${RUNNING_PODS}"
    
    # Check for critical components
    CRITICAL_COMPONENTS=("coredns" "kube-proxy" "aws-node")
    
    for component in "${CRITICAL_COMPONENTS[@]}"; do
        COMPONENT_PODS=$(echo "${PODS}" | grep "${component}" | grep -c " Running " || echo "0")
        if [ "${COMPONENT_PODS}" -gt 0 ]; then
            print_success "${component}: ${COMPONENT_PODS} pod(s) running"
        else
            print_error "${component}: No running pods found"
        fi
    done
    
    echo -e "\n${YELLOW}System Pod Status:${NC}"
    kubectl get pods -n kube-system 2>/dev/null || print_warning "Unable to get pod details"
}

# Function to test kubectl connectivity
test_kubectl_connectivity() {
    print_section "Testing kubectl Connectivity"
    
    if kubectl cluster-info &> /dev/null; then
        print_success "kubectl can connect to the cluster"
        kubectl cluster-info 2>/dev/null
    else
        print_error "kubectl cannot connect to the cluster"
    fi
}

# Function to check cluster add-ons
check_cluster_addons() {
    print_section "Checking Cluster Add-ons"
    
    ADDONS=$(aws eks list-addons \
        --cluster-name "${CLUSTER_NAME}" \
        --region "${AWS_REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'addons[]' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${ADDONS}" ]; then
        print_warning "No managed add-ons found"
        return
    fi
    
    for addon in ${ADDONS}; do
        ADDON_STATUS=$(aws eks describe-addon \
            --cluster-name "${CLUSTER_NAME}" \
            --addon-name "${addon}" \
            --region "${AWS_REGION}" \
            --profile "${AWS_PROFILE}" \
            --query 'addon.status' \
            --output text)
        
        if [ "${ADDON_STATUS}" == "ACTIVE" ]; then
            print_success "Add-on ${addon}: ${ADDON_STATUS}"
        else
            print_warning "Add-on ${addon}: ${ADDON_STATUS}"
        fi
    done
}

# Function to generate summary
generate_summary() {
    print_section "Verification Summary"
    
    echo -e "${GREEN}Cluster Health Check Complete${NC}\n"
    echo "Cluster Name: ${CLUSTER_NAME}"
    echo "Environment: ${ENVIRONMENT}"
    echo "Region: ${AWS_REGION}"
    echo "Timestamp: $(date)"
}

# Main execution
main() {
    check_aws_cli
    check_kubectl
    check_aws_credentials
    check_cluster_status
    check_cluster_version
    check_control_plane_logging
    check_oidc_provider
    check_endpoint_access
    check_encryption
    check_node_groups
    check_cluster_addons
    update_kubeconfig
    check_node_readiness
    check_system_pods
    test_kubectl_connectivity
    generate_summary
}

# Run main function
main
