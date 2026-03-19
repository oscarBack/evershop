# Output Values for EKS Deployment

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = module.vpc.database_subnet_group_name
}

# Security Group Outputs
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

# IAM Outputs
output "eks_node_iam_role_arn" {
  description = "ARN of the IAM role for EKS nodes"
  value       = aws_iam_role.eks_node_role.arn
}

output "graphql_api_irsa_role_arn" {
  description = "ARN of the IAM role for GraphQL API service account (IRSA)"
  value       = aws_iam_role.graphql_api.arn
}

output "frontend_irsa_role_arn" {
  description = "ARN of the IAM role for Frontend service account (IRSA)"
  value       = aws_iam_role.frontend.arn
}

output "monitoring_irsa_role_arn" {
  description = "ARN of the IAM role for Monitoring service account (IRSA)"
  value       = aws_iam_role.monitoring.arn
}

output "cluster_autoscaler_iam_role_arn" {
  description = "ARN of the IAM role for Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "aws_load_balancer_controller_iam_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

# CloudWatch Log Group Outputs
output "cloudwatch_log_group_graphql_api" {
  description = "CloudWatch log group name for GraphQL API"
  value       = aws_cloudwatch_log_group.graphql_api.name
}

output "cloudwatch_log_group_frontend" {
  description = "CloudWatch log group name for React Frontend"
  value       = aws_cloudwatch_log_group.frontend.name
}

output "cloudwatch_log_group_application" {
  description = "CloudWatch log group name for general application logs"
  value       = aws_cloudwatch_log_group.application.name
}

# Ingress Outputs
output "graphql_api_ingress_hostname" {
  description = "Hostname of the GraphQL API ALB ingress"
  value       = try(kubernetes_ingress_v1.graphql_api.status[0].load_balancer[0].ingress[0].hostname, null)
}

output "react_frontend_ingress_hostname" {
  description = "Hostname of the React Frontend ALB ingress"
  value       = try(kubernetes_ingress_v1.react_frontend.status[0].load_balancer[0].ingress[0].hostname, null)
}

# AWS Load Balancer Controller
output "aws_load_balancer_controller_release_name" {
  description = "Helm release name of the AWS Load Balancer Controller"
  value       = module.aws_load_balancer_controller.release_name
}

# ACM Certificate
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate attached to the ALB ingress"
  value       = var.acm_certificate_arn
}

# ECR Outputs
output "ecr_graphql_api_repository_url" {
  description = "URL of the ECR repository for GraphQL API"
  value       = aws_ecr_repository.graphql_api.repository_url
}

output "ecr_graphql_api_repository_arn" {
  description = "ARN of the ECR repository for GraphQL API"
  value       = aws_ecr_repository.graphql_api.arn
}

output "ecr_react_frontend_repository_url" {
  description = "URL of the ECR repository for React Frontend"
  value       = aws_ecr_repository.react_frontend.repository_url
}

output "ecr_react_frontend_repository_arn" {
  description = "ARN of the ECR repository for React Frontend"
  value       = aws_ecr_repository.react_frontend.arn
}
