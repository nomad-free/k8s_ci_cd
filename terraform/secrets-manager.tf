resource "aws_secretsmanager_secret" "app" {
  name                    = "${local.project_name}/${var.environment}/app-secrets"
  description             = "Application secrets (DB, API Key, JWT, Encryption) for ${var.environment}"
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  # [중요] 초기값은 더미(REPLACE_ME)입니다. 배포 후 AWS 콘솔에서 실제 값으로 변경해야 합니다.
  secret_string = jsonencode({
    DB_HOST     = "REPLACE_ME"
    DB_PORT     = "5432"
    DB_NAME     = "REPLACE_ME"
    DB_USER     = "REPLACE_ME"
    DB_PASSWORD = "REPLACE_ME"

    API_KEY    = "REPLACE_ME" # 서버 간 통신용 (M2M)
    API_SECRET = "REPLACE_ME"

    JWT_SECRET     = "REPLACE_ME" # 관리자 로그인 토큰 발급용
    ENCRYPTION_KEY = "REPLACE_ME" # 민감 데이터 DB 저장 시 암호화용 (32byte)
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "cicd" {
  name                    = "${local.project_name}/${var.environment}/cicd-secrets"
  description             = "CI/CD pipeline secrets for ${var.environment}"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "cicd" {
  secret_id = aws_secretsmanager_secret.cicd.id

  # CI/CD 전용 시크릿 (앱 시크릿과 다릅니다)
  secret_string = jsonencode({
    SLACK_WEBHOOK_URL    = "REPLACE_ME"
    CLOUDFLARE_API_TOKEN = "REPLACE_ME"
    CLOUDFLARE_ZONE_ID   = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}
resource "helm_release" "external_secrets" {
  name = "external-secrets"

  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  # - 성능 최적화 및 AWS Secrets Manager 연동 속도 개선
  version          = "0.12.1"
  namespace        = "external-secrets"
  create_namespace = true

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = "external-secrets"
    }
  })]
  depends_on = [time_sleep.wait_for_eks, module.external_secrets_irsa]
}

module "external_secrets_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  # [2025.09 출시] IAM Module v5.50.0
  version                        = "5.50.0"
  role_name                      = "${local.cluster_name}-external-secrets"
  attach_external_secrets_policy = true
  external_secrets_secrets_manager_arns = [
    aws_secretsmanager_secret.app.arn,
    aws_secretsmanager_secret.cicd.arn
  ]
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
  tags = local.common_tags
}

module "app_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.50.0"

  role_name = "${local.cluster_name}-secrets-manager"

  attach_external_secrets_policy = true
  external_secrets_secrets_manager_arns = [
    aws_secretsmanager_secret.app.arn
  ]

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = [
        "app-dev:app-sa",
        "app-prod:app-sa"
      ]
    }
  }

  tags = local.common_tags
}