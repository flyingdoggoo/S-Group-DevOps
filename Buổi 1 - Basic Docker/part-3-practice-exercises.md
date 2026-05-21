# Part 3 - Practice Exercises

> Mục tiêu: luyện hai kỹ năng production rất hay gặp: đặt reverse proxy trước app và debug container khi app lỗi. Phần này có yêu cầu, gợi ý, lời giải mẫu, lỗi thường gặp và cách triển khai production.

## 1. Bối cảnh bài tập

Ta bắt đầu từ stack ở Part 2:

```text
browser/curl -> app:3000
app -> db:5432
app -> redis:6379
```

Trong production, thường không để client gọi thẳng app container. Ta đặt reverse proxy ở trước:

```text
internet -> reverse proxy:80/443 -> app:3000
app -> db:5432
app -> redis:6379
```

Reverse proxy có thể là Nginx, Caddy, Traefik, Envoy, cloud load balancer hoặc ingress controller. Bài này dùng Nginx vì dễ hiểu.

## 2. Exercise 1 - Thêm Nginx reverse proxy

### Yêu cầu

1. Thêm service `nginx` dùng image `nginx:alpine`.
2. Host chỉ publish port `80`.
3. App không publish port ra host nữa, chỉ expose port nội bộ `3000`.
4. Tạo config Nginx proxy request đến service `app`.
5. Mount config vào container Nginx dạng read-only.
6. Nginx start sau khi app healthy.
7. Verify `curl http://localhost/health` trả JSON từ app.

## 3. Vì sao cần reverse proxy?

Reverse proxy đứng giữa client và app:

```text
Client -> Nginx -> app
```

Nó thường xử lý:

- Nhận traffic public ở port `80/443`.
- TLS termination.
- Routing nhiều domain/path về nhiều app.
- Header chuẩn như `X-Forwarded-For`, `X-Forwarded-Proto`.
- Compression, static files, request size limit.
- Basic rate limiting hoặc access control.
- Blue/green hoặc canary ở hệ thống lớn.

App container chỉ cần nghe private port trong Docker network.

## 4. Tạo file Nginx config

Tạo `nginx.conf`:

```nginx
events {}

http {
  upstream app_backend {
    server app:3000;
  }

  server {
    listen 80;
    server_name _;

    location / {
      proxy_pass http://app_backend;

      proxy_http_version 1.1;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
    }
  }
}
```

Giải thích:

| Dòng | Ý nghĩa |
|---|---|
| `upstream app_backend` | Đặt tên backend pool |
| `server app:3000` | Gọi service Compose tên `app` ở port 3000 |
| `listen 80` | Nginx nghe HTTP port 80 trong container |
| `proxy_pass` | Chuyển request đến app |
| `proxy_set_header` | Giữ thông tin request gốc cho app |

## 5. Compose lời giải mẫu

`compose.yaml`:

```yaml
services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      app:
        condition: service_healthy

  app:
    build: .
    expose:
      - "3000"
    environment:
      NODE_ENV: development
      PORT: 3000
      DATABASE_URL: postgres://user:password@db:5432/mydb
      REDIS_URL: redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:18
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s

  redis:
    image: redis:8-alpine
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s

volumes:
  pg_data:
  redis_data:
```

### `ports` khác `expose` thế nào?

`ports` publish port ra host:

```yaml
ports:
  - "80:80"
```

Máy host truy cập được `localhost:80`.

`expose` chỉ ghi nhận port nội bộ cho các container cùng network:

```yaml
expose:
  - "3000"
```

Host không gọi trực tiếp được `localhost:3000`, nhưng `nginx` gọi được `app:3000`.

## 6. Chạy và kiểm tra

Start stack:

```bash
docker compose up -d --build
```

Xem trạng thái:

```bash
docker compose ps
```

Test:

```bash
curl http://localhost/health
```

Kỳ vọng:

```json
{"status":"ok","env":"development"}
```

Xem log Nginx:

```bash
docker compose logs -f nginx
```

Reload sau khi sửa `nginx.conf`:

```bash
docker compose exec nginx nginx -s reload
```

Nếu mount config sai và Nginx không start:

```bash
docker compose logs nginx
docker compose exec nginx nginx -t
```

## 7. Lỗi thường gặp trong Exercise 1

### Nginx proxy đến `localhost:3000`

Sai:

```nginx
proxy_pass http://localhost:3000;
```

Trong container Nginx, `localhost` là chính container Nginx. App nằm ở service `app`.

Đúng:

```nginx
proxy_pass http://app:3000;
```

### Vẫn publish app ra host

Không nên để:

```yaml
app:
  ports:
    - "3000:3000"
```

Nếu đã có reverse proxy, app chỉ cần:

```yaml
app:
  expose:
    - "3000"
```

### Mount nhầm path config Nginx

Image `nginx:alpine` mặc định đọc `/etc/nginx/nginx.conf`. Nếu mount file server block riêng, thường mount vào `/etc/nginx/conf.d/default.conf`. Hai cách đều được, nhưng path phải đúng với nội dung config.

