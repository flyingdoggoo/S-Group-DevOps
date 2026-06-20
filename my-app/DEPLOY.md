# DEPLOY.md

Tài liệu này mô tả cách cấp quyền SSH vào EC2 cho thành viên mới một cách an toàn.

## 1. Mục tiêu

- Chỉ cho phép đúng người, đúng IP được SSH vào server.
- Không chia sẻ private key qua kênh không an toàn.
- Có thể thu hồi quyền nhanh khi cần.

## 2. Điều kiện trước khi cấp quyền

- Thành viên mới đã có tài khoản AWS (nếu cần truy cập Console).
- Đã bật MFA cho tài khoản AWS.
- Có IP public hiện tại của thành viên mới.
- Có kênh chia sẻ bí mật an toàn (AWS Secrets Manager, 1Password, Vault).

## 3. Quy trình cấp SSH cho thành viên mới

### Bước 1: Thêm IP vào Security Group

1. Vào `AWS Console -> EC2 -> Instances -> <instance>`.
2. Mở tab `Security` và bấm vào Security Group đang gắn với instance.
3. Chọn `Edit inbound rules`.
4. Thêm rule:
   - Type: `SSH`
   - Port: `22`
   - Source: `<teammate_public_ip>/32`
   - Description: `ssh-<teammate-name>`
5. Save rules.

Lưu ý:
- Không mở SSH `0.0.0.0/0`.
- Mỗi người một rule riêng để dễ audit và thu hồi.

### Bước 2: Cấp key an toàn

1. Không gửi file `.pem` qua email, chat, Slack.
2. Chia sẻ private key qua secret manager hoặc công cụ password manager có audit log.
3. Gửi kèm hướng dẫn bảo mật:
   - Không upload key lên GitHub.
   - Không lưu key ở thư mục public/shared drive.
   - Đặt quyền file key đúng:

```bash
chmod 400 training-key.pem
```

### Bước 3: Hướng dẫn lệnh SSH

```bash
ssh -i ~/path/to/training-key.pem ubuntu@<PUBLIC_IP>
```

## 4. Xác minh sau khi cấp quyền

Trên máy thành viên mới:

```bash
ssh -i ~/path/to/training-key.pem ubuntu@<PUBLIC_IP>
```

Trên server, kiểm tra log:

```bash
sudo tail -f /var/log/auth.log
```

Kỳ vọng:
- Có dòng `Accepted publickey for ubuntu from <teammate_ip>`.
- Không có đăng nhập bằng password.

## 5. Thu hồi quyền truy cập

Khi thành viên rời dự án hoặc không cần quyền nữa:

1. Xóa rule SSH IP của thành viên khỏi Security Group.
2. Rotate key nếu key đã được chia sẻ rộng.
3. Cập nhật danh sách người có quyền truy cập trong tài liệu nội bộ.

## 6. Checklist bảo mật nhanh

- [ ] SSH chỉ mở cho IP cụ thể (`/32`).
- [ ] Không gửi private key qua email/chat.
- [ ] Có log/audit cho việc chia sẻ secret.
- [ ] Kiểm tra `auth.log` định kỳ.
- [ ] Thu hồi quyền ngay khi không còn nhu cầu.
