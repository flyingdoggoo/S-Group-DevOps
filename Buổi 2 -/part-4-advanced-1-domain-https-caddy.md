# Part 4 - Advanced 1 - Dùng Domain + HTTPS với Caddy

IP thô nhìn không chuyên nghiệp, và HTTP không mã hoá dữ liệu.  
Bạn có thể thêm HTTPS rất nhanh bằng Caddy.

## Điều kiện trước khi làm

- Có domain riêng (Cloudflare, Namecheap...)
- Có bản ghi DNS `A` trỏ `app.example.com` -> `<PUBLIC_IP>`
- Security Group mở port `80` và `443`

## Thay Nginx bằng Caddy trong `compose.yaml`

```yaml
services:
  caddy:
    image: caddy:2-alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - app
    restart: unless-stopped

  app:
    build: .
    expose:
      - "3000"
    # ... phần còn lại giữ nguyên

volumes:
  caddy_data:
  caddy_config:
```

## Tạo `Caddyfile`

```text
app.example.com {
  reverse_proxy app:3000
}
```

Chạy lại stack:

```bash
docker compose up -d
```

Sau đó truy cập `https://app.example.com`.

## Caddy làm gì cho bạn?

- Tự xin chứng chỉ TLS từ Let's Encrypt.
- Tự gia hạn chứng chỉ.
- Tự redirect HTTP -> HTTPS (mặc định trong nhiều trường hợp).

## Lỗi thường gặp

- DNS chưa trỏ đúng IP.
- Port 80/443 chưa mở.
- Dùng CDN/proxy DNS sai mode khiến challenge TLS thất bại.