Ví dụ chỉ mount server block:

```nginx
server {
  listen 80;

  location / {
    proxy_pass http://app:3000;
  }
}
```

Mount:

```yaml
volumes:
  - ./default.conf:/etc/nginx/conf.d/default.conf:ro
```

### Healthcheck app dùng tool không tồn tại

`node:24` thường có nhiều tool hơn, nhưng image runtime tối giản có thể không có `wget` hoặc `curl`. Nếu healthcheck dùng:

```yaml
test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
```

mà container không có `wget`, healthcheck sẽ fail dù app chạy tốt.

Cách xử lý:

- Dùng base image có tool cần thiết.
- Cài tool rất tối thiểu.
- Viết healthcheck bằng Node script nếu phù hợp.
- Để orchestrator gọi HTTP health endpoint bên ngoài thay vì Dockerfile healthcheck, tùy platform.

### `depends_on` không thay thế retry trong app

`depends_on.condition: service_healthy` giúp thứ tự start tốt hơn, nhưng production app vẫn nên có retry/backoff khi kết nối database. Database có thể restart sau khi app đã chạy.

## 8. Exercise 2 - Debugging containers

### Mục tiêu

Bạn cần biết debug theo luồng:

```text
container có chạy không?
-> log nói gì?
-> config/env đúng không?
-> network gọi được không?
-> process trong container là gì?
-> filesystem có file cần thiết không?
```

### Tạo container lỗi

Ví dụ:

```bash
docker run -d --name broken-app \
  -e DATABASE_URL=wrong_url \
  my-app:dev
```

Nếu app mẫu chưa thật sự connect database lúc start, `DATABASE_URL=wrong_url` có thể chưa làm container crash. Trong app thật, lỗi này thường xuất hiện khi app validate config hoặc connect database khi boot.

Bạn có thể tạo lỗi chắc chắn hơn bằng cách chạy command sai:

```bash
docker run -d --name broken-app my-app:dev node missing-file.js
```

Hoặc dùng port đã bị chiếm:

```bash
docker run -d --name app-1 -p 3000:3000 my-app:dev
docker run -d --name app-2 -p 3000:3000 my-app:dev
```

Container thứ hai sẽ lỗi publish port.

## 9. Debug checklist

### 1. Container còn chạy không?

```bash
docker ps
docker ps -a
```

Nếu status là `Exited`, xem exit code:

```bash
docker inspect broken-app --format='{{.State.ExitCode}}'
```

Exit code thường gặp:

| Exit code | Ý nghĩa thường gặp |
|---|---|
| `0` | Process kết thúc bình thường |
| `1` | App tự báo lỗi |
| `125` | Docker daemon không chạy được container |
| `126` | Command không executable |
| `127` | Command không tồn tại |
| `137` | Bị kill, thường do OOM hoặc `SIGKILL` |
| `143` | Nhận `SIGTERM`, thường do stop/restart |

### 2. Xem logs

```bash
docker logs broken-app
docker logs --tail 100 broken-app
docker logs -f broken-app
```

Với Compose:

```bash
docker compose logs -f app
```

App production nên log ra stdout/stderr để các lệnh này và platform logging đọc được.

### 3. Inspect container

```bash
docker inspect broken-app
```

Lọc thông tin:

```bash
docker inspect broken-app --format='{{json .Config.Env}}'
docker inspect broken-app --format='{{json .NetworkSettings.Networks}}'
docker inspect broken-app --format='{{.Path}} {{json .Args}}'
```

Trên PowerShell, quote có thể khó hơn. Nếu lỗi quote, dùng:

```powershell
docker inspect broken-app
```

rồi đọc JSON đầy đủ.

### 4. Vào shell container đang chạy

```bash
docker exec -it broken-app sh
```

Kiểm tra:

```sh
pwd
ls -la
env
ps aux
```

Nếu container đã exit, không `exec` được. Dùng image đó để mở shell mới:

```bash
docker run --rm -it --entrypoint sh my-app:dev
```

### 5. Test network trong Compose

```bash
docker compose exec app sh
```

Trong shell:

```sh
getent hosts db
getent hosts redis
```

Nếu có `wget`:

```sh
wget -qO- http://localhost:3000/health
```

Nếu cần kiểm tra port:

```sh
nc -vz db 5432
nc -vz redis 6379
```

Không phải image nào cũng có `nc`.

### 6. Kiểm tra health status

```bash
docker inspect --format='{{json .State.Health}}' <container_name>
```

Nếu có `jq`:

```bash
docker inspect --format='{{json .State.Health}}' <container_name> | jq
```

## 10. Debug theo triệu chứng

### App không truy cập được từ host

Kiểm tra:

```bash
docker compose ps
docker compose logs app
docker compose logs nginx
```

Câu hỏi:

