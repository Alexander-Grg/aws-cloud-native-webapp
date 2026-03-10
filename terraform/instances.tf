resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.subnet_2a.id
 
  vpc_security_group_ids = [aws_security_group.EC2_SG_Nginx.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

   root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 20
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

tags = {
  Name        = "app_server"
  Role        = "app"
  Environment = var.environment
}
}

# A policy for the EC2 role to read DynamoDB
resource "aws_iam_role_policy" "dynamodb_messages_access" {
  name = "DynamoDBMessagesAccessPolicy"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          "arn:aws:dynamodb:ap-southeast-2:735702561203:table/webapp-messages",
          "arn:aws:dynamodb:ap-southeast-2:735702561203:table/webapp-messages/index/*"
        ]
      }
    ]
  })
}