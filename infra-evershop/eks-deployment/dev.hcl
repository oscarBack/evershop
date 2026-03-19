project_name = "evershop"
environment  = "dev"
aws_region   = "us-east-1"

vpc_cidr               = "10.0.0.0/16"
vpc_single_nat_gateway = true

eks_cluster_name            = "evershop-cluster"
eks_version                 = "1.28"
eks_endpoint_public_access  = true
eks_endpoint_private_access = true

node_instance_types   = ["t3.medium"]
node_desired_capacity = 2
node_min_capacity     = 2
node_max_capacity     = 4
node_disk_size        = 50

rds_instance_class          = "db.t3.micro"
rds_allocated_storage       = 20
rds_engine_version          = "15.4"
rds_multi_az                = false
rds_backup_retention_period = 7

cloudwatch_log_retention_days = 7

domain_name         = "dev.evershop.example.com"
acm_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERTIFICATE_ID"

common_tags = {
  ManagedBy    = "Terraform"
  Organization = "EverShop"
  Environment  = "dev"
  CostCenter   = "development"
}
