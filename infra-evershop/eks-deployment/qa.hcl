project_name = "evershop"
environment  = "qa"
aws_region   = "us-east-1"

vpc_cidr               = "10.1.0.0/16"
vpc_single_nat_gateway = false

eks_cluster_name            = "evershop-cluster"
eks_version                 = "1.28"
eks_endpoint_public_access  = true
eks_endpoint_private_access = true

node_instance_types   = ["t3.large"]
node_desired_capacity = 3
node_min_capacity     = 3
node_max_capacity     = 6
node_disk_size        = 50

rds_instance_class          = "db.t3.small"
rds_allocated_storage       = 50
rds_engine_version          = "15.4"
rds_multi_az                = true
rds_backup_retention_period = 14

cloudwatch_log_retention_days = 14

domain_name         = "qa.evershop.example.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"

common_tags = {
  ManagedBy    = "Terraform"
  Organization = "EverShop"
  Environment  = "qa"
  CostCenter   = "testing"
}
