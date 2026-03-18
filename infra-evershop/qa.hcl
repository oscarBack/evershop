# EverShop QA Environment Variables

# Project Configuration
project_name = "evershop"
environment  = "qa"

# AWS Configuration
aws_region = "us-east-1"

# EKS Configuration
eks_version          = "1.28"
eks_instance_types   = ["t3.medium", "t3.large"]
eks_desired_capacity = 3
eks_min_capacity     = 2
eks_max_capacity     = 5

# RDS Configuration
rds_instance_class         = "db.t3.medium"
rds_allocated_storage      = 50
rds_engine_version         = "15.4"
rds_multi_az               = true
rds_backup_retention_period = 14

# VPC Configuration (optional - will use module VPC if empty)
vpc_id                 = ""
vpc_private_subnet_ids = []
vpc_public_subnet_ids  = []

# Common Tags
common_tags = {
  ManagedBy   = "Terraform"
  Organization = "EverShop"
  Environment = "qa"
  CostCenter  = "testing"
}