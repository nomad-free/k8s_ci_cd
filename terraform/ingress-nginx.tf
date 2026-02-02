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
          "service.beta.kubernetes.io/aws-load-balancer-type"   = "external"
          "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
          # 3. 타겟 유형 (성능 핵심)
          # "ip": NLB가 트래픽을 노드(EC2)를 거치지 않고 "파드(Pod)의 IP"로 직접 꽂아줍니다.
          # - 장점: 지연 시간(Latency) 감소, 불필요한 네트워크 홉 제거.
          # - 조건: Amazon VPC CNI를 사용해야 함 (앞서 설정한 vpc-cni 설정과 연결됨).
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
          # 각 존(Zone) 간의 파드 개수 차이가 1개를 넘지 않도록 합니다. (균등 분배)
          maxSkew = 1
          # 파드들을 AWS의 **서로 다른 가용 영역(AZ, 예: ap-northeast-2a, 2c)**에 골고루 퍼뜨립니다.
          topologyKey = "topology.kubernetes.io/zone"
          # 만약 균등하게 배포할 수 없는 상황(예: 한쪽 존 장애)이라면, 억지로 한쪽에 몰아넣지 말고 "배포를 대기(Pending)" 시키라는 강력한 제약입니다. (상황에 따라 ScheduleAnyway를 쓰기도 하지만, 여기선 엄격한 HA를 추구함)
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
