# Phần 3.2 — Bài tập 2: Roll Out Phiên bản Backend Mới

Thực hành vòng lặp deploy mà bạn sẽ sử dụng mãi mãi về sau.

### Yêu cầu:
1. Thêm một trường (field) mới vào phản hồi (response) `/health` trong file `src/index.ts` (ví dụ: `version: "2"`).
2. Build lại và push image lên ECR với cả tag `:latest` và một tag duy nhất `:v2`.
3. Trong ECS, cập nhật task definition để sử dụng image có tag `:v2` → tạo một phiên bản (revision) mới.
4. Cập nhật service để sử dụng revision mới và quan sát quá trình rolling deploy trên console.
5. Xác nhận `curl .../health` trả về trường mới — mà URL không hề bị gián đoạn (nếu bạn dùng ALB) hoặc chỉ bị gián đoạn một chút (nếu dùng public IP trực tiếp).

---

## Hướng dẫn giải quyết & Giải thích

### Bước 1: Sửa mã nguồn
Mở file `src/index.ts` và tìm route xử lý `/health`. Sửa lại JSON trả về để thêm `version`.
```typescript
// Ví dụ thay đổi
app.get('/health', (req, res) => {
  res.json({ status: "ok", env: "production", version: "2" });
});
```

### Bước 2: Build và push lên ECR
Chạy các lệnh sau để build image mới, gắn tag và push lên registry:
```bash
# Build image mới
docker build --platform linux/amd64 -t cloud-training-backend .

# Gắn tag :v2
docker tag cloud-training-backend:latest "$ECR/cloud-training-backend:v2"
# Gắn lại tag :latest để ghi đè
docker tag cloud-training-backend:latest "$ECR/cloud-training-backend:latest"

# Push cả 2 tag lên ECR
docker push "$ECR/cloud-training-backend:v2"
docker push "$ECR/cloud-training-backend:latest"
```

### Bước 3: Cập nhật Task Definition
1. Truy cập AWS Console → **ECS** → **Task definitions**.
2. Chọn `cloud-training-backend`, ấn **Create new revision**.
3. Tại phần Container, sửa Image URI để sử dụng tag `:v2` thay vì `:latest` (ví dụ: `<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/cloud-training-backend:v2`).
4. Lưu và tạo revision mới.

**Tại sao dùng `:v2` thay vì `:latest`?** Dùng `:v2` giúp chúng ta kiểm soát chính xác phiên bản nào đang được chạy. Nếu có lỗi, chúng ta có thể rollback về `:v1` dễ dàng.

### Bước 4: Cập nhật Service
1. Quay lại Cluster `cloud-training`, vào tab **Services**.
2. Chọn service `backend`, ấn **Update**.
3. Chọn Task definition revision mới nhất vừa tạo ở Bước 3.
4. Tiến hành Update.
5. Trên giao diện, bạn sẽ thấy ECS bắt đầu "rolling deploy" - khởi động container mới, và khi container mới "healthy", nó sẽ tự động tắt container cũ.

### Bước 5: Kiểm tra kết quả
Trong khi deploy diễn ra (hoặc sau khi hoàn tất), chạy lệnh curl liên tục để kiểm tra:
```bash
curl http://<TASK_PUBLIC_IP_MOI>:3000/health
# curl http://13.250.172.157:3000/health
```
Kết quả mong đợi: `{"status":"ok","env":"production","version":"2"}`.
(Nếu bạn dùng ALB, bạn có thể gọi thẳng địa chỉ ALB mà không cần tìm IP mới).
