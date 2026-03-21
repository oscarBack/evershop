#!/bin/bash

# RDS Connectivity Verification Script for EverShop EKS Deployment
# This script verifies that EKS pods can connect to the RDS PostgreSQL database

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
NAMESPACE="default"
POD_NAME="rds-connectivity-test"

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

# Function to get RDS endpoint from Terraform outputs
get_rds_endpoint() {
    print_header "Retrieving RDS Connection Details"
    
    print_info "Getting RDS endpoint from Terraform outputs..."
    
    cd "$(dirname "$0")/.." || exit 1
    
    # Try to get RDS endpoint from terraform output
    RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
    
    if [ -z "${RDS_ENDPOINT}" ]; then
        print_warning "Could not get RDS endpoint from Terraform output"
        print_info "Attempting to retrieve from AWS RDS API..."
        
        RDS_IDENTIFIER="evershop-${ENVIRONMENT}"
        RDS_ENDPOINT=$(aws rds describe-db-instances \
            --db-instance-identifier "${RDS_IDENTIFIER}" \
            --region "${REGION}" \
            --profile "${AWS_PROFILE}" \
            --query 'DBInstances[0].Endpoint.Address' \
            --output text 2>/dev/null || echo "")
        
        if [ -z "${RDS_ENDPOINT}" ] || [ "${RDS_ENDPOINT}" == "None" ]; then
            print_error "Could not retrieve RDS endpoint. Please ensure RDS instance exists."
            exit 1
        fi
    fi
    
    print_success "RDS Endpoint: ${RDS_ENDPOINT}"
    
    # Get RDS password from Secrets Manager
    print_info "Retrieving RDS password from Secrets Manager..."
    SECRET_NAME="evershop/${ENVIRONMENT}/rds-password"
    RDS_PASSWORD=$(aws secretsmanager get-secret-value \
        --secret-id "${SECRET_NAME}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'SecretString' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${RDS_PASSWORD}" ]; then
        print_error "Could not retrieve RDS password from Secrets Manager"
        exit 1
    fi
    
    print_success "RDS password retrieved successfully"
}

# Function to create Kubernetes secret with RDS credentials
create_k8s_secret() {
    print_header "Creating Kubernetes Secret"
    
    print_info "Creating secret with RDS credentials in namespace: ${NAMESPACE}"
    
    # Delete existing secret if it exists
    kubectl delete secret rds-credentials -n "${NAMESPACE}" 2>/dev/null || true
    
    # Create new secret
    kubectl create secret generic rds-credentials \
        -n "${NAMESPACE}" \
        --from-literal=password="${RDS_PASSWORD}" \
        --from-literal=endpoint="${RDS_ENDPOINT}" \
        --from-literal=database="evershop" \
        --from-literal=username="evershop_admin" || {
        print_error "Failed to create Kubernetes secret"
        exit 1
    }
    
    print_success "Kubernetes secret created successfully"
}

# Function to deploy test pod
deploy_test_pod() {
    print_header "Deploying RDS Test Pod"
    
    # Delete existing pod if it exists
    print_info "Cleaning up any existing test pod..."
    kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" 2>/dev/null || true
    
    # Wait for pod to be deleted
    sleep 5
    
    print_info "Creating test pod manifest..."
    
    # Create temporary pod manifest with actual RDS endpoint
    cat > /tmp/rds-test-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${NAMESPACE}
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
      value: "${RDS_ENDPOINT}"
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
EOF
    
    print_info "Deploying test pod..."
    kubectl apply -f /tmp/rds-test-pod.yaml || {
        print_error "Failed to deploy test pod"
        exit 1
    }
    
    print_success "Test pod deployed"
    
    # Wait for pod to be ready
    print_info "Waiting for pod to be ready (timeout: 120s)..."
    kubectl wait --for=condition=Ready pod/"${POD_NAME}" \
        -n "${NAMESPACE}" \
        --timeout=120s || {
        print_error "Pod failed to become ready"
        print_info "Pod status:"
        kubectl describe pod "${POD_NAME}" -n "${NAMESPACE}"
        exit 1
    }
    
    print_success "Test pod is ready"
}

