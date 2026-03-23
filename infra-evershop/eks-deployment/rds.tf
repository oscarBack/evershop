# RDS PostgreSQL Configuration
# Uses public Terraform Registry module: terraform-aws-modules/rds/aws

# KMS Key for RDS encryption
resource "aws_kms_key" "rds" {
  description             = "${var.project_name}-rds-key-${var.environment}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-rds-key-${var.environment}"
    Environment = var.environment
    Component   = "rds"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-rds-${var.environment}"
  target_key_id = aws_kms_key.rds.key_id
}

# Random password for RDS master user
resource "random_password" "rds" {
  length  = 32
  special = false
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "rds_password" {
  name                    = "${var.project_name}/${var.environment}/rds-password"
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-rds-secret-${var.environment}"
    Environment = var.environment
    Component   = "rds"
  })
}

resource "aws_secretsmanager_secret_version" "rds_password" {
  secret_id     = aws_secretsmanager_secret.rds_password.id
  secret_string = random_password.rds.result
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
    }]
  })

  tags = merge(var.common_tags, {
    Environment = var.environment
    Component   = "rds"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS PostgreSQL instance
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-${var.environment}"

  engine               = "postgres"
  engine_version       = var.rds_engine_version
  family               = "postgres${split(".", var.rds_engine_version)[0]}"
  major_engine_version = split(".", var.rds_engine_version)[0]
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  storage_type         = "gp3"
  storage_encrypted    = true
  kms_key_id           = aws_kms_key.rds.arn

  db_name  = var.rds_db_name
  username = var.rds_username
  password = random_password.rds.result
  port     = 5432

  multi_az               = var.rds_multi_az
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period   = var.rds_backup_retention_period
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  skip_final_snapshot       = var.environment == "dev" ? true : false
  final_snapshot_identifier = var.environment != "dev" ? "${var.project_name}-final-${var.environment}" : null
  deletion_protection       = var.environment == "prod" ? true : false

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  performance_insights_enabled    = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-rds-${var.environment}"
    Environment = var.environment
    Component   = "rds"
  })
}

# Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret containing RDS password"
  value       = aws_secretsmanager_secret.rds_password.arn
}
