# Input Variables for EKS Deployment

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
  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "Environment must be dev, qa, or prod."
  }
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy    = "Terraform"
    Organization = "EverShop"
    Project      = "evershop"
  }
}

# VPC
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "vpc_single_nat_gateway" {
  description = "Use single NAT Gateway (true for dev, false for qa/prod)"
  type        = bool
  default     = true
}

# EKS Cluster
variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "evershop-cluster"
}

variable "eks_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "eks_endpoint_public_access" {
  description = "Enable public endpoint access for EKS cluster"
  type        = bool
  default     = true
}

variable "eks_endpoint_private_access" {
  description = "Enable private endpoint access for EKS cluster"
  type        = bool
  default     = true
}

variable "eks_cluster_enabled_log_types" {
  description = "List of enabled log types for EKS control plane"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# EKS Node Group
variable "node_instance_types" {
  description = "EC2 instance types for EKS worker nodes"
  type        = list(string)
  default     = ["m5.large"]
}

variable "node_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
}

variable "node_min_capacity" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_max_capacity" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 6
}

variable "node_disk_size" {
  description = "EBS disk size in GB for worker nodes"
  type        = number
  default     = 100
}

# RDS
variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.r5.large"
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
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

variable "rds_db_name" {
  description = "Name of the database"
  type        = string
  default     = "evershop"
}

variable "rds_username" {
  description = "Master username for RDS"
  type        = string
  default     = "evershop_admin"
}

# Monitoring
variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 30
}
