# Phần 2 — Tiêu chuẩn: Thực hành (Hands-On)

Mục tiêu: triển khai (deploy) **frontend lên S3** và **backend từ Session 1 lên ECS Fargate** thông qua ECR.

Chúng ta sẽ thêm một frontend nhỏ gọn vào project từ Session 1:

```text
my-app/
├── Dockerfile
├── compose.yaml
├── src/              # backend (Session 1)
└── frontend/
    └── index.html
```

**`frontend/index.html`:**
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <title>Cloud Training</title>
  </head>
  <body>
    <h1>Cloud Training — Frontend trên S3</h1>
    <p>Trạng thái Backend: <span id="status">đang kiểm tra…</span></p>
    <script>
      // Thay thế bằng ECS public IP/URL của bạn sau Phần 2.4
      const API_URL = window.API_URL || "http://localhost:3000";
      fetch(`${API_URL}/health`)
        .then((r) => r.json())
        .then((d) => (document.getElementById("status").textContent = JSON.stringify(d)))
        .catch((e) => (document.getElementById("status").textContent = "lỗi: " + e.message));
    </script>
  </body>
</html>
```

---

### 2.1 Triển khai Frontend lên S3

**Bước 1 — Tạo một bucket** (Tên bucket là duy nhất trên toàn cầu; hãy chọn một hậu tố riêng của bạn):

```bash
# Chọn region một lần và tái sử dụng nó
export AWS_REGION=ap-southeast-1
export BUCKET=cloud-training-frontend-nth-2026

aws s3 mb "s3://$BUCKET" --region "$AWS_REGION"
```

**Bước 2 — Bật tính năng static website hosting:**

```bash
aws s3 website "s3://$BUCKET/" \
  --index-document index.html \
  --error-document index.html
```

**Bước 3 — Cho phép quyền đọc công khai (public read).** Các bucket mới sẽ tự động chặn mọi quyền truy cập công khai. Để có một website công khai, chúng ta phải bỏ chặn và thêm một bucket policy.

```bash
# Bỏ chặn tính năng "block public access" cho bucket này
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
```

Tạo file **`bucket-policy.json`** (thay thế `BUCKET` bằng tên bucket thực tế của bạn):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET/*"
    }
  ]
}
```

```bash
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file://bucket-policy.json
```

**Bước 4 — Upload frontend:**

```bash
aws s3 sync ./frontend "s3://$BUCKET/"
```

**Bước 5 — Mở website.** URL endpoint của website S3 tuân theo một quy tắc cố định:

```text
http://<BUCKET>.s3-website-<REGION>.amazonaws.com
# ví dụ: http://cloud-training-frontend-ln-2026.s3-website-ap-southeast-1.amazonaws.com
```

```bash
echo "http://$BUCKET.s3-website-$AWS_REGION.amazonaws.com"
```

Mở URL đó trong trình duyệt. Bạn sẽ thấy trang web; phần trạng thái (health check) hiện tại sẽ báo `lỗi` (error) — chúng ta sẽ triển khai backend ngay sau đây.

> **Deploy lại frontend** đơn giản chỉ là chạy lại lệnh `aws s3 sync ./frontend "s3://$BUCKET/"`. Đó là toàn bộ "pipeline deploy" cho nội dung tĩnh.

---

### 2.2 Push Image của Backend lên ECR

ECS chỉ có thể chạy image từ một registry, vì vậy đầu tiên chúng ta phải push image từ Session 1 lên ECR.

**Bước 1 — Tạo repository:**

```bash
aws ecr create-repository \
  --repository-name cloud-training-backend \
  --region "$AWS_REGION"
```

**Bước 2 — Xác thực Docker với ECR:**

```bash
# ID tài khoản 12 chữ số của bạn
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR"
```

**Bước 3 — Build, tag, và push.** Fargate chạy trên kiến trúc `linux/amd64`; nếu bạn đang dùng máy Mac Apple Silicon, bạn bắt buộc phải build cho nền tảng này một cách tường minh:

```bash
docker build --platform linux/amd64 -t cloud-training-backend .

docker tag cloud-training-backend:latest "$ECR/cloud-training-backend:latest"

docker push "$ECR/cloud-training-backend:latest"
```

**Bước 4 — Xác nhận image đã được push thành công:**

