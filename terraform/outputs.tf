output "environment" {
  description = "Current environment"
  value       = var.environment
}

output "aws_region" {
  description = "AWS Region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of Private Subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of Public Subnet IDs"
  value       = module.vpc.public_subnets
}

output "cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API Server Endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "EKS Cluster ARN"
  value       = module.eks.cluster_arn
}

output "ecr_repository_url" {
  description = "ECR Repository URL (target for docker push)"
  value       = aws_ecr_repository.app.repository_url
}

output "github_actions_role_arn" {
  description = "IAM Role ARN for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "app_secrets_arn" {
  description = "App Secrets ARN"
  value       = aws_secretsmanager_secret.app.arn
}

output "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets"
  value       = module.external_secrets_irsa.iam_role_arn
}

# [2025] Manual authentication configuration is no longer required due to Access Entry usage,
# but the kubeconfig update command is retained for convenience.
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}"
}

output "app_domain" {
  description = "Application Domain"
  value       = var.environment == "prod" ? var.domain_name : "${var.environment}.${var.domain_name}"
}

output "app_irsa_role_arn" {
  description = "IAM Role ARN for App ServiceAccount"
  value       = module.app_irsa.iam_role_arn
}
