resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  # - K8s 1.34 호환성 확보 및 HTTP/3 지원 강화
  version          = "4.15.0"
  namespace        = "ingress-nginx"
  create_namespace = true
  values = [yamlencode({
    controller = {

      replicaCount = local.env_config[var.environment].ingress_replicas

      service = {
        type = "LoadBalancer"
        annotations = {
          # [2025 Best Practice] AWS Load Balancer Controller v3.x 호환 설정
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
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

      # [2025 표준] 고가용성을 위한 토폴로지 분산 제약 조건 추가
      topologySpreadConstraints = [
        {
          maxSkew           = 1
          topologyKey       = "topology.kubernetes.io/zone"
          whenUnsatisfiable = "DoNotSchedule"
          labelSelector = {
            matchLabels = {
              "app.kubernetes.io/name"      = "ingress-nginx"
              "app.kubernetes.io/component" = "controller"
            }
          }
        }
      ]
    }
  })]
  depends_on = [module.eks]
}
