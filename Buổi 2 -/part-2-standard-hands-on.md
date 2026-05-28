# Part 2 - Standard: Hands-On

## 2.1 Tạo EC2 Instance

**Mục tiêu:** tạo một VM thật trên AWS để chạy stack Docker Compose từ Session 1.

## Các bước thực hiện

1. Đăng nhập [AWS Console](https://console.aws.amazon.com/) -> tìm **EC2** -> **Launch instance**.
2. Điền thông tin:
   - **Name:** `training-session-2`
   - **AMI:** `Ubuntu Server 24.04 LTS` (Free Tier eligible)
   - **Instance type:** `t3.micro` (Free Tier eligible)
   - **Key pair:** tạo mới `training-key`, type `RSA`, format `.pem`, tải file về máy
   - **Network settings -> Edit:**
     - Allow SSH from **My IP**
     - Allow HTTP from Anywhere (`0.0.0.0/0`)
     - Allow HTTPS from Anywhere (`0.0.0.0/0`)
   - **Storage:** 8 GB `gp3` (mặc định)
3. Bấm **Launch instance**.

Sau khoảng 30 giây, trạng thái sẽ là `Running`.  
Hãy copy **Public IPv4 address** để dùng cho bước SSH.

## Lưu ý quan trọng cho người mới

- File `.pem` chỉ tải được một lần từ AWS, mất file này là phải tạo key mới.
- Nếu chọn sai region (ví dụ bạn đang học ở Singapore nhưng lại mở ở Tokyo), bạn sẽ “không thấy” instance vừa tạo.
- Nếu AWS báo không free tier, kiểm tra loại máy hoặc AMI đã đúng `Free Tier eligible` chưa.

---

## 2.2 SSH vào server

File `.pem` bạn tải về là private key để đăng nhập vào EC2.

## Kết nối SSH

```bash
## Chỉ chạy 1 lần: siết quyền file key
chmod 400 ~/Downloads/training-key.pem

## Kết nối (thay <PUBLIC_IP>)
ssh -i ~/Downloads/training-key.pem ubuntu@<PUBLIC_IP>
```

Lần đầu SSH sẽ hỏi xác nhận fingerprint host, gõ `yes`.

Nếu thành công, bạn sẽ thấy prompt kiểu:

```bash
ubuntu@ip-172-31-x-x:~$
```

## Kiểm tra nhanh sau khi đăng nhập

```bash
whoami
uname -a
df -h
free -h
```

Kỳ vọng:
- User là `ubuntu`
- OS là Linux
- Dung lượng disk khoảng 8GB
- RAM khoảng 1GB với `t3.micro`

## Lỗi thường gặp và cách xử lý

- `Permission denied (publickey)`:
  - Sai đường dẫn file `.pem`
  - Sai user (Ubuntu dùng `ubuntu`, không phải `ec2-user`)
  - File key chưa `chmod 400`
- `Connection timed out`:
  - Chưa mở port 22 trong Security Group
  - Rule 22 không cho đúng IP máy bạn

---

## 2.3 Cài Docker trên VM

Ubuntu repo mặc định thường có Docker cũ.  
Nên dùng repo chính thức của Docker để có bản mới và có sẵn Compose v2 plugin.

## Các lệnh cài đặt

```bash
## Cập nhật danh sách package
sudo apt-get update

## Cài gói cần thiết
sudo apt-get install -y ca-certificates curl gnupg

## Thêm GPG key chính thức của Docker
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

## Thêm Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

## Cài Docker Engine + Compose plugin
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

## Cho user ubuntu chạy docker không cần sudo
sudo usermod -aG docker ubuntu

## Đăng xuất và SSH lại để nhận group mới
exit
ssh -i ~/Downloads/training-key.pem ubuntu@<PUBLIC_IP>

## Kiểm tra
docker --version
docker compose version
docker run --rm hello-world
```

## Vì sao phải SSH lại?

Lệnh `usermod -aG docker ubuntu` thêm user vào group `docker`, nhưng phiên shell hiện tại chưa nhận group mới.  
`exit` rồi SSH lại để áp dụng.

## Lỗi thường gặp

- `docker: permission denied`: chưa SSH lại hoặc group chưa áp dụng.
- `docker compose: command not found`: thiếu `docker-compose-plugin`.

---

## 2.4 Chạy Docker Compose trên VM

**Mục tiêu:** đưa source từ Session 1 lên VM và chạy thành công qua Docker Compose.

## Cách đưa source lên VM

### Option A - Clone từ Git (khuyên dùng)

```bash
git clone https://github.com/<your-user>/<your-repo>.git my-app
cd my-app
```

### Option B - Copy từ laptop bằng `scp`

```bash
## Chạy trên LAPTOP, không chạy trên VM
scp -i ~/Downloads/training-key.pem -r ./my-app \
  ubuntu@<PUBLIC_IP>:/home/ubuntu/my-app
```

Sau đó trên VM:

```bash
cd ~/my-app
docker compose up -d --build
docker compose ps
docker compose logs -f app
```

## Mở cổng 3000 để test tạm thời

Vào AWS Console:

- EC2 -> chọn instance -> tab **Security** -> click Security Group
- **Edit inbound rules** -> Add rule
  - Type: Custom TCP
  - Port: `3000`
  - Source: `My IP`

Test từ máy local:

```bash
curl http://<PUBLIC_IP>:3000/health
## {"status":"ok","env":"development"}
```

Nếu ra JSON như trên là deploy thành công.

## Lưu ý quan trọng

- Chỉ mở `3000` tạm thời để kiểm tra.
- Bước bài tập sau sẽ đưa traffic qua Nginx/Caddy và đóng lại `3000`.

---

## 2.5 Bộ lệnh VM thường dùng

File này là cheat sheet ngắn để kiểm tra nhanh tình trạng máy và service.

## Theo dõi tài nguyên và process

```bash
htop                 # q để thoát (nếu chưa có: sudo apt install -y htop)
top
df -h                # dung lượng disk
free -h              # RAM
```

## Kiểm tra cổng đang lắng nghe

```bash
sudo ss -tulpn
```

## Xem log hệ thống Docker

```bash
journalctl -u docker --since "10 min ago"
```

## Copy file giữa laptop và VM

```bash
scp -i key.pem file.txt ubuntu@<IP>:/home/ubuntu/
scp -i key.pem ubuntu@<IP>:/home/ubuntu/file.txt ./
```

## Chạy lệnh từ xa không vào shell tương tác

```bash
ssh -i key.pem ubuntu@<IP> "docker compose ps"
```

## Mẹo cho người mới

- Khi app lỗi, luôn chạy theo thứ tự:
  1. `docker compose ps`
  2. `docker compose logs -f <service-name>`
  3. `sudo ss -tulpn`
- Nhìn `Up` trong `docker compose ps` chưa chắc app healthy, vẫn nên `curl` endpoint health.

