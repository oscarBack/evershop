# EKS Cluster Configuration
# Uses internal module: git@bitbucket.org:Coopeuch/terraform.git//modules/aws_eks

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

# EKS Cluster (ec2 sub-module)
module "eks" {
  source = "git@bitbucket.org:Coopeuch/terraform.git//modules/aws_eks/ec2?ref=modules/aws_eks/ec2-v1.4.5"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_version

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  control_plane_subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  cluster_endpoint_public_access  = var.eks_endpoint_public_access
  cluster_endpoint_private_access = var.eks_endpoint_private_access

  cluster_enabled_log_types = var.eks_cluster_enabled_log_types

  # KMS encryption for secrets
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # IRSA
  enable_irsa = true

  # Node group
  eks_managed_node_groups = {
    "${var.project_name}-ng" = {
      instance_types = var.node_instance_types
      ami_type       = "AL2_x86_64"

      min_size     = var.node_min_capacity
      max_size     = var.node_max_capacity
      desired_size = var.node_desired_capacity

      disk_size = var.node_disk_size

      iam_role_arn = aws_iam_role.eks_node_role.arn

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

  tags = merge(var.common_tags, {
    Name        = var.eks_cluster_name
    Environment = var.environment
    Component   = "eks"
  })

  depends_on = [
    aws_cloudwatch_log_group.eks_control_plane,
    aws_iam_role_policy_attachment.eks_node_worker,
    aws_iam_role_policy_attachment.eks_node_cni,
    aws_iam_role_policy_attachment.eks_node_ecr,
  ]
}
