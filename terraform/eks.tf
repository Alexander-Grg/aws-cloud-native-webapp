module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "webapp-cluster"
  cluster_version = "1.30"

  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.subnet_2a.id, aws_subnet.subnet_2b.id, aws_subnet.subnet_2c.id]

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    app_nodes = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"] 
      capacity_type  = "SPOT"
    }
  }
}