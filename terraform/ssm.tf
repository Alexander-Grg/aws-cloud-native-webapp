# VPC endpoints for SSM

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-2.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_2a.id, aws_subnet.subnet_2b.id, aws_subnet.subnet_2c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-2.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_2a.id, aws_subnet.subnet_2b.id, aws_subnet.subnet_2c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-2.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_2a.id, aws_subnet.subnet_2b.id, aws_subnet.subnet_2c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true

  tags = {
    Name = "ec2messages-endpoint"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.ap-southeast-2.s3"
  
  route_table_ids = [aws_route_table.main.id]
  
  tags = {
    Name = "s3-gateway-endpoint"
  }
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.ap-southeast-2.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_2a.id, aws_subnet.subnet_2b.id, aws_subnet.subnet_2c.id]
  security_group_ids  = [aws_security_group.vpc_endpoints_sg.id]
  private_dns_enabled = true
  tags = { Name = "cloudwatch-logs-endpoint" }
}