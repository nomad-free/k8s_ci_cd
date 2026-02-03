data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.13.0"
  name    = "${local.cluster_name}-vpc"
  cidr    = local.vpc_config[var.environment].cidr

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = local.vpc_config[var.environment].private_subnets
  public_subnets  = local.vpc_config[var.environment].public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = local.env_config[var.environment].single_nat_gateway
  one_nat_gateway_per_az = !local.env_config[var.environment].single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "karpenter.sh/discovery" = local.cluster_name
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "karpenter.sh/discovery"                      = local.cluster_name
  }
  tags = local.common_tags
}
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "~> 20.31"
  cluster_name    = local.cluster_name
  cluster_version = var.eks_cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # [핵심] Terraform 실행 주체(IAM User/Role)에게 클러스터 관리자 권한 부여
  # 이 설정이 없으면 helm_release 등 K8s 리소스 생성 시 인증 에러 발생
  enable_cluster_creator_admin_permissions = false

  access_entries = {
    master_admin = {
      # 2. 계정 ID 부분을 변수(${...})로 처리합니다.
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/Master-Admin"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }


  kms_key_administrators = [
    # 1. 현재 이 Terraform을 실행하는 사람 (Bootstrap하는 개발자)
    data.aws_caller_identity.current.arn,

    # 2. 미래에 실행될 GitHub Actions Role (Prod) - 미리 문 열어두기
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-${local.project_name}-prod",

    # 3. 미래에 실행될 GitHub Actions Role (Dev) - 미리 문 열어두기
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/github-actions-${local.project_name}-dev"
  ]

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
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }
  eks_managed_node_groups = {
    main = {
      name           = "${local.cluster_name}-node"
      instance_types = local.node_config[var.environment].instance_types
      capacity_type  = local.node_config[var.environment].capacity_type

      min_size     = local.node_config[var.environment].min_size
      max_size     = local.node_config[var.environment].max_size
      desired_size = local.node_config[var.environment].desired_size

      labels = { Environment = var.environment }

      enable_irsa = true

      tags = {
        "k8s.io/cluster-autoscaler/enabled"               = "true"
        "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
      }
    }
  }

  enable_irsa = true

  # [중요] aws-auth ConfigMap 관리 기능이 모듈에서 제거되었습니다.
  # 대신 Access Entry API를 사용해야 합니다. (github-oidc.tf 참조)
  authentication_mode = "API_AND_CONFIG_MAP"
  tags                = local.common_tags
}

# EBS CSI 전용 IAM Role (IRSA)
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
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

# EKS 클러스터가 완전히 준비될 때까지 대기
# Helm 리소스들이 이 리소스에 depends_on으로 연결됩니다
resource "time_sleep" "wait_for_eks" {
  depends_on = [module.eks, aws_eks_access_entry.github_actions,
  aws_eks_access_policy_association.github_actions]

  create_duration = "60s"
}