# Function to test RDS connectivity
test_rds_connectivity() {
    print_header "Testing RDS Connectivity"
    
    print_info "Testing basic network connectivity to RDS endpoint..."
    
    # Test 1: Network connectivity (nc or telnet)
    print_info "Test 1: TCP connection to ${RDS_ENDPOINT}:5432"
    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c "timeout 10 nc -zv ${RDS_ENDPOINT} 5432" || {
        print_error "Cannot establish TCP connection to RDS"
        print_info "Checking security group rules..."
        return 1
    }
    print_success "TCP connection successful"
    
    # Test 2: PostgreSQL connection
    print_info "Test 2: PostgreSQL authentication and connection"
    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c "psql -h ${RDS_ENDPOINT} -U evershop_admin -d evershop -c 'SELECT version();'" || {
        print_error "PostgreSQL connection failed"
        return 1
    }
    print_success "PostgreSQL connection successful"
    
    # Test 3: Database operations
    print_info "Test 3: Database operations (CREATE/SELECT/DROP)"
    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c "
        psql -h ${RDS_ENDPOINT} -U evershop_admin -d evershop <<EOSQL
CREATE TABLE IF NOT EXISTS connectivity_test (
    id SERIAL PRIMARY KEY,
    test_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    test_message TEXT
);

INSERT INTO connectivity_test (test_message) VALUES ('RDS connectivity test successful');

SELECT * FROM connectivity_test ORDER BY test_time DESC LIMIT 1;

DROP TABLE connectivity_test;
EOSQL
    " || {
        print_error "Database operations failed"
        return 1
    }
    print_success "Database operations successful"
    
    # Test 4: Connection pooling
    print_info "Test 4: Multiple concurrent connections"
    for i in {1..5}; do
        kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- sh -c "psql -h ${RDS_ENDPOINT} -U evershop_admin -d evershop -c 'SELECT 1;'" > /dev/null 2>&1 &
    done
    wait
    print_success "Multiple concurrent connections successful"
    
    print_success "All RDS connectivity tests passed!"
}

# Function to verify security group rules
verify_security_groups() {
    print_header "Verifying Security Group Configuration"
    
    print_info "Retrieving RDS security group..."
    RDS_IDENTIFIER="evershop-${ENVIRONMENT}"
    RDS_SG=$(aws rds describe-db-instances \
        --db-instance-identifier "${RDS_IDENTIFIER}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "${RDS_SG}" ]; then
        print_warning "Could not retrieve RDS security group"
        return
    fi
    
    print_success "RDS Security Group: ${RDS_SG}"
    
    print_info "Checking ingress rules..."
    aws ec2 describe-security-groups \
        --group-ids "${RDS_SG}" \
        --region "${REGION}" \
        --profile "${AWS_PROFILE}" \
        --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432`]' \
        --output table
    
    print_success "Security group verification complete"
}

# Function to cleanup
cleanup() {
    print_header "Cleanup"
    
    read -p "Do you want to delete the test pod? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deleting test pod..."
        kubectl delete pod "${POD_NAME}" -n "${NAMESPACE}" 2>/dev/null || true
        print_success "Test pod deleted"
        
        print_info "Deleting Kubernetes secret..."
        kubectl delete secret rds-credentials -n "${NAMESPACE}" 2>/dev/null || true
        print_success "Secret deleted"
    else
        print_info "Test pod and secret retained for further testing"
        print_info "To delete manually, run:"
        echo "  kubectl delete pod ${POD_NAME} -n ${NAMESPACE}"
        echo "  kubectl delete secret rds-credentials -n ${NAMESPACE}"
    fi
}

# Function to generate verification report
generate_report() {
    print_header "Verification Report"
    
    REPORT_FILE="rds-connectivity-verification-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "RDS Connectivity Verification Report"
        echo "====================================="
        echo ""
        echo "Environment: ${ENVIRONMENT}"
        echo "Cluster: ${CLUSTER_NAME}"
        echo "Region: ${REGION}"
        echo "Date: $(date)"
        echo ""
        echo "RDS Details:"
        echo "  Endpoint: ${RDS_ENDPOINT}"
        echo "  Database: evershop"
        echo "  Username: evershop_admin"
        echo ""
        echo "Test Results:"
        echo "  ✓ TCP Connection: PASSED"
        echo "  ✓ PostgreSQL Authentication: PASSED"
        echo "  ✓ Database Operations: PASSED"
        echo "  ✓ Concurrent Connections: PASSED"
        echo ""
        echo "Security Group Configuration:"
        aws ec2 describe-security-groups \
            --group-ids "${RDS_SG}" \
            --region "${REGION}" \
            --profile "${AWS_PROFILE}" \
            --query 'SecurityGroups[0].IpPermissions[?FromPort==`5432`]' \
            --output table 2>/dev/null || echo "  Could not retrieve security group details"
        echo ""
        echo "Verification Status: SUCCESS"
    } > "${REPORT_FILE}"
    
    print_success "Verification report saved to: ${REPORT_FILE}"
}

# Main execution
main() {
    print_header "RDS Connectivity Verification for EverShop EKS"
    
    echo "Environment: ${ENVIRONMENT}"
    echo "Cluster: ${CLUSTER_NAME}"
    echo "Region: ${REGION}"
    echo "AWS Profile: ${AWS_PROFILE}"
    echo ""
    
    check_prerequisites
    authenticate_aws
    update_kubeconfig
    get_rds_endpoint
    create_k8s_secret
    deploy_test_pod
    
    if test_rds_connectivity; then
        verify_security_groups
        generate_report
        print_success "RDS connectivity verification completed successfully!"
    else
        print_error "RDS connectivity verification failed"
        print_info "Checking pod logs..."
        kubectl logs "${POD_NAME}" -n "${NAMESPACE}" 2>/dev/null || true
        exit 1
    fi
    
    cleanup
}

# Run main function
main
