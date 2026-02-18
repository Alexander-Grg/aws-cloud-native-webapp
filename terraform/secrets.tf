resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "${var.project_name}-rds-credentials"

# I'm adding it because after TF destroy, secrets are not getting destroyed, and the next CI/CD run fails
  recovery_window_in_days = 0
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.webapp_rds_instance.username
    password = var.db_password
    host     = aws_db_instance.webapp_rds_instance.address
    port     = aws_db_instance.webapp_rds_instance.port
    dbname   = aws_db_instance.webapp_rds_instance.db_name
  })
}

resource "aws_iam_role_policy_attachment" "lambda_secrets_manager" {
  role       = aws_iam_role.webapp_post_confirmation_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}