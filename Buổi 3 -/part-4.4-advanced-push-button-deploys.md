# Phần 4.4 — Nâng cao 4: Tự động hóa quá trình Deploy (Push-Button Deploys) bằng AWS CLI

Việc click chuột thủ công qua trình hướng dẫn ECS có thể làm một lần cho biết. Nhưng để có một quy trình deploy ổn định và lặp lại được, bạn phải script hóa nó. Đây chính là bước đệm để tiến tới hệ thống CI/CD.

**`deploy.sh`:**
```bash
#!/usr/bin/env bash
set -euo pipefail

TAG="$(git rev-parse --short HEAD)"   # gắn tag image theo mã commit của git
IMAGE="$ECR/cloud-training-backend:$TAG"

# 1. Build + push image
docker build --platform linux/amd64 -t "$IMAGE" .
docker push "$IMAGE"

# 2. Đăng ký một task-definition revision mới trỏ tới image mới
NEW_TASK_DEF=$(aws ecs register-task-definition \
  --cli-input-json "$(sed "s|IMAGE_PLACEHOLDER|$IMAGE|" taskdef.json)" \
  --query 'taskDefinition.taskDefinitionArn' --output text)

# 3. Cập nhật service sang revision mới (ALB sẽ lo việc zero-downtime - không bị gián đoạn)
aws ecs update-service \
  --cluster cloud-training \
  --service backend \
  --task-definition "$NEW_TASK_DEF"

# 4. Tải lên (re-deploy) frontend
aws s3 sync ./frontend "s3://$BUCKET/"
echo "Đã triển khai thành công tag $TAG"
```

**Thử thách:** Chuyển đổi đoạn script này thành một **GitHub Actions** workflow được kích hoạt (trigger) mỗi khi có push lên nhánh `main`, sử dụng IAM role với OIDC (tránh sử dụng khóa AWS tĩnh sống thọ trong môi trường CI).