- Service nào publish port?
- App có listen `0.0.0.0` hay chỉ `127.0.0.1`?
- Nginx proxy đúng service name chưa?
- Host port có bị process khác chiếm không?

Node/Express thường listen all interfaces nếu chỉ truyền port:

```ts
app.listen(PORT)
```

Nếu app listen `127.0.0.1` bên trong container, container khác có thể không gọi được.

### App không connect được database

Kiểm tra:

- `DATABASE_URL` có dùng host `db` không?
- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` có khớp không?
- Database healthcheck healthy chưa?
- App có retry khi database restart không?
- Volume cũ có dữ liệu với user/password cũ không?

Lưu ý PostgreSQL official image chỉ dùng `POSTGRES_*` để init database lần đầu khi data directory trống. Nếu volume đã tồn tại, đổi env password không tự đổi password trong database.

Local muốn reset:

```bash
docker compose down -v
docker compose up -d
```

Chỉ làm vậy với dữ liệu local.

### Container bị restart liên tục

Kiểm tra:

```bash
docker compose ps
docker compose logs --tail 200 app
docker inspect <container> --format='{{.RestartCount}}'
```

Nguyên nhân thường gặp:

- App crash do thiếu env.
- Migration fail.
- Command sai.
- Healthcheck fail và orchestrator restart.
- OOM kill.

### Image build được nhưng run lỗi thiếu file

Kiểm tra Dockerfile:

- Có copy `dist` chưa?
- Có chạy `npm run build` chưa?
- `.dockerignore` có ignore nhầm `src`, `dist`, `package-lock.json` không?
- `CMD` trỏ đúng path chưa?

## 11. Production thật triển khai reverse proxy như nào?

### Mô hình nhỏ trên VPS

```text
Client HTTPS
-> Caddy/Nginx/Traefik container publish 80/443
-> app container expose 3000
-> db private network hoặc managed DB
```

Yêu cầu production:

- Chỉ reverse proxy publish public ports.
- App, db, redis nằm private network.
- TLS tự động bằng Caddy/Traefik hoặc certbot với Nginx.
- Access log và app log được collect.
- Có health endpoint nhẹ, không phụ thuộc quá nhiều external service.
- Có backup database.
- Có firewall chỉ mở `80/443/SSH`.
- SSH nên giới hạn IP/key, không dùng password nếu có thể.

### Mô hình cloud/orchestrator

Trên Kubernetes:

```text
Ingress/LoadBalancer -> Service -> Pods
```

Trên AWS ECS:

```text
ALB -> Target Group -> ECS Service Tasks
```

Trên cả hai mô hình, app container vẫn chỉ cần nghe port nội bộ. Public traffic vào qua load balancer/reverse proxy.

## 12. Production debugging khác local thế nào?

Local bạn có thể `exec` vào container thoải mái. Production cần kỷ luật hơn:

- Ưu tiên logs, metrics, traces trước khi exec.
- Không sửa file thủ công trong container production.
- Không cài tool debug trực tiếp vào container đang chạy.
- Không in secret ra logs.
- Có runbook cho lỗi phổ biến.
- Có dashboard health, latency, error rate, CPU/RAM.
- Có rollback image tag rõ ràng.

Debug production thường theo hướng:

```text
Alert
-> xem dashboard
-> xem logs theo request id
-> xác định version đang chạy
-> so sánh deploy gần nhất
-> rollback hoặc hotfix bằng pipeline
```

Không nên SSH vào server rồi sửa tay trong container. Cách đó làm mất tính reproducible.

## 13. Bài tập mở rộng

1. Thêm route `/ready` cho app. `/health` chỉ báo process sống, `/ready` kiểm tra app sẵn sàng nhận traffic.
2. Đổi Nginx để thêm `client_max_body_size 10m`.
3. Thêm access log format có `request_time`.
4. Tạo `compose.override.yaml` cho local publish app port 3000, còn `compose.yaml` mặc định chỉ đi qua Nginx.
5. Tạo lỗi sai `proxy_pass http://localhost:3000`, đọc log và sửa.
6. Đổi password PostgreSQL khi volume đã tồn tại, quan sát vì sao không có tác dụng, rồi reset volume local.

## 14. Checklist hoàn thành

Bạn nên làm được:

- Giải thích reverse proxy là gì.
- Biết khác nhau giữa `ports` và `expose`.
- Viết Nginx config proxy đến service Compose.
- Debug container exited bằng `docker logs` và `docker inspect`.
- Vào shell container đúng cách.
- Biết vì sao production không sửa container bằng tay.
- Hiểu mô hình public reverse proxy + private app/db.

## 15. Nguồn tham khảo chính thức

- Docker Compose services reference: https://docs.docker.com/reference/compose-file/services/
- Docker Compose startup order: https://docs.docker.com/compose/how-tos/startup-order/
- Dockerfile HEALTHCHECK reference: https://docs.docker.com/reference/dockerfile/#healthcheck
- Nginx official Docker image: https://hub.docker.com/_/nginx

