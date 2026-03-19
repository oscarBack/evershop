# VPC Configuration using terraform-aws-modules/vpc/aws

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc-${var.environment}"
  cidr = var.vpc_cidr

  azs = var.availability_zones

  # 2 private subnets per AZ (compute + database)
  private_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, length(var.availability_zones) + i)]

  # Database subnets (separate from compute private subnets)
  database_subnets                   = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, length(var.availability_zones) * 2 + i)]
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # NAT Gateway - single for dev, one per AZ for qa/prod
  enable_nat_gateway     = true
  single_nat_gateway     = var.vpc_single_nat_gateway
  one_nat_gateway_per_az = !var.vpc_single_nat_gateway

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # EKS subnet tags required for ALB and node discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb"                                       = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                              = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }

  # VPC Flow Logs
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_iam_role             = true
  create_flow_log_cloudwatch_log_group            = true
  flow_log_cloudwatch_log_group_retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "vpc"
  })
}
