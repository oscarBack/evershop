# Security Groups Configuration for EverShop EKS Deployment
# Task 3.3.1: Create security_groups.tf file

# =============================================================================
# EKS Node Security Group
# =============================================================================
# Allows traffic from ALB to EKS nodes and internal cluster communication

resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-${var.environment}"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "security-group"
    Name        = "${var.project_name}-eks-nodes-${var.environment}"
    Purpose     = "EKS worker nodes"
  })
}

# Ingress: HTTPS (443) from ALB security group
resource "aws_security_group_rule" "eks_nodes_ingress_alb_https" {
  security_group_id = aws_security_group.eks_nodes.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from ALB"
}

# Ingress: kubelet (10250) from EKS control plane
resource "aws_security_group_rule" "eks_nodes_ingress_kubelet" {
  security_group_id = aws_security_group.eks_nodes.id
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  description       = "Allow kubelet from EKS control plane"
}

# Ingress: DNS (53) from VPC CIDR
resource "aws_security_group_rule" "eks_nodes_ingress_dns" {
  security_group_id = aws_security_group.eks_nodes.id
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow DNS from VPC"
}

resource "aws_security_group_rule" "eks_nodes_ingress_dns_udp" {
  security_group_id = aws_security_group.eks_nodes.id
  type              = "ingress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow DNS (UDP) from VPC"
}

# Ingress: Ephemeral ports (1024-65535) from EKS nodes (node-to-node communication)
resource "aws_security_group_rule" "eks_nodes_ingress_ephemeral" {
  security_group_id = aws_security_group.eks_nodes.id
  type              = "ingress"
  from_port         = 1024
  to_port           = 65535
  protocol          = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  description       = "Allow ephemeral ports from self (node-to-node)"
}

# Ingress: NodePort services (30000-32767) from VPC
resource "aws_security_group_rule" "eks_nodes_ingress_nodeport" {
  security_group_id = aws_security_group.eks_nodes.id
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow NodePort services from VPC"
}

# Egress: All traffic to 0.0.0.0/0
resource "aws_security_group_rule" "eks_nodes_egress_all" {
  security_group_id = aws_security_group.eks_nodes.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all egress traffic"
}

# =============================================================================
# EKS Cluster Security Group
# =============================================================================
# Security group for EKS cluster control plane communication

resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster-${var.environment}"
  description = "Security group for EKS cluster control plane"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "security-group"
    Name        = "${var.project_name}-eks-cluster-${var.environment}"
    Purpose     = "EKS cluster control plane"
  })
}

# Ingress: Kubernetes API server (443) from EKS nodes
resource "aws_security_group_rule" "eks_cluster_ingress_nodes" {
  security_group_id = aws_security_group.eks_cluster.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  description       = "Allow API server access from worker nodes"
}

# Ingress: kubelet API from worker nodes
resource "aws_security_group_rule" "eks_cluster_ingress_kubelet" {
  security_group_id = aws_security_group.eks_cluster.id
  type              = "ingress"
  from_port         = 10250
  to_port           = 10250
  protocol          = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  description       = "Allow kubelet API from worker nodes"
}

# Egress: HTTPS to VPC (for API calls)
resource "aws_security_group_rule" "eks_cluster_egress_vpc" {
  security_group_id = aws_security_group.eks_cluster.id
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow HTTPS to VPC"
}

# =============================================================================
# RDS Security Group
# =============================================================================
# Allows PostgreSQL connections only from EKS nodes

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-${var.environment}"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "security-group"
    Name        = "${var.project_name}-rds-${var.environment}"
    Purpose     = "RDS PostgreSQL"
  })
}

# Ingress: PostgreSQL (5432) from EKS nodes only
resource "aws_security_group_rule" "rds_ingress_postgres" {
  security_group_id = aws_security_group.rds.id
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  description       = "Allow PostgreSQL from EKS worker nodes"
}

# Egress: None required (RDS doesn't initiate connections)
# By default, security groups allow all egress, we restrict it to none
resource "aws_security_group_rule" "rds_egress_none" {
  security_group_id = aws_security_group.rds.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Deny all egress (RDS doesn't initiate connections)"
}

# =============================================================================
# ALB Security Group
# =============================================================================
# Allows HTTP/HTTPS traffic from the internet to the ALB

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-${var.environment}"
  description = "Security group for Application Load Balancer"
  vpc_id      = module.vpc.vpc_id

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "security-group"
    Name        = "${var.project_name}-alb-${var.environment}"
    Purpose     = "Application Load Balancer"
  })
}

# Ingress: HTTP (80) from 0.0.0.0/0
resource "aws_security_group_rule" "alb_ingress_http" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP from anywhere"
}

# Ingress: HTTPS (443) from 0.0.0.0/0
resource "aws_security_group_rule" "alb_ingress_https" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS from anywhere"
}

# Egress: All traffic to EKS node security group
resource "aws_security_group_rule" "alb_egress_eks_nodes" {
  security_group_id = aws_security_group.alb.id
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  description       = "Allow traffic to EKS worker nodes"
}

# =============================================================================
# Security Group Outputs
# =============================================================================

output "eks_node_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = aws_security_group.eks_nodes.id
}

output "eks_cluster_security_group_id" {
  description = "Security group ID for EKS cluster control plane"
  value       = aws_security_group.eks_cluster.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS PostgreSQL"
  value       = aws_security_group.rds.id
}

output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  value       = aws_security_group.alb.id
}