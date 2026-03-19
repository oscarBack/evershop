project_name = "evershop"
environment  = "prod"
aws_region   = "us-east-1"

vpc_cidr               = "10.2.0.0/16"
vpc_single_nat_gateway = false

eks_cluster_name            = "evershop-cluster"
eks_version                 = "1.28"
eks_endpoint_public_access  = false
eks_endpoint_private_access = true

node_instance_types   = ["m5.xlarge"]
node_desired_capacity = 5
node_min_capacity     = 5
node_max_capacity     = 10
node_disk_size        = 100

rds_instance_class          = "db.r5.large"
rds_allocated_storage       = 100
rds_engine_version          = "15.4"
rds_multi_az                = true
rds_backup_retention_period = 30

cloudwatch_log_retention_days = 30

domain_name         = "evershop.example.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"

common_tags = {
  ManagedBy    = "Terraform"
  Organization = "EverShop"
  Environment  = "prod"
  CostCenter   = "production"
}
