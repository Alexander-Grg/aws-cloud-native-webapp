resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.subnet_2a.id
 
  vpc_security_group_ids = [aws_security_group.EC2_SG.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

   root_block_device {
    encrypted   = true
    volume_type = "gp3"
    volume_size = 8
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name = "app_server"
  }
}