# Monitoring and Logging Configuration
# CloudWatch log groups for EverShop application components
# Note: EKS control plane log group is managed in eks.tf

# Log retention periods per environment (FR1.4, NFR6.1, FR8.1)
locals {
  log_retention_days_map = {
    dev  = 7
    qa   = 14
    prod = 30
  }

  log_retention_days = lookup(local.log_retention_days_map, var.environment, var.cloudwatch_log_retention_days)
}

# CloudWatch Log Group for GraphQL API application logs
resource "aws_cloudwatch_log_group" "graphql_api" {
  name              = "/aws/eks/evershop-${var.environment}/graphql-api"
  retention_in_days = local.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "/aws/eks/evershop-${var.environment}/graphql-api"
    Environment = var.environment
    Component   = "graphql-api"
    Project     = var.project_name
    ManagedBy   = "terraform"
  })
}

# CloudWatch Log Group for React Frontend application logs
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/aws/eks/evershop-${var.environment}/frontend"
  retention_in_days = local.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "/aws/eks/evershop-${var.environment}/frontend"
    Environment = var.environment
    Component   = "frontend"
    Project     = var.project_name
    ManagedBy   = "terraform"
  })
}

# CloudWatch Log Group for general EverShop application logs
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/evershop-${var.environment}/application"
  retention_in_days = local.log_retention_days

  tags = merge(var.common_tags, {
    Name        = "/aws/eks/evershop-${var.environment}/application"
    Environment = var.environment
    Component   = "application"
    Project     = var.project_name
    ManagedBy   = "terraform"
  })
}
