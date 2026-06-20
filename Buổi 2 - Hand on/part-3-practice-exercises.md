# Part 3 - Practice Exercises

## Exercise 1 - Đặt Nginx phía trước App

Mục tiêu: dùng Nginx reverse proxy giống Session 1, nhưng lần này chạy trên EC2.

## Yêu cầu

1. Cập nhật `compose.yaml` trên VM để Nginx lắng nghe host port `80` và proxy đến service `app` nội bộ.
2. Gỡ publish host port `3000` của app (chỉ cho Nginx public ra ngoài).
3. Xóa rule mở port `3000` tạm thời trong Security Group.
4. Từ laptop, chạy `curl http://<PUBLIC_IP>/health` phải trả JSON đúng.
5. Từ laptop, chạy `curl http://<PUBLIC_IP>:3000/health` phải timeout hoặc không truy cập được.

## Gợi ý cấu hình

- Nginx nên có `depends_on: [app]`.
- App dùng `expose: "3000"` thay vì `ports`.
- Nginx proxy tới `http://app:3000`.

## Tiêu chí đạt bài

- Có thể truy cập app qua port 80.
- Không thể truy cập app trực tiếp qua port 3000 từ internet.
- Security Group sạch, không giữ rule test không cần thiết.

---

## Exercise 2 - Survive a Reboot

Mục tiêu: VM khởi động lại thì toàn bộ service vẫn tự lên, không cần thao tác thủ công.

## Nhiệm vụ

1. Thêm `restart: unless-stopped` vào từng service trong `compose.yaml`.
2. Reboot VM bằng lệnh:

```bash
sudo reboot
```

3. Chờ khoảng 30 giây, SSH vào lại.
4. Chạy:

```bash
docker compose ps
```

Tất cả service phải ở trạng thái `Up`.

5. Kiểm tra app từ trong VM:

```bash
curl http://localhost/health
```

## Vì sao bài này quan trọng?

Server thực tế sẽ có lúc reboot do:

- Update kernel
- Bảo trì hạ tầng cloud
- Sự cố hệ thống

Nếu service không tự lên lại, downtime sẽ xảy ra ngay cả khi app không hề lỗi code.

## Tiêu chí đạt bài

- Sau reboot, không cần chạy lại `docker compose up` mà app vẫn phục vụ bình thường.

---

## Exercise 3 - Lock Down SSH

Mục tiêu: giảm bề mặt tấn công cho server bằng cách giới hạn cổng SSH.

## Nhiệm vụ

1. Trong Security Group, xác nhận port `22` chỉ mở cho **My IP**, không mở `0.0.0.0/0`.
2. Trên VM, theo dõi log SSH trong 1 phút:

```bash
sudo tail -f /var/log/auth.log
```

Nếu mở 22 cho toàn internet, bạn thường thấy brute-force rất nhanh.  
Nếu đã lock down đúng, log sẽ yên tĩnh hơn nhiều.

3. Tạo file `DEPLOY.md` mô tả quy trình cấp SSH cho thành viên mới:
   - Thêm IP của họ vào Security Group
   - Chia sẻ key qua secret manager
   - Không gửi key qua email/Slack

## Tiêu chí đạt bài

- Rule SSH tối thiểu quyền.
- Có tài liệu vận hành đội nhóm (`DEPLOY.md`) rõ ràng, tái sử dụng được.

## Gợi ý thêm cho môi trường thật

- Bật MFA cho tài khoản AWS.
- Cân nhắc đổi sang AWS SSM Session Manager để giảm phụ thuộc SSH key.

