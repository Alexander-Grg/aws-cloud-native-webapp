# RDS Database Instance - webapp-rds-instance
# trivy:ignore:aws-rds-enable-iam-authentication
resource "aws_db_instance" "webapp_rds_instance" {
  identifier     = "webapp-rds-instance"
  engine         = "postgres"
  engine_version = "17.6"
  instance_class = "db.t3.micro"

  db_name  = "webapp"
  username = "root"
  password = var.db_password
  port     = 5432

  # iam_database_authentication_enabled = true

  allocated_storage = 20
  storage_type      = "gp3" 
  storage_encrypted = true
  publicly_accessible  = false

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.webapp_db_subnet_group.name
  
  # Ignore for trivy, because backup retention is out of the FREE AWS Tier.
  # trivy:ignore:aws-rds-specify-backup-retention
  # backup_retention_period = 7
    # For production env should be false
  skip_final_snapshot     = true
    # For production env should be true
  deletion_protection     = false 

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  performance_insights_kms_key_id       = aws_kms_key.rds_pi_key.arn

  # Essential for Postgres health
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring_role.arn

tags = {
  Name        = "webapp-rds-instance"
  Role        = "db"
  Environment = var.environment
}
}

# Output the database endpoint
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.webapp_rds_instance.endpoint
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.webapp_rds_instance.port
}

output "db_connection_string" {
  description = "Connection string for local development"
  value       = "postgresql://root:${var.db_password}@${aws_db_instance.webapp_rds_instance.endpoint}/webapp"
  sensitive   = true
}

# Dynamo DB table

resource "aws_dynamodb_table" "webapp_messages" {
  name           = "webapp-messages"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "pk"
  range_key      = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "message_group_uuid"
    type = "S"
  }

  global_secondary_index {
    name            = "message-group-sk-index"
    hash_key        = "message_group_uuid"
    range_key       = "sk"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  server_side_encryption {
    enabled = true 
  }

  # deletion_protection_enabled = true

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "webapp-messages"
    Environment = var.environment
    Application = "webapp"
  }
}

# Output the table details
output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.webapp_messages.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.webapp_messages.arn
}

output "dynamodb_table_stream_arn" {
  description = "ARN of the DynamoDB table stream"
  value       = aws_dynamodb_table.webapp_messages.stream_arn
}

output "dynamodb_table_stream_label" {
  description = "Stream label of the DynamoDB table"
  value       = aws_dynamodb_table.webapp_messages.stream_label
}

# S3 Bucket
resource "aws_s3_bucket" "ansible_bucket" {
  bucket        = "ansible-ops-${data.aws_caller_identity.current.account_id}-${var.default_region}"
  force_destroy = true

  tags = {
    Name        = "Ansible Operations Bucket"
    Environment = "Production"
  }
}

resource "aws_s3_bucket_public_access_block" "ansible_bucket_access" {
  bucket = aws_s3_bucket.ansible_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ansible_bucket_crypto" {
  bucket = aws_s3_bucket.ansible_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.ansible_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ansible_bucket_cleanup" {
  bucket = aws_s3_bucket.ansible_bucket.id

  rule {
    id     = "expire-temp-files"
    status = "Enabled"
    filter {}

    expiration {
      days = 1
    }
  }
}

resource "aws_iam_role_policy" "ansible_s3_access" {
  name = "ansible_s3_transfer_policy"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3Access"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ansible_bucket.arn,
          "${aws_s3_bucket.ansible_bucket.arn}/*"
        ]
      },
      {
        Sid    = "AllowKMSDecryption"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.ansible_key.arn
        ]
      }
    ]
  })
}