# ✅ Kết quả của Session 3 (Session 3 Outcomes)

Vào cuối buổi học này, bạn có thể (có khả năng) đạt được:

| Kỹ năng | Cơ bản (Standard) | Nâng cao (Advanced) |
|---|---|---|
| Giải thích nội dung tĩnh vs động và lý do chia tách chúng | ✅ | ✅ |
| Mô tả kiến trúc frontend-static / backend-compute | ✅ | ✅ |
| Giải thích object storage (S3) là gì và không là gì | ✅ | ✅ |
| Host một frontend tĩnh trên S3 | ✅ | ✅ |
| Giải thích task / service / cluster trong ECS và Fargate | ✅ | ✅ |
| Push Docker image lên ECR | ✅ | ✅ |
| Chạy một container trên ECS Fargate và truy cập nó | ✅ | ✅ |
| Quản lý các cache header cho các file tài nguyên tĩnh (static assets) | ✅ | ✅ |
| Đặt một CDN (CloudFront) phía trước S3 + HTTPS | | ✅ |
| Đặt ALB phía trước ECS để có khả năng phục vụ ổn định trên nhiều task | | ✅ |
| Định tuyến frontend + backend dùng chung một domain (không dính lỗi CORS) | | ✅ |
| Viết script triển khai lặp lại được (Script a repeatable deploy) | | ✅ |

---

## 🧹 Dọn dẹp hệ thống (Quan trọng!)

S3, ECR và ECS đều tính phí cho các tài nguyên ở trạng thái chờ (idle resources). Khi bạn thực hành xong:

```bash
# Ngừng việc phải trả tiền cho container đang chạy: chỉnh service về 0 task, sau đó xóa
aws ecs update-service --cluster cloud-training --service backend --desired-count 0
aws ecs delete-service --cluster cloud-training --service backend --force
aws ecs delete-cluster --cluster cloud-training

# Xóa trắng (làm trống) nội dung + xóa S3 bucket
aws s3 rm "s3://$BUCKET/" --recursive
aws s3 rb "s3://$BUCKET"

# Xóa ECR image + repository
aws ecr delete-repository --repository-name cloud-training-backend --force
```

Đồng thời xóa bất kỳ **ALB**, **CloudFront distribution**, và **Elastic IPs** nào bạn đã tạo trong Phần 4 — Các bộ cân bằng tải (load balancers) và các điểm phân phối mạng (distributions) dù không làm gì cũng vẫn tính tiền thật.

---

## 📚 Đọc thêm (Further Reading)

- [Amazon S3 — Hosting Website tĩnh](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [Amazon ECR — Bắt đầu với CLI](https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html)
- [Amazon ECS trên Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Deploy container lên ECS — Hướng dẫn của AWS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/getting-started-fargate.html)
- [Amazon CloudFront — Phục vụ nội dung tĩnh từ S3](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/getting-started-cloudfront-overview.html)
- [Application Load Balancer với ECS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/service-load-balancing.html)
