resource "aws_secretsmanager_secret" "app" {
  name        = "${local.project_name}/${var.environment}/app-secrets"
  description = "${var.environment} 환경 애플리케이션 시크릿"
  
  recovery_window_in_days = var.environment == "prod" ? 30 : 7
  tags = local.common_tags
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
  name        = "${local.project_name}/${var.environment}/cicd-secrets"
  description = "${var.environment} 환경 CI/CD 시크릿"
  recovery_window_in_days = 7
  tags = local.common_tags
}
resource "aws_secretsmanager_secret_version" "cicd" {
  secret_id = aws_secretsmanager_secret.cicd.id
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
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.9.11"
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
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.32.0"
  role_name = "${local.cluster_name}-external-secrets"
  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = [
    aws_secretsmanager_secret.app.arn
  ]
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["app-${var.environment}:app-sa"]
    }
  }
  tags = local.common_tags
}
