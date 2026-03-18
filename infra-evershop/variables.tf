# Input Variables

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "evershop"
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
  default     = "dev"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Organization = "EverShop"
  }
}

# EKS Variables
variable "eks_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "eks_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "eks_max_capacity" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 5
}

# RDS Variables
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "rds_multi_az" {
  description = "Enable multi-AZ deployment for RDS"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period in days"
  type        = number
  default     = 7
}

# VPC Variables
variable "vpc_id" {
  description = "VPC ID for EKS cluster"
  type        = string
  default     = ""
}

variable "vpc_private_subnet_ids" {
  description = "Private subnet IDs for EKS"
  type        = list(string)
  default     = []
}

variable "vpc_public_subnet_ids" {
  description = "Public subnet IDs for EKS"
  type        = list(string)
  default     = []
}