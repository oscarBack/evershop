# EKS Cluster Health - Quick Verification Reference

Quick reference for verifying EKS cluster health. For detailed instructions, see [VERIFICATION.md](./VERIFICATION.md).

## Prerequisites Check

```bash
# Check AWS CLI
aws --version

# Check kubectl
kubectl version --client

# Login to AWS SSO
aws sso login --profile aws-evershop-dev
```

## One-Line Health Checks

### Cluster Status
```bash
aws eks describe-cluster --name evershop-cluster --region us-east-1 --profile aws-evershop-dev --query 'cluster.status' --output text
```
✓ Expected: `ACTIVE`

### Cluster Version
```bash
aws eks describe-cluster --name evershop-cluster --region us-east-1 --profile aws-evershop-dev --query 'cluster.version' --output text
```
✓ Expected: `1.28` or higher

### Node Group Status
```bash
aws eks describe-nodegroup --cluster-name evershop-cluster --nodegroup-name evershop-ng --region us-east-1 --profile aws-evershop-dev --query 'nodegroup.status' --output text
```
✓ Expected: `ACTIVE`

### Node Readiness
```bash
kubectl get nodes --no-headers | awk '{print $2}' | grep -c "Ready"
```
✓ Expected: Number should match desired node count

### System Pods Health
```bash
kubectl get pods -n kube-system --no-headers | grep -c "Running"
```
✓ Expected: All pods should be Running

### API Server Health
```bash
kubectl get --raw /healthz
```
✓ Expected: `ok`

## Quick Verification Script

### PowerShell (Windows)
```powershell
.\infra-evershop\eks-deployment\scripts\Verify-EKSHealth.ps1 -Environment dev
```

### Bash (Linux/Mac)
```bash
./infra-evershop/eks-deployment/scripts/verify-eks-health.sh dev
```

## Critical Components Checklist

```bash
# Update kubeconfig first
aws eks update-kubeconfig --name evershop-cluster --region us-east-1 --profile aws-evershop-dev

# Check all critical components
kubectl get nodes                                    # All nodes Ready
kubectl get pods -n kube-system -l k8s-app=kube-dns # CoreDNS running
kubectl get pods -n kube-system -l k8s-app=kube-proxy # kube-proxy running
kubectl get pods -n kube-system -l k8s-app=aws-node  # VPC CNI running
```

## Environment-Specific Expected Values

| Check | Dev | QA | Prod |
|-------|-----|-----|------|
| Node Count | 2 | 3 | 5 |
| Instance Type | t3.medium | t3.large | m5.xlarge |
| Public Endpoint | true | true | false |
| Private Endpoint | true | true | true |

## Troubleshooting Quick Fixes

### Credentials Expired
```bash
aws sso login --profile aws-evershop-dev
```

### kubeconfig Not Updated
```bash
aws eks update-kubeconfig --name evershop-cluster --region us-east-1 --profile aws-evershop-dev
```

### Check Cluster Exists
```bash
aws eks list-clusters --region us-east-1 --profile aws-evershop-dev
```

## Success Criteria

✅ **Cluster is healthy when:**
- Cluster status: `ACTIVE`
- All nodes: `Ready`
- All system pods: `Running`
- kubectl connectivity: Working
- Control plane logs: Enabled (5 types)
- OIDC provider: Configured

## Next Steps After Verification

1. Deploy AWS Load Balancer Controller
2. Deploy Cluster Autoscaler
3. Deploy application workloads
4. Configure monitoring and alerting
5. Set up CI/CD pipelines
