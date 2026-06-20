# Session 2 Outcomes + Cleanup + Tài liệu đọc thêm

## Bạn nên đạt được gì sau buổi 2

| Kỹ năng | Standard | Advanced |
|---|---|---|
| Giải thích được Cloud, IaaS, VM | ✅ | ✅ |
| Hiểu IP, port, security group | ✅ | ✅ |
| Tạo EC2 với cấu hình hợp lý | ✅ | ✅ |
| SSH vào server bằng key pair | ✅ | ✅ |
| Cài Docker trên Ubuntu VM | ✅ | ✅ |
| Deploy Docker Compose lên VM public | ✅ | ✅ |
| Dùng Nginx/Caddy đứng trước app | ✅ | ✅ |
| Dùng domain riêng + HTTPS tự động |  | ✅ |
| Quản lý chi phí với budgets và EIP |  | ✅ |
| Làm vệ sinh vận hành cơ bản |  | ✅ |
| Nhận diện giá trị của IaC |  | ✅ |

## Cleanup rất quan trọng

Khi kết thúc buổi học, chọn một trong hai:

- **Stop instance**: giữ dữ liệu EBS, không tốn compute (phù hợp khi học tiếp ngày mai)
- **Terminate instance**: xoá toàn bộ tài nguyên compute (phù hợp khi học xong)

Ngoài ra:

- Release các **Elastic IP** không còn gắn tài nguyên để tránh phí idle.

## Tài liệu tham khảo

- [AWS EC2 - Getting started](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html)
- [AWS Free Tier limits](https://aws.amazon.com/free/)
- [Docker install on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [SSH essentials - DigitalOcean](https://www.digitalocean.com/community/tutorials/ssh-essentials-working-with-ssh-servers-clients-and-keys)
- [Caddy - Automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [Terraform - Get started on AWS](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)

## Gợi ý học tiếp

Sau khi xong buổi 2, bạn có thể làm mini-project:

1. Deploy lại app từ đầu trên một EC2 mới trong dưới 30 phút.
2. Gắn domain + HTTPS bằng Caddy.
3. Viết `DEPLOY.md` chuẩn hóa quy trình để đồng đội làm theo.
