output "environment" {
  description = "현재 환경"
  value       = var.environment
}
output "aws_region" {
  description = "AWS 리전"
  value       = var.aws_region
}
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
output "private_subnets" {
  description = "Private 서브넷 ID 목록"
  value       = module.vpc.private_subnets
}
output "public_subnets" {
  description = "Public 서브넷 ID 목록"
  value       = module.vpc.public_subnets
}
output "cluster_name" {
  description = "EKS 클러스터 이름"
  value       = module.eks.cluster_name
}
output "cluster_endpoint" {
  description = "EKS API 서버 엔드포인트"
  value       = module.eks.cluster_endpoint
}
output "cluster_arn" {
  description = "EKS 클러스터 ARN"
  value       = module.eks.cluster_arn
}
output "ecr_repository_url" {
  description = "ECR 레포지토리 URL (docker push 대상)"
  value       = aws_ecr_repository.app.repository_url
}
output "github_actions_role_arn" {
  description = "GitHub Actions용 IAM Role ARN"
  value       = aws_iam_role.github_actions.arn
}
output "app_secrets_arn" {
  description = "앱 시크릿 ARN"
  value       = aws_secretsmanager_secret.app.arn
}
output "external_secrets_role_arn" {
  description = "External Secrets용 IAM Role ARN"
  value       = module.external_secrets_irsa.iam_role_arn
}
output "configure_kubectl" {
  description = "kubectl 설정 명령어"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
output "ecr_login_command" {
  description = "ECR 로그인 명령어"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}"
}
output "app_domain" {
  description = "애플리케이션 도메인"
  value       = var.environment == "prod" ? var.domain_name : "${var.environment}.${var.domain_name}"
}
