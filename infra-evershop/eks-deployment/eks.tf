# EKS Cluster Configuration

# KMS Key for cluster secrets encryption
resource "aws_kms_key" "eks" {
  description             = "${var.project_name}-eks-key-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-eks-key-${var.environment}"
    Environment = var.environment
    Component   = "eks"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-eks-${var.environment}"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch Log Group for EKS control plane
resource "aws_cloudwatch_log_group" "eks_control_plane" {
  name              = "/aws/eks/${var.eks_cluster_name}/cluster"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(var.common_tags, {
    Name        = "/aws/eks/${var.eks_cluster_name}/cluster"
    Environment = var.environment
    Component   = "eks"
  })
}

# EKS Cluster using Terraform Registry module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_version

  # Cluster endpoint access
  cluster_endpoint_public_access  = var.eks_endpoint_public_access
  cluster_endpoint_private_access = var.eks_endpoint_private_access

  # Networking
  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  # Cluster logging
  cluster_enabled_log_types = var.eks_cluster_enabled_log_types

  # Cluster encryption
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # IRSA
  enable_irsa = true

  # EKS Managed Node Group
  eks_managed_node_groups = {
    "${var.project_name}-ng" = {
      name            = "${var.project_name}-ng"
      use_name_prefix = true

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_capacity
      max_size     = var.node_max_capacity
      desired_size = var.node_desired_capacity

      disk_size = var.node_disk_size

      vpc_security_group_ids = [aws_security_group.eks_nodes.id]

      labels = {
        environment = var.environment
        workload    = var.project_name
      }

      tags = merge(var.common_tags, {
        Environment = var.environment
        Component   = "eks-nodegroup"
      })
    }
  }

  # Cluster tags
  tags = merge(var.common_tags, {
    Name        = var.eks_cluster_name
    Environment = var.environment
    Component   = "eks"
  })

  depends_on = [
    aws_cloudwatch_log_group.eks_control_plane,
  ]
}
