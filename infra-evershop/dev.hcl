# EverShop Development Environment Variables

# Project Configuration
project_name = "evershop"
environment  = "dev"

# AWS Configuration
aws_region = "us-east-1"

# EKS Configuration
eks_version          = "1.28"
eks_instance_types   = ["t3.medium"]
eks_desired_capacity = 2
eks_min_capacity     = 1
eks_max_capacity     = 3

# RDS Configuration
rds_instance_class         = "db.t3.medium"
rds_allocated_storage      = 20
rds_engine_version         = "15.4"
rds_multi_az               = false
rds_backup_retention_period = 7

# VPC Configuration (optional - will use module VPC if empty)
vpc_id                 = ""
vpc_private_subnet_ids = []
vpc_public_subnet_ids  = []

# Common Tags
common_tags = {
  ManagedBy   = "Terraform"
  Organization = "EverShop"
  Environment = "dev"
  CostCenter  = "development"
}