# CloudWatch Logs
import {
  to = aws_cloudwatch_log_group.webapp_fargate_cluster_managed
  id = "/webapp/fargate-cluster"
}

import {
  to = aws_cloudwatch_log_group.webapp_messaging_stream_logs
  id = "/aws/lambda/webapp-messaging-stream"
}

import {
  to = aws_cloudwatch_log_group.lambda_post_confirmation_logs
  id = "/aws/lambda/webapp-post-confirmation2"
}

# IAM Roles & Policies
import {
  to = aws_iam_role.messaging_stream_lambda_role
  id = "webapp-messaging-stream-role"
}

import {
  to = aws_iam_role.webapp_post_confirmation_role
  id = "webapp-post-confirmation-role"
}

import {
  to = aws_iam_role.ec2_ssm_role
  id = "ec2-ssm-role"
}

import {
  to = aws_iam_role.rds_monitoring_role
  id = "rds-enhanced-monitoring-role"
}

import {
  to = aws_iam_policy.lambda_dynamodb_policy
  id = "arn:aws:iam::735702561203:policy/webapp-messaging-stream-dynamodb-policy"
}

# Databases & Secrets
import {
  to = aws_dynamodb_table.webapp_messages
  id = "webapp-messages"
}

import {
  to = aws_db_subnet_group.webapp_db_subnet_group
  id = "webapp-db-subnet-group"
}

import {
  to = aws_secretsmanager_secret.rds_credentials
  id = "webapp-rds-credentials"
}

# KMS Aliases
import {
  to = aws_kms_alias.rds_pi_key_alias
  id = "alias/rds-performance-insights"
}

import {
  to = aws_kms_alias.sns_key_alias
  id = "alias/sns-alerts-key"
}