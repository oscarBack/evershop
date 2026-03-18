# RDS PostgreSQL Configuration

# RDS Subnet Group
resource "aws_db_subnet_group" "evershop" {
  name       = "${var.project_name}-subnet-group-${var.environment}"
  subnet_ids = var.vpc_private_subnet_ids != [] ? var.vpc_private_subnet_ids : module.vpc.private_subnet_ids

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-subnet-group-${var.environment}"
    Environment = var.environment
  })
}

# RDS Parameter Group
resource "aws_db_parameter_group" "evershop" {
  name   = "${var.project_name}-pg-${var.environment}"
  family = "postgres${split(".", var.rds_engine_version)[0]}"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }
}

# RDS Instance (using terraform-aws-modules/rds/aws from registry)
module "rds_postgres" {
  source  = "terraform-aws-modules/rds/aws"
  version = "latest"

  identifier = "${var.project_name}-${var.environment}"

  # Engine configuration
  engine               = "postgres"
  engine_version       = var.rds_engine_version
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  storage_encrypted    = true
  storage_type         = "gp3"
  iops                 = 3000
  deletion_protection  = var.environment == "prod" ? true : false

  # Multi-AZ
  multi_az = var.rds_multi_az

  # Backup configuration
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "03:00-04:00"
  skip_final_snapshot     = var.environment == "dev" ? true : false
  final_snapshot_identifier = "${var.project_name}-final-snapshot-${var.environment}"

  # Maintenance
  maintenance_window      = "sun:04:00-sun:05:00"
  auto_minor_version_upgrade = true

  # Networking
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.evershop.name

  # Database name and credentials
  database_name  = "evershop"
  username       = "evershop_admin"
  password       = random_password.rds_password.result
  port           = 5432

  # Parameters
  parameter_group_name = aws_db_parameter_group.evershop.name

  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Performance insights
  enable_performance_insights = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id = aws_kms_key.rds_key.arn

  # Tags
  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-rds-${var.environment}"
    Environment = var.environment
  })
}

# RDS Password (random)
resource "random_password" "rds_password" {
  length  = 32
  special = false
}

# RDS Monitoring IAM Role
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# RDS KMS Key for encryption
resource "aws_kms_key" "rds_key" {
  description             = "${var.project_name}-rds-key-${var.environment}"
  key_usage               = "ENCRYPT_DECRYPT"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-rds-key-${var.environment}"
    Environment = var.environment
  })
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds_postgres.db_instance_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds_postgres.db_instance_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = "evershop"
}

output "rds_username" {
  description = "RDS username"
  value       = "evershop_admin"
  sensitive   = true
}

output "rds_password" {
  description = "RDS password"
  value       = random_password.rds_password.result
  sensitive   = true
}