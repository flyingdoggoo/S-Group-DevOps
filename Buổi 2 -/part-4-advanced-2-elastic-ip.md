# Part 4 - Advanced 2 - Elastic IP và lý do Public IP thay đổi

Mặc định, public IP của EC2 có thể đổi khi bạn `stop` rồi `start` instance.

- `Reboot` thường không đổi IP.
- `Stop/Start` có thể đổi IP.

Điều này làm DNS bị sai nếu domain đang trỏ vào IP cũ.

## Giải pháp: Elastic IP (EIP)

**Elastic IP** là IP public tĩnh bạn sở hữu trong tài khoản AWS và gắn vào instance.

```text
EC2 Console -> Elastic IPs -> Allocate Elastic IP address
            -> Actions -> Associate -> chọn instance
```

## Lưu ý chi phí

- EIP đang gắn vào instance: thường không bị tính thêm.
- EIP không gắn vào tài nguyên nào: có phí (khoảng ~$3.60/tháng theo mức tham khảo trong tài liệu gốc).

Nguyên tắc: dùng xong thì release EIP không còn dùng để tránh phí rác.

## Khi nào nên dùng EIP?

- Bạn cần IP cố định cho DNS/domain.
- Bạn có whitelist IP ở hệ thống đối tác.
- Bạn cần endpoint ổn định trong thời gian dài.

