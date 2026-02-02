# 1. GitHub OIDC Provider 생성
# 설명: AWS가 GitHub의 인증 토큰을 신뢰할 수 있도록 "신원 제공자(Identity Provider)"를 등록합니다.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.environment == "dev" ? 1 : 0

  # GitHub Actions의 OIDC 토큰 발급 주소 (이 주소에서 온 토큰만 믿겠다는 설정)
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]


  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
  tags = local.common_tags
}

# 설명: GitHub Actions가 AWS에 로그인했을 때 뒤집어쓸 "가면(Role)"을 만듭니다.
resource "aws_iam_role" "github_actions" {
  name = "github-actions-${local.cluster_name}"

  # [신뢰 정책] "누가" 이 Role을 사용할 수 있는지 정의합니다.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow" # 허용한다

        # [주체] 누구에게? -> 위에서 만든 GitHub OIDC Provider를 통해 인증된 사용자에게
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }

        # [행동] 무엇을? -> 웹 신원 토큰(WebIdentity)을 가지고 역할을 수행(AssumeRole)하는 것을
        Action = "sts:AssumeRoleWithWebIdentity"

        # [조건] 단, 아래 조건이 맞아야만 허용한다 (매우 중요! 보안 핵심)
        Condition = {
          # 토큰의 aud(audience)가 sts.amazonaws.com인지 확인
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # [핵심] 토큰의 sub(subject)가 특정 리포지토리인지 확인
          # 즉, "nomad-free" 사용자의 "k8s_ci_cd" 리포지토리에서 실행된 Action만 이 역할을 쓸 수 있음
          # 끝에 :*는 main 브랜치, PR 등 모든 트리거를 허용한다는 뜻
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:nomad-free/k8s_ci_cd:*"
          }
        }
      }
    ]
  })
  tags = local.common_tags
}

# 3. 정책 연결 1: ECR 접근 권한
# 설명: GitHub Actions가 도커 이미지를 빌드해서 ECR에 올릴(Push) 수 있게 허용합니다.
resource "aws_iam_role_policy" "ecr_access" {
  name = "ecr-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # [로그인 권한] ECR에 로그인하기 위한 인증 토큰을 발급받을 수 있음 (전체 리소스 대상)
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        # [이미지 조작 권한] 이미지를 업로드(Push)하거나 다운로드(Pull)하는 데 필요한 구체적 액션들
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
        # [대상 제한] 오직 특정 리포지토리(aws_ecr_repository.app)에만 접근 가능 (보안 강화)
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

# 4. 정책 연결 2: EKS 기본 접근 권한
# 설명: kubectl이 클러스터 정보를 조회할 수 있게 허용합니다.
resource "aws_iam_role_policy" "eks_access" {
  name = "eks-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # [클러스터 조회] 'aws eks update-kubeconfig' 명령어를 실행할 때 필요함
        # 클러스터의 엔드포인트나 인증 정보를 받아오기 위함
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = module.eks.cluster_arn
      }
    ]
  })
}

# 5. 정책 연결 3: Secrets Manager 접근 권한
# 설명: 배포 시 환경변수(DB비번 등)를 주입하기 위해 시크릿 값을 읽을 수 있게 허용합니다.
resource "aws_iam_role_policy" "secrets_access" {
  name = "secrets-manager-access"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue", # 시크릿 값 읽기 (핵심)
          "secretsmanager:DescribeSecret"  # 시크릿 메타데이터 조회
        ]
        # [대상 제한] 프로젝트 이름으로 시작하는 시크릿만 읽을 수 있음 (최소 권한 원칙)
        # 예: arn:aws:secretsmanager:us-east-1:123456789:secret:k8s-ci-cd/*
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${local.project_name}/*"
      }
    ]
  })
}


# [2025 New Standard] aws-auth ConfigMap 대신 Access Entry API 사용
# - Terraform AWS Provider v6.0 이상에서 지원
# 6. [NEW] EKS Access Entry 생성
# 설명: IAM Role을 쿠버네티스 유저로 매핑하는 최신 방식입니다. (aws-auth ConfigMap 대체)
resource "aws_eks_access_entry" "github_actions" {
  cluster_name  = module.eks.cluster_name         # 대상 EKS 클러스터
  principal_arn = aws_iam_role.github_actions.arn # 매핑할 IAM Role (GitHub Actions Role)
  type          = "STANDARD"
}

# 클러스터 관리자 권한(ClusterAdmin) 정책 연결
# 7. [NEW] EKS 접근 정책 연결
# 설명: 위에서 등록한 Access Entry에 "클러스터 관리자" 권한을 부여합니다.
resource "aws_eks_access_policy_association" "github_actions" {
  cluster_name = module.eks.cluster_name
  # AWS가 미리 만들어둔 관리자 정책 (ClusterAdmin)을 사용
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.github_actions.arn

  # 권한 범위 설정 (클러스터 전체)
  access_scope {
    type = "cluster"
  }
}