```bash
aws ecr list-images --repository-name cloud-training-backend
```

---

### 2.3 Tạo một ECS Fargate Service (Qua Console)

Giao diện CLI của ECS khá dài dòng; **Trình thiết lập "Create" trong giao diện Console là cách nhanh nhất** cho lần deploy đầu tiên. (Phần Advanced 1 sẽ hướng dẫn dùng IaC).

1. AWS Console → **ECS** → **Clusters** → **Create cluster**.
   - **Tên (Name):** `cloud-training`
   - **Cơ sở hạ tầng (Infrastructure):** *AWS Fargate (serverless)* → **Create**.
2. **Task definitions** → **Create new task definition**.
   - **Family:** `cloud-training-backend`
   - **Launch type:** Fargate
   - **CPU:** `.25 vCPU`, **Memory:** `0.5 GB` (nhỏ nhất = rẻ nhất)
   - **Container:**
     - **Name:** `backend`
     - **Image URI:** dán `<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/cloud-training-backend:latest`
     - **Port mappings:** container port `3000`, protocol TCP
     - **Environment variables:** `NODE_ENV=production`
   - **Create**.
3. Mở cluster → **Services** → **Create**.
   - **Launch type:** Fargate
   - **Task definition:** `cloud-training-backend` (phiên bản mới nhất - latest revision)
   - **Service name:** `backend`
   - **Desired tasks:** `1`
   - **Networking:**
     - Sử dụng VPC và subnets mặc định
     - **Security group → Create new:** cho phép inbound **TCP 3000** từ `0.0.0.0/0` (chỉ dùng để test)
     - **Public IP:** *Bật (Turned on)* (để chúng ta có thể truy cập mà không cần load balancer)
   - **Create**.

ECS giờ sẽ pull image từ ECR và bắt đầu chạy một task.

---

### 2.4 Kiểm tra Backend Đã Triển Khai

1. Mở Cluster → **Tasks** → click vào task đang chạy → **Networking** → copy **Public IP**.

```bash
curl http://<TASK_PUBLIC_IP>:3000/health
# curl http://54.151.189.131:3000/health
# Kết quả mong đợi: {"status":"ok","env":"production"}
```

2. **Kết nối frontend với backend.** Thiết lập `API_URL` trong frontend thành public IP của task, tải lên lại và làm mới (refresh) trang:

```bash
# Cách nhanh: đưa URL vào thông qua một file cấu hình nhỏ mà trang sẽ đọc
echo "window.API_URL = 'http://<TASK_PUBLIC_IP>:3000';" > frontend/config.js
# echo "window.API_URL = 'http://54.151.189.131:3000';" > frontend/config.js
```

Thêm `<script src="config.js"></script>` **trước** thẻ script inline trong `index.html`, sau đó:

```bash
aws s3 sync ./frontend "s3://$BUCKET/"
```

Làm mới URL website S3 — dòng kiểm tra trạng thái bây giờ sẽ hiển thị dữ liệu JSON trực tiếp từ ECS.

🎉 Frontend trên S3, backend trên ECS, đang giao tiếp với nhau.

> **Lưu ý về việc thay đổi IP:** một task Fargate đơn thuần sẽ nhận một public IP mới mỗi khi deploy lại — điều này chấp nhận được cho demo, nhưng không thể chấp nhận trong production. Giải pháp là sử dụng **Application Load Balancer** (Advanced 2), nó cung cấp một tên miền DNS ổn định đứng trước các task.

---

### 2.5 Danh sách Lệnh Hữu ích

```bash
# --- S3 ---
aws s3 ls                                  # liệt kê các bucket
aws s3 ls "s3://$BUCKET/"                   # liệt kê các object
aws s3 sync ./frontend "s3://$BUCKET/"      # deploy frontend
aws s3 rm "s3://$BUCKET/" --recursive       # làm trống (xóa nội dung) bucket

# --- ECR ---
aws ecr list-images --repository-name cloud-training-backend
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR"

# --- ECS ---
aws ecs list-clusters
aws ecs list-services --cluster cloud-training
aws ecs list-tasks --cluster cloud-training
aws ecs describe-tasks --cluster cloud-training --tasks <TASK_ARN>

# Xem log container (nếu CloudWatch logging được bật trên task definition)
aws logs tail /ecs/cloud-training-backend --follow
```
