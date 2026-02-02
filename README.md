AWS EKS에 애플리케이션을 자동 배포하는 CI/CD 파이프라인입니다.

````

| 구분                    | 기술                                   |
| ----------------------- | -------------------------------------- |
| 인프라                  | AWS EKS, VPC, ECR                      |
| IaC                     | Terraform                              |
| CI/CD                   | GitHub Actions                         |
| 컨테이너 오케스트레이션 | Kubernetes                             |
| 매니페스트 관리         | Kustomize                              |
| 시크릿 관리             | AWS Secrets Manager + External Secrets |
| Ingress                 | NGINX Ingress Controller               |
| DNS                     | Cloudflare                             |

---

```bash
terraform --version
aws --version
kubectl version
````

- AWS 계정 및 적절한 IAM 권한
- S3 버킷 (Terraform 상태 저장용): `plydevops-infra-tf-dev`
- GitHub 레포지토리: `play-builder/k8d_ci_cd`
- GitHub Secrets 설정 필요:
  - `AWS_ROLE_ARN`: Terraform 배포 후 출력되는 값
- 도메인: `playdevops.xyz`
- API Token (DNS 관리용)

---

```bash
git clone https://github.com/play-builder/k8d_ci_cd.git
cd k8d_ci_cd
```

```bash
cd terraform
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
terraform output github_actions_role_arn
```

GitHub 레포지토리 → Settings → Secrets and variables → Actions
| Secret 이름 | 값 |
| -------------- | -------------------------------------------- |
| `AWS_ROLE_ARN` | Terraform output의 `github_actions_role_arn` |

```bash
aws eks update-kubeconfig --region us-east-1 --name k8s-ci-cd-dev
kubectl get nodes
```

```bash
aws secretsmanager put-secret-value \
  --secret-id k8s-ci-cd/dev/app-secrets \
  --secret-string '{
    "DB_HOST": "your-db-host",
    "DB_PASSWORD": "your-password",
    "API_KEY": "your-api-key"
  }'
```

```bash
git checkout -b develop
git push origin develop
```

---

```bash
kubectl apply -k kustomize/overlays/dev/
kubectl apply -k kustomize/overlays/prod/
```

---

```
k8s-ci-cd/
├── dev/
│   ├── app-secrets
│   └── cicd-secrets
└── prod/
    ├── app-secrets
    └── cicd-secrets
```

```bash
aws secretsmanager put-secret-value \
  --secret-id k8s-ci-cd/dev/app-secrets \
  --secret-string '{"DB_HOST":"...", "DB_PASSWORD":"..."}'
aws secretsmanager get-secret-value \
  --secret-id k8s-ci-cd/dev/app-secrets \
  --query SecretString --output text | jq
```

---

```bash
aws eks update-kubeconfig --region us-east-1 --name k8s-ci-cd-dev
kubectl get pods -n app-dev -w
kubectl logs -f deployment/app -n app-dev
kubectl rollout undo deployment/app -n app-dev
cd kustomize/overlays/dev
kustomize edit set image app=123456789.dkr.ecr.us-east-1.amazonaws.com/k8s-ci-cd-app:v1.0.0
kubectl apply -k .
```



