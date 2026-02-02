variable "environment" {
  description = "배포 환경 (dev 또는 prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment는 'dev' 또는 'prod'만 가능합니다."
  }
}
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "us-east-1"
}
variable "domain_name" {
  description = "메인 도메인 (Cloudflare에서 관리)"
  type        = string
  default     = "playdevops.xyz"
}
variable "app_port" {
  description = "애플리케이션 포트"
  type        = number
  default     = 3000
}
variable "eks_cluster_version" {
  description = "EKS Kubernetes 버전"
  type        = string
  default     = "1.29"
}
locals {



  project_name = "k8s-ci-cd"
  cluster_name = "${local.project_name}-${var.environment}"





  vpc_config = {
    dev = {
      cidr            = "10.0.0.0/16"
      private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
      public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    }
    prod = {
      cidr            = "10.1.0.0/16"
      private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
      public_subnets  = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
    }
  }






  node_config = {
    dev = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
      capacity_type  = "SPOT"
    }
    prod = {
      instance_types = ["t3.large"]
      desired_size   = 2
      min_size       = 2
      max_size       = 5
      capacity_type  = "ON_DEMAND"
    }
  }



  env_config = {
    dev = {
      single_nat_gateway  = true
      deletion_protection = false
      ingress_replicas    = 1
    }
    prod = {
      single_nat_gateway  = false
      deletion_protection = true
      ingress_replicas    = 2
    }
  }



  common_tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
