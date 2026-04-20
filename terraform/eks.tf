module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "webapp-cluster"
  cluster_version = "1.30"

  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.subnet_2a.id, aws_subnet.subnet_2b.id, aws_subnet.subnet_2c.id]

  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    app_nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"] 
      capacity_type  = "SPOT"
    }
  }

  node_security_group_additional_rules = {
    ingress_allow_alb_nodeports = {
      description              = "Allow ALB to route to NodePorts"
      protocol                 = "tcp"
      from_port                = 30000
      to_port                  = 32767
      type                     = "ingress"
      cidr_blocks              = [aws_vpc.main.cidr_block]
    }

    ingress_vpc_all = {
      description = "Allow all intra VPC traffic pod to pod communication"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [aws_vpc.main.cidr_block]
    }
  }
}

