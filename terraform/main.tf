data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
data "aws_caller_identity" "current" {}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.4.0"
  name = "${local.cluster_name}-vpc"
  cidr = local.vpc_config[var.environment].cidr
  
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  
  private_subnets = local.vpc_config[var.environment].private_subnets
  public_subnets  = local.vpc_config[var.environment].public_subnets
  
  enable_nat_gateway     = true
  single_nat_gateway     = local.env_config[var.environment].single_nat_gateway
  one_nat_gateway_per_az = !local.env_config[var.environment].single_nat_gateway
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
  tags = local.common_tags
}
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"
  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  cluster_endpoint_public_access  = true    
  cluster_endpoint_private_access = true    
  
  
  
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
  }
  
  
  
  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }
  eks_managed_node_groups = {
    main = {
      name = "${local.cluster_name}-node"
      instance_types = local.node_config[var.environment].instance_types
      capacity_type  = local.node_config[var.environment].capacity_type
      min_size     = local.node_config[var.environment].min_size
      max_size     = local.node_config[var.environment].max_size
      desired_size = local.node_config[var.environment].desired_size
      labels = {
        Environment = var.environment
      }
      tags = {
        "k8s.io/cluster-autoscaler/enabled"               = "true"
        "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
      }
    }
  }
  
  enable_irsa = true
  
  manage_aws_auth_configmap = true
  tags = local.common_tags
}
resource "aws_ecr_repository" "app" {
  name                 = "${local.project_name}-app"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  encryption_configuration {
    encryption_type = "AES256"
  }
  tags = local.common_tags
}
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "최근 30개 이미지만 유지"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
