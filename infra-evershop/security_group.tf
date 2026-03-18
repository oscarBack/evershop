# Security Groups Configuration

# EKS Security Group
resource "aws_security_group" "eks" {
  name        = "${var.project_name}-eks-${var.environment}"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : module.vpc.vpc_id

  # Allow all egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-eks-${var.environment}"
    Environment = var.environment
  })
}

# EKS Ingress Rules
resource "aws_security_group_rule" "eks_ingress_nodes" {
  security_group_id = aws_security_group.eks.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_id != "" ? module.vpc.vpc_cidr_block : "10.0.0.0/16"]
  description       = "Allow all traffic within VPC for node communication"
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-${var.environment}"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : module.vpc.vpc_id

  # Allow egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-rds-${var.environment}"
    Environment = var.environment
  })
}

# RDS Ingress Rules
resource "aws_security_group_rule" "rds_ingress_from_eks" {
  security_group_id = aws_security_group.rds.id
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  source_security_group_id = aws_security_group.eks.id
  description       = "Allow PostgreSQL from EKS nodes"
}

# Application Load Balancer Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-${var.environment}"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id != "" ? var.vpc_id : module.vpc.vpc_id

  # Allow HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-alb-${var.environment}"
    Environment = var.environment
  })
}

# ALB Ingress to EKS
resource "aws_security_group_rule" "alb_ingress_to_eks" {
  security_group_id = aws_security_group.eks.id
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description       = "Allow traffic from ALB to EKS node ports"
}