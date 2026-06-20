# Part 4 - Advanced 4 - Logs, Updates và Backups

Server thật cần ít nhất mức vận hành tối thiểu: log không đầy đĩa, có cập nhật bảo mật, có backup.

## 1) Giới hạn log Docker để tránh đầy ổ

```bash
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker
```

Ý nghĩa:
- Mỗi file log tối đa 10MB.
- Giữ 3 file gần nhất.
- Tránh trường hợp log phình to làm hết disk.

## 2) Bật cập nhật bảo mật tự động

```bash
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

Mục tiêu: tự động vá các gói bảo mật cơ bản.

## 3) Snapshot EBS để backup

```text
EC2 Console -> Volumes -> chọn volume -> Actions -> Create snapshot
```

Snapshot là ảnh chụp dữ liệu tại một thời điểm.  
Khi cần restore:

- Tạo volume mới từ snapshot.
- Attach volume đó vào instance.

## Thử thách thêm

- Tạo policy snapshot hằng ngày bằng **Amazon Data Lifecycle Manager** (qua Console, không cần code).

