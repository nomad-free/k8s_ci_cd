resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.9.0"
  namespace        = "ingress-nginx"
  create_namespace = true
  values = [yamlencode({
    controller = {
      
      replicaCount = local.env_config[var.environment].ingress_replicas
      
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
        }
      }
      
      resources = {
        requests = {
          cpu    = var.environment == "prod" ? "200m" : "100m"
          memory = var.environment == "prod" ? "256Mi" : "128Mi"
        }
        limits = {
          cpu    = var.environment == "prod" ? "500m" : "200m"
          memory = var.environment == "prod" ? "512Mi" : "256Mi"
        }
      }
      
      metrics = {
        enabled = true
      }
    }
  })]
  depends_on = [module.eks]
}
