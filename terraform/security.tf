# SECURITY GROUPS

# Lambda Security Group
resource "aws_security_group" "lambda_sg" {
  name        = "webapp-lambda-sg"
  description = "Security Group for Lambda functions"
  vpc_id      = aws_vpc.main.id

    egress {
    description = "AWS Services (S3, CloudWatch)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    prefix_list_ids = [
      data.aws_prefix_list.s3.id
    ]
  }

  egress {
    description = "PostgreSQL to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]  # Simpler: Allow to VPC
  }

  tags = {
    Name        = "webapp-lambda-sg"
    Environment = var.environment
  }
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "webapp-rds-sg"
  description = "Security Group for RDS PostgreSQL database"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  ingress {
    description     = "PostgreSQL from EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.EC2_SG.id]
  }

  egress {
    description     = "Allow responses to EC2"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.EC2_SG.id]
  }

  egress {
    description     = "Allow responses to Lambda"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  tags = {
    Name        = "webapp-rds-sg"
    Environment = var.environment
    Component   = "rds"
  }
}


# SG for EC2
# trivy:ignore:AVD-AWS-0104
resource "aws_security_group" "EC2_SG" {
  name        = "EC2_SG"
  description = "Security group for EC2 server"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

# For debugging
  # ingress {
  #   description = "ICMP from admin IP"
  #   from_port   = 8  # Echo Request
  #   to_port     = 0
  #   protocol    = "icmp"
  #   cidr_blocks = [var.admin_ip]
  # }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "post-srv-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Security Group for VPC Endpoints
# trivy:ignore:AVD-AWS-0104
resource "aws_security_group" "vpc_endpoints_sg" {
  name        = "vpc-endpoints-sg"
  description = "Security group for VPC endpoints (SSM, EC2Messages, SSMMessages)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

egress {
  description = "Allow HTTPS to AWS services"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"] 
}

  tags = {
    Name        = "vpc-endpoints-sg"
    Environment = var.environment
  }
}

# IAM ROLES

#  for the Session Manager (EC2 access)
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# for the RDS to send metrics to CloudWatch
resource "aws_iam_role" "rds_monitoring_role" {
  name = "rds-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring_attachment" {
  role       = aws_iam_role.rds_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_iam_role_policy_attachment" "ssm_core_policy" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# LAMBDA & COGNITO IAM

resource "aws_iam_role" "webapp_post_confirmation_role" {
  name = "webapp-post-confirmation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "webapp_post_confirmation_vpc_policy" {
  role       = aws_iam_role.webapp_post_confirmation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role" "messaging_stream_lambda_role" {
  name = "${var.function_name_webapp_messaging_stream}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.function_name_webapp_messaging_stream}-role"
    Environment = var.environment
  }
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "${var.function_name_webapp_messaging_stream}-dynamodb-policy"
  description = "Policy for Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:ListStreams"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.default_region}:${var.aws_account_id}:table/${var.dynamodb_table_name}",
          "arn:aws:dynamodb:${var.default_region}:${var.aws_account_id}:table/${var.dynamodb_table_name}/stream/*"
        ]
      }
    ]
  })
}



resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.messaging_stream_lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.messaging_stream_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "cognito_authenticated" {
  role       = aws_iam_role.authenticated.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonCognitoPowerUser"
}

# COGNITO
resource "aws_cognito_user_pool" "main" {
  name = "webapp-user-pool"

  username_attributes = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject = "Account Confirmation"
    email_message = "Your confirmation code is {####}"
  }

  schema {
    attribute_data_type = "String"
    name               = "name"
    required           = true
    mutable           = true
  }

  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable           = true
  }
  
  lambda_config {
    post_confirmation = aws_lambda_function.webapp_post_confirmation.arn
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name = "webapp-app-client"
  user_pool_id = aws_cognito_user_pool.main.id
  generate_secret = false
  
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_CUSTOM_AUTH"
  ]

  supported_identity_providers = ["COGNITO"]
  
  callback_urls = ["http://localhost:3000/signin"]
  logout_urls   = ["http://localhost:3000/signin"]
}

resource "aws_cognito_identity_pool" "main" {
  identity_pool_name               = "webapp-identity-pool"
  allow_unauthenticated_identities = true

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.client.id
    provider_name           = aws_cognito_user_pool.main.endpoint
    server_side_token_check = false
  }
}

resource "aws_iam_role" "authenticated" {
  name = "webapp-cognito-authenticated-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Federated = "cognito-identity.amazonaws.com" }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          "StringEquals" = {
            "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.main.id
          }
          "ForAnyValue:StringLike" = {
            "cognito-identity.amazonaws.com:amr" = "authenticated"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "authenticated_policy" {
  name = "webapp-authenticated-policy"
  role = aws_iam_role.authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mobileanalytics:PutEvents"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_secrets_access" {
  name = "lambda-secrets-access"
  role = aws_iam_role.webapp_post_confirmation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.rds_credentials.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "cognito_authenticated_limited" {
  name = "cognito-authenticated-limited"
  role = aws_iam_role.authenticated.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-identity:GetId",
          "cognito-identity:GetCredentialsForIdentity"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "main" {
  identity_pool_id = aws_cognito_identity_pool.main.id

  roles = {
    "authenticated" = aws_iam_role.authenticated.arn
  }
}

# KMS keys

# FOR S3 (Ansible)
resource "aws_kms_key" "ansible_key" {
  description             = "KMS key for Ansible S3 bucket encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "ansible_key_alias" {
  name          = "alias/ansible-bucket-key"
  target_key_id = aws_kms_key.ansible_key.key_id
}

# FOR RDS
resource "aws_kms_key" "rds_pi_key" {
  description             = "Encryption key for RDS Performance Insights"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "rds-pi-key"
  }
}

resource "aws_kms_alias" "rds_pi_key_alias" {
  name          = "alias/rds-performance-insights"
  target_key_id = aws_kms_key.rds_pi_key.key_id
}

# FOR SNS
resource "aws_kms_key" "sns_encryption_key" {
  description             = "KMS key for encrypting SNS topics"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  # This policy allows CloudWatch to use the key to send alerts
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Alarms to use the key"
        Effect = "Allow"
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "sns_key_alias" {
  name          = "alias/sns-alerts-key"
  target_key_id = aws_kms_key.sns_encryption_key.key_id
}

# OUTPUTS
output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "EC2_SG_id" {
  description = "ID of the post-srv-sg security group"
  value       = aws_security_group.EC2_SG.id
}

output "ssm_instance_profile_name" {
  description = "Name of the IAM instance profile for SSM"
  value       = aws_iam_instance_profile.ec2_ssm_profile.name
}

output "lambda_sg_id" {
  description = "ID of the Lambda security group"
  value       = aws_security_group.lambda_sg.id
}

output "rds_sg_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds_sg.id
}
