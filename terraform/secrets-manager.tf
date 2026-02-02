resource "aws_secretsmanager_secret" "app" {
  name        = "${local.project_name}/${var.environment}/app-secrets"
  description = "Application secrets for ${var.environment} environment"

  recovery_window_in_days = var.environment == "prod" ? 30 : 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DB_HOST     = "REPLACE_ME"
    DB_PORT     = "5432"
    DB_NAME     = "REPLACE_ME"
    DB_USER     = "REPLACE_ME"
    DB_PASSWORD = "REPLACE_ME"

    API_KEY    = "REPLACE_ME"
    API_SECRET = "REPLACE_ME"

    JWT_SECRET     = "REPLACE_ME"
    ENCRYPTION_KEY = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "aws_secretsmanager_secret" "cicd" {
  name                    = "${local.project_name}/${var.environment}/cicd-secrets"
  description             = "CI/CD secrets for ${var.environment} environment"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "cicd" {
  secret_id = aws_secretsmanager_secret.cicd.id

  # 주의: CI/CD 시크릿 키 값들이 app 시크릿과 동일하게 복사되어 있는 것 같습니다.
  # 실제 파일(secrets-manager.tf) 내용에 맞춰 SLACK_WEBHOOK 등으로 수정이 필요할 수 있습니다.
  secret_string = jsonencode({
    DB_HOST        = "REPLACE_ME"
    DB_PORT        = "5432"
    DB_NAME        = "REPLACE_ME"
    DB_USER        = "REPLACE_ME"
    DB_PASSWORD    = "REPLACE_ME"
    API_KEY        = "REPLACE_ME"
    API_SECRET     = "REPLACE_ME"
    JWT_SECRET     = "REPLACE_ME"
    ENCRYPTION_KEY = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  # - 성능 최적화 및 AWS Secrets Manager 연동 속도 개선
  version          = "0.12.0"
  namespace        = "external-secrets"
  create_namespace = true

  values = [yamlencode({
    installCRDs = true
    serviceAccount = {
      create = true
      name   = "external-secrets"
    }
  })]
  depends_on = [module.eks]
}

module "external_secrets_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  # [2025.09 출시] IAM Module v5.50.0
  version                        = "5.50.0"
  role_name                      = "${local.cluster_name}-external-secrets"
  attach_external_secrets_policy = true
  external_secrets_secrets_manager_arns = [
    aws_secretsmanager_secret.app.arn
  ]
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }
  tags = local.common_tags
}