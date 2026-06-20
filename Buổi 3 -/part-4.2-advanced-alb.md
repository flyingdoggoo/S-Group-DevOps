# Phần 4.2 — Nâng cao 2: Application Load Balancer Đặt Trước ECS

Cách tiếp cận sử dụng "Public IP trực tiếp" sẽ bị lỗi mỗi lần chúng ta deploy lại ứng dụng. **Application Load Balancer (ALB)** cung cấp cho ECS một tên miền DNS ổn định, tự động kiểm tra trạng thái (health-check) các task của bạn, và cho phép bạn chạy nhiều task cùng một lúc.

```text
Trình duyệt ──► ALB (DNS ổn định, :443) ──► Target Group ──► ECS Tasks (N bản sao)
              │ kiểm tra sức khỏe /health         │
              └ loại bỏ các task gặp lỗi ─────────┘
```

**Các bước phác thảo:**
1. Tạo một ALB trong cùng một VPC, lắng nghe (listener) ở port `80` (và `443` kèm chứng chỉ ACM để dùng HTTPS).
2. Tạo một **Target Group** với kiểu là *IP* (Fargate sử dụng IP làm target), với đường dẫn health check là `/health`.
3. Trong ECS service, đính kèm load balancer → trỏ container `backend:3000` → tới target group.
4. Chỉnh sửa **desired tasks** (số lượng task mong muốn) thành `2` — ALB bây giờ sẽ phân bổ traffic đều qua cả hai task, và nếu có một task gặp sự cố, hệ thống vẫn phục vụ người dùng bình thường (không có downtime).
5. Thay đổi `API_URL` của frontend để trỏ vào tên miền DNS của ALB (bỏ qua việc phải quản lý từng IP của mỗi task riêng lẻ).

Đây là bước tiến lớn nhất giúp ứng dụng chuyển từ trạng thái "demo" sang một cấu hình sẵn sàng cho "production".
