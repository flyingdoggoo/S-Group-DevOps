# Phần 4.5 — Nâng cao 5: Cơ sở hạ tầng dưới dạng mã (Infrastructure as Code - IaC) - (Bản Xem trước)

Giống như ví dụ sơ lược về Terraform ở Session 2, toàn bộ hệ thống bao gồm S3 + ECR + ECS + ALB đều có thể được khai báo bằng code. Tiêu chuẩn phổ biến trong cộng đồng đối với ECS là module [`terraform-aws-modules/ecs`](https://registry.terraform.io/modules/terraform-aws-modules/ecs/aws).

```hcl
# Những gì bạn sẽ định nghĩa, về mặt ý tưởng:
# - aws_s3_bucket          (hosting cho frontend)
# - aws_cloudfront_distribution
# - aws_ecr_repository     (nơi chứa image)
# - aws_ecs_cluster        (Fargate)
# - aws_ecs_task_definition
# - aws_ecs_service        (desired_count, đính kèm ALB)
# - aws_lb / aws_lb_target_group / aws_lb_listener
```

Bạn sẽ không phải tự viết những dòng này trong khóa học này, nhưng hãy nhận thức rõ lộ trình phát triển: **từ Console → tới script CLI → cuối cùng là Infrastructure as Code (Cơ sở hạ tầng bằng mã).** Mỗi bước tiến sẽ đánh đổi một chút sự tiện lợi tức thời ở hiện tại để đổi lấy độ ổn định và khả năng tái lập lại gần như hoàn hảo trong tương lai.
