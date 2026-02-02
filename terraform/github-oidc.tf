resource "aws_iam_openid_connect_provider" "github" {
  count = var.environment == "dev" ? 1 : 0
  url = "https://token.actions.githubusercontent.com"
  
  client_id_list = ["sts.amazonaws.com"]
  
  
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
  tags = local.common_tags
}
resource "aws_iam_role" "github_actions" {
  name = "github-actions-${local.cluster_name}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            
            "token.actions.githubusercontent.com:sub" = "repo:applejjmango/eks_ci_cd:*"
          }
        }
      }
    ]
  })
  tags = local.common_tags
}
resource "aws_iam_role_policy" "ecr_access" {
  name = "ecr-access"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}
resource "aws_iam_role_policy" "eks_access" {
  name = "eks-access"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}
resource "aws_iam_role_policy" "secrets_access" {
  name = "secrets-manager-access"
  role = aws_iam_role.github_actions.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${local.project_name}/*"
      }
    ]
  })
}
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  force = true
  data = {
    mapRoles = yamlencode([
      
      {
        rolearn  = module.eks.eks_managed_node_groups["main"].iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
      
      {
        rolearn  = aws_iam_role.github_actions.arn
        username = "github-actions"
        groups   = ["system:masters"]
      }
    ])
  }
  depends_on = [module.eks]
}
