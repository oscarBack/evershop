# Data Sources for EKS Deployment

# EKS Cluster Authentication (used by kubernetes/helm providers)
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# AWS Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# AWS Caller Identity
data "aws_caller_identity" "current" {}

# TLS Certificate for OIDC provider thumbprint
data "tls_certificate" "eks" {
  url = module.eks.cluster_oidc_issuer_url
}

# SSM Parameter for EKS optimized AMI
data "aws_ssm_parameter" "eks_ami" {
  name = "/aws/service/eks/optimized-ami/${var.eks_version}/amazon-linux-2/recommended/image_id"
}
